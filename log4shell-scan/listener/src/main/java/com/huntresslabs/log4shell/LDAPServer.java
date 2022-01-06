package com.huntresslabs.log4shell;

import java.lang.reflect.Field;
import java.lang.StringBuilder;
import java.io.BufferedReader;
import java.io.Reader;
import java.io.OutputStream;
import java.io.InputStreamReader;
import java.io.UnsupportedEncodingException;
import java.io.IOException;
import java.net.URLEncoder;
import java.net.InetAddress;
import java.net.URL;
import java.net.URLDecoder;
import java.net.HttpURLConnection;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

import javax.net.ServerSocketFactory;
import javax.net.SocketFactory;
import javax.net.ssl.SSLSocketFactory;

import com.unboundid.ldap.listener.InMemoryDirectoryServer;
import com.unboundid.ldap.listener.InMemoryDirectoryServerConfig;
import com.unboundid.ldap.listener.InMemoryListenerConfig;
import com.unboundid.ldap.listener.LDAPListenerClientConnection;
import com.unboundid.ldap.listener.interceptor.InMemoryInterceptedSearchResult;
import com.unboundid.ldap.listener.interceptor.InMemoryOperationInterceptor;
import com.unboundid.ldap.sdk.LDAPResult;
import com.unboundid.ldap.sdk.ResultCode;

import org.jboss.logging.Logger;
import org.json.JSONObject;
import org.json.JSONArray;

import io.lettuce.core.RedisClient;
import io.lettuce.core.api.StatefulRedisConnection;
import io.lettuce.core.api.sync.RedisCommands;


/**
 * LDAP Server Thread which caches validated requests
 **/
public class LDAPServer
{
    private static final Logger logger = Logger.getLogger(LDAPServer.class);

    private static void log_attempt(String address, String webhook, String uuid, Boolean valid, String host, Integer port, String hostname) throws IOException {
        logger.infof("ldap query with %s uuid \"%s\" received from %s; dropping request.", valid ? "valid" : "invalid", uuid, address);
        logger.infof("Building Slack alert...");
        URL slack = new URL(webhook);
        HttpURLConnection con = (HttpURLConnection) slack.openConnection();
        con.setDoOutput(true);
        con.setRequestMethod("POST");
        con.setRequestProperty("Content-Type", "application/json");

        JSONObject payload = new JSONObject();
        JSONArray payloadAttachments = new JSONArray();
        JSONObject payloadAttachment = new JSONObject();
        JSONArray payloadAttachmentBlocks = new JSONArray();
        JSONObject payloadAttachmentBlock = new JSONObject();
        JSONObject payloadAttachmentBlockText = new JSONObject();

        String uuidDecoded = URLDecoder.decode(uuid, "utf-8");
        String exploit = String.format("${jndi:ldap://%s:%d/%s}", hostname, port, URLEncoder.encode(uuid, "utf-8"));
        payloadAttachmentBlockText.put("type", "mrkdwn");
        payloadAttachmentBlockText.put("text", String.format(
            ":exclamation: *Exploitable Log4Shell Detected on Host* :exclamation: @here\n\t- *host*: "
            +"`%s`\n\t- *path*: `%s`",
            // +"\nConfirm by running: ```curl %s -H 'User-Agent: %s'```", 
            address, uuid, uuidDecoded, exploit
        ));
        payloadAttachmentBlock.put("type", "section");
        payloadAttachmentBlock.put("text", payloadAttachmentBlockText);
        payloadAttachmentBlocks.put(payloadAttachmentBlock);
        payloadAttachment.put("color", "#ff0000");
        payloadAttachment.put("blocks", payloadAttachmentBlocks);
        payloadAttachments.put(payloadAttachment);
        payload.put("attachments", payloadAttachments);
        logger.info(String.format("Slack payload: %s", payload.toString()));

        byte[] payloadBytes = payload.toString().getBytes("utf-8");
        try(OutputStream out = con.getOutputStream()) {
            out.write(payloadBytes, 0, payloadBytes.length);
            out.flush();
        }
        logger.infof("Sent message to Slack webhook.");

        int status = con.getResponseCode();
        Reader streamReader = null;
        if (status > 299) {
            streamReader = new InputStreamReader(con.getErrorStream());
        } else {
            streamReader = new InputStreamReader(con.getInputStream());
        }
        try(BufferedReader reader = new BufferedReader(streamReader)) {
            String inputLine;
            StringBuffer content = new StringBuffer();
            while ((inputLine = reader.readLine()) != null) {
                content.append(inputLine);
            }
            logger.info(String.format("Slack response: %d: %s", status, content.toString()));
        }
        con.disconnect();

    }

    public static void run(String host, String webhook, int port, RedisClient redis, String hostname) {
        try {
            InMemoryDirectoryServerConfig config = new InMemoryDirectoryServerConfig(
                "dc=example,dc=com"
            );

            config.setListenerConfigs(new InMemoryListenerConfig(
                "listen",
                InetAddress.getByName(host),
                port,
                ServerSocketFactory.getDefault(),
                SocketFactory.getDefault(),
                (SSLSocketFactory)SSLSocketFactory.getDefault()
            ));

            config.addInMemoryOperationInterceptor(new InMemoryOperationInterceptor() {
                @Override
                public void processSearchResult ( InMemoryInterceptedSearchResult result ) {
                    String key = result.getRequest().getBaseDN();
                    StatefulRedisConnection<String, String> connection = redis.connect();

                    try {
                        RedisCommands<String, String> commands = connection.sync();
                        LDAPListenerClientConnection conn;

                        // Send an error response regardless
                        result.setResult(new LDAPResult(0, ResultCode.OPERATIONS_ERROR));

                        // This is a gross reflection block to get the client address
                        try {
                            Field field = result.getClass().getSuperclass().getDeclaredField("clientConnection");
                            field.setAccessible(true);

                            conn = (LDAPListenerClientConnection)field.get(result);
                        } catch ( Exception e2 ) {
                            e2.printStackTrace();
                            return;
                        }

                        // Build the resulting value, storing the UTC timestamp and the requestor address
                        String when = Instant.now().toString();
                        String addr = conn.getSocket().getInetAddress().toString().replaceAll("^/", "");
                        String value = addr + "/" + when;
                        Boolean valid = (commands.exists(key) != 0);

                        // Log any requests
                        try {
                            log_attempt(addr, webhook, key, valid, host, port, hostname);
                        } catch ( IOException e ) {
                            logger.error("Error while trying to log attempt.");
                            logger.error(e.toString());
                            System.exit(1);
                        }

                        // Ignore requests with invalid UUIDs
                        if ( ! valid ) {
                            return;
                        }

                        // Store this result
                        commands.lpush(key, value);

                        // Keys expire after 30 minutes from creation...
                        // commands.expire(key, 1800);
                    } finally {
                        connection.close();
                    }
                }
            });
            InMemoryDirectoryServer ds = new InMemoryDirectoryServer(config);

            ds.startListening();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
