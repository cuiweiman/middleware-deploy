

```bash
vi /pulsar/conf/admin_token.key # 写入 JWT Token

# 创建租户
bin/pulsar-admin --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken \
    --auth-params "file:///pulsar/conf/admin_token.key" \
    tenants create taskey_demo

bin/pulsar-admin \
  --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken \
  --auth-params "file:///pulsar/conf/admin_token.key" \
  tenants list

# 为租户创建 namespace 
bin/pulsar-admin \
  --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken \
  --auth-params "file:///pulsar/conf/admin_token.key" \
  namespaces create taskey_demo/quickstart-namespace

bin/pulsar-admin \
  --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken \
  --auth-params "file:///pulsar/conf/admin_token.key" \
  namespaces list taskey_demo

# 为租户 taskey_demo 生成 JWT:
# eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0YXNrZXlfZGVtbyJ9.KqotX6tI5BAj-3ow-8RlszK8jmb7WKhVg3xwgTygFHo
bin/pulsar tokens create \
  --secret-key file:///pulsar/conf/secret.key \
  --subject taskey_demo

# 创建2个分区的 topic
bin/pulsar-admin \
  --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken \
  --auth-params "file:///pulsar/conf/admin_token.key" \
  topics create-partitioned-topic persistent://taskey_demo/quickstart-namespace/hello-taskey -p 2

# 查看租户命名空间的 topic
bin/pulsar-admin \
  --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken \
  --auth-params "file:///pulsar/conf/admin_token.key" \
  topics list taskey_demo/quickstart-namespace

# 租户命名空间的 持久化/非持久化的 topic
bin/pulsar-admin \
  --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken \
  --auth-params "file:///pulsar/conf/admin_token.key" \
  persistent list taskey_demo/quickstart-namespace

bin/pulsar-admin \
  --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken \
  --auth-params "file:///pulsar/conf/admin_token.key" \
  non-persistent list taskey_demo/quickstart-namespace

# 查看 topic 的元数据信息, 有分区的话, 需要添加 -partition-{index} 后缀
bin/pulsar-admin \
  --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken \
  --auth-params "file:///pulsar/conf/admin_token.key" \
  topics stats persistent://taskey_demo/quickstart-namespace/hello-taskey{-partition-index}


# topic 延迟消息统计(需要启用 消息延迟)
bin/pulsar-admin \
  --auth-plugin org.apache.pulsar.client.impl.auth.AuthenticationToken \
  --auth-params "file:///pulsar/conf/admin_token.key" \
  topics stats persistent://taskey_demo/quickstart-namespace/hello-taskey --get-delayed



```


