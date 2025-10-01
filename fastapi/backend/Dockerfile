FROM python:3.12-slim

RUN apt-get update --fix-missing && \ 
    apt-get install -y --no-install-recommends \
        git netcat-traditional curl iputils-ping dnsutils && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /backend
ADD ./requirements.txt requirements.txt
RUN pip install -r requirements.txt
ADD . /backend/
WORKDIR /backend