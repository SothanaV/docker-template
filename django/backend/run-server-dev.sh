while ! nc -w 1 -z ${POSTGRES_HOST} ${POSTGRES_PORT};
do sleep 5;
done;

uv run python manage.py runserver 0.0.0.0:8000