FROM codercom/code-server:4.104.1

ENV SHELL=/bin/bash
RUN sudo apt update && \
    sudo apt upgrade -y && \
    sudo apt install -y wget git htop gcc g++ netcat-traditional curl iputils-ping docker-compose

WORKDIR /home/jovyan