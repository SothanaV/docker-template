FROM python:3.8-slim
RUN apt-get update --fix-missing

RUN apt install -y git netcat

WORKDIR /backend
ADD ./requirements.txt requirements.txt
RUN pip install -r requirements.txt
ADD . /backend/
WORKDIR /backend