# myELK & Co.

Stack ELK local con dos modos: **sin seguridad** (HTTP) y **con seguridad** (TLS/SSL).
No arranques ambos a la vez: comparten puertos, nombres de contenedor y volúmenes de datos.

## Configuración inicial (.env)

El fichero `.env` **no se versiona** (política de seguridad, está en `.gitignore`).
En una instalación desde cero, copia la plantilla del modo que quieras a `.env`:

```bash
# Modo sin seguridad (HTTP)
cp .env.NOSECURE .env

# Modo con seguridad (TLS/SSL)
cp .env.SECURE .env
```

> Nota: las contraseñas y claves de las plantillas son de **laboratorio**. Cámbialas en producción.

## Arranque

| Modo | Compose | Arranque | Configs |
|------|---------|----------|---------|
| Sin seguridad | `docker-compose.yml` | `./start.sh` | `config-nosecure/` |
| Con seguridad | `docker-compose-secure.yml` | `./start-secure.sh` | `config/` (con certificados) |

El `./start-secure.sh` genera certificados si faltan y configura el usuario `kibana_system` automáticamente.

## URLs y credenciales (laboratorio)

### Modo sin seguridad (HTTP, sin login)

| Servicio | URL |
|----------|-----|
| Elasticsearch (nodo 01) | http://localhost:9201 |
| Elasticsearch (nodo 02) | http://localhost:9202 |
| Elasticsearch (nodo 03) | http://localhost:9203 |
| Kibana | http://localhost:5601 |
| Logstash API | http://localhost:9600 |
| Fleet Server | http://localhost:8220 |

### Modo con seguridad (HTTPS, certificado autofirmado)

| Servicio | URL | Usuario | Password |
|----------|-----|---------|----------|
| Elasticsearch (nodo 01) | https://localhost:9201 | `elastic` | `tXrCLc79` |
| Elasticsearch (nodo 02) | https://localhost:9202 | `elastic` | `tXrCLc79` |
| Elasticsearch (nodo 03) | https://localhost:9203 | `elastic` | `tXrCLc79` |
| Kibana | https://localhost:5601 | `elastic` | `tXrCLc79` |
| Fleet Server | https://localhost:8220 | — | — |

> **Login en Kibana:** usa siempre `elastic` / `tXrCLc79`.
> `kibana_system` / `LuTvybW2` es una **cuenta de servicio interna** (Kibana↔Elasticsearch) y **NO puede entrar a la UI**: si lo usas verás "You do not have permission to access the requested page".

Ejemplo de consulta autenticada al clúster seguro:

```bash
source .env
curl --cacert ./config/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  https://localhost:9201/_cluster/health?pretty
```

## Scripts

- start.sh: Inicia el stack (modo sin seguridad).
- start-secure.sh: Inicia el stack con seguridad (genera certs y configura kibana_system).
- setup-users.sh: Configura el password de kibana_system (modo seguro).
- setup-fleet.sh: Genera el service token y el enrollment token de Fleet (ambos modos).
- stop.sh: Detiene los servicios.
- uninstall.sh: Elimina contenedores/volúmenes locales (destructivo).
- status.sh: Verifica el estado del clúster (health, nodos, master, índices).

## Fleet Server y Elastic Agent

Ambos stacks incluyen **Fleet Server** y un **Elastic Agent de ejemplo** enrolado.
Kibana trae preconfiguradas dos políticas: `fleet-server-policy` (Fleet Server) y
`agent-policy-1` (agente con la integración `system`).

El arranque (`start.sh` / `start-secure.sh`) lo automatiza en este orden:

1. Elasticsearch (3 nodos) + Kibana con la preconfig de Fleet.
2. `setup-fleet.sh` genera el **service token** (Fleet Server) y el **enrollment token**
   (agente), y los escribe en `.env`. En modo seguro también calcula el
   **fingerprint de la CA** para la salida de datos.
3. Se levantan `fleet-server` (puerto 8220) y `elastic-agent`.

Ver los agentes enrolados desde la UI: **Kibana > Management > Fleet > Agents**
(debería haber 2: `fleet-server` y `elastic-agent`).

Comprobación por API (modo seguro):

```bash
source .env
curl --cacert ./config/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" \
  -H "kbn-xsrf: true" https://localhost:5601/api/fleet/agents?pretty
```

> Los tokens de Fleet se guardan en `.env` (ignorado por git). Si recreas el clúster
> desde cero, `setup-fleet.sh` los regenera.

## Verificación rápida del clúster

Con el entorno levantado, puedes validar que todo está correcto:

```
./status.sh            # Resumen: reachability, health, master, nodos
./status.sh health     # Solo health
./status.sh master     # Nodo master actual
./status.sh nodes      # Tabla de nodos
./status.sh indices    # Resumen de índices
./status.sh roles      # Roles detallados por nodo (requiere jq para mejor salida)
./status.sh verify     # Devuelve error si status != green o hay shards sin asignar
./status.sh allocation # Explicación de asignación (útil cuando hay shards sin asignar)
./status.sh json       # Salida JSON resumida para CI (status, unassigned, nodes, master, ok)
```

Notas:
- status.sh lee variables de .env (puertos 9201/9202/9203 por defecto).
- Requiere curl; si jq está instalado, mostrará JSON con formato.
