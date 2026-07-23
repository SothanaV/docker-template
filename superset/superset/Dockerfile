FROM apache/superset:6.1.0

COPY ./requirements.txt /requirements.txt
USER root
RUN /app/.venv/bin/python3 -m ensurepip --upgrade && \
    /app/.venv/bin/python3 -m pip install --no-cache-dir --upgrade pip setuptools && \
    /app/.venv/bin/python3 -m pip install --no-cache-dir -r /requirements.txt
USER superset
COPY ./prep.sh /prep.sh
RUN bash /prep.sh
