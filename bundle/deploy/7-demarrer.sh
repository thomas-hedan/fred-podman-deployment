# Démarre la pile via systemd (redémarrage au boot) et trace la version déployée.

systemctl daemon-reload
systemctl enable --now fred-stack.service   # = podman compose up -d
{
    echo "--- $(date -Is) rôle=$role tag=${FRED_TAG:--} commit=$(git -c safe.directory='*' -C "$bundle" rev-parse HEAD)"
    podman ps --format '{{.Image}}' | sort -u | while read -r image; do
        echo "$image $(podman image inspect --format '{{.Digest}}' "$image")"
    done
} | tee -a /opt/fred/deployment.log
echo "Conteneurs :"
podman ps --format '  {{printf "%-25s" .Names}} {{.Status}}'
