FROM apache/superset:4.1.4-py310

COPY ./requirements.txt /requirements.txt
USER root
RUN pip3 install --no-cache-dir -r /requirements.txt

USER superset
COPY ./prep.sh /prep.sh
RUN bash /prep.sh