#!/bin/bash

#get enviroment variable
. /etc/profile

version=2.8.17_ucs
server_dir=/export/servers
data_dir=/export/Data/redis_data
log_dir=/export/Logs/redis
pid_dir=/export/Data/redis_pid
agent_dir=`pwd`


check_port() {
	echo "Checking instance port ..."

    if ! echo $1 | grep -q -E "^[0-9]+$"
    then
        echo "The port $1 you provided is not integer!" && exit 1
	fi

    if netstat -tlpn | grep "\b$1\b"
    then
	    echo >&2 "port:$port is using, exit!" && exit 1
    fi
}

download_package() {
	cd $server_dir
	if [ ! -e redis-$version.tar.gz ]
	then
		echo "Getting redis package by wget, waiting ..."
	    if ! wget -O redis-$version.tar.gz "http://172.22.190.64/upload/redis-$version.tar.gz"
	    then
		    echo >&2 "Can't get redis package, exit!"
		    /bin/rm -fr redis-$version.tar.gz
		    exit 1
	    fi
	    tar xzvf redis-$version.tar.gz
	fi
}

deploy() {
	mkdir -p $server_dir $data_dir $log_dir $pid_dir

	while [ $# -gt 0 ]
	do
		case $1 in
		-port|--port)
	        if [ -z $2 ]
	        then
		        echo >&2 "you must provide redis instance ports, exit!" && exit 1
            else
	            local p1=`echo $2 | awk -F- '{print $1}'`
	            local p2=`echo $2 | awk -F- '{print $2}'`
                if [ -z $p1 ] || [ -z $p2 ]
                then
                    local ports=$2
                else
                    if [ $p1 -le $p2 ]
                    then
                        local ports=`seq $p1 $p2`
                    else
                        local ports=`seq $p2 $p1`
                    fi
                fi

                for port in $ports
                do
                    check_port $port
                done
	        fi
			shift
			;;
		-version|--version)
			version=$2
			shift
			;;
		esac
		shift
	done

	echo "Deploying redis instance $version ..."
    echo "Downloading package ..." && download_package
	redis_dir=${server_dir}/redis-${version}

    for port in $ports
    do
        mkdir -p $data_dir/$port
	    cd $redis_dir && make clean && make distclean && make && cd conf && cp redis-template.conf redis_$port.conf

	    sed -i "s:\${port}:${port}:g; s:\${data_dir}:${data_dir//\//\/}:g; s:\${log_dir}:${log_dir//\//\/}:g; s:\${pid_dir}:${pid_dir//\//\/}:g" redis_${port}.conf
	    while [ $# -gt 0 ]
	    do
	    	case $1 in
            -port|-version|--port|--version)
                shift
                ;;
	    	-*|--*)
	    		key=${1##*-}
	    		value=$2
	    		sed -i "s/^$key\s*.*$/$key $value/g" redis_$port.conf
	    		shift
	    		;;
	    	*)
	    		echo "Unrecognized option, you must provide redis parameters!"
	    		exit 1
	    		;;
	    	esac
	    	shift
	    done

		start $port
		save_deploy_info $port
    done
    echo "Done."
}

start() {
	[ $# -eq 0 ] && echo "Instance port must be provided!" && exit 1
    for port in "$@"
    do
	    pid=`netstat -ntlp | grep -w $port | head -1 | awk '{print $7}' | cut -d '/' -f1`
	    if [ -z $pid ]
	    then
	    	if [ -z $redis_dir ]
	    	then
	    		local cmd=`cat $agent_dir/.deploy_info | grep $port | awk '{print $2" "$3}'`
	    		if [ -z "$cmd" ]
	    		then
	    			echo "No such instance deployed on this machine. Skipped. "
	    		else
	    			nohup $cmd > $log_dir/nohup_$port.log 2>&1 &
	    		fi
	    	else
	    		nohup $redis_dir/src/redis-server $redis_dir/conf/redis_$port.conf > $log_dir/nohup_$port.log 2>&1 &
	    	fi
	    	echo "$port started."
	    else
	    	echo "There is already one instance running at $port port. Skip!"
	    fi
    done
}

restart() {
	[ $# -eq 0 ] && echo "Instance port must be provided!" && exit 1
    for port in "$@"
    do
	    pid=`netstat -ntlp | grep -w $port | head -1 | awk '{print $7}' | cut -d '/' -f1`
	    if [ -z $pid ]
	    then
	    	echo "There is no instance running at $port port."
	    else
	    	cd `ls -l /proc/$pid/exe | sed 's/.*\s//;s/redis-server//'` && cd ..
	    	redis_dir=`pwd`
	    	if [ -e $redis_dir/src/redis-server ]
	    	then
	    		if [ -e $redis_dir/src/redis-cli ]
	    		then
	    			$redis_dir/src/redis-cli -p $port shutdown save
	    			if [ $? -ne 0 ] 
	    			then
	    				kill -s TERM $pid
	    			fi
	    		else
	    			kill -s TERM $pid
	    		fi
	    		sleep 2
	    		nohup $redis_dir/src/redis-server $redis_dir/conf/redis_$port.conf > $log_dir/nohup_$port.log 2>&1 &
	    		echo "$port restart."
	    	fi
	    fi
    done
}

stop() {
	[ $# -eq 0 ] && echo "Instance port must be provided!" && exit 1
    for port in "$@"
    do
	    pid=`netstat -ntlp | grep -w $port | head -1 | awk '{print $7}' | cut -d '/' -f1`
	    if [ -z $pid ]
	    then
	    	echo "There is no instance running at $port port. Stopped already."
	    else
	    	save_deploy_info $port
	    	local redis_cli=`ls -l /proc/$pid/exe | sed 's/.*\s//;s/redis-server/redis-cli/'`
	    	if [ -e $redis_cli ]
	    	then
	    		$redis_cli -p $port shutdown save
	    		if [ $? -ne 0 ] 
	    		then
	    			echo "This instance can't be shutdown by command, forced to close!"
	    			kill -s TERM $pid
	    		fi
	    	else
	    		echo "This instance wasn't deployed in normal, forced to close!"
	    		kill -s TERM $pid
	    	fi
	    	echo "$port stopped."
	    fi
    done
}

status() {
	[ $# -ne 1 ] && echo "Instance port must be provided!" && exit 1
	if [ -z `netstat -ntlp | grep -w $1 | head -1 | awk '{print $7}' | cut -d '/' -f1` ]
	then
		echo "Stopped!"
	else
		echo "Running..."
	fi
}

list() {
	for item in `ps -ef | grep 'redis-server' | awk '{print $8"|"$9}' | grep -v '^grep'`
	do
		local app=${item%|*}
		local conf=${item#*|}
		if echo $conf | grep -q -E '^\*:[0-9]+$'
		then
			port=`echo $conf | grep -o -E '[0-9]+'`
			conf=`${app/%redis-server/redis-cli} -p $port info | grep 'config_file' | cut -d ':' -f2`
		else
			port=`echo ${conf##/*/} | grep -o -E '[0-9]+'`
		fi
		echo "$port  $app  $conf"
	done
}

authorize() {
	if [ $UID -eq 0 ]
	then
		chown -R admin $data_dir $log_dir $pid_dir $redis_dir
	fi
}

save_deploy_info() {
	local app=`ps -ef |grep 'redis-server' | grep "[^0-9]$1[^0-9]" | awk '{print $8}'`
	local conf=`ps -ef |grep 'redis-server' | grep "[^0-9]$1[^0-9]" | awk '{print $9}'`
	if echo $conf | grep -q -E '^\*:[0-9]+$'
	then
		conf=`${app/%redis-server/redis-cli} -p $1 info | grep 'config_file' | cut -d ':' -f2 | tr -d '[:space:]'`
	fi

	if echo $conf | grep -q -E '^\/.+$'
	then
		touch $agent_dir/.deploy_info
		if grep -q $1 $agent_dir/.deploy_info
		then
			sed -i "s:^$1\s*.*$:${1}\t${app//\//\/}\t${conf//\//\/}:g" $agent_dir/.deploy_info
		else
			echo "$1	$app	$conf" >> $agent_dir/.deploy_info
		fi
	fi
}

start_all() {
	cat $agent_dir/.deploy_info | while read line
	do
		local port=`echo $line | awk '{print $1}'`
		local cmd=`echo $line | awk '{print $2" "$3}'`
		if [ -n "$cmd" ]
		then
			nohup $cmd > $log_dir/nohup_$port.log 2>&1 &
		fi
	done
}

help() {
	echo "Usage: ./`basename $0` {restart|start|stop|status|list|startall|deploy [OPTION VAL]... -port} PORT"
}


if [ $# -eq 0 ]
then
	help
else
	case $1 in
	deploy)
		shift
		if deploy $@
		then
		    authorize
            echo -e "\n"
            list
		fi
		;;
	start)
		shift
		start $@
		;;
	restart)
		shift
		restart $@
		;;
	stop)
		shift
		stop $@
		;;
	status)
		shift
		status $@
		;;
	list)
		list
		;;
	startall)
		start_all
		;;
	*|-h|--help)
		help
		;;
	esac
fi

exit 0


