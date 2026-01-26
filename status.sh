#!/usr/bin/env bash
set -euo pipefail

# Simple cluster status checker for local ELK
# Uses environment from .env when present

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$ROOT_DIR/.env" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ROOT_DIR/.env"
  set +a
fi

ES_HOST="${ES_LOCAL_HOST:-127.0.0.1}"
ES_PORT_NODE01="${ES_LOCAL_PORT_NODE01:-9201}"
ES_PORT_NODE02="${ES_LOCAL_PORT_NODE02:-9202}"
ES_PORT_NODE03="${ES_LOCAL_PORT_NODE03:-9203}"

GREEN="\033[0;32m"; YELLOW="\033[0;33m"; RED="\033[0;31m"; NC="\033[0m"

function ping_node() {
  local port=$1
  curl -s "http://${ES_HOST}:${port}" >/dev/null
}

function health() {
  curl -s "http://${ES_HOST}:${ES_PORT_NODE01}/_cluster/health?pretty"
}

function nodes() {
  curl -s "http://${ES_HOST}:${ES_PORT_NODE01}/_cat/nodes?v&h=name,ip,node.role,master,heap.percent,ram.percent,uptime" | sed 's/\bmdi\b/mdi (master-eligible,data,ingest)/'
}

function master() {
  curl -s "http://${ES_HOST}:${ES_PORT_NODE01}/_cat/master?v"
}

function indices() {
  curl -s "http://${ES_HOST}:${ES_PORT_NODE01}/_cat/indices?v&health,status,index,pri,rep,docs.count,store.size"
}

function show_summary() {
  echo -e "${YELLOW}Checking nodes reachability...${NC}"
  for p in "$ES_PORT_NODE01" "$ES_PORT_NODE02" "$ES_PORT_NODE03"; do
    if ping_node "$p"; then
      echo -e "${GREEN}OK${NC} - http://${ES_HOST}:${p}"
    else
      echo -e "${RED}DOWN${NC} - http://${ES_HOST}:${p}"
    fi
  done
  echo
  echo -e "${YELLOW}Cluster health${NC}"
  health | jq . 2>/dev/null || health
  local status; local unassigned
  status=$(curl -s "http://${ES_HOST}:${ES_PORT_NODE01}/_cluster/health" | jq -r '.status' 2>/dev/null || curl -s "http://${ES_HOST}:${ES_PORT_NODE01}/_cluster/health" | grep -Eo '"status"\s*:\s*"[^"]+"' | sed 's/.*:"\([^"]\+\)"/\1/')
  unassigned=$(curl -s "http://${ES_HOST}:${ES_PORT_NODE01}/_cluster/health" | jq -r '.unassigned_shards' 2>/dev/null || curl -s "http://${ES_HOST}:${ES_PORT_NODE01}/_cluster/health" | grep -Eo '"unassigned_shards"\s*:\s*[0-9]+' | awk '{print $2}')
  if [ "${status}" != "green" ] || [ "${unassigned}" != "0" ]; then
    echo -e "${RED}ALERT${NC} status=${status:-unknown} unassigned_shards=${unassigned:-unknown}"
    echo "Tip: ./status.sh allocation para explicación de asignación"
  else
    echo -e "${GREEN}OK${NC} status=${status} unassigned_shards=${unassigned}"
  fi
  echo
  echo -e "${YELLOW}Elected master${NC}"
  master
  echo
  echo -e "${YELLOW}Nodes${NC}"
  nodes
}

function allocation() {
  local tmp resp_code
  tmp=$(mktemp)
  resp_code=$(curl -sS -X POST "http://${ES_HOST}:${ES_PORT_NODE01}/_cluster/allocation/explain" -H 'Content-Type: application/json' -d '{}' -o "$tmp" -w '%{http_code}' || true)
  if [ "$resp_code" = "200" ]; then
    if command -v jq >/dev/null 2>&1; then
      jq . "$tmp"
    else
      cat "$tmp"
    fi
  else
    if grep -qi 'no unassigned shards' "$tmp" || grep -qi 'explain for at least one unassigned' "$tmp"; then
      echo "No hay shards sin asignar; nada que explicar."
    else
      echo "Fallo en allocation explain (HTTP $resp_code):"
      cat "$tmp"
    fi
  fi
  rm -f "$tmp"
}

function json() {
  local res status unassigned nodes master_name ok
  res=$(curl -s "http://${ES_HOST}:${ES_PORT_NODE01}/_cluster/health")
  status=$(printf "%s" "$res" | jq -r '.status' 2>/dev/null || printf "%s" "$res" | grep -Eo '"status"\s*:\s*"[^"]+"' | sed 's/.*:"\([^"]\+\)"/\1/')
  unassigned=$(printf "%s" "$res" | jq -r '.unassigned_shards' 2>/dev/null || printf "%s" "$res" | grep -Eo '"unassigned_shards"\s*:\s*[0-9]+' | awk '{print $2}')
  nodes=$(printf "%s" "$res" | jq -r '.number_of_nodes' 2>/dev/null || printf "%s" "$res" | grep -Eo '"number_of_nodes"\s*:\s*[0-9]+' | awk '{print $2}')
  master_name=$(curl -s "http://${ES_HOST}:${ES_PORT_NODE01}/_cat/master?h=node" | tr -d '\r' | head -n1)
  if [ "${status}" = "green" ] && [ "${unassigned}" = "0" ]; then ok=true; else ok=false; fi
  echo "{\"status\":\"${status:-unknown}\",\"unassigned_shards\":${unassigned:-0},\"number_of_nodes\":${nodes:-0},\"master\":\"${master_name:-unknown}\",\"ok\":${ok}}"
}

function roles() {
  if command -v jq >/dev/null 2>&1; then
    echo -e "name\troles"
    curl -s "http://${ES_HOST}:${ES_PORT_NODE01}/_nodes" | jq -r '.nodes[] | [ .name, (.roles | join(",")) ] | @tsv'
  else
    echo "Install jq for detailed roles; falling back to _cat/nodes"
    curl -s "http://${ES_HOST}:${ES_PORT_NODE01}/_cat/nodes?v&h=name,node.role"
  fi
}

function verify() {
  local res status unassigned
  res=$(curl -s "http://${ES_HOST}:${ES_PORT_NODE01}/_cluster/health")
  status=$(printf "%s" "$res" | jq -r '.status' 2>/dev/null || printf "%s" "$res" | grep -Eo '"status"\s*:\s*"[^"]+"' | sed 's/.*:"\([^"]\+\)"/\1/')
  unassigned=$(printf "%s" "$res" | jq -r '.unassigned_shards' 2>/dev/null || printf "%s" "$res" | grep -Eo '"unassigned_shards"\s*:\s*[0-9]+' | awk '{print $2}')
  if [ "${status}" != "green" ] || [ "${unassigned}" != "0" ]; then
    echo "ALERT status=${status:-unknown} unassigned_shards=${unassigned:-unknown}"
    return 1
  fi
  echo "OK status=${status} unassigned_shards=${unassigned}"
}

case "${1:-summary}" in
  summary) show_summary ;;
  health) health ;;
  master) master ;;
  nodes) nodes ;;
  roles) roles ;;
  verify) verify ;;
  allocation) allocation ;;
  json) json ;;
  indices) indices ;;
  *) echo "Usage: $0 [summary|health|master|nodes|roles|indices|verify|allocation|json]"; exit 1 ;;
 esac
