# Vérifie les entrées, sans rien modifier : variables, certificats, mots de passe SQL.

echo "Variables publiques :"
for name in "${public[@]}"; do printf '  %-20s %s\n' "$name" "${!name}"; done
echo "Secrets reçus : ${secrets[*]}"

cert() {  # service nom-attendu
    openssl verify -CAfile /etc/fred/tls/ca.crt -verify_hostname "$2" "/etc/fred/tls/$1/server.crt" >/dev/null \
        || die "certificat $1 absent, expiré ou invalide pour $2"
    echo "Certificat $1 valide pour $2 (expire le $(openssl x509 -enddate -noout -in "/etc/fred/tls/$1/server.crt" | cut -d= -f2))"
}
if [[ $role == storage ]]; then
    cert postgres "$STO_FQDN"
    cert seaweedfs "$STO_FQDN"
else
    cert frontend "$APP_FQDN"
    cert frontend "$(python3 -c 'import sys,urllib.parse as u; print(u.urlsplit(sys.argv[1]).hostname)' "$PUBLIC_URL")"
fi

# PostgreSQL ne lit ses mots de passe qu'à l'initialisation : en changer un sur une
# base existante demande un ALTER ROLE manuel (docs/EXPLOITATION.md).
if [[ $role == storage && -d /var/lib/fred/postgres/pgdata ]]; then
    for name in fred_postgres_password fred_db_password fred_openfga_db_password fred_temporal_db_password; do
        if podman secret exists "$name" && ! secret_is "$name" "${podman_secret[$name]}"; then
            die "$name diffère de la base existante : rotation SQL manuelle requise"
        fi
    done
    echo "Mots de passe SQL identiques à ceux de la base existante"
fi
