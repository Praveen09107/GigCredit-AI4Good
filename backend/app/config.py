"""
Configuration for the GigCredit backend.

Values should ultimately be loaded from environment variables or a `.env` file.
"""

from pydantic import BaseSettings


class Settings(BaseSettings):
    mongo_uri: str = "mongodb://localhost:27017/gigcredit"
    api_key: str = "gigcredit_dev_key"
    gemini_api_key: str = "replace_me"

    class Config:
        env_file = ".env"


settings = Settings()

