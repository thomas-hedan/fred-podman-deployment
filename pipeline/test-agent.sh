#!/bin/bash
# Test d'un agent Azure DevOps, quel que soit le mode : pool (YAML) ou groupe de
# déploiement (mise en production classique). Version script de test-azure.yml, à
# coller dans une tâche Bash "Inline". Ne touche à aucun service.
# Entrées (variables d'environnement de la tâche) :
#   TEST_PUBLIC   variable publique (pipeline ou Library)
#   SECRET_MAPPE  valeur de TEST_SECRET, mappée dans la tâche : un secret n'arrive pas seul
#   IMAGE         image de test joignable depuis la VM (défaut : ubi9/ubi-minimal)
issues=0 errors=0
warn() { echo "##vso[task.logissue type=warning]$*"; echo "  ATTENTION $*"; issues=$((issues + 1)); }
fail() { echo "##vso[task.logissue type=error]$*"; echo "  ÉCHEC     $*"; errors=$((errors + 1)); }
ok() { echo "  ok        $*"; }
section() { echo "##[section]$*"; }

section "1 · agent et machine"
echo "  Agent   : ${AGENT_NAME:-?} v${AGENT_VERSION:-?}"
echo "  Compte  : $(id -un) (uid $(id -u)) · groupes $(id -Gn)"
echo "  Machine : $(hostname -f) · $(. /etc/os-release && echo "$PRETTY_NAME") · noyau $(uname -r)"
echo "  Dossier : ${AGENT_WORKFOLDER:-?}"
echo "  Run     : ${RELEASE_RELEASENAME:-${BUILD_BUILDNUMBER:-?}} · phase ${RELEASE_ENVIRONMENTNAME:-?}"

section "2 · variables et secrets Azure"
[[ -n ${TEST_PUBLIC-} ]] && ok "TEST_PUBLIC = $TEST_PUBLIC" || warn "TEST_PUBLIC non défini"
[[ -z $(printenv TEST_SECRET) ]] && ok "secret non mappé : invisible (attendu)" || warn "TEST_SECRET visible sans mappage"
secret=${SECRET_MAPPE-}
if [[ -z $secret || $secret == '$('* ]]; then
    warn "SECRET_MAPPE vide : TEST_SECRET non défini ou non mappé dans la tâche"
    secret=genere-$(date +%s%N)
else
    ok "secret mappé reçu, ${#secret} caractères"
    echo "  Masquage dans les logs (doit afficher ***) : $secret"
fi

section "3 · droits sudo (lecture seule)"
sudo -n true 2>/dev/null && warn "sudo complet sans mot de passe : à restreindre" || ok "sudo complet refusé"
rules=$(sudo -n -l 2>/dev/null | sed -n '/may run/,$p' | tail -n +2)
echo "  Règles sudo sans mot de passe :"; echo "${rules:-    aucune}"
[[ -x /usr/local/sbin/fred-run ]] && ok "fred-run installé" || echo "  fred-run absent"

section "4 · Podman"
if ! command -v podman >/dev/null; then
    fail "podman absent"
else
    ok "$(podman --version)"
    podman compose version >/dev/null 2>&1 && ok "podman compose" \
        || warn "podman compose indisponible (installer podman-compose ou docker-compose)"
    if info=$(podman info --format 'rootless={{.Host.Security.Rootless}} · stockage={{.Store.GraphDriverName}}' 2>&1); then
        ok "$info"
    else
        fail "podman info : $info"
    fi
fi

section "5 · secret Podman dans un conteneur"
image=${IMAGE:-registry.access.redhat.com/ubi9/ubi-minimal:latest}
name=azdo_test_$$
if ((errors)); then
    echo "  ignoré : Podman ne fonctionne pas"
elif ! out=$(printf '%s' "$secret" | podman secret create "$name" - 2>&1); then
    fail "création du secret Podman : $out"
else
    ok "secret Podman $name créé"
    if ! out=$(podman pull -q "$image" 2>&1); then
        fail "téléchargement de $image : $out"
    elif [[ $(podman run --rm --secret "$name",target=test "$image" cat /run/secrets/test 2>&1) == "$secret" ]]; then
        ok "conteneur : /run/secrets/test identique au secret Azure"
    else
        fail "secret lu dans le conteneur différent"
    fi
    podman secret rm "$name" >/dev/null 2>&1 || true
fi

echo
if ((errors)); then
    echo "$errors échec(s), $issues avertissement(s)"; exit 1
elif ((issues)); then
    echo "##vso[task.complete result=SucceededWithIssues;]$issues avertissement(s)"
else
    echo "Tout est au vert"
fi
