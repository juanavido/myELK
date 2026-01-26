#!/bin/bash

# Script de inicio para ELK Stack con Seguridad
# Ejecutar desde el directorio myELK

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/config/certs"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Iniciando ELK Stack con Seguridad ===${NC}"

# Verificar que existen los certificados
if [ ! -f "${CERTS_DIR}/ca/ca.crt" ]; then
    echo -e "${YELLOW}No se encontraron certificados. Generándolos...${NC}"
    
    # Verificar openssl
    if ! command -v openssl &> /dev/null; then
        echo -e "${RED}Error: openssl no está instalado.${NC}"
        echo "Instálalo con: sudo apt-get install openssl"
        exit 1
    fi
    
    # Ejecutar script de generación de certificados
    chmod +x "${CERTS_DIR}/generate-certs.sh"
    cd "${CERTS_DIR}"
    ./generate-certs.sh
    cd "${SCRIPT_DIR}"
fi

# Verificar que existe el .env
if [ ! -f "${SCRIPT_DIR}/.env" ]; then
    echo -e "${YELLOW}Copiando archivo .env desde .env.secure...${NC}"
    cp "${SCRIPT_DIR}/.env.secure" "${SCRIPT_DIR}/.env"
    echo -e "${YELLOW}¡IMPORTANTE! Edita el archivo .env para cambiar las contraseñas por defecto.${NC}"
fi

# Levantar primero Elasticsearch (3 nodos)
echo -e "${GREEN}Levantando Elasticsearch (3 nodos)...${NC}"
docker compose -f docker-compose-secure.yml up -d elasticsearch01 elasticsearch02 elasticsearch03

# Configurar usuario kibana_system automáticamente
echo -e "${GREEN}Configurando usuario kibana_system...${NC}"
if ./setup-users.sh; then
    echo -e "${GREEN}✓ kibana_system configurado correctamente.${NC}"
else
    echo -e "${YELLOW}⚠ No se pudo configurar kibana_system automáticamente. Puedes ejecutar ./setup-users.sh manualmente.${NC}"
fi

# Levantar el resto de servicios (Kibana, Logstash, Beats)
echo -e "${GREEN}Levantando Kibana, Logstash y Beats...${NC}"
docker compose -f docker-compose-secure.yml up -d kibana logstash filebeat metricbeat

echo ""
echo -e "${GREEN}=== Stack iniciado ===${NC}"
echo ""
echo "Puedes verificar el estado con:"
echo "  docker compose -f docker-compose-secure.yml ps"
echo "  docker compose -f docker-compose-secure.yml logs -f"
echo ""
echo "URLs de acceso (una vez que estén listos):"
echo "  - Elasticsearch: https://localhost:9201 (usuario: elastic)"
echo "  - Kibana:        https://localhost:5601 (usuario: kibana_system)"
echo ""
echo -e "${YELLOW}Nota: Los navegadores mostrarán advertencia de certificado autofirmado.${NC}"
