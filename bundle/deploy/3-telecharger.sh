# Configure l'accès à la registry et télécharge toutes les images du rôle.
# Une image absente arrête ici le déploiement : la pile en place continue de tourner.

insecure=true; [[ $REGISTRY_TLS_VERIFY == true ]] && insecure=false
printf '[[registry]]\nlocation = "%s"\ninsecure = %s\n' "$REGISTRY_HOST" "$insecure" \
    > /etc/containers/registries.conf.d/90-fred-registry.conf
[[ -s $REGISTRY_AUTH_FILE ]] || (umask 077; echo '{"auths": {}}' > "$REGISTRY_AUTH_FILE")
if [[ -n ${var[REGISTRY_USERNAME]-} ]]; then
    printf '%s' "${var[REGISTRY_PASSWORD]-}" | podman login --tls-verify="$REGISTRY_TLS_VERIFY" \
        --username "${var[REGISTRY_USERNAME]}" --password-stdin "$REGISTRY_HOST"
else
    podman logout --all >/dev/null
    echo "Registry $REGISTRY_HOST : accès anonyme (TLS vérifié : $REGISTRY_TLS_VERIFY)"
fi

next_compose=(podman compose -f "$next/opt/fred/compose.yaml" --env-file "$next/opt/fred/.env" --profile jobs)
fold "Téléchargement (détail)" "${next_compose[@]}" pull
echo "Images prêtes :"
"${next_compose[@]}" config | sed -n 's/^ *image: //p' | sort -u | while read -r image; do
    printf '  %-70s %s\n' "$image" "$(podman image inspect --format '{{.Digest}}' "$image")"
done
