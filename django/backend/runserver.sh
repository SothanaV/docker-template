while ! nc -w 1 -z ${DB_HOST} ${DB_PORT};
do sleep 5;
done;

python manage.py collectstatic --no-input

gunicorn --workers=4 --timeout 300 --log-level debug --bind 0.0.0.0:8000 backend.wsgi