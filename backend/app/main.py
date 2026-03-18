"""Entry point for the GigCredit FastAPI backend."""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI

from .database import close_client, ping_database
from .routers import report, verify


@asynccontextmanager
async def lifespan(_: FastAPI):
    yield
    close_client()


app = FastAPI(title="GigCredit Backend", version="0.1.0", lifespan=lifespan)
app.include_router(verify.router)
app.include_router(report.router)


@app.get("/")
async def root() -> dict[str, str]:
    return {"status": "GigCredit API Running"}


@app.get("/health")
async def health() -> dict[str, bool]:
    return {"ok": True, "db": await ping_database()}

