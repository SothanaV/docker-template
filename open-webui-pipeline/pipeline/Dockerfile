FROM ghcr.io/open-webui/pipelines:main
COPY ./requirements.txt requirements.txt
RUN pip install -r requirements.txt
RUN pip install -U litellm
ADD ./pipelines /app/pipelines