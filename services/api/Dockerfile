FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_NO_CACHE=1

RUN useradd --create-home --uid 10001 app
WORKDIR /app
COPY --from=ghcr.io/astral-sh/uv:0.11.17 /uv /usr/local/bin/uv
COPY services/api/pyproject.toml services/api/uv.lock ./
COPY services/api/src ./src
COPY models ./models
RUN uv sync --frozen --no-dev --group face
USER app
EXPOSE 8000
CMD [".venv/bin/uvicorn", "attendance_api.main:app", "--host", "0.0.0.0", "--port", "8000"]
