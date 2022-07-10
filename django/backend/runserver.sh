while ! nc -w 1 -z ${DB_HOST} ${DB_PORT};
do sleep 5;
done;

python manage.py runserver 0.0.0.0:8000