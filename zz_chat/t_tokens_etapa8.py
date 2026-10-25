"""Etapa 8: o que vai para o Groq numa mensagem do chat fica abaixo de 3 000
tokens (contados com o vocabulário do Qwen, ver qwen_tokens.py).

    GROQ_API_KEY=dummy python -m zz_chat.t_tokens_etapa8
"""
import json, os, subprocess, sys

LIMIT = 3000
env = dict(os.environ, GROQ_API_KEY=os.environ.get("GROQ_API_KEY", "dummy"))
results = []
for args, name in [([], "partida de teste"), (["--real"], "maior partida guardada")]:
    out = subprocess.run([sys.executable, "-m", "zz_chat.measure_prompt", *args], capture_output=True, text=True, env=env).stdout
    report = json.loads(out[out.index('{\n "interp'):])
    total = report["total_por_mensagem"]["tokens_qwen"]
    ok = total <= LIMIT
    results.append(ok)
    print(("PASS" if ok else "FAIL"), f"T8.{len(results)} {name}: {total} tokens por mensagem "
          f"(interpretador {report['interpretador']['tokens_qwen']}, resposta {report['resposta']['tokens_qwen']}) <= {LIMIT}")
print(f"RESULTADO T8: {sum(results)} / {len(results)} PASS")
