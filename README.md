# Find Hope: instalação

## Requisitos

- **Godot 4.7** (o projeto usa o renderizador GL Compatibility).
- **Python 3** (o projeto foi usado com Python 3.13, em Windows).
- Uma chave da API do **Groq**.
- Opcional: uma base de dados **PostgreSQL** no Supabase, para os saves remotos.

## 1. Obter o código

```powershell
git clone https://github.com/M7R1NHO/findhope.git
cd findhope
```

## 2. Instalar o backend

Na raiz do repositório (a pasta que tem `backend\` e `game\`), no PowerShell:

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

Se o PowerShell bloquear o `Activate.ps1`, corre primeiro `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` e depois repete o `Activate.ps1`.

## 3. Configurar o `.env`

Cria um ficheiro `.env` na raiz do repositório:

```
GROQ_API_KEY=a_tua_chave_do_groq
DATABASE_URL=postgresql://utilizador:palavra-passe@servidor:5432/postgres
```

- `GROQ_API_KEY` é obrigatória (respostas do Atlas).
- `DATABASE_URL` é a URL PostgreSQL do Supabase. Sem ela, o jogo grava só localmente e os saves remotos falham.
- `DATABASE_CONNECT_TIMEOUT` é opcional: segundos de espera pela base de dados (15 por omissão).

O `.env` está no `.gitignore` e **nunca** deve ir para o GitHub.

## 4. Arrancar o backend

Na raiz do repositório, com o venv ativo:

```powershell
python -m uvicorn backend.main:app --reload
```

O servidor fica em `http://127.0.0.1:8000`. Se abrir esse endereço no browser aparecer `{"message": "Find Hope API online"}`, está a funcionar. Deixa este terminal aberto enquanto jogas.

## 5. Abrir o jogo

1. Abre o Godot 4.7 e importa `game/project.godot`.
2. Com o backend a correr, carrega em **F5**. O jogo começa no menu principal.
