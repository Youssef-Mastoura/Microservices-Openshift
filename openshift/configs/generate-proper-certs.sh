#!/bin/bash
set -e

echo "=== Generating proper Kafka SSL certificates ==="

# Clean up any old files
rm -rf certs
mkdir -p certs
cd certs

# 1. Generate CA certificate
echo "1. Generating CA certificate..."
openssl req -new -x509 -keyout ca-key.pem -out ca-cert.pem \
  -days 365 -subj "/CN=kafka-ca/O=Microservices" \
  -passout pass:kafka123

# 2. Generate Kafka server keystore
echo "2. Generating Kafka server keystore..."
keytool -keystore kafka.server.keystore.jks -alias kafka-server \
  -validity 365 -genkey -keyalg RSA \
  -storepass kafka123 -keypass kafka123 \
  -dname "CN=kafka-cluster, O=Microservices" \
  -ext "SAN=DNS:kafka-cluster,DNS:kafka-cluster.microservices.svc.cluster.local,IP:127.0.0.1"

# 3. Import CA into keystore
echo "3. Importing CA into keystore..."
keytool -keystore kafka.server.keystore.jks -alias ca-cert \
  -import -file ca-cert.pem \
  -storepass kafka123 -noprompt

# 4. Create certificate signing request
echo "4. Creating CSR..."
keytool -keystore kafka.server.keystore.jks -alias kafka-server \
  -certreq -file kafka-server.csr \
  -storepass kafka123

# 5. Sign certificate with CA
echo "5. Signing certificate..."
openssl x509 -req -CA ca-cert.pem -CAkey ca-key.pem \
  -in kafka-server.csr -out kafka-server.crt \
  -days 365 -CAcreateserial -passin pass:kafka123

# 6. Import signed certificate
echo "6. Importing signed certificate..."
keytool -keystore kafka.server.keystore.jks -alias kafka-server \
  -import -file kafka-server.crt \
  -storepass kafka123 -noprompt

# 7. Create truststore
echo "7. Creating truststore..."
keytool -keystore kafka.server.truststore.jks -alias ca-cert \
  -import -file ca-cert.pem \
  -storepass kafka123 -noprompt

# 8. Generate client certificates
echo "8. Generating client certificates..."
for service in kafka-exporter orders-service users-service; do
  echo "  - Generating for $service..."
  
  # Generate key and CSR
  openssl req -new -newkey rsa:2048 -nodes \
    -keyout ${service}-key.pem \
    -out ${service}.csr \
    -subj "/CN=${service}/O=Microservices"
  
  # Sign with CA
  openssl x509 -req -CA ca-cert.pem -CAkey ca-key.pem \
    -in ${service}.csr -out ${service}-certificate.pem \
    -days 365 -CAcreateserial -passin pass:kafka123
  
  rm ${service}.csr
done

# 9. Base64 encode for Kubernetes
echo "9. Base64 encoding for Kubernetes..."
for file in *.jks *.pem; do
  if [ -f "$file" ]; then
    base64 -w 0 "$file" > "${file}.b64"
    echo "  Encoded: $file"
  fi
done

# 10. Create updated YAML files
echo "10. Creating updated YAML files..."

# Kafka secrets
cat > updated-kafka-secrets.yml << 'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: kafka-secrets
  namespace: microservices
type: Opaque
data:
  kafka.server.keystore.jks: $(cat kafka.server.keystore.jks.b64)
  kafka.server.truststore.jks: $(cat kafka.server.truststore.jks.b64)
  ca-cert.pem: $(cat ca-cert.pem.b64)
YAML

# Kafka exporter secrets
cat > updated-kafka-exporter-secrets.yml << 'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: kafka-exporter-secrets
  namespace: microservices
type: Opaque
data:
  kafka-exporter-key.pem: $(cat kafka-exporter-key.pem.b64)
  kafka-exporter-certificate.pem: $(cat kafka-exporter-certificate.pem.b64)
  ca-cert.pem: $(cat ca-cert.pem.b64)
YAML

# Orders service secrets
cat > updated-orders-service-secrets.yml << 'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: orders-service-kafka-secrets
  namespace: microservices
type: Opaque
data:
  orders-service-key.pem: $(cat orders-service-key.pem.b64)
  orders-service-certificate.pem: $(cat orders-service-certificate.pem.b64)
  ca-cert.pem: $(cat ca-cert.pem.b64)
YAML

# Users service secrets
cat > updated-users-service-secrets.yml << 'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: users-service-kafka-secrets
  namespace: microservices
type: Opaque
data:
  users-service-key.pem: $(cat users-service-key.pem.b64)
  users-service-certificate.pem: $(cat users-service-certificate.pem.b64)
  ca-cert.pem: $(cat ca-cert.pem.b64)
YAML

echo "=== Verification ==="
echo "Checking generated files:"
keytool -list -keystore kafka.server.keystore.jks -storepass kafka123 | head -10

echo ""
echo "=== DONE ==="
echo "Certificates generated in: $(pwd)"
echo "Apply with:"
echo "kubectl apply -f updated-*.yml -n microservices"
