# Create the virtual environment
python -m venv env

# Activate the virtual environment
.\env\Scripts\Activate.ps1

# Install and upgrade required packages
pip install -U django psycopg2-binary djangorestframework django-cors-headers drf-yasg gunicorn setuptools

# Start the Django project
django-admin startproject backend

# Create the static directory
New-Item -ItemType Directory -Force -Path backend\static

# Create the test file
Set-Content -Path backend\static\test.txt -Value "test"

# Save the requirements
pip freeze > backend\requirements.txt