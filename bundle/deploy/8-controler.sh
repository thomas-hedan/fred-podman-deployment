# Contrôle de bout en bout, en HTTPS avec la CA interne. Fin de la coupure.

if [[ $role == storage ]]; then
    timeout 180 podman wait --condition=healthy postgres >/dev/null
    url=https://$STO_FQDN:8333/ expected=403   # S3 sans identifiants : refus attendu
else
    url=https://$APP_FQDN/control-plane/v1/frontend/config expected=200
fi
for _ in $(seq 60); do
    code=$(curl --noproxy '*' --cacert /etc/fred/tls/ca.crt -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" || true)
    [[ $code == "$expected" ]] && break
    sleep 3
done
[[ $code == "$expected" ]] || die "$url répond $code au lieu de $expected"
echo "OK $url → $code"
