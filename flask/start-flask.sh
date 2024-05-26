python3 -m venv env
source env/bin/activate
pip install Flask gunicorn
mkdir backend
echo "from flask import Flask, Response

app = Flask(__name__)

@app.route('/', methods=['GET'])
def index():
    return Response('Hello', status=200)

" > backend/server.py
pip freeze > backend/requirements.txt