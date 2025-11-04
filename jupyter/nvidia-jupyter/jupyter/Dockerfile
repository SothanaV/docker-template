FROM nvidia/cuda:12.8.0-cudnn-devel-ubuntu24.04
RUN apt-get update --fix-missing

RUN apt install -y git gcc g++ python3 python3-pip python3.12-venv

WORKDIR /jupyter
ADD ./requirements.txt requirements.txt
RUN pip install virtualenv --break-system-packages
ADD . /jupyter/
RUN python3 -m venv /jupyter/venv && \
    . /jupyter/venv/bin/activate &&\
    pip install -r /jupyter/requirements.txt && \
    ls /jupyter/venv/bin/activate && \
    python3 -m ipykernel install --user --name coop2025 --display-name "Python (coop2025)"
WORKDIR /jupyter