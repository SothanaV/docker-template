FROM python:3.14-slim
RUN apt-get update --fix-missing

RUN apt install -y git netcat-traditional curl iputils-ping

WORKDIR /backend
RUN pip install ollama
ADD . /backend