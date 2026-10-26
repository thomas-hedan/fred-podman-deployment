#!/bin/bash
# Installe ou met à jour le rôle storage|app de cette VM. Lancé en root par fred-run.
# Les étapes sont les fichiers de deploy/, dans l'ordre de leur numéro :
#   deploy.sh <rôle>            toutes les étapes 1 à 8 (usage manuel)
#   deploy.sh <rôle> <étape>    une seule étape, ex. 3-telecharger (une tâche Azure par étape)
#   deploy.sh <rôle> 0-diagnostic  état de la VM, sans exiger les variables
# Les variables du pipeline arrivent sur stdin (NOM=valeur séparés par NUL).
# Rien n'est modifié sur la VM avant l'étape 3 ; la pile n'est arrêtée qu'à l'étape 5.
set -euo pipefail
role=${1:?storage|app}
step=${2:-}
bundle=$(cd "$(dirname "$0")" && pwd)
steps=("$bundle"/deploy/${2:-[1-9]-*}.sh)
[[ ${2:-} =~ ^([0-9]-[a-z]+)?$ && -f ${steps[0]} ]] || { echo "ERREUR : étape inconnue : ${2:-}" >&2; exit 2; }
source "$bundle/deploy/lib.sh"
for file in "${steps[@]}"; do
    name=${file##*/}
    echo "##[section]$role · ${name%.sh}"
    source "$file"
done
