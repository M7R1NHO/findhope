
"""Ligação PostgreSQL para Find Hope (Supabase ou PostgreSQL local)."""
import os
from contextlib import contextmanager
from pathlib import Path

import psycopg
from dotenv import load_dotenv

PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(PROJECT_ROOT / ".env")


def get_database_url() -> str:
    url = os.getenv("DATABASE_URL", "").strip()
    if not url:
        raise RuntimeError("A variável DATABASE_URL não está definida no ficheiro .env.")
    return url


@contextmanager
def get_db_connection():
    """Abre uma ligação; o context manager faz commit/rollback e fecha-a."""
    with psycopg.connect(get_database_url(), connect_timeout=15) as connection:
        yield connection


def check_database_connection() -> bool:
    with get_db_connection() as connection:
        connection.execute("SELECT 1")
    return True