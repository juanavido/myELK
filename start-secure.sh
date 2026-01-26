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

# Levantar el stack
echo -e "${GREEN}Levantando contenedores...${NC}"
docker compose -f docker-compose-secure.yml up -d

echo ""
echo -e "${GREEN}=== Stack iniciado ===${NC}"
echo ""
echo "Esperando a que los servicios estén listos..."
echo ""
echo "Puedes verificar el estado con:"
echo "  docker compose -f docker-compose-secure.yml ps"
echo "  docker compose -f docker-compose-secure.yml logs -f"
echo ""
echo "URLs de acceso (una vez que estén listos):"
echo "  - Elasticsearch: https://localhost:9201 (usuario: elastic)"
echo "  - Kibana:        https://localhost:5601 (usuario: elastic)"
echo ""
echo -e "${YELLOW}Nota: Los navegadores mostrarán advertencia de certificado autofirmado.${NC}"
