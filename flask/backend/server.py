import os

from flask import Flask, Response, jsonify

app = Flask(__name__)


@app.get("/")
def index():
    return Response("Hello", status=200)


@app.get("/healthz")
def healthz():
    return jsonify({"status": "healthy", "service": os.environ.get("PROJECT_NAME", "flask")})
