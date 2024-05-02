while ! nc -w 1 -z ${DB_HOST} ${DB_PORT};
do sleep 5;
done;

python manage.py collectstatic --no-input

n_worker=${1:-4}
echo n_worker=$n_worker
gunicorn --workers=$n_worker --timeout 300 --log-level debug --bind 0.0.0.0:8000 backend.wsgi