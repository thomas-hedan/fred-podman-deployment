# Migrations des bases (applicatif seulement). Chaque job est idempotent.
# Profil "jobs", hors du graphe depends_on : podman-compose refuse de démarrer un
# service dont une dépendance est un job terminé.

if [[ $role == storage ]]; then
    echo "Rien à migrer sur le stockage"
    return 0
fi
job() { fold "$*" "${compose[@]}" --profile jobs run --rm --no-deps -T "$@"; }
schema=/etc/temporal/schema/postgresql/v12
job temporal-sql --database temporal setup-schema -v 0.0
job temporal-sql --database temporal update-schema -d "$schema/temporal/versioned"
job temporal-sql --database temporal_visibility setup-schema -v 0.0
job temporal-sql --database temporal_visibility update-schema -d "$schema/visibility/versioned"
job openfga-migrate
fold "Démarrage de temporal et openfga" "${compose[@]}" up -d temporal openfga
podman wait --condition=healthy temporal openfga >/dev/null
"${compose[@]}" --profile jobs run --rm --no-deps -T temporal-cli operator namespace describe --namespace default >/dev/null 2>&1 \
    || job temporal-cli operator namespace create --namespace default
job control-plane-migrate   # possède les tables lues par knowledge-flow
job knowledge-flow-migrate
job fred-agents-migrate
echo "Migrations terminées"
