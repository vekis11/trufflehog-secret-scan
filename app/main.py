"""Small API behind Nginx; no secrets in application code."""

from fastapi import FastAPI

app = FastAPI(title="Demo API", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/")
def root() -> dict[str, str]:
    return {"message": "hello from app"}
