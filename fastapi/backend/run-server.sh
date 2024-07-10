n_worker=${1:-4}
echo n_worker=$n_worker
uvicorn --workers=$n_worker --log-level debug --host 0.0.0.0 --port 5000 server:app