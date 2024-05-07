FROM python:3.10-slim
RUN apt-get update --fix-missing

RUN apt install -y git gcc g++

WORKDIR /jupyter
ADD ./requirements.txt requirements.txt
RUN pip install -r requirements.txt
ADD . /jupyter/
WORKDIR /jupyter