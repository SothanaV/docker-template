from flask import Flask, Response, jsonify
import os

app = Flask(__name__)

@app.route('/', methods=['GET'])
def index():
    return Response("Hello", status=200)


@app.route("/healthz", methods=['GET'])
def healthz():
    status = {"status": "healthy", "service": "flask"}

    # Check PostgreSQL
    try:
        from sqlalchemy import create_engine
        import sqlalchemy
        db_url = os.getenv("DATABASE_URL", os.getenv("SQLALCHEMY_DATABASE_URI", ""))
        if db_url:
            engine = create_engine(db_url)
            with engine.connect() as conn:
                conn.execute(sqlalchemy.text("SELECT 1"))
            status["postgresql"] = "connected"
    except Exception as e:
        status["postgresql"] = f"disconnected: {str(e)}"
        status["status"] = "degraded"

    # Check Redis
    try:
        import redis
        redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
        r = redis.from_url(redis_url)
        r.ping()
        status["redis"] = "connected"
    except Exception as e:
        status["redis"] = f"disconnected: {str(e)}"
        status["status"] = "degraded"

    code = 503 if status["status"] != "healthy" else 200
    return jsonify(status), code
