from flask import Flask, Response

app = Flask(__name__)

@app.route('/', methods=['GET'])
def index():
    return Response("Hello", status=200)
