# Ollama Multi-GPU Cluster

A Docker Compose template for running multiple [Ollama](https://ollama.com/) instances across multiple NVIDIA GPUs, with Nginx load balancing, automatic model pulling, and a custom balancer service.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)
- NVIDIA GPU(s) with [nvidia-container-runtime](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) installed

## Architecture

```
                    ┌─────────────────────────────────────┐
Client → :11434 → Nginx → ollama-1 (GPU 0)
                        → ollama-2 (GPU 1)
                        → ollama-3 (GPU 2)
                        → ollama-4 (GPU 3)

Client → :11435 → Custom Balancer (advanced routing)
```

- **ollama-1 to ollama-4**: Four Ollama v0.6.0 instances, each pinned to a different GPU
- **nginx**: Load balancer on port 11434 distributing requests across all instances
- **balancer**: Custom balancer service on port 11435 for advanced routing
- **puller**: Automatically pulls configured models on startup

## Quick Start

```bash
docker compose up -d
```

Models are pulled automatically by the `puller` service. Wait for model downloads to complete before sending requests.

Access:
- Nginx proxy: http://localhost:11434
- Custom balancer: http://localhost:11435

## Services

| Service    | Image / Build       | Port  | GPU              |
|------------|---------------------|-------|------------------|
| `ollama-1` | `ollama/ollama:0.6.0` | —   | Default (GPU 0)  |
| `ollama-2` | `ollama/ollama:0.6.0` | —   | GPU 1            |
| `ollama-3` | `ollama/ollama:0.6.0` | —   | GPU 2            |
| `ollama-4` | `ollama/ollama:0.6.0` | —   | GPU 3            |
| `nginx`    | `nginx`             | 11434 | —                |
| `balancer` | `./balancer`        | 11435 | —                |
| `puller`   | `./script`          | —     | —                |

## Configuration

### Models

Edit the `MODEL_NAMES` environment variable in the `puller` service to change which models are pulled:

```yaml
environment:
  - MODEL_NAMES=llama3.3,gemma3:27b
```

### Parallelism

Each Ollama instance is configured with `OLLAMA_NUM_PARALLEL=16` (16 parallel requests) and `OLLAMA_KEEP_ALIVE=-1` (keeps models loaded indefinitely).

### Nginx & Balancer Config

- Nginx: edit `./config/nginx.conf` and `./config/default.conf`
- Balancer: edit files in `./balancer/`

## Stop

```bash
docker compose down
```
