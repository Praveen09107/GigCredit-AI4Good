"""MongoDB connection helpers for the GigCredit backend."""

from __future__ import annotations

from typing import Any

from .config import settings

_client: Any = None


def _motor_asyncio_module() -> Any:
    import importlib

    return importlib.import_module("motor.motor_asyncio")


def get_client() -> Any:
    global _client
    if _client is None:
        motor_asyncio = _motor_asyncio_module()
        _client = motor_asyncio.AsyncIOMotorClient(
            settings.mongo_uri,
            serverSelectionTimeoutMS=3000,
        )
    return _client


def get_database() -> Any:
    client = get_client()
    return client[settings.mongo_db_name]


def get_collection(name: str) -> Any:
    return get_database()[name]


async def ping_database() -> bool:
    try:
        await get_database().command("ping")
        return True
    except Exception:
        return False


def close_client() -> None:
    global _client
    if _client is not None:
        _client.close()
        _client = None

