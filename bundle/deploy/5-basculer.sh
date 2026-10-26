# Arrête l'ancienne pile puis installe les fichiers préparés. Début de la coupure.

[[ -d $next ]] || die "$next absent : relancer l'étape 2-preparer"
if [[ -f /opt/fred/compose.yaml ]]; then
    systemctl stop fred-stack.service 2>/dev/null || true
    fold "Arrêt et suppression des conteneurs" "${compose[@]}" --profile jobs down   # sans -v : données conservées
fi
cp -r "$next/." / && rm -rf "$next"
echo "Fichiers installés"
# CA interne dans le magasin système, monté dans les conteneurs qui parlent en TLS.
install -m 0644 /etc/fred/tls/ca.crt /etc/pki/ca-trust/source/anchors/fred-internal-ca.crt
update-ca-trust extract
[[ $role == app ]] || mkdir -p /var/lib/fred/postgres /var/lib/fred/seaweedfs
