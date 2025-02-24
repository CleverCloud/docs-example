
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
pip install .
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

Environment variables list:

```env
CC_WEBROOT="/api/v1.0/"
```