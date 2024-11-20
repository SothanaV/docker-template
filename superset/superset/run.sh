
echo "======= db init ======="
superset db init
echo "======= db upgrade ======="
superset db upgrade
echo "======= create admin ======="
superset fab create-admin \
               --username $SUPERSET_ADMIN_USERNAME \
               --firstname Superset \
               --lastname Admin \
               --email admin@superset.com \
               --password $SUPERSET_ADMIN_PASSWORD
echo "======= init superset ======="
superset init

echo "======= install package ======="
pip install -r requirements.txt

# superset run -p 8088 -h 0.0.0.0 --with-threads --no-debug
gunicorn \
        --bind 0.0.0.0:8088 \
        --workers 4 \
        --worker-class gthread \
        --threads 8 \
        --timeout 120 \
        'superset.app:create_app()'
