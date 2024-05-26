python3 -m venv env
source env/bin/activate
pip install fastapi "uvicorn[standard]"
mkdir backend
echo "from typing import Union

from fastapi import FastAPI

app = FastAPI()


@app.get('/')
def read_root():
    return {'Hello': 'World'}

" > backend/server.py
pip freeze > backend/requirements.txt