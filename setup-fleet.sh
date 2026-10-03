#!/bin/bash
# =====================================================
# Configuración de Fleet Server
# - Genera el service token para Fleet Server
# - Calcula el fingerprint SHA-256 de la CA (modo seguro)
# - Obtiene el enrollment token de la política de agentes por defecto
# Escribe todo en .env (que está en .gitignore).
# =====================================================
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}"
# shellcheck disable=SC1091
. ./.env

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'

# Detectar modo según el esquema de ES_LOCAL_URL
case "${ES_LOCAL_URL}" in
  https*) SCHEME="https"; CA_ARG="--cacert ./config/certs/ca/ca.crt" ;;
  *)      SCHEME="http";  CA_ARG="" ;;
esac
ES_HOST="${SCHEME}://localhost:${ES_LOCAL_PORT_NODE01}"
KBN_HOST="${SCHEME}://localhost:${KIBANA_LOCAL_PORT}"
AGENT_POLICY_ID="agent-policy-1"

# Actualiza (o añade) una variable KEY=VALUE en el .env
set_env() {
  key="$1"; val="$2"
  if grep -q "^${key}=" .env; then
    # Usa | como separador porque los tokens pueden contener /
    sed -i "s|^${key}=.*|${key}=${val}|" .env
  else
    printf '%s=%s\n' "${key}" "${val}" >> .env
  fi
}

echo -e "${GREEN}=== Configurando Fleet Server (${SCHEME}) ===${NC}"

# 1) Esperar a Elasticsearch
echo "Esperando a que Elasticsearch esté disponible..."
# shellcheck disable=SC2086
until curl ${CA_ARG} -s -u "elastic:${ELASTIC_PASSWORD}" "${ES_HOST}/_cluster/health" >/dev/null 2>&1; do
  echo -n "."; sleep 2
done
echo ""

# 2) Service token para Fleet Server (rota si ya existe)
echo "Generando service token para Fleet Server..."
# shellcheck disable=SC2086
curl ${CA_ARG} -s -u "elastic:${ELASTIC_PASSWORD}" -X DELETE \
  "${ES_HOST}/_security/service/elastic/fleet-server/credential/token/fleet-token" >/dev/null 2>&1 || true
# shellcheck disable=SC2086
TOKEN_JSON=$(curl ${CA_ARG} -s -u "elastic:${ELASTIC_PASSWORD}" -X POST \
  "${ES_HOST}/_security/service/elastic/fleet-server/credential/token/fleet-token")
if command -v jq >/dev/null 2>&1; then
  SERVICE_TOKEN=$(printf '%s' "${TOKEN_JSON}" | jq -r '.token.value')
else
  SERVICE_TOKEN=$(printf '%s' "${TOKEN_JSON}" | grep -o '"value"[^,}]*' | sed 's/.*:"\([^"]*\)".*/\1/')
fi
if [ -z "${SERVICE_TOKEN}" ] || [ "${SERVICE_TOKEN}" = "null" ]; then
  echo -e "${RED}✗ No se pudo generar el service token.${NC}"; echo "${TOKEN_JSON}"; exit 1
fi
set_env "FLEET_SERVER_SERVICE_TOKEN" "${SERVICE_TOKEN}"
echo -e "${GREEN}   ✓ Service token guardado en .env${NC}"

# 3) Fingerprint de la CA (solo modo seguro)
if [ "${SCHEME}" = "https" ]; then
  FPR=$(openssl x509 -fingerprint -sha256 -noout -in ./config/certs/ca/ca.crt \
        | sed 's/.*=//; s/://g' | tr 'A-Z' 'a-z')
  set_env "FLEET_CA_FINGERPRINT" "${FPR}"
  echo -e "${GREEN}   ✓ Fingerprint de la CA guardado en .env${NC}"
fi

# 4) Enrollment token de la política de agentes por defecto
echo "Obteniendo enrollment token (esperando a Fleet en Kibana)..."
ENROLL=""
for _ in $(seq 1 60); do
  # shellcheck disable=SC2086
  KEYS=$(curl ${CA_ARG} -s -u "elastic:${ELASTIC_PASSWORD}" \
    -H "kbn-xsrf: true" "${KBN_HOST}/api/fleet/enrollment_api_keys" 2>/dev/null || true)
  if command -v jq >/dev/null 2>&1; then
    ENROLL=$(printf '%s' "${KEYS}" | jq -r --arg p "${AGENT_POLICY_ID}" \
      '.items[]? | select(.policy_id==$p) | .api_key' 2>/dev/null | head -n1)
  else
    ENROLL=$(printf '%s' "${KEYS}" | tr ',' '\n' | grep -A1 "\"policy_id\":\"${AGENT_POLICY_ID}\"" \
      | grep '"api_key"' | sed 's/.*"api_key":"\([^"]*\)".*/\1/' | head -n1)
  fi
  if [ -n "${ENROLL}" ] && [ "${ENROLL}" != "null" ]; then break; fi
  sleep 3
done
if [ -n "${ENROLL}" ] && [ "${ENROLL}" != "null" ]; then
  set_env "FLEET_ENROLLMENT_TOKEN" "${ENROLL}"
  echo -e "${GREEN}   ✓ Enrollment token guardado en .env${NC}"
else
  echo -e "${YELLOW}   ⚠ No se obtuvo enrollment token (¿Fleet aún no listo?). El agente de ejemplo podría no enrolarse.${NC}"
fi

echo -e "${GREEN}=== Fleet configurado ===${NC}"
