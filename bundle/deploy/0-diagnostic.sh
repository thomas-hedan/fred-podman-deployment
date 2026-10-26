# Niveau 0, hors déploiement (pipeline/diagnostic.yml) : VM et agent, variables
# reçues, secrets Podman. Aucune image, aucun service. Ne modifie rien, hors un secret
# de test créé puis supprimé. Les manques sont des avertissements, pas des échecs.

issues=0
warn() { echo "##vso[task.logissue type=warning]$*"; echo "  MANQUE   $*"; issues=$((issues + 1)); }
ok() { echo "  ok       $*"; }

echo "Machine : $(hostname -f) · $(. /etc/os-release && echo "$PRETTY_NAME")"
echo "Agent   : ${var[AGENT_NAME]-?} (v${var[AGENT_VERSION]-?}), compte ${SUDO_USER:-?}, exécuté en $(id -un)"
echo "Dépôt   : ${var[BUILD_SOURCEBRANCH]-?} @ ${var[BUILD_SOURCEVERSION]-?}"

echo "Prérequis :"
for cmd in podman python3 openssl curl; do
    command -v "$cmd" >/dev/null && ok "$cmd" || warn "commande $cmd absente"
done
podman compose version >/dev/null 2>&1 && ok "podman compose" || warn "podman compose indisponible"
case $role in
    storage) tls=(ca.crt postgres/server.crt postgres/server.key seaweedfs/server.crt seaweedfs/server.key) ;;
    app) tls=(ca.crt frontend/server.crt frontend/server.key) ;;
esac
for file in "${tls[@]}"; do
    [[ -f /etc/fred/tls/$file ]] && ok "/etc/fred/tls/$file" || warn "/etc/fred/tls/$file absent"
done

echo "Variables publiques (Library fred-<env> et fred-<env>-$role) :"
for name in "${public[@]}"; do
    [[ -n ${var[$name]-} ]] && ok "$name = ${var[$name]}" || warn "variable $name absente"
done
echo "Secrets (valeur jamais affichée) :"
for name in "${secrets[@]}"; do
    [[ -n ${var[$name]-} ]] && ok "$name reçu" || warn "secret $name absent (ou non mappé dans stage.yml)"
done

echo "Secrets Podman :"
if command -v podman >/dev/null; then
    value=diagnostic-$(date +%s%N)
    if printf '%s' "$value" | podman secret create --replace fred_diagnostic - >/dev/null \
        && [[ $(podman secret inspect --showsecret --format '{{.SecretData}}' fred_diagnostic) == "$value" ]]; then
        ok "secret de test créé, relu et supprimé"
    else
        warn "création ou relecture d'un secret Podman impossible"
    fi
    podman secret rm fred_diagnostic >/dev/null 2>&1 || true
    existing=$(podman secret ls --format '{{.Name}}' | { grep '^fred_' || true; } | sort | tr '\n' ' ')
    echo "  déjà présents : ${existing:-aucun}"
else
    warn "test des secrets impossible sans podman"
fi

if ((issues)); then
    echo "##vso[task.complete result=SucceededWithIssues;]$issues point(s) à compléter sur $role"
else
    echo "Tout est en place pour un déploiement de $role"
fi
