#!/bin/bash
# Exécuté une seule fois, à l'initialisation d'un répertoire de données vide.
# Un compte par consommateur, propriétaire de sa seule base.
set -euo pipefail

# L'entrypoint officiel n'interprète que POSTGRES_PASSWORD_FILE. Les trois mots de
# passe applicatifs sont lus ici, au premier démarrage seulement.
FRED_DB_PASSWORD=$(<"$FRED_DB_PASSWORD_FILE")
OPENFGA_DB_PASSWORD=$(<"$OPENFGA_DB_PASSWORD_FILE")
TEMPORAL_DB_PASSWORD=$(<"$TEMPORAL_DB_PASSWORD_FILE")
[[ -n $FRED_DB_PASSWORD && -n $OPENFGA_DB_PASSWORD && -n $TEMPORAL_DB_PASSWORD ]] || {
    echo "[fred-init] mot de passe applicatif vide" >&2
    exit 1
}

# psql n'interpole les variables (:'p', :"u") que sur stdin, pas avec -c.
# \getenv évite de passer le mot de passe dans les arguments de psql.
sql() { psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" "$@" >/dev/null; }

create_db() {
    local user=$1 password=$2
    shift 2
    FRED_INIT_PASSWORD=$password sql -v u="$user" <<'SQL'
\getenv p FRED_INIT_PASSWORD
CREATE ROLE :"u" LOGIN PASSWORD :'p';
SQL
    for db in "$@"; do
        sql -v u="$user" -v d="$db" <<<"CREATE DATABASE :\"d\" OWNER :\"u\";"
        sql -v d="$db" <<<"REVOKE ALL ON DATABASE :\"d\" FROM PUBLIC;"
        echo "[fred-init] base $db (propriétaire $user)"
    done
}

create_db fred "$FRED_DB_PASSWORD" fred
create_db openfga "$OPENFGA_DB_PASSWORD" openfga
create_db temporal "$TEMPORAL_DB_PASSWORD" temporal temporal_visibility
unset FRED_DB_PASSWORD OPENFGA_DB_PASSWORD TEMPORAL_DB_PASSWORD

# pgvector : magasin de vecteurs de Knowledge Flow (pas d'OpenSearch dans cette pile).
sql --dbname fred <<<"CREATE EXTENSION IF NOT EXISTS vector;"
echo "[fred-init] extension vector créée dans fred"
