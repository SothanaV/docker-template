#!/bin/bash
set -e

n_workers=${1:-4}
root_path=${2:-}

# Remove leading slash to avoid double slashes
root_path="${root_path#/}"

echo "n_workers=$n_workers"
echo "root_path=$root_path"
echo "Starting uvicorn with $n_workers workers..."

uvicorn --log-config log-config.yaml --workers="$n_workers" --log-level debug --host 0.0.0.0 --port 5000 server:app --root-path "${root_path}"