#!/usr/bin/env bash
python3 -m venv env
source env/bin/activate
pip install -U django psycopg2-binary djangorestframework django-cors-headers drf-yasg gunicorn setuptools
django-admin startproject backend
mkdir backend/static
echo "test" > backend/static/test.txt
pip freeze > backend/requirements.txt