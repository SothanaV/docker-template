FROM python:3.14-slim

RUN apt-get update --fix-missing && \
    apt install -y git netcat-traditional curl iputils-ping && \
    apt-get clean


ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_PROJECT_ENVIRONMENT=/venv \
    PATH="/venv/bin:$PATH"

WORKDIR /backend

COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

COPY pyproject.toml ./
RUN uv sync

COPY . .
