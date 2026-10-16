
import os
from contextlib import contextmanager

import psycopg
from dotenv import load_dotenv

# Carrega o .env da raiz do projeto Find Hope.
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))


def get_database_url() -> str:
    database_url = os.getenv("DATABASE_URL")

    if not database_url:
        raise RuntimeError(
            "DATABASE_URL não encontrada no ficheiro .env."
        )

    return database_url


@contextmanager
def get_db_connection():
    """Abre uma ligação PostgreSQL e fecha-a no final."""
    with psycopg.connect(
        get_database_url(),
        connect_timeout=15,
    ) as connection:
        yield connection


def check_database_connection() -> bool:
    """Confirma que a base de dados responde."""
    with get_db_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1;")
            return cursor.fetchone() == (1,)
