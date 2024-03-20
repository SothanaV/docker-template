#!/usr/bin/env bash
python3 -m virtualenv env
source env/bin/activate
pip install django psycopg2-binary djangorestframework django-cors-headers gunicorn
django-admin startproject backend
cd backend
mkdir static
pip freeze > requirements.txt
cd ..