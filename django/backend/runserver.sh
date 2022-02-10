while ! nc -w 1 -z ${PROJECT_NAME}_db 5432;
do sleep 5;
done;

python manage.py runserver 0.0.0.0:8000