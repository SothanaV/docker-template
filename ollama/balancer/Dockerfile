FROM python:3.14-slim
RUN pip install fastapi httpx 'uvicorn[standard]'

ADD . /balancer
WORKDIR /balancer