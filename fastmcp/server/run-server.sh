n_worker=${1:-4}
uvicorn --workers=$n_worker --log-level debug --host 0.0.0.0 --port 8000 server:app