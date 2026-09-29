FROM python:3.10-slim

RUN apt-get update && apt-get install -y \
    gdal-bin \
    libgdal-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt gunicorn

COPY . .

RUN python manage.py collectstatic --noinput || true

CMD ["gunicorn", "backend_incidencias.wsgi:application", "--bind", "0.0.0.0:8000"]
