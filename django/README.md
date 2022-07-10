# Django docker Template
## Start Django New version
- create django project
```bash
    sh start-django.sh
```
- create docker component
    - <a href="docker-compose.yml"> docker-compose.yml </a>
    - <a href="backend/Dockerfile"> Dockerfile </a>
    - <a href="backend/runserver.sh"> runserver.sh </a>
    - <a href=".env"> .env </a>

- edit django project settings

```python
import os
...

SECRET_KEY = os.environ.get('DJANGO_SECRET')

DEBUG = os.environ.get('STATE', None) == "dev"
if DEBUG:print("STATE :", os.environ.get('STATE'))

INSTALLED_APPS = [
    ...
    'corsheaders',
    'rest_framework',
    ...
]

MIDDLEWARE = [
    ...
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.common.CommonMiddleware',
]

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('POSTGRES_DB', None),
        'USER': os.environ.get('POSTGRES_USER', None),
        'PASSWORD': os.environ.get('POSTGRES_PASSWORD', None),
        'HOST': os.environ.get('DB_HOST', None),
        'PORT': os.environ.get('DB_PORT', None),
    }
}

MEDIA_ROOT = os.path.join(BASE_DIR, 'media')


CORS_ORIGIN_WHITELIST = [
    'http://localhost:30000',
]
```

- edit in ```backend/settings.py```
```python
from django.urls import path, include

urlpatterns = [
    ...
    path('api/', include('api.urls'))
    ...
]
```

if use server-side render(ssr)
- edit in ```settings.py```
```python
STATIC_URL = '/static/'
STATIC_ROOT = f"/var/www/{os.environ.get('PROJECT_NAME')}/static/"
STATICFILES_DIRS = [
    os.path.join(BASE_DIR, "static"),
]
MEDIA_URL = '/media/'
MEDIA_ROOT = f"/var/www/{os.environ.get('PROJECT_NAME')}/media/"
```
- edit in ```urls.py```
```python
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    ...
]+static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
```
## Architech Backend

```
.
├── Dockerfile
├── api
│   ├── urls.py
│   └── v1
│   |   ├── routers.py
│   |   ├── serializers.py
│   |   └── viewsets.py
|   |____
|    ... v2
├── backend
│   ├── __init__.py
│   ├── asgi.py
│   ├── settings.py
│   ├── urls.py
│   └── wsgi.py
├── manage.py
├── requirements.txt
└── runserver.sh
```

## Environment ```.env```

```bash
PROJECT_NAME=<projectname>
STATE=<dev/production>

DJANGO_SECRET=<DJANGO SECRETKEY>
DJANGO_ALLOW_ASYNC_UNSAFE=true
PYTHONUNBUFFERED=1

POSTGRES_DB=<DB NAME>
POSTGRES_USER=<DB USER>
POSTGRES_PASSWORD=<DB PASSWORD>
DB_HOST=${PROJECT_NAME}-db
DB_PORT=5432

NODE_ENV=development
CI=true
```

# Django command
```must be exec in django container```
- start app
```sh
python manage.py startapp 
```