# Première installation

À faire une fois par environnement. Ensuite, tout passe par le pipeline :
[EXPLOITATION.md](EXPLOITATION.md).

## 1. Les VM

Sur **chaque VM** (RHEL 9) :

1. **Paquets** : `podman` (référence 5.8), `podman-compose` (référence 1.6), `python3`,
   `git`, `openssl`, `curl`. Aucun téléchargement n'est fait par le déploiement.
2. **Fournisseur compose** : si podman-compose est dans `/usr/local/bin`,
   créer `/etc/containers/containers.conf.d/90-compose-provider.conf` :

   ```toml
   [engine]
   compose_providers = ["/usr/local/bin/podman-compose"]
   ```

3. **Réseau** : DNS de `STO_FQDN`, `APP_FQDN`, du nom de `PUBLIC_URL` et de la
   registry. Pare-feu : `5432` et `8333` du stockage ouverts à l'applicatif
   seulement, `443` de l'applicatif ouvert aux utilisateurs.
4. **Certificats** issus de la PKI du client (la clé de la CA ne va jamais sur les VM) :

   | VM | Fichiers | Propriétaire de la clé |
   |---|---|---|
   | Les deux | `/etc/fred/tls/ca.crt` | — |
   | Stockage | `/etc/fred/tls/postgres/server.{crt,key}` | UID 999, mode 0600 |
   | Stockage | `/etc/fred/tls/seaweedfs/server.{crt,key}` | UID 1000, mode 0600 |
   | Applicative | `/etc/fred/tls/frontend/server.{crt,key}` | UID 65532, mode 0600 |

   Noms à inclure : `STO_FQDN` pour le stockage ; `APP_FQDN` et le nom de
   `PUBLIC_URL` pour le frontend. La registry HTTPS doit être reconnue par le
   magasin système (`/etc/pki/ca-trust`).

5. **Lanceur root et sudoers**, depuis une copie de ce dépôt :

   ```bash
   sudo install -m 0755 -o root -g root bundle/fred-run /usr/local/sbin/fred-run
   echo 'azagent ALL=(root) NOPASSWD: /usr/local/sbin/fred-run' | sudo tee /etc/sudoers.d/fred-cd
   sudo chmod 0440 /etc/sudoers.d/fred-cd && sudo visudo -c
   ```

   `fred-run` ne change pas d'une version à l'autre : les scripts qu'il lance
   viennent du checkout. Adapter `azagent` au compte des agents.

## 2. Azure DevOps Server

1. **Agents** : un pool (`fred-vms` par défaut, paramètre `agentPool`) contenant
   `agent-stockage` sur la VM stockage et `agent-applicatif` sur la VM applicative.
2. **Library** : trois groupes par environnement (`fred-dev`, `fred-dev-storage`,
   `fred-dev-app`, idem pour `prod`), contenu dans [VARIABLES.md](VARIABLES.md).
3. **Environnements** : `fred-dev-storage`, `fred-dev-app`, `fred-prod-storage`,
   `fred-prod-app`. Mettre une **approbation** sur ceux de prod.
4. **Pipelines** : *New pipeline* → ce dépôt → *Existing YAML file* :
   `pipeline/deploy.yml`, puis `pipeline/stop.yml`. Autoriser leur accès au pool,
   aux groupes Library et aux environnements au premier lancement.
5. **Branche** : protéger la branche déployée (revue obligatoire), car le
   pipeline exécute ses scripts en root sur les VM.

## 3. Premier déploiement

Lancer `deploy.yml` avec `environnement=dev` et `imageTag` égal à la version
publiée dans la registry. Le premier passage crée les bases PostgreSQL avec les
mots de passe de Library : **ils ne pourront plus être changés depuis Library**
sans rotation SQL (voir EXPLOITATION).
