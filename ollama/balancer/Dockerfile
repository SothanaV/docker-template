FROM python:3.12-slim
RUN pip install fastapi httpx 'uvicorn[standard]'

ADD . /balancer
WORKDIR /balancer