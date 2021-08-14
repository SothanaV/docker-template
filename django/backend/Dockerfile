FROM python:3.7-slim
RUN apt update

RUN apt install -y git netcat

WORKDIR /backend
ADD ./requirements.txt requirements.txt
RUN pip install -r requirements.txt
ADD . /backend/
WORKDIR /backend