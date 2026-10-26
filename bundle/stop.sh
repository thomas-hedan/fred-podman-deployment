#!/bin/bash
# Arrête la pile Fred de cette VM. Conteneurs, données et secrets sont conservés.
# Usage (root, via fred-run) : stop.sh storage|app [--disable]
#   --disable : ne pas redémarrer au prochain boot (le prochain déploiement réactive).
set -euo pipefail
role=${1:?storage|app}
if [[ $role == app ]]; then
    # Workers d'abord : ils terminent leurs tâches pendant que les API tournent encore.
    podman stop --ignore -t 60 control-plane-worker knowledge-flow-worker
fi
systemctl stop fred-stack.service
podman compose -f /opt/fred/compose.yaml stop   # si la pile a été démarrée hors systemd
if [[ ${2:-} == --disable ]]; then
    systemctl disable fred-stack.service
fi
podman ps -a --format '{{.Names}}\t{{.Status}}'
