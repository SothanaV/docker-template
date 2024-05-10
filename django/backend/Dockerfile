FROM python:3.12-slim
RUN apt-get update --fix-missing

RUN apt install -y git netcat-traditional curl iputils-ping

WORKDIR /backend
ADD ./requirements.txt requirements.txt
RUN pip install -r requirements.txt
ADD . /backend/
WORKDIR /backend