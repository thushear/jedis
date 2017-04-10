package com.github.thushear.jedis;

import com.sohu.tv.builder.ClientBuilder;
import org.apache.commons.pool2.impl.GenericObjectPoolConfig;
import org.junit.Test;
import redis.clients.jedis.JedisCluster;
import redis.clients.jedis.JedisPool;

import java.util.Map;

/**
 * Created by kongming on 2017/4/10.
 */
public class CacheCloudTest {


    @Test
    public void testCache(){
        GenericObjectPoolConfig poolConfig = new GenericObjectPoolConfig();
        JedisCluster redisCluster = ClientBuilder.redisCluster(10000)
                .setJedisPoolConfig(poolConfig)
                .setConnectionTimeout(1000)
                .setSoTimeout(1000)
                .setMaxRedirections(5)
                .build();
        redisCluster.set("kv","v1");
        Map<String,JedisPool> map = redisCluster.getClusterNodes();
        System.out.println(map);
        System.out.println(redisCluster.get("kv"));

    }



}
