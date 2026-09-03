# Find Hope — Cheat sheet de comandos (Windows / PowerShell)

*Guarda isto e consulta sempre que precisares — não precisas decorar nada.*

## Rotina diária (faz isto sempre, em qualquer PC)

Ao começar a trabalhar:
```powershell
git pull
```

Ao terminar (mesmo que seja pouco progresso — "checkpoint" vale a pena):
```powershell
git add .
git commit -m "descrição curta do que mudou"
git push
```

## Git

| O que quero fazer | Comando |
|---|---|
| Criar repositório local pela primeira vez | `git init` |
| Ver o que mudou desde o último commit | `git status` |
| Adicionar tudo o que mudou | `git add .` |
| Guardar as mudanças com uma mensagem | `git commit -m "mensagem"` |
| Ligar o repositório local a um do GitHub | `git remote add origin <URL>` |
| Enviar para o GitHub pela primeira vez | `git push -u origin main` |
| Enviar depois (já ligado) | `git push` |
| Trazer mudanças de outro PC | `git pull` |
| Copiar o repositório num PC novo (ex.: da escola) | `git clone <URL>` |
| Ver o histórico de commits | `git log --oneline` |
| Ver diferenças ainda não commitadas | `git diff` |

**Nunca esquecer:** o `.gitignore` tem de excluir `venv/` (ou `.venv/`), `__pycache__/`, `*.pyc` e `.env` — o `.env` é onde vai a tua chave de API, e essa nunca pode ir para o GitHub, nem em repositório privado.

## Ambiente virtual (venv) — opcional, mas se decidires usar

| O que quero fazer | Comando |
|---|---|
| Criar o venv | `python -m venv venv` |
| Ativar (PowerShell) | `.\venv\Scripts\Activate.ps1` |
| Se der erro de "execução de scripts desabilitada" | `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` (depois repete o Activate) |
| Confirmar que está ativo | o prompt mostra `(venv)` na frente |
| Desativar | `deactivate` |
| Instalar tudo que o projeto precisa | `pip install -r requirements.txt` |
| Atualizar a lista de dependências | `pip freeze > requirements.txt` |

**Importante:** os comandos `pip install` e `pip freeze` só afetam o venv se ele estiver **ativo** (prompt com `(venv)`). Se não estiver ativo, estás a mexer no Python global — o que também funciona, só não é isolado.

## Python / pip em geral

| O que quero fazer | Comando |
|---|---|
| Instalar um pacote (se `pip` sozinho não for reconhecido) | `python -m pip install nome-do-pacote` |
| Ver os pacotes instalados no ambiente atual | `pip list` |
| Ver de onde um pacote está a ser importado | `pip show nome-do-pacote` (olha a linha `Location`) |
| Ver qual Python está a ser usado | `python --version` e `where python` |

## FastAPI / Uvicorn

| O que quero fazer | Comando |
|---|---|
| Instalar o essencial | `pip install fastapi uvicorn` |
| Rodar o servidor (com auto-reload ao salvar arquivos) | `python -m uvicorn backend.main:app --reload` |
| Endereço do servidor | `http://127.0.0.1:8000` |
| Documentação automática / testar endpoints no navegador | `http://127.0.0.1:8000/docs` |
| Parar o servidor | `Ctrl + C` no terminal onde está rodando |

## VS Code — problemas comuns

| Sintoma | Solução |
|---|---|
| `Import "fastapi" could not be resolved` (sublinhado) | `Ctrl+Shift+P` → "Python: Select Interpreter" → escolhe o interpretador certo (onde o pacote está instalado de verdade) → depois `Ctrl+Shift+P` → "Developer: Reload Window" |
| O aviso acima aparece mas o servidor roda normalmente | É só cosmético (Pylance/editor) — ignora e segue, não bloqueia nada |
| Terminal não reconhece mudança de interpretador/venv | Fecha o terminal integrado e abre um novo |

## Checklist rápido antes de fechar o PC no fim do dia

1. O servidor ainda funciona? (`python -m uvicorn backend.main:app --reload`)
2. `git add .` → `git commit -m "..."` → `git push`
3. Anotar no relatório/documentação o que mudou hoje (mesmo 2 linhas)
