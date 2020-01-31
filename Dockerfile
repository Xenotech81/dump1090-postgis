FROM python:3-slim-stretch

RUN apt-get -y update && apt-get -y install \
    gcc \
    libpq5 \
    libpq-dev \
    libgeos-dev

ENV DUMP1090_HOST=192.168.0.14 \
    DUMP1090_PORT=30003 \
    POSTGRES_HOST=localhost \
    POSTGRES_PORT=5432 \
    POSTGRES_USER=dump1090 \
    POSTGRES_PW=dump1090 \
    POSTGRES_DB=dump1090 \
    PYTHONPATH=$PYTHONPATH:/app

WORKDIR /app/

COPY requirements.txt .
RUN pip install --disable-pip-version-check --no-cache-dir -r requirements.txt

COPY ./src/ .

ENTRYPOINT ["python", "run.py"]