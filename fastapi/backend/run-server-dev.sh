root_path=${1:-}
uvicorn --log-config log-config.yaml --reload --log-level debug --host 0.0.0.0 --port 5000 server:app --root-path "/${root_path}"