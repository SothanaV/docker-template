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

INSTALLED_APPS = [
    ...
    'corsheaders',
    'rest_framework',
    ...
]

MIDDLEWARE = [
    ...
    'corsheaders.middleware.CorsMiddleware'
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

CORS_ORIGIN_WHITELIST = [
    'http://localhost:30000',
]

CSRF_TRUSTED_ORIGINS = [
    os.environ.get('CSRF_TRUSTED_ORIGINS', 'http://localhost:8000')
]

SESSION_COOKIE_NAME = os.environ.get('PROJECT_NAME', "django")
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

urlpatterns+=static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
```

- optional securities `settings.py`
```python
SESSION_COOKIE_AGE=60*60*24 # sec
SESSION_EXPIRE_AT_BROWSER_CLOSE=True
```
## Architech Backend

```
.
├── Dockerfile
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

CSRF_TRUSTED_ORIGINS='<DOMAIN eg https://system.data.storemesh.com>'
```

# Django command
```must be exec in django container```
- start app
```sh
python manage.py startapp 
```

# Setup Api Docs
`settings.py`
```python
INSTALLED_APPS = [
    ...
    'drf_yasg',
    ...
]
```
`urls.py`
```python
from django.urls import re_path
from rest_framework import permissions
from drf_yasg.views import get_schema_view
from drf_yasg import openapi

schema_view = get_schema_view(
   openapi.Info(
      title="Snippets API",
      default_version='v1',
      description="""<br><p>APP Name</p><br><br>SignIn to admin <a href="/admin/"> Admin page </a>""",
      terms_of_service="https://www.google.com/policies/terms/",
      contact=openapi.Contact(email="contact@snippets.local"),
      license=openapi.License(name="BSD License"),
   ),
   public=True,
   permission_classes=[permissions.AllowAny],
)

urlpatterns += [
   re_path(r'^swagger(?P<format>\.json|\.yaml)$', schema_view.without_ui(cache_timeout=0), name='schema-json'),
   re_path(r'^swagger/$', schema_view.with_ui('swagger', cache_timeout=0), name='schema-swagger-ui'),
   re_path(r'^$', schema_view.with_ui('redoc', cache_timeout=0), name='schema-redoc'),
   
]
```