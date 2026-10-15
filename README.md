![Logo Clever Cloud](./assets/clever-cloud-logo.png)

# Deploy Docs (La Suite numérique) on Clever Cloud
[![Clever Cloud - PaaS](https://img.shields.io/badge/Clever%20Cloud-PaaS-orange)](https://clever-cloud.com)

This repository is a fork of [Docs](https://github.com/suitenumerique/docs), the open source
collaborative note-taking, wiki and documentation platform built by the French and German
governments (Django REST Framework, Next.js, BlockNote.js and Yjs). It tracks upstream release
**v5.7.0** and adds the few files needed to run it natively on Clever Cloud, without Docker or
Kubernetes.

Docs is made of three components, deployed here as four Clever Cloud applications sharing a
single domain thanks to [path routing](https://www.clever.cloud/developers/doc/administrate/domain-names/):

| Application   | Runtime          | Route                              | Purpose                                         |
|---------------|------------------|------------------------------------|-------------------------------------------------|
| Backend       | Python 3.14 (uv) | `/api/`                            | Django API, OIDC authentication, migrations     |
| Collaboration | Node.js 24       | `/collaboration/`, `/api/convert/` | Yjs live editing server and document conversion |
| Frontend      | Static (Caddy)   | `/`                                | Next.js static export                           |
| Media proxy   | Linux (Caddy)    | `/media/`                          | Authenticated access to private Cellar objects  |

They rely on a PostgreSQL, a Redis and a Cellar (S3-compatible) add-on, and on an OpenID Connect
provider such as the Clever Cloud Keycloak add-on.

The full walkthrough is also available in the
[Clever Cloud Docs guide](https://www.clever.cloud/developers/guides/docs/).

## How it works

- **Backend** – the Python runtime syncs `src/backend` with `uv` (`APP_FOLDER=src/backend`).
  `clevercloud.sh` maps the linked add-on variables (`POSTGRESQL_ADDON_URI`, `CELLAR_ADDON_*`) to
  the names Docs expects (`DATABASE_URL`, `AWS_S3_*`). It runs `migrate` as a post-build hook and
  starts Uvicorn on `0.0.0.0:8080` with `CC_PYTHON_UV_RUN_COMMAND`. Redis provides `REDIS_URL`
  directly.
- **Collaboration** – the Node.js runtime installs the Yarn workspace in `src/frontend`, builds
  the `server-y-provider` workspace and starts it.
- **Frontend** – the Static runtime builds the Next.js static export (`yarn app:build`, L build
  instance) and serves it with Caddy (`frontend-static/Caddyfile`), which rewrites dynamic routes
  such as `/docs/<uuid>/` to the exported page, like the upstream nginx configuration does.
- **Media proxy** – the Linux runtime installs Caddy through Mise (`media-proxy/mise.toml`). For
  each `/media/` request it asks the backend whether the current user may read the object, then
  forwards the signed request to the private Cellar bucket.

Some build-time dependencies (`i18next-parser`) still declare `node <= 22` in their `engines`
field. Node.js 24 LTS works fine, so the frontend and collaboration apps set
`YARN_IGNORE_ENGINES=true`.

## Project structure

Only the Clever Cloud specific files are listed; everything else is upstream Docs.

```
.
├── clevercloud.sh            # Backend helper: maps add-on variables, runs migrate / uvicorn
├── frontend-static/
│   └── Caddyfile             # Frontend static server with Docs route rewrites
├── media-proxy/
│   ├── mise.toml             # Installs Caddy, defines the build and run tasks
│   └── Caddyfile             # forward_auth to the backend, then proxy to Cellar
├── src/
│   ├── backend/              # Django application (pyproject.toml + uv.lock)
│   └── frontend/             # Yarn workspace: apps/impress (Next.js) + servers/y-provider
├── documentation/            # Upstream documentation (env variables, customization…)
└── .last-checked             # Date of the last maintenance check of this example
```

## Deployment steps

To deploy Docs, you need [Clever Tools](https://github.com/CleverCloud/clever-tools), Git, jq,
OpenSSL, `s3cmd` (or another S3 client) and a domain name. The commands below run from the root
of this repository.

### 1. Create the applications and add-ons

```bash
clever create -t python myDocsBackend -a myDocsBackend
clever create -t static myDocsFrontend -a myDocsFrontend
clever create -t node myDocsCollaboration -a myDocsCollaboration
clever create -t linux myDocsMedia -a myDocsMedia

clever addon create postgresql-addon myDocsPostgreSQL -p xxs_sml -l myDocsBackend
clever addon create redis-addon myDocsRedis -p s_mono -l myDocsBackend
clever addon create cellar-addon myDocsCellar -l myDocsBackend
clever addon create keycloak myDocsKeycloak -p base
```

The PostgreSQL `dev` plan is enough for a test instance.

### 2. Create a private Cellar bucket

`clever addon env` expects the add-on ID (`addon_…`), shown by `clever addon list`:

```bash
export DOCS_BUCKET="your-unique-docs-bucket"
CELLAR_ENV="$(clever addon env <myDocsCellar addon ID> -F json)"
export CELLAR_HOST="$(jq -er '.CELLAR_ADDON_HOST' <<<"$CELLAR_ENV")"
s3cmd --access_key="$(jq -er '.CELLAR_ADDON_KEY_ID' <<<"$CELLAR_ENV")" \
  --secret_key="$(jq -er '.CELLAR_ADDON_KEY_SECRET' <<<"$CELLAR_ENV")" \
  --host="$CELLAR_HOST" --host-bucket="$CELLAR_HOST" \
  --ssl mb "s3://$DOCS_BUCKET"
unset CELLAR_ENV
```

Do not add a public bucket policy: the media proxy only forwards requests signed by Docs.

### 3. Configure the shared domain

```bash
export DOCS_DOMAIN="docs.example.com"
export DOCS_URL="https://$DOCS_DOMAIN"
clever domain add "$DOCS_DOMAIN" -a myDocsFrontend
clever domain add "$DOCS_DOMAIN/api/" -a myDocsBackend
clever domain add "$DOCS_DOMAIN/collaboration/" -a myDocsCollaboration
clever domain add "$DOCS_DOMAIN/api/convert/" -a myDocsCollaboration
clever domain add "$DOCS_DOMAIN/media/" -a myDocsMedia
```

Keep the trailing slash on each path route. A `*.cleverapps.io` subdomain also works for testing.

### 4. Configure Keycloak

Open the Keycloak add-on from the Console (or with `clever keycloak open`, after
`clever features enable operators`) and log in with the initial credentials it displays. Then:

- create a realm named `impress`
- create an OpenID Connect client `impress` with client authentication and the standard flow
- set its root and home URLs to `$DOCS_URL`, add `$DOCS_URL/api/v1.0/callback/*` to the valid
  redirect URIs, `$DOCS_URL/*` to the post-logout redirect URIs and `$DOCS_URL` to the web origins
- copy the client secret, and create users (or plug an identity provider)

```bash
export KEYCLOAK_URL="https://<your-keycloak-host>"
export OIDC_CLIENT_SECRET="<impress client secret>"
```

### 5. Configure the applications

```bash
export DJANGO_SECRET_KEY="$(openssl rand -base64 48)"
export COLLABORATION_SERVER_SECRET="$(openssl rand -base64 48)"
export Y_PROVIDER_API_KEY="$(openssl rand -base64 48)"
OIDC="$KEYCLOAK_URL/realms/impress/protocol/openid-connect"

# Backend
clever env set APP_FOLDER src/backend -a myDocsBackend
clever env set CC_PYTHON_VERSION 3.14 -a myDocsBackend
clever env set CC_POST_BUILD_HOOK './clevercloud.sh migrate' -a myDocsBackend
clever env set CC_PYTHON_UV_RUN_COMMAND '../../clevercloud.sh run' -a myDocsBackend
clever env set DATA_DIR /tmp/docs -a myDocsBackend
clever env set DJANGO_CONFIGURATION Production -a myDocsBackend
clever env set DJANGO_SETTINGS_MODULE impress.settings -a myDocsBackend
clever env set DJANGO_SECRET_KEY "$DJANGO_SECRET_KEY" -a myDocsBackend
clever env set DJANGO_ALLOWED_HOSTS "$DOCS_DOMAIN" -a myDocsBackend
clever env set DJANGO_CSRF_TRUSTED_ORIGINS "$DOCS_URL" -a myDocsBackend
clever env set CORS_ALLOWED_ORIGINS "$DOCS_URL" -a myDocsBackend
clever env set IMPRESS_BASE_URL "$DOCS_URL" -a myDocsBackend
clever env set LOGIN_REDIRECT_URL "$DOCS_URL" -a myDocsBackend
clever env set LOGIN_REDIRECT_URL_FAILURE "$DOCS_URL" -a myDocsBackend
clever env set LOGOUT_REDIRECT_URL "$DOCS_URL" -a myDocsBackend
clever env set AWS_STORAGE_BUCKET_NAME "$DOCS_BUCKET" -a myDocsBackend
clever env set AWS_S3_REGION_NAME auto -a myDocsBackend
clever env set AWS_REQUEST_CHECKSUM_CALCULATION when_required -a myDocsBackend
clever env set AWS_RESPONSE_CHECKSUM_VALIDATION when_required -a myDocsBackend
clever env set COLLABORATION_API_URL "$DOCS_URL/collaboration/api/" -a myDocsBackend
clever env set COLLABORATION_WS_URL "wss://$DOCS_DOMAIN/collaboration/ws/" -a myDocsBackend
clever env set COLLABORATION_SERVER_SECRET "$COLLABORATION_SERVER_SECRET" -a myDocsBackend
clever env set Y_PROVIDER_API_BASE_URL "$DOCS_URL/" -a myDocsBackend
clever env set Y_PROVIDER_API_KEY "$Y_PROVIDER_API_KEY" -a myDocsBackend
clever env set OIDC_OP_AUTHORIZATION_ENDPOINT "$OIDC/auth" -a myDocsBackend
clever env set OIDC_OP_JWKS_ENDPOINT "$OIDC/certs" -a myDocsBackend
clever env set OIDC_OP_LOGOUT_ENDPOINT "$OIDC/logout" -a myDocsBackend
clever env set OIDC_OP_TOKEN_ENDPOINT "$OIDC/token" -a myDocsBackend
clever env set OIDC_OP_USER_ENDPOINT "$OIDC/userinfo" -a myDocsBackend
clever env set OIDC_REDIRECT_ALLOWED_HOSTS "$DOCS_DOMAIN" -a myDocsBackend
clever env set OIDC_RP_CLIENT_ID impress -a myDocsBackend
clever env set OIDC_RP_CLIENT_SECRET "$OIDC_CLIENT_SECRET" -a myDocsBackend
clever env set OIDC_RP_SCOPES 'openid email profile' -a myDocsBackend
clever env set OIDC_RP_SIGN_ALGO RS256 -a myDocsBackend
clever env set OIDC_USERINFO_FULLNAME_FIELDS 'given_name,family_name' -a myDocsBackend
clever env set OIDC_USERINFO_SHORTNAME_FIELD preferred_username -a myDocsBackend

# Frontend (static export, needs an L build instance)
clever env set APP_FOLDER src/frontend -a myDocsFrontend
clever env set CC_NODE_VERSION 24 -a myDocsFrontend
clever env set CC_BUILD_COMMAND '. /home/bas/.nvm/nvm.sh && nvm use "$CC_NODE_VERSION" && yarn install --frozen-lockfile && yarn app:build' -a myDocsFrontend
clever env set CC_WEBROOT /src/frontend/apps/impress/out -a myDocsFrontend
clever env set CC_STATIC_CADDYFILE ../../frontend-static/Caddyfile -a myDocsFrontend
clever env set CC_OVERRIDE_BUILDCACHE 'src/frontend/apps/impress/out:frontend-static' -a myDocsFrontend
clever env set NEXT_PUBLIC_API_BASE_PATH / -a myDocsFrontend
clever env set NEXT_PUBLIC_API_ORIGIN "$DOCS_URL" -a myDocsFrontend
clever env set NEXT_PUBLIC_PUBLISH_AS_MIT true -a myDocsFrontend
clever env set NEXT_PUBLIC_SW_DEACTIVATED true -a myDocsFrontend
clever env set YARN_IGNORE_ENGINES true -a myDocsFrontend
clever env set -a myDocsFrontend NODE_OPTIONS -- --max-old-space-size=4096
clever scale --build-flavor L -a myDocsFrontend

# Collaboration server
clever env set APP_FOLDER src/frontend -a myDocsCollaboration
clever env set CC_NODE_VERSION 24 -a myDocsCollaboration
clever env set CC_NODE_BUILD_TOOL yarn -a myDocsCollaboration
clever env set CC_NODE_DEV_DEPENDENCIES true -a myDocsCollaboration
clever env set CC_POST_BUILD_HOOK 'cd src/frontend && yarn COLLABORATION_SERVER build' -a myDocsCollaboration
clever env set CC_RUN_COMMAND 'cd src/frontend && yarn COLLABORATION_SERVER start' -a myDocsCollaboration
clever env set COLLABORATION_BACKEND_BASE_URL "$DOCS_URL" -a myDocsCollaboration
clever env set COLLABORATION_LOGGING true -a myDocsCollaboration
clever env set COLLABORATION_SERVER_ORIGIN "$DOCS_URL" -a myDocsCollaboration
clever env set COLLABORATION_SERVER_SECRET "$COLLABORATION_SERVER_SECRET" -a myDocsCollaboration
clever env set Y_PROVIDER_API_KEY "$Y_PROVIDER_API_KEY" -a myDocsCollaboration
clever env set YARN_IGNORE_ENGINES true -a myDocsCollaboration

# Media proxy (no Cellar credentials: Docs signs each authorized request)
clever env set CC_MISE_FILE_PATH media-proxy/mise.toml -a myDocsMedia
clever env set DOCS_BACKEND_HOST "$DOCS_DOMAIN" -a myDocsMedia
clever env set CELLAR_HOST "$CELLAR_HOST" -a myDocsMedia
clever env set AWS_STORAGE_BUCKET_NAME "$DOCS_BUCKET" -a myDocsMedia
```

`NODE_OPTIONS` uses `--` so that Clever Tools does not read its value as an option. The frontend
is built on a dedicated instance and only the build cache reaches the runtime instance:
`CC_OVERRIDE_BUILDCACHE` (relative to the repository root) keeps both the exported site and the
Caddyfile, and `CC_STATIC_CADDYFILE` is relative to `APP_FOLDER`.

### 6. Deploy

```bash
clever deploy -a myDocsBackend
clever deploy -a myDocsCollaboration
clever deploy -a myDocsFrontend
clever deploy -a myDocsMedia
```

Then open `$DOCS_URL`, sign in through Keycloak, create a document and upload an image. You can
also check the public configuration endpoint and that anonymous media requests are rejected:

```bash
curl -sS "$DOCS_URL/api/v1.0/config/" | jq .
curl -sS -o /dev/null -w '%{http_code}\n' "$DOCS_URL/media/not-authorized"   # 403
```

### Update Docs

Back up PostgreSQL, rebase the Clever Cloud files onto the new upstream tag and redeploy the four
applications. The backend build hook applies pending migrations.

```bash
git remote add upstream https://github.com/suitenumerique/docs.git
git fetch upstream --tags
git rebase vX.Y.Z
```

## Running locally

Docs is developed with Docker Compose. With Docker and GNU Make installed:

```bash
make bootstrap FLUSH_ARGS='--no-input'
```

Then open <http://localhost:3000> and log in with `impress` / `impress`. See the
[upstream README](https://github.com/suitenumerique/docs#readme) and the
[`documentation/`](./documentation/) folder for the other Make rules, environment variables and
customization options.

## Troubleshooting

1. Check the logs of each application: `clever logs -a myDocsBackend` (and so on).
2. Verify the environment variables: `clever env -a myDocsBackend`.
3. The frontend build is memory hungry: keep the L build instance and `NODE_OPTIONS`.
4. `yarn install` failing with `The engine "node" is incompatible` means `YARN_IGNORE_ENGINES` is
   missing.
5. A `400 Bad Request` with `DisallowedHost` in the backend logs during deployment comes from the
   internal health check and can be ignored. Check that `DJANGO_ALLOWED_HOSTS` matches your domain.
6. If `/docs/<uuid>/` links return the 404 page, the frontend is served by Static Web Server
   instead of Caddy: check `CC_OVERRIDE_BUILDCACHE` and `CC_STATIC_CADDYFILE`.
7. Login errors usually come from the Keycloak client: check the redirect URIs and the secret.

## Contributing

Contributions to improve this deployment example are welcome! Please feel free to submit pull
requests or open issues for any enhancements or bug fixes. Contributions to Docs itself go to the
[upstream repository](https://github.com/suitenumerique/docs/blob/main/CONTRIBUTING.md).

## License

Docs is released under the MIT License (see [LICENSE](./LICENSE)). Some advanced features (such
as PDF export) rely on AGPL-3.0 BlockNote XL packages: this example sets
`NEXT_PUBLIC_PUBLISH_AS_MIT=true` to build without them.
