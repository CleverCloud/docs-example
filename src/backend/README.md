
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

Set impress on editable mode in `requirements.tx`:

```
impress @ file://${PWD}
```

will expand to the current working directory where your setup.py is located. This will allow pip to find and install the local impress package correctly

Environment variables list:

```env
APP_FOLDER="/src/backend"
CC_PYTHON_MODULE="impress.wsgi:application"
CC_PYTHON_VERSION="3"
CC_TROUBLESHOOT="true"
CELLAR_STORAGE_BUCKET_NAME="impress-media-storage"
DJANGO_ALLOWED_HOSTS="frontend-url/*"
DJANGO_CONFIGURATION="Development"
DJANGO_SECRET_KEY="YourNewlyGeneratedKeyHere"
DJANGO_SETTINGS_MODULE="impress.settings"
DJANGO_SUPERUSER_PASSWORD="<your-password>"
OIDC_OP_AUTHORIZATION_ENDPOINT="<>"
OIDC_OP_JWKS_ENDPOINT="<>"
OIDC_OP_TOKEN_ENDPOINT="<>"
OIDC_OP_USER_ENDPOINT="<>"
OIDC_RP_CLIENT_SECRET="<your-sercet>"
STATIC_URL="frontend url"
```
