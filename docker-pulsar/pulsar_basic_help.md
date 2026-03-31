

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


```


