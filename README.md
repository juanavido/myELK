# myELK & Co.

## Scripts

- start.sh: Inicia el stack.
- stop.sh: Detiene los servicios.
- uninstall.sh: Elimina contenedores/volúmenes locales (destructivo).
- status.sh: Verifica el estado del clúster (health, nodos, master, índices).

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
