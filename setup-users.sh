#!/bin/bash

# Script para configurar usuarios de Kibana después del primer inicio
# Ejecutar después de que Elasticsearch esté funcionando

set -e

# Cargar variables de entorno
source .env

ES_HOST="https://localhost:9201"
CA_CERT="./config/certs/ca/ca.crt"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Configurando usuario kibana_system ===${NC}"

# Esperar a que Elasticsearch esté listo
echo "Esperando a que Elasticsearch esté disponible..."
until curl --cacert ${CA_CERT} -s -u "elastic:${ELASTIC_PASSWORD}" "${ES_HOST}/_cluster/health" > /dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo ""
echo -e "${GREEN}Elasticsearch está disponible.${NC}"

# Establecer password para kibana_system
echo "Configurando password para kibana_system..."
curl --cacert ${CA_CERT} -s -X POST "${ES_HOST}/_security/user/kibana_system/_password" \
    -u "elastic:${ELASTIC_PASSWORD}" \
    -H "Content-Type: application/json" \
    -d "{\"password\": \"${KIBANA_SYSTEM_PASSWORD}\"}"

echo ""
echo -e "${GREEN}Usuario kibana_system configurado.${NC}"

# Verificar la configuración
echo ""
echo "Verificando acceso..."
if curl --cacert ${CA_CERT} -s -u "kibana_system:${KIBANA_SYSTEM_PASSWORD}" "${ES_HOST}/_security/_authenticate" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ kibana_system puede autenticarse correctamente.${NC}"
else
    echo -e "${RED}✗ Error al autenticar kibana_system.${NC}"
fi

echo ""
echo -e "${GREEN}=== Configuración completada ===${NC}"
echo ""
echo "Ahora puedes reiniciar Kibana si es necesario:"
echo "  docker compose -f docker-compose-secure.yml restart kibana"
