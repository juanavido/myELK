#!/bin/bash

# Script para generar certificados autofirmados para el stack ELK
# Requiere: openssl

set -e

CERTS_DIR="$(cd "$(dirname "$0")" && pwd)"
CA_DIR="${CERTS_DIR}/ca"
DAYS_VALID=365
KEY_SIZE=2048

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Generador de Certificados para ELK Stack ===${NC}"

# Verificar que openssl está instalado
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}Error: openssl no está instalado.${NC}"
    echo "Instálalo con:"
    echo "  Ubuntu/Debian: sudo apt-get install openssl"
    echo "  CentOS/RHEL:   sudo yum install openssl"
    echo "  Alpine:        apk add openssl"
    exit 1
fi

# Crear directorios
echo -e "${YELLOW}Creando estructura de directorios...${NC}"
mkdir -p "${CA_DIR}"
mkdir -p "${CERTS_DIR}/elasticsearch"
mkdir -p "${CERTS_DIR}/kibana"
mkdir -p "${CERTS_DIR}/logstash"
mkdir -p "${CERTS_DIR}/filebeat"
mkdir -p "${CERTS_DIR}/metricbeat"

# Limpiar certificados anteriores (opcional)
read -p "¿Deseas eliminar certificados existentes? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo -e "${YELLOW}Limpiando certificados anteriores...${NC}"
    rm -f "${CA_DIR}"/*.pem "${CA_DIR}"/*.crt "${CA_DIR}"/*.key
    rm -f "${CERTS_DIR}/elasticsearch"/*.pem "${CERTS_DIR}/elasticsearch"/*.crt "${CERTS_DIR}/elasticsearch"/*.key "${CERTS_DIR}/elasticsearch"/*.p12
    rm -f "${CERTS_DIR}/kibana"/*.pem "${CERTS_DIR}/kibana"/*.crt "${CERTS_DIR}/kibana"/*.key
    rm -f "${CERTS_DIR}/logstash"/*.pem "${CERTS_DIR}/logstash"/*.crt "${CERTS_DIR}/logstash"/*.key "${CERTS_DIR}/logstash"/*.p12
    rm -f "${CERTS_DIR}/filebeat"/*.pem "${CERTS_DIR}/filebeat"/*.crt "${CERTS_DIR}/filebeat"/*.key
    rm -f "${CERTS_DIR}/metricbeat"/*.pem "${CERTS_DIR}/metricbeat"/*.crt "${CERTS_DIR}/metricbeat"/*.key
fi

# =====================================================
# 1. Generar CA (Certificate Authority)
# =====================================================
echo -e "${GREEN}[1/7] Generando Certificate Authority (CA)...${NC}"

# Generar clave privada de la CA
openssl genrsa -out "${CA_DIR}/ca.key" ${KEY_SIZE}

# Generar certificado de la CA
openssl req -x509 -new -nodes \
    -key "${CA_DIR}/ca.key" \
    -sha256 \
    -days ${DAYS_VALID} \
    -out "${CA_DIR}/ca.crt" \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=MyOrg/OU=IT/CN=ELK-CA"

echo -e "${GREEN}   ✓ CA generada: ${CA_DIR}/ca.crt${NC}"

# =====================================================
# 2. Generar certificado para Elasticsearch
# =====================================================
echo -e "${GREEN}[2/7] Generando certificados para Elasticsearch...${NC}"

# Crear archivo de extensiones para SAN (Subject Alternative Names)
cat > "${CERTS_DIR}/elasticsearch/elasticsearch.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = elasticsearch
DNS.2 = elasticsearch01
DNS.3 = elasticsearch02
DNS.4 = elasticsearch03
DNS.5 = es-local-node-01
DNS.6 = es-local-node-02
DNS.7 = es-local-node-03
DNS.8 = localhost
IP.1 = 127.0.0.1
IP.2 = 192.168.64.1
EOF

# Generar clave privada
openssl genrsa -out "${CERTS_DIR}/elasticsearch/elasticsearch.key" ${KEY_SIZE}

# Generar CSR (Certificate Signing Request)
openssl req -new \
    -key "${CERTS_DIR}/elasticsearch/elasticsearch.key" \
    -out "${CERTS_DIR}/elasticsearch/elasticsearch.csr" \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=MyOrg/OU=IT/CN=elasticsearch"

# Firmar el certificado con la CA
openssl x509 -req \
    -in "${CERTS_DIR}/elasticsearch/elasticsearch.csr" \
    -CA "${CA_DIR}/ca.crt" \
    -CAkey "${CA_DIR}/ca.key" \
    -CAcreateserial \
    -out "${CERTS_DIR}/elasticsearch/elasticsearch.crt" \
    -days ${DAYS_VALID} \
    -sha256 \
    -extfile "${CERTS_DIR}/elasticsearch/elasticsearch.ext"

# Crear PKCS12 keystore para Elasticsearch
openssl pkcs12 -export \
    -in "${CERTS_DIR}/elasticsearch/elasticsearch.crt" \
    -inkey "${CERTS_DIR}/elasticsearch/elasticsearch.key" \
    -certfile "${CA_DIR}/ca.crt" \
    -out "${CERTS_DIR}/elasticsearch/elasticsearch.p12" \
    -password pass:changeit

echo -e "${GREEN}   ✓ Certificados Elasticsearch generados${NC}"

# =====================================================
# 3. Generar certificado para Kibana
# =====================================================
echo -e "${GREEN}[3/7] Generando certificados para Kibana...${NC}"

cat > "${CERTS_DIR}/kibana/kibana.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = kibana
DNS.2 = kibana-local
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF

openssl genrsa -out "${CERTS_DIR}/kibana/kibana.key" ${KEY_SIZE}

openssl req -new \
    -key "${CERTS_DIR}/kibana/kibana.key" \
    -out "${CERTS_DIR}/kibana/kibana.csr" \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=MyOrg/OU=IT/CN=kibana"

openssl x509 -req \
    -in "${CERTS_DIR}/kibana/kibana.csr" \
    -CA "${CA_DIR}/ca.crt" \
    -CAkey "${CA_DIR}/ca.key" \
    -CAcreateserial \
    -out "${CERTS_DIR}/kibana/kibana.crt" \
    -days ${DAYS_VALID} \
    -sha256 \
    -extfile "${CERTS_DIR}/kibana/kibana.ext"

echo -e "${GREEN}   ✓ Certificados Kibana generados${NC}"

# =====================================================
# 4. Generar certificado para Logstash
# =====================================================
echo -e "${GREEN}[4/7] Generando certificados para Logstash...${NC}"

cat > "${CERTS_DIR}/logstash/logstash.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = logstash
DNS.2 = logstash-local
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF

openssl genrsa -out "${CERTS_DIR}/logstash/logstash.key" ${KEY_SIZE}

openssl req -new \
    -key "${CERTS_DIR}/logstash/logstash.key" \
    -out "${CERTS_DIR}/logstash/logstash.csr" \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=MyOrg/OU=IT/CN=logstash"

openssl x509 -req \
    -in "${CERTS_DIR}/logstash/logstash.csr" \
    -CA "${CA_DIR}/ca.crt" \
    -CAkey "${CA_DIR}/ca.key" \
    -CAcreateserial \
    -out "${CERTS_DIR}/logstash/logstash.crt" \
    -days ${DAYS_VALID} \
    -sha256 \
    -extfile "${CERTS_DIR}/logstash/logstash.ext"

# Crear PKCS12 para Logstash
openssl pkcs12 -export \
    -in "${CERTS_DIR}/logstash/logstash.crt" \
    -inkey "${CERTS_DIR}/logstash/logstash.key" \
    -certfile "${CA_DIR}/ca.crt" \
    -out "${CERTS_DIR}/logstash/logstash.p12" \
    -password pass:changeit

echo -e "${GREEN}   ✓ Certificados Logstash generados${NC}"

# =====================================================
# 5. Generar certificado para Filebeat
# =====================================================
echo -e "${GREEN}[5/7] Generando certificados para Filebeat...${NC}"

cat > "${CERTS_DIR}/filebeat/filebeat.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = filebeat
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

openssl genrsa -out "${CERTS_DIR}/filebeat/filebeat.key" ${KEY_SIZE}

openssl req -new \
    -key "${CERTS_DIR}/filebeat/filebeat.key" \
    -out "${CERTS_DIR}/filebeat/filebeat.csr" \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=MyOrg/OU=IT/CN=filebeat"

openssl x509 -req \
    -in "${CERTS_DIR}/filebeat/filebeat.csr" \
    -CA "${CA_DIR}/ca.crt" \
    -CAkey "${CA_DIR}/ca.key" \
    -CAcreateserial \
    -out "${CERTS_DIR}/filebeat/filebeat.crt" \
    -days ${DAYS_VALID} \
    -sha256 \
    -extfile "${CERTS_DIR}/filebeat/filebeat.ext"

echo -e "${GREEN}   ✓ Certificados Filebeat generados${NC}"

# =====================================================
# 6. Generar certificado para Metricbeat
# =====================================================
echo -e "${GREEN}[6/7] Generando certificados para Metricbeat...${NC}"

cat > "${CERTS_DIR}/metricbeat/metricbeat.ext" << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = metricbeat
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

openssl genrsa -out "${CERTS_DIR}/metricbeat/metricbeat.key" ${KEY_SIZE}

openssl req -new \
    -key "${CERTS_DIR}/metricbeat/metricbeat.key" \
    -out "${CERTS_DIR}/metricbeat/metricbeat.csr" \
    -subj "/C=ES/ST=Madrid/L=Madrid/O=MyOrg/OU=IT/CN=metricbeat"

openssl x509 -req \
    -in "${CERTS_DIR}/metricbeat/metricbeat.csr" \
    -CA "${CA_DIR}/ca.crt" \
    -CAkey "${CA_DIR}/ca.key" \
    -CAcreateserial \
    -out "${CERTS_DIR}/metricbeat/metricbeat.crt" \
    -days ${DAYS_VALID} \
    -sha256 \
    -extfile "${CERTS_DIR}/metricbeat/metricbeat.ext"

echo -e "${GREEN}   ✓ Certificados Metricbeat generados${NC}"

# =====================================================
# 7. Establecer permisos
# =====================================================
echo -e "${GREEN}[7/7] Estableciendo permisos...${NC}"

# Permisos restrictivos para claves privadas
chmod 600 "${CA_DIR}/ca.key"
chmod 600 "${CERTS_DIR}/elasticsearch/elasticsearch.key"
chmod 600 "${CERTS_DIR}/kibana/kibana.key"
chmod 600 "${CERTS_DIR}/logstash/logstash.key"
chmod 600 "${CERTS_DIR}/filebeat/filebeat.key"
chmod 600 "${CERTS_DIR}/metricbeat/metricbeat.key"

# Permisos de lectura para certificados
chmod 644 "${CA_DIR}/ca.crt"
chmod 644 "${CERTS_DIR}/elasticsearch/elasticsearch.crt"
chmod 644 "${CERTS_DIR}/kibana/kibana.crt"
chmod 644 "${CERTS_DIR}/logstash/logstash.crt"
chmod 644 "${CERTS_DIR}/filebeat/filebeat.crt"
chmod 644 "${CERTS_DIR}/metricbeat/metricbeat.crt"

# Limpiar archivos temporales
rm -f "${CERTS_DIR}"/*/*.csr
rm -f "${CERTS_DIR}"/*/*.ext
rm -f "${CA_DIR}"/*.srl

echo ""
echo -e "${GREEN}=== Certificados generados exitosamente ===${NC}"
echo ""
echo "Estructura creada:"
echo "  ${CERTS_DIR}/"
echo "  ├── ca/"
echo "  │   ├── ca.crt          (Certificado CA)"
echo "  │   └── ca.key          (Clave privada CA)"
echo "  ├── elasticsearch/"
echo "  │   ├── elasticsearch.crt"
echo "  │   ├── elasticsearch.key"
echo "  │   └── elasticsearch.p12"
echo "  ├── kibana/"
echo "  │   ├── kibana.crt"
echo "  │   └── kibana.key"
echo "  ├── logstash/"
echo "  │   ├── logstash.crt"
echo "  │   ├── logstash.key"
echo "  │   └── logstash.p12"
echo "  ├── filebeat/"
echo "  │   ├── filebeat.crt"
echo "  │   └── filebeat.key"
echo "  └── metricbeat/"
echo "      ├── metricbeat.crt"
echo "      └── metricbeat.key"
echo ""
echo -e "${YELLOW}Password para keystores PKCS12: changeit${NC}"
echo ""
echo "Ahora puedes ejecutar: docker compose up -d"
