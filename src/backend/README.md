
## Run the backend without helm/Docker

## Locally

1. Start the virtual environment:

```shell
python3 -m venv venv                                                         
source venv/bin/activate
```

2. Install dependencies

On production mode:

```shell
pip install .
```

On development mode:

```shell
pip install -e .\[dev\]
```

3. Create `requirement.tx`:

```shell
pip freeze > requirements.txt
```

4. Install dependencies

```shell
pip install -r requirements.txt 
```

5. Run/check migrations

```shell
python3 manage.py migrate
```

6. Run the server

```shell
python3 manage.py runserver
```

Try accessing the webserver at http://127.0.0.1:8000/api/v1.0/

## Deploy on Clever Cloud

Check that impress is set on editable mode in `requirements.tx`:

```
impress @ file://${PWD}
```

This will expand to the current working directory where your setup.py is located, and allow pip to find and install the local impress package correctly.

### Environment variables

```env
APP_FOLDER="/src/backend"
CC_PYTHON_MODULE="impress.wsgi:application"
CC_PYTHON_VERSION="3"
CC_RUN_SUCCEEDED_HOOK="cd src/backend && python manage.py migrate"
CELLAR_STORAGE_BUCKET_NAME="impress-media-storage"
DJANGO_ALLOWED_HOSTS="<docs-url>"
DJANGO_CONFIGURATION="Development"
DJANGO_SECRET_KEY="YourNewlyGeneratedKeyHere"
DJANGO_SETTINGS_MODULE="impress.settings"
DJANGO_SUPERUSER_PASSWORD="<your-password>"
LOGIN_REDIRECT_URL="<docs-url>"
OIDC_OP_JWKS_ENDPOINT: <keycloak-host>/realms/impress/protocol/openid-connect/certs
OIDC_OP_AUTHORIZATION_ENDPOINT: <keycloak-host>/realms/impress/protocol/openid-connect/auth
OIDC_OP_TOKEN_ENDPOINT: <keycloak-host>/realms/impress/protocol/openid-connect/token
OIDC_OP_USER_ENDPOINT: <keycloak-host>/realms/impress/protocol/openid-connect/userinfo
OIDC_OP_LOGOUT_ENDPOINT: <keycloak-host>/realms/impress/protocol/openid-connect/session/end
OIDC_RP_CLIENT_ID: impress
OIDC_RP_CLIENT_SECRET: ThisIsAnExampleKeyForDevPurposeOnly
OIDC_RP_SIGN_ALGO: RS256
OIDC_RP_SCOPES: "openid email"
STATIC_URL="<docs-url>"
REDIS_URL="redis://default:password@host:port"
```

⚠️ Since `REDIS_URL` value format differs from the one provided by the add-on on Clever Cloud, insert its values manually (leave `default`).

Find more useful environment variables in [the samples values file](/env.d/development/common.dist)

#### Exposed configuration

Connect the backend to the frontend in **Service dependencies**, and in **Exposed configuration**, expose the variables defined 

### Domains

To host both backend and frontend **under the same domain**, leverage [the path routing feature on Clever Cloud](https://www.clever-cloud.com/developers/doc/administrate/domain-names/#path-routing). Configure the domain name for the backend as follows:

- Domain name: the frontend domain name
- Route: `/api/v1.0/`

⚠️ The trailing slash `/` at the end of the route is mandatory to prevent path duplication from NGINX.
