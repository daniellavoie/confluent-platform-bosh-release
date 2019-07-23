# Output SSL Handshake info from running component

Add the following JVM param to the component you are looking to debug:

```
-Djava.net.debug=all
```

# Security Cheatsheet

CONFIG_DIR=/var/vcap/jobs/confluent-connect/config
KEY_TOOL=$JAVA_HOME/bin/keytool
KEYSTORE_PASSWORD=<%= p("keystore_password") %>

TRUST_STORE=$CONFIG_DIR/generated.truststore.jks
KEY_STORE=$CONFIG_DIR/generated.keystore.jks
P12_STORE=$CONFIG_DIR/generated.key.p12

# Writing trust store

```
$KEY_TOOL \
  -noprompt \
  -import \
  -storepass $KEYSTORE_PASSWORD \
  -keystore $TRUST_STORE \
  -storetype PKCS12 \
  -file $CONFIG_DIR/ca_certs.pem
```

# Converting key/cert into PKCS12"

```
openssl pkcs12 \
  -export \
  -in $CONFIG_DIR/cert.pem \
  -inkey $CONFIG_DIR/key.pem \
  -out $P12_STORE \
  -password pass:$KEYSTORE_PASSWORD \
  -name localhost
```

# Writing key store

```
$KEY_TOOL -importkeystore \
  -deststorepass $KEYSTORE_PASSWORD \
  -destkeypass $KEYSTORE_PASSWORD \
  -destkeystore $KEY_STORE \
  -deststoretype PKCS12 \
  -srckeystore $P12_STORE \
  -srcstoretype PKCS12 \
  -srcstorepass $KEYSTORE_PASSWORD \
  -srckeypass $KEYSTORE_PASSWORD \
  -alias localhost
```

# Test a certificate served by a socket

```
export URL=my-service:port
export CA_CERT=my-ca-cert.pem

openssl s_client -showcerts -connect $URL -CAfile $CA_CERT
```
