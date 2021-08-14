#!/usr/bin/env bash
virtualenv env
source env/bin/activate
pip install django psycopg2-binary djangorestframework django-cors-headers
django-admin startproject backend
cd backend
pip freeze > requirements.txt
cd ..