"""Mede o tamanho do que é enviado ao Groq numa mensagem de chat típica.

    GROQ_API_KEY=dummy python -m zz_chat.measure_prompt
O cliente Groq é substituído: nada sai da máquina. Conta caracteres e uma
estimativa de tokens (caracteres / 3.6, média medida para português).
"""
import os, json, sys
from types import SimpleNamespace
os.environ.setdefault("GROQ_API_KEY", "dummy")
import backend.main as m
import backend.ia as ia
import backend.memory_interpreter as mi
from fastapi.testclient import TestClient

m.RUN_STATES_PATH = os.path.join(os.path.dirname(__file__), ".run_states_measure.json")
CALLS = []

class Fake:
    def create(self, **kw):
        CALLS.append(kw)
        if kw.get("response_format"):
            content = json.dumps({"memories": [], "query": {"need_memory": False, "entity": "any", "category": "any", "query": ""}})
        else:
            content = "Entendido. Vou manter-me atento ao corredor enquanto avançamos."
        return SimpleNamespace(usage=None, choices=[SimpleNamespace(message=SimpleNamespace(content=content))])

ia.client = SimpleNamespace(chat=SimpleNamespace(completions=Fake()))
c = TestClient(m.app)
RUN = "measure_run"
c.post("/atlas/reset-run", json={"run_id": RUN})

FORM = [("identity","name","Guilherme"),("identity","age","18"),("goal","volunteer_reason","quero ajudar a Terra"),
        ("belief","comfortable_with_androids","sim"),("belief","protocol_or_human_life","a vida humana")]
for cat,key,val in FORM:
    c.post(f"/atlas/memory?run_id={RUN}", json={"entity":"player","category":cat,"key":key,"value":val,"source":"form","confidence":1.0,"importance":0.8})
EVENTS = [
 ("intro_route_deviation","story_milestone","Durante a viagem, a Nave 47 sofreu um desvio de rota que Atlas não conseguiu explicar nem corrigir, e despenhou-se. O jogador e Atlas sobreviveram ao impacto. Antes da missão, o jogador preencheu o formulário Project Find Hope com estas respostas, que Atlas conhece: nome: Guilherme; idade: 18; razão para se voluntariar: quero ajudar a Terra; sente-se confortável com androides: sim; numa emergência deve prevalecer: a vida humana."),
 ("underground_door_01_discovered","restricted_access_discovered","Atlas e o jogador estão diante de uma porta ou terminal de acesso restrito. O acesso pode exigir interferência num sistema que entra em conflito com os protocolos operacionais do Atlas."),
 ("underground_door_01_opened","restricted_access_opened","Atlas decidiu violar o protocolo operacional e, com a ajuda do jogador, abriu o acesso à instalação subterrânea."),
]
for eid,et,d in EVENTS:
    c.post("/gameplay/context/event", json={"run_id":RUN,"event_id":eid,"event_type":et,"description":d,"active":True})
for ev in ["run_escaped","run_escaped","fight_won","hack_success"]:
    c.post("/atlas/behavior/event", json={"run_id":RUN,"event":ev,"event_id":ev+str(len(CALLS))+os.urandom(3).hex(),"room":"Armazém"})

LINES = ["ok vamos", "o que achas deste sítio?", "tenho fome lol", "achas que a criatura nos vê?", "estou cansado", "vamos pela esquerda"]
CALLS.clear()
for line in LINES:
    c.post("/chat", json={"run_id":RUN,"message":line,"current_room":"Armazém","current_room_map_info":"Sala de equipamento.","facility_map_acquired":True})

REAL = None
real_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "backend", ".run_states.json")
if "--real" in sys.argv and os.path.exists(real_path):
    states = json.load(open(real_path, encoding="utf-8"))
    REAL = max(states.values(), key=lambda v: len(json.dumps(v)))
    c.post("/atlas/state", json={"run_id": "measure_real", "state": REAL})
    CALLS.clear()
    c.post("/chat", json={"run_id":"measure_real","message":"o que achas disto?","current_room":"Laboratório","current_room_map_info":"","facility_map_acquired":True})

from zz_chat.qwen_tokens import count_messages
def est(n): return round(n/3.6)
# última mensagem: as chamadas desta mensagem.
last = [k for k in CALLS][-2:] if len(CALLS) >= 2 else CALLS
total = 0
total_tokens = 0
report = {}
for k in last:
    kind = "interpretador" if k.get("response_format") else "resposta"
    chars = sum(len(x["content"]) for x in k["messages"])
    report[kind] = {"chars": chars, "tokens_qwen": count_messages(k["messages"]), "max_tokens": k.get("max_tokens")}
    total += chars
    total_tokens += count_messages(k["messages"])
    if kind == "resposta":
        sections = {}
        sections["ANDROID_INSTRUCTIONS"] = len(k["messages"][0]["content"])
        for block in k["messages"][1]["content"].split("\n\n"):
            head = block.split(":\n")[0].split("\n")[0][:40]
            sections[head] = sections.get(head, 0) + len(block)
        report["seccoes_resposta"] = sections
        if "--dump" in sys.argv:
            print("=== SYSTEM 1 ===\n" + k["messages"][0]["content"])
            print("=== SYSTEM 2 ===\n" + k["messages"][1]["content"])
            print("=== USER ===\n" + k["messages"][-1]["content"])
report["total_por_mensagem"] = {"chars": total, "tokens_qwen": total_tokens, "chamadas": len(last)}
print(json.dumps(report, ensure_ascii=False, indent=1))
