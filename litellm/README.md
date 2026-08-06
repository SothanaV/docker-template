# LiteLLM Proxy

Docker Compose template for [LiteLLM](https://github.com/BerriAI/litellm) — an open-source proxy server that provides a OpenAI-compatible API for 100+ LLMs including OpenAI, Anthropic, Azure, Bedrock, Vertex AI, Ollama, and more.

## Quick Start

```bash
docker compose up
```

## Access

- LiteLLM API: http://localhost:${LITELLM_PORT:-4000}
- API Docs: http://localhost:${LITELLM_PORT:-4000}/docs
- Open WebUI: http://localhost:${WEBUI_PORT:-8080}
- Ollama: http://localhost:${OLLAMA_PORT:-11434}

## Architecture

| Service      | Description                          | Port      |
|-------------|--------------------------------------|-----------|
| `postgres`  | PostgreSQL database for LiteLLM      | 5432      |
| `litellm`   | LiteLLM proxy server                 | 4000      |

## Configuration

Edit `.env`:

- `LITELLM_MASTER_KEY`: Master API key for LiteLLM admin


Edit `config.yaml` for:

- Retry policy (`num_retries`, `request_timeout`)
- Guardrails configuration
- Rate limiting

Models are configured by adding entries to `models.yaml` in the LiteLLM container or via the `/model/info` API.

## Adding Models

Via API:

```bash
curl -X POST http://localhost:4000/model/new \
  -H "Authorization: Bearer your-master-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model_name": "gpt-4",
    "litellm_params": {
      "model": "openai/gpt-4",
      "api_key": "sk-your-key"
    }
  }'
```

Via `model.yaml` file mounted at `/app/model.yaml` in the container.

## Python Client

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:4000/v1",
    api_key="your-master-key"
)

response = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "Hello!"}]
)
print(response.choices[0].message.content)
```