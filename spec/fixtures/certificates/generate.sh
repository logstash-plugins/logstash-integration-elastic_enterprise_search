# Warning: do not use the certificates produced by this tool in production. This is for testing purposes only

openssl genrsa 4096 | openssl pkcs8 -topk8 -nocrypt -out root_ca.key
openssl req -sha256 -x509 -newkey rsa:4096 -nodes -key root_ca.key -sha256 -days 365 -out root_ca.crt -subj "/C=ES/ST=The Internet/L=The Internet/O=Logstash CA/OU=Logstash/CN=enterprise_search"
openssl req -sha256 -x509 -newkey rsa:4096 -nodes -key root_ca.key -sha256 -days 365 -out root_untrusted_ca.crt -subj "/C=ES/ST=The Darknet/L=The Darknet/O=Logstash CA/OU=Logstash/CN=127.0.0.1"
openssl pkcs12 -export -in root_ca.crt -inkey root_ca.key -out root_keystore.p12 -password pass:changeme -name ent-search
keytool -importkeystore -srckeystore root_keystore.p12 -destkeystore root_keystore.jks -srcstoretype PKCS12 -deststoretype jks -srcstorepass changeme -deststorepass changeme -srcalias ent-search -destalias ent-search -srckeypass changeme -destkeypass changeme

rm -rf root_keystore.p12
rm -rf *.csr