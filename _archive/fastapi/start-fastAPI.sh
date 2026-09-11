#!/bin/bash
set -e

# Create virtual environment if it doesn't exist
if [ ! -d "env" ]; then
    python3 -m venv env
fi

source env/bin/activate

# Install dependencies
pip install fastapi "uvicorn[standard]" -q

mkdir -p backend

# Create server.py if it doesn't exist
if [ ! -f "backend/server.py" ]; then
    cat > backend/server.py << 'EOF'
from fastapi import FastAPI

app = FastAPI()


@app.get('/')
def read_root():
    return {'Hello': 'World'}
EOF
fi

pip freeze > backend/requirements.txt
echo "FastAPI project setup complete!"