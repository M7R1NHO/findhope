# Teste de ligação à base de dados PostgreSQL do Supabase
import os
import sys

import psycopg
from dotenv import load_dotenv

load_dotenv()

database_url = os.getenv("DATABASE_URL")

if not database_url:
    print("ERRO: DATABASE_URL não encontrada no ficheiro .env.")
    sys.exit(1)

try:
    with psycopg.connect(
        database_url,
        connect_timeout=15,
    ) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1;")
            result = cursor.fetchone()

    if result == (1,):
        print("SUCESSO: ligação ao PostgreSQL do Supabase confirmada!")
        print("A base de dados respondeu corretamente ao SELECT 1.")

except psycopg.OperationalError as error:
    print("ERRO: não foi possível estabelecer a ligação.")
    print("Verifica o URL, a palavra-passe, a porta e a rede.")
    print("Detalhes:", error)

except psycopg.Error as error:
    print("ERRO PostgreSQL:", error)
    sys.exit(1)
