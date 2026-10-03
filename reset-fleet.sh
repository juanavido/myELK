#!/bin/sh
# =====================================================
# Reset limpio de Fleet
# Borra contenedores y volúmenes de fleet-server/elastic-agent,
# limpia los tokens del .env, regenera con setup-fleet.sh y
# vuelve a levantar Fleet desde cero.
# Úsalo cuando quieras ROTAR el service token a propósito.
# =====================================================
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"
# shellcheck disable=SC1091
. ./.env

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

# Selección de compose según el modo del .env
case "${ES_LOCAL_URL}" in
  https*) COMPOSE="docker-compose-secure.yml" ;;
  *)      COMPOSE="docker-compose.yml" ;;
esac

echo "${GREEN}=== Reset de Fleet (compose: ${COMPOSE}) ===${NC}"
echo "${YELLOW}Esto elimina fleet-server, elastic-agent y sus volúmenes de datos.${NC}"
printf "¿Continuar? (yes/no): "
read -r answer
case "${answer}" in
  yes|y|Y|Yes|YES) ;;
  *) echo "Cancelado."; exit 0 ;;
esac

echo "${GREEN}1/4 Eliminando contenedores y volúmenes de Fleet...${NC}"
docker compose -f "${COMPOSE}" rm -fsv fleet-server elastic-agent || true
docker volume rm myelk_fleet-server-data myelk_elastic-agent-data 2>/dev/null || true

echo "${GREEN}2/4 Limpiando tokens del .env...${NC}"
sed -i 's|^FLEET_SERVER_SERVICE_TOKEN=.*|FLEET_SERVER_SERVICE_TOKEN=|' .env
sed -i 's|^FLEET_ENROLLMENT_TOKEN=.*|FLEET_ENROLLMENT_TOKEN=|' .env

echo "${GREEN}3/4 Regenerando configuración de Fleet...${NC}"
./setup-fleet.sh

echo "${GREEN}4/4 Levantando Fleet Server y Elastic Agent...${NC}"
docker compose -f "${COMPOSE}" up -d fleet-server elastic-agent

echo "${GREEN}=== Fleet reseteado ===${NC}"
echo "Comprueba el estado en Kibana → Management → Fleet"
