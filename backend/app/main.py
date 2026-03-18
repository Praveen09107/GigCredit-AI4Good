"""
Entry point for the GigCredit FastAPI backend.

This is a minimal skeleton; routing, auth, and database wiring
will be implemented according to the planning docs.
"""

from fastapi import FastAPI

app = FastAPI(title="GigCredit Backend")


@app.get("/")
async def root() -> dict:
    return {"status": "GigCredit API Running"}

