# Variables Library

Trois groupes par environnement (`<env>` = `dev` ou `prod`). Les noms sont les
mêmes partout, seules les valeurs changent. Saisir des valeurs brutes, sans
guillemets. Les valeurs non secrètes ne doivent contenir ni espace, ni `"`, `'`,
`\`, `$` ou `#`.

## `fred-<env>` : chargé par les deux VM

| Nom | Secret | Valeur |
|---|---|---|
| `REGISTRY_HOST` | | Hôte:port de la registry, sans schéma ni chemin : `harbor.client.example:443` |
| `REGISTRY_TLS_VERIFY` | | `true` ; `false` seulement pour une registry de test en HTTP |
| `REGISTRY_USERNAME` | | Compte en lecture seule. Absent ou vide = registry anonyme |
| `REGISTRY_PASSWORD` | 🔒 | Mot de passe ou jeton de ce compte |
| `STO_FQDN` | | Nom DNS de la VM stockage, présent dans ses certificats |
| `APP_FQDN` | | Nom DNS de la VM applicative, présent dans le certificat frontend |
| `PUBLIC_URL` | | Origine HTTPS du navigateur, sans chemin : `https://fred.client.example` |
| `APP_PODMAN_SUBNET` | | CIDR privé interne aux conteneurs applicatifs, sans chevauchement avec les réseaux du client |
| `S3_ACCESS_KEY` | | Identifiant S3, par exemple `fred-app` |
| `S3_SECRET_KEY` | 🔒 | Secret S3 associé |
| `FRED_DB_PASSWORD` | 🔒 | Compte SQL `fred` |
| `OPENFGA_DB_PASSWORD` | 🔒 | Compte SQL `openfga` |
| `TEMPORAL_DB_PASSWORD` | 🔒 | Compte SQL `temporal` |
| `TENANT_ID` | | Tenant Entra |
| `API_APP_ID` | | Client ID de l'application API Fred (audience des jetons) |
| `API_URI` | | URI de l'API, sans suffixe : `api://fred-api` |
| `UI_CLIENT_ID` | | Client ID du frontend (SPA, sans secret) |
| `CP_CLIENT_ID` | | Client ID Control Plane |
| `KF_CLIENT_ID` | | Client ID Knowledge Flow |
| `RUNTIME_CLIENT_ID` | | Client ID des agents Fred |

## `fred-<env>-storage` : VM stockage uniquement

| Nom | Secret | Valeur |
|---|---|---|
| `FRED_POSTGRES_PASSWORD` | 🔒 | Administrateur PostgreSQL `postgres` |

## `fred-<env>-app` : VM applicative uniquement

| Nom | Secret | Valeur |
|---|---|---|
| `CP_SECRET` | 🔒 | Valeur du secret client Entra Control Plane (pas son ID) |
| `KF_SECRET` | 🔒 | Secret client Entra Knowledge Flow |
| `RUNTIME_SECRET` | 🔒 | Secret client Entra des agents Fred |
| `OPENAI_API_KEY` | 🔒 | Clé du fournisseur LLM configuré |
| `OPENFGA_PRESHARED_KEY` | 🔒 | Clé entre Fred et OpenFGA (aléatoire, longue) |
| `FRED_BOOTSTRAP_TOKEN` | 🔒 | Jeton du premier administrateur Fred |

## À savoir

- Une variable manquante ou invalide arrête le déploiement **avant** toute
  modification et donne son nom.
- Un secret ajouté au pipeline doit aussi être mappé dans `pipeline/stage.yml`
  (`env:`) : Azure ne transmet pas les secrets sans mappage explicite.
- Les mots de passe SQL ne servent qu'à la création des bases. Les changer dans
  Library ensuite arrête le déploiement : voir *Changer un mot de passe SQL* dans
  [EXPLOITATION.md](EXPLOITATION.md).
- `imageTag` (version des images) et `agentPool` sont des paramètres de lancement,
  pas des variables Library.
