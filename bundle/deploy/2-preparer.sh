# Prépare dans /opt/fred/.next les fichiers à installer, sans toucher aux fichiers actifs.

rm -rf "$next"
put() { install -D -m "${3:-0644}" "$1" "$next$2"; }
put "$bundle/$role/compose.yaml" /opt/fred/compose.yaml
put "$bundle/fred-stack.service" /etc/systemd/system/fred-stack.service
put "$bundle/podman-hardening.conf" /etc/containers/containers.conf.d/60-fred-hardening.conf
for name in "${public[@]}"; do echo "$name=${!name}"; done > "$next/opt/fred/.env"
if [[ $role == storage ]]; then
    put "$bundle/storage/postgres/pg_hba.conf" /etc/fred/postgres/pg_hba.conf
    put "$bundle/storage/postgres/initdb/10-fred-databases.sh" /etc/fred/postgres/initdb/10-fred-databases.sh 0755
else
    for file in "$bundle"/app/config/*; do put "$file" "/etc/fred/config/${file##*/}"; done
    for file in "$bundle"/app/templates/*.yaml; do   # ${NOM} remplacé ; nom inconnu = erreur
        python3 -c 'import os,string,sys; sys.stdout.write(string.Template(open(sys.argv[1]).read()).substitute(os.environ))' \
            "$file" > "$next/etc/fred/config/${file##*/}"
    done
fi
echo "Fichiers préparés :"
(cd "$next" && find . -type f | sed 's|^\.|  |' | sort)
