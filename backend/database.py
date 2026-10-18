"""Ligação PostgreSQL para Find Hope / Atlas 2.0.

Mantém uma interface pequena para Supabase ou PostgreSQL local.
Este módulo gere apenas a ligação à base de dados; não decide estado
narrativo, memória, descobertas ou isolamento entre execuções.
"""
from __future__ import annotations

import os
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

import psycopg
from dotenv import load_dotenv
from psycopg import Connection

PROJECT_ROOT = Path(__file__).resolve().parent.parent
load_dotenv(PROJECT_ROOT / ".env")


def get_database_url() -> str:
    """Obtém e valida a URL PostgreSQL sem expor credenciais em mensagens."""
    url = os.getenv("DATABASE_URL", "").strip()
    if not url:
        raise RuntimeError(
            "A variável DATABASE_URL não está definida no ficheiro .env."
        )

    # psycopg aceita postgres:// e postgresql://. Evita tentar ligar a
    # URLs claramente destinadas a outro tipo de serviço.
    if not url.startswith(("postgres://", "postgresql://")):
        raise RuntimeError(
            "DATABASE_URL deve conter uma URL válida de PostgreSQL."
        )
    return url


def _get_connect_timeout() -> int:
    """Lê o timeout configurável; usa 15 segundos se o valor for inválido."""
    try:
        timeout = int(os.getenv("DATABASE_CONNECT_TIMEOUT", "15"))
    except (TypeError, ValueError):
        return 15
    return max(1, min(timeout, 120))


@contextmanager
def get_db_connection() -> Iterator[Connection]:
    """Abre uma ligação e garante o fecho, com commit/rollback via psycopg.

    O bloco `with` da ligação confirma a transação se tudo correr bem,
    faz rollback perante uma exceção e fecha a ligação no final.
    """
    with psycopg.connect(
        get_database_url(),
        connect_timeout=_get_connect_timeout(),
        application_name="find-hope-atlas-2.0",
    ) as connection:
        yield connection


def check_database_connection() -> bool:
    """Confirma a ligação com uma consulta mínima.

    Devolve False em falhas de ligação/consulta, em vez de propagar erros
    operacionais para código que só precisa de testar a disponibilidade.
    Erros de configuração (por exemplo, DATABASE_URL ausente) continuam
    a ser propagados para facilitar a correção da configuração.
    """
    # A validação da configuração ocorre fora do try para distinguir
    # configuração em falta de uma falha temporária da base de dados.
    get_database_url()
    try:
        with get_db_connection() as connection:
            connection.execute("SELECT 1")
        return True
    except psycopg.Error:
        return False
