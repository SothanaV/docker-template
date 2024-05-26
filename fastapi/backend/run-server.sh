n_worker=${1:-4}
echo n_worker=$n_worker
uvicorn --workers=$n_worker --log-level debug --bind 0.0.0.0:5000 server:app