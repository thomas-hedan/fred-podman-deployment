# Déployer Fred chez le client

Fred tourne sur **deux VM RHEL avec Podman**, déployées par **Azure DevOps Server**
depuis ce dépôt. Les images viennent d'une **registry OCI** (locale, Harbor…).

| VM | Services | Compose |
|---|---|---|
| Stockage | PostgreSQL (TLS) et SeaweedFS S3 (HTTPS) | [bundle/storage/compose.yaml](bundle/storage/compose.yaml) |
| Applicative | Frontend HTTPS, services Fred, OpenFGA, Temporal | [bundle/app/compose.yaml](bundle/app/compose.yaml) |

- **Première installation** : [docs/INSTALLATION.md](docs/INSTALLATION.md)
- **Variables Library** : [docs/VARIABLES.md](docs/VARIABLES.md)
- **Déployer, mettre à jour, arrêter** : [docs/EXPLOITATION.md](docs/EXPLOITATION.md)

## Comment ça marche

```text
pipeline/deploy.yml  (paramètres : environnement, imageTag)
  stage storage → agent-stockage    ┐ checkout de ce dépôt, puis une tâche Azure par étape :
  stage app     → agent-applicatif  ┘ env -0 | sudo fred-run <checkout> deploy <rôle> <étape>

$ ls bundle/deploy/                     (exécutées en root, dans l'ordre)
0-diagnostic.sh    hors déploiement : agent, variables, secrets  (pipeline/diagnostic.yml)
1-verifier.sh      variables, certificats, mots de passe SQL      ┐ rien n'est
2-preparer.sh      fichiers à installer, dans /opt/fred/.next     ┘ modifié
3-telecharger.sh   accès registry, pull de toutes les images
4-secrets.sh       secrets Podman
5-basculer.sh      arrêt de l'ancienne pile, installation         ┐ coupure
6-migrer.sh        migrations des bases (applicatif)              │ de
7-demarrer.sh      démarrage via systemd, trace de version        │ service
8-controler.sh     contrôle HTTPS de bout en bout                 ┘
lib.sh             commun : lecture et validation des variables
```

- **Versions** : les images Fred prennent le tag `imageTag` du lancement ;
  PostgreSQL et SeaweedFS ont leur tag figé dans le Compose stockage.
- **Configuration** : `bundle/app/templates/*.yaml` contiennent des `${NOM}`
  remplacés sur la VM par les variables Library. Un nom inconnu bloque le déploiement.
- **Secrets** : Library → stdin de `fred-run` → secrets Podman → conteneurs.
  Jamais en argument, jamais dans un fichier.
- **Redémarrage** : `fred-stack.service` relance la pile au boot avec les images déjà présentes.
- **Provenance** : `/opt/fred/deployment.log` garde, à chaque déploiement, le
  commit de ce dépôt, le tag et le digest de chaque image.

## Arborescence

```text
bundle/
├── deploy.sh                 enchaîne les étapes de deploy/ (root, via fred-run)
├── deploy/                   une étape = un fichier = une tâche Azure
├── stop.sh                   arrêt d'un rôle
├── fred-run                  lanceur root, installé une fois par VM (sudoers)
├── fred-stack.service        démarrage au boot
├── podman-hardening.conf     défauts Podman durcis (racine en lecture seule…)
├── storage/                  compose + règles PostgreSQL et création des bases
└── app/
    ├── compose.yaml          services, jobs de migration
    ├── templates/            configs Fred et Temporal avec ${NOM}
    └── config/               catalogues copiés tels quels
pipeline/
├── deploy.yml                stockage puis applicatif
├── stop.yml                  applicatif, puis stockage si cible=all
├── diagnostic.yml            niveau 0 : agents, variables, secrets, sans image
└── stage.yml                 un stage = un rôle = un agent
```

| Besoin | Fichier |
|---|---|
| Ports, volumes, services | `bundle/<rôle>/compose.yaml` |
| Version PostgreSQL / SeaweedFS | ligne `image:` du Compose stockage (une version majeure PostgreSQL demande une migration des données) |
| Configuration Fred | régénérer `bundle/app/templates/` depuis les sources Fred (voir EXPLOITATION) |
| Valeurs d'un environnement | Library Azure |

## Sécurité : ce qui protège quoi

- Le compte de l'agent ne peut lancer en root que `fred-run`. Mais `fred-run`
  exécute les scripts du checkout : **qui peut modifier ce dépôt ou lancer le
  pipeline est root sur les VM**. Protéger la branche (revue obligatoire) et
  les environnements Azure (approbation en prod).
- Chaque VM ne reçoit que les secrets de son rôle : le mot de passe administrateur
  PostgreSQL ne quitte pas la VM stockage.
- Flux réseau : TLS vérifié entre VM, HTTPS pour le navigateur. Seuls `5432`, `8333`
  (stockage) et `443` (applicatif) sont publiés ; le pare-feu filtre les sources.
