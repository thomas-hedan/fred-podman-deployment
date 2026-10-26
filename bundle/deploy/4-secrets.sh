# Crée ou met à jour les secrets Podman du rôle. Les conteneurs en place gardent
# leur copie jusqu'à leur recréation à l'étape 7.

for name in $(printf '%s\n' "${!podman_secret[@]}" | sort); do
    if secret_is "$name" "${podman_secret[$name]}"; then
        echo "  inchangé   $name"
    else
        printf '%s' "${podman_secret[$name]}" | podman secret create --replace "$name" - >/dev/null
        echo "  mis à jour $name"
    fi
done
