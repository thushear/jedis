package com.github.thushear.jedis;

import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import redis.clients.jedis.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.concurrent.TimeUnit;

/**
 * Created by kongming on 2017/3/29.
 */
public class AdvancedUsage {

    JedisPool jedisPool = new JedisPool("192.168.159.130",6380);


    List<JedisShardInfo> shards = new ArrayList<>();

    ShardedJedisPool shardedJedisPool;


    @Before
    public void setUp(){



        JedisShardInfo shard1 = new JedisShardInfo("192.168.159.130",6379);
        JedisShardInfo shard2 = new JedisShardInfo("192.168.159.130",6380);
        shards.add(shard1);
        shards.add(shard2);
        shardedJedisPool = new ShardedJedisPool(new JedisPoolConfig(),shards,ShardedJedis.DEFAULT_KEY_TAG_PATTERN);
    }

    @After
    public void tearDown(){
        jedisPool.destroy();
        shardedJedisPool.destroy();
    }



    @Test
    public void testMonitor() throws InterruptedException {
        try (Jedis jedis = jedisPool.getResource()) {
            jedis.monitor(new JedisMonitor() {
                @Override
                public void onCommand(String command) {
                    System.out.println("command = " + command);
                }
            });
        }



    }


    @Test
    public void testKeyTag(){

        try (ShardedJedis shardedJedis = shardedJedisPool.getResource()) {
            shardedJedis.set("aaa{keytag}","aaa");
            shardedJedis.set("bbb{keytag}","bbb");

        }
    }


    @Test
    public void testShardedJedis(){
        List<JedisShardInfo> shards = new ArrayList<>();
        JedisShardInfo shard1 = new JedisShardInfo("192.168.159.130",6379);
        JedisShardInfo shard2 = new JedisShardInfo("192.168.159.130",6380);
        shards.add(shard1);
        shards.add(shard2);
        ShardedJedisPool shardedJedisPool = new ShardedJedisPool(new JedisPoolConfig(),shards);
        try(ShardedJedis shardedJedis = shardedJedisPool.getResource()) {
            shardedJedis.set("aaaa","aaaa");
            shardedJedis.set("bbbb","bbbb");

        }

        shardedJedisPool.destroy();
    }



    @Test
    public void testPipeLine(){
        try(Jedis jedis = jedisPool.getResource()) {
            Pipeline pipeline = jedis.pipelined();
            pipeline.set("ppp","pipeline");
            pipeline.zadd("pzset",Double.valueOf(11),"1");
            pipeline.zadd("pzset",Double.valueOf(22),"2");
            Response<String> pipeGet =  pipeline.get("ppp");
            Response<Set<String>> zsetResp = pipeline.zrange("pzset",0,10);
            pipeline.sync();
            System.out.println("zsetResp = " + zsetResp.get());
            System.out.println("pipeGet = " + pipeGet.get());
        }

    }





    @Test
    public void testPrint(){
        StringBuilder stringBuilder = new StringBuilder();
        stringBuilder.append("commentId=" + 111).append("\t\n").append("\n").append("score").append("=" + 111);
        System.out.println(stringBuilder.toString());
        System.out.println("commentId=10175910421\\nold\\t105.63136084615044\\t4.849599958826386\\t20.0\\t60.0\\t20.781760887324054\\t0.0\\t0.0\\t0.0\\tnull\\t\\nnew\\t105.63136084615044\\t4.849599958826386\\t20.0\\t60.0\\t20.781760887324054\\t0.0\\t0.0\\t0.0\\tnull\\t\\n");
    }


    @Test
    public void testTranscation() throws InterruptedException {
        JedisPool jedisPool = new JedisPool("192.168.159.130",6380);
        try(Jedis jedis = jedisPool.getResource()) {

            Transaction transaction = jedis.multi();
            Response<String> setResponse = transaction.set("ttt11","transcation");

            transaction.append("ttt","tttttt");
            Response<String> getResponse = transaction.get("ttt11");
            getResponse.wait();


            Response<Long> zaddResp = transaction.zadd("zzz111", Double.valueOf(100),"z1");

            transaction.exec();
            System.out.println(setResponse.get());
            System.out.println(zaddResp.get());

        }

        jedisPool.destroy();
    }

}
