FROM docker.io/library/python:3.11-slim

# ----------------------------
# Environment
# ----------------------------
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    TZ=UTC

WORKDIR /app

# ----------------------------
# System dependencies
# ----------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       curl \
       ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# ----------------------------
# Python dependencies
# ----------------------------
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# ----------------------------
# Application code
# ----------------------------
COPY app /app/app

# ----------------------------
# Runtime
# ----------------------------
EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
