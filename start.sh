#!/bin/sh
# Start script for the local (non-secure) ELK stack
# Levanta el docker-compose.yml por defecto (sin TLS/seguridad)
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"
. ./.env

# Check disk space
available_gb=$(($(df -k / | awk 'NR==2 {print $4}') / 1024 / 1024))
required=$(echo "${ES_LOCAL_DISK_SPACE_REQUIRED}" | grep -Eo '[0-9]+')
if [ "$available_gb" -lt "$required" ]; then
  echo "----------------------------------------------------------------------------"
  echo "WARNING: Disk space is below the ${required} GB limit. Elasticsearch will be"
  echo "executed in read-only mode. Please free up disk space to resolve this issue."
  echo "----------------------------------------------------------------------------"
  echo "Press ENTER to confirm."
  # shellcheck disable=SC2034
  read -r line
fi

docker compose up -d --wait elasticsearch01 elasticsearch02 elasticsearch03

# Levantar Kibana, Logstash y Beats
docker compose up -d --wait kibana logstash filebeat metricbeat

# Configurar Fleet (service token + enrollment token) y levantar Fleet Server + Agent
if ./setup-fleet.sh; then
  docker compose up -d fleet-server elastic-agent
else
  echo "AVISO: no se pudo configurar Fleet. Ejecuta ./setup-fleet.sh y luego:"
  echo "  docker compose up -d fleet-server elastic-agent"
fi

echo
echo "=== Stack ELK (no seguro) iniciado ==="
echo "  - Elasticsearch: http://localhost:${ES_LOCAL_PORT_NODE01} (nodo 01)"
echo "  - Kibana:        http://localhost:${KIBANA_LOCAL_PORT}"
echo "  - Fleet Server:  http://localhost:8220"
echo
echo "Estado del cluster: ./status.sh"
