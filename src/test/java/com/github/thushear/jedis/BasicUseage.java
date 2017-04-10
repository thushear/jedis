package com.github.thushear.jedis;

import org.junit.Test;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;

/**
 * Created by kongming on 2017/3/28.
 */
public class BasicUseage {

    @Test
    public void testPool(){
        JedisPool jedisPool = new JedisPool("192.168.159.130",6380);
        try(Jedis jedis = jedisPool.getResource()) {
            jedis.set("foo","bar");
            String fooValue = jedis.get("foo");
            System.out.println("fooValue = " + fooValue);

        }

        jedisPool.destroy();

    }



}
