"""Entry point for the GigCredit FastAPI backend."""

from __future__ import annotations

from contextlib import asynccontextmanager
import time
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from .database import close_client, ensure_indexes, indexes_ready, ping_database
from .models.api import ApiResponse
from .routers import report, verify
from .utils.logging import get_logger

logger = get_logger(__name__)


def _trace_id_from_request(request: Request) -> str:
    return request.headers.get("X-Request-ID") or str(uuid4())


@asynccontextmanager
async def lifespan(_: FastAPI):
    await ensure_indexes()
    yield
    close_client()


app = FastAPI(title="GigCredit Backend", version="0.1.0", lifespan=lifespan)
app.include_router(verify.router)
app.include_router(report.router)


@app.middleware("http")
async def request_logging_middleware(request: Request, call_next):
    trace_id = _trace_id_from_request(request)
    start = time.perf_counter()
    request.state.trace_id = trace_id
    try:
        response = await call_next(request)
    finally:
        latency_ms = int((time.perf_counter() - start) * 1000)
        logger.info(
            "trace_id=%s method=%s path=%s latency_ms=%d",
            trace_id,
            request.method,
            request.url.path,
            latency_ms,
        )
    response.headers["X-Trace-ID"] = trace_id
    return response


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException) -> JSONResponse:
    trace_id = getattr(request.state, "trace_id", _trace_id_from_request(request))
    if exc.status_code == 401:
        envelope_status = "ERROR"
    elif exc.status_code == 429:
        envelope_status = "ERROR"
    elif exc.status_code == 400:
        envelope_status = "INVALID"
    else:
        envelope_status = "ERROR"

    payload = ApiResponse(
        status=envelope_status,
        data=None,
        error=str(exc.detail),
        trace_id=trace_id,
    )
    return JSONResponse(status_code=exc.status_code, content=payload.model_dump())


@app.exception_handler(RequestValidationError)
async def request_validation_exception_handler(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    trace_id = getattr(request.state, "trace_id", _trace_id_from_request(request))
    payload = ApiResponse(
        status="INVALID",
        data=None,
        error=str(exc.errors()),
        trace_id=trace_id,
    )
    return JSONResponse(status_code=400, content=payload.model_dump())


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, _: Exception) -> JSONResponse:
    trace_id = getattr(request.state, "trace_id", _trace_id_from_request(request))
    payload = ApiResponse(
        status="ERROR",
        data=None,
        error="Internal server error",
        trace_id=trace_id,
    )
    return JSONResponse(status_code=500, content=payload.model_dump())


@app.get("/")
async def root() -> dict[str, str]:
    return {"status": "GigCredit API Running"}


@app.get("/health")
async def health() -> dict[str, bool]:
    db_ok = await ping_database()
    return {"ok": True, "db": db_ok, "indexes_ready": db_ok and indexes_ready()}

