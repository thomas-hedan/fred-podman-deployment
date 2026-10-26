# Commun à toutes les étapes : lit et valide les variables, prépare les secrets.
# Sourcé par deploy.sh à chaque étape : chaque tâche Azure revalide ses entrées.

next=/opt/fred/.next                           # fichiers préparés, installés à l'étape 5
compose=(podman compose -f /opt/fred/compose.yaml)
export REGISTRY_AUTH_FILE=/etc/fred/registry-auth.json
export PODMAN_COMPOSE_WARNING_LOGS=false       # sans la bannière "external compose provider"

# Messages lisibles dans Azure : erreurs dans le résumé, sorties longues repliables.
die() { echo "##vso[task.logissue type=error]$*"; echo "ERREUR : $*" >&2; exit 1; }
fold() { echo "##[group]$1"; shift; "$@"; echo "##[endgroup]"; }

# ---------------------------------------------------------------- variables
# Publiques : exportées pour les templates et écrites dans /opt/fred/.env.
public=(REGISTRY_HOST REGISTRY_TLS_VERIFY STO_FQDN S3_ACCESS_KEY)
secrets=(FRED_DB_PASSWORD OPENFGA_DB_PASSWORD TEMPORAL_DB_PASSWORD S3_SECRET_KEY)
case $role in
    storage) secrets+=(FRED_POSTGRES_PASSWORD) ;;
    app) public+=(FRED_TAG APP_FQDN PUBLIC_URL APP_PODMAN_SUBNET TENANT_ID API_APP_ID API_URI
                  UI_CLIENT_ID CP_CLIENT_ID KF_CLIENT_ID RUNTIME_CLIENT_ID)
         secrets+=(OPENFGA_PRESHARED_KEY FRED_BOOTSTRAP_TOKEN OPENAI_API_KEY CP_SECRET KF_SECRET RUNTIME_SECRET) ;;
    *) die "rôle inconnu : $role" ;;
esac

declare -A var=()
while IFS= read -r -d '' pair; do
    value=${pair#*=}
    [[ $value == '$('* ]] && value=''   # $(NOM) : variable absente de Library
    var[${pair%%=*}]=$value
done
[[ $step == 0-* ]] && return   # diagnostic : rapporte les manques au lieu d'échouer
bad=()
for name in "${public[@]}" "${secrets[@]}"; do
    [[ -n ${var[$name]-} ]] || bad+=("$name")
done
forbidden='[[:space:]"\\$#'"']"   # valeurs injectées dans du YAML et un .env
for name in "${public[@]}"; do
    [[ ${var[$name]-} =~ $forbidden ]] && bad+=("$name")
done
((${#bad[@]} == 0)) || die "variables absentes ou invalides : ${bad[*]}"
for name in "${public[@]}"; do export "$name=${var[$name]}"; done
[[ $REGISTRY_TLS_VERIFY =~ ^(true|false)$ ]] || die 'REGISTRY_TLS_VERIFY : true ou false'
[[ $role == storage ]] || PUBLIC_URL=${PUBLIC_URL%/} API_URI=${API_URI%/}

# ---------------------------------------------------------------- secrets Podman
secret_is() { [[ $(podman secret inspect --showsecret --format '{{.SecretData}}' "$1" 2>/dev/null) == "$2" ]]; }
declare -A podman_secret=(
    [fred_db_password]=${var[FRED_DB_PASSWORD]}
    [fred_temporal_db_password]=${var[TEMPORAL_DB_PASSWORD]}
)
if [[ $role == storage ]]; then
    podman_secret+=(
        [fred_postgres_password]=${var[FRED_POSTGRES_PASSWORD]}
        [fred_openfga_db_password]=${var[OPENFGA_DB_PASSWORD]}
        [fred_s3_config]=$(printf '%s' "${var[S3_SECRET_KEY]}" | python3 -c 'import json,sys; k=sys.argv[1]; print(json.dumps({"identities": [{"name": k,
            "credentials": [{"accessKey": k, "secretKey": sys.stdin.read()}],
            "actions": ["Admin", "Read", "Write", "List", "Tagging"]}]}))' "$S3_ACCESS_KEY")
    )
else
    podman_secret+=(
        [fred_s3_secret_key]=${var[S3_SECRET_KEY]}
        [fred_openfga_preshared_key]=${var[OPENFGA_PRESHARED_KEY]}
        [fred_bootstrap_token]=${var[FRED_BOOTSTRAP_TOKEN]}
        [fred_openai_api_key]=${var[OPENAI_API_KEY]}
        [fred_cp_secret]=${var[CP_SECRET]}
        [fred_kf_secret]=${var[KF_SECRET]}
        [fred_runtime_secret]=${var[RUNTIME_SECRET]}
        [fred_openfga_datastore_uri]=postgres://openfga:$(printf '%s' "${var[OPENFGA_DB_PASSWORD]}" \
            | python3 -c 'import sys,urllib.parse as u; print(u.quote(sys.stdin.read(), safe=""))')@$STO_FQDN:5432/openfga?sslmode=verify-full\&sslrootcert=/etc/fred/tls/ca.crt
    )
fi
