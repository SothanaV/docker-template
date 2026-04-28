n_worker=${1:-4}
root_path=${2:-}
echo n_worker=$n_worker
echo root_path=$root_path
uvicorn --log-config log-config.yaml --workers=$n_worker --log-level debug --host 0.0.0.0 --port 5000 server:app --root-path "/${root_path}"