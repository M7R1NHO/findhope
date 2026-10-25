"""Conta tokens com o vocabulário do Qwen (qwen.tiktoken do pacote dashscope).

O Groq usa qwen/qwen3.8-27b; o Qwen3 usa o mesmo BPE de 151 643 tokens do
Qwen. Soma ~4 tokens por mensagem do template de chat (<|im_start|>role\\n …
<|im_end|>\\n).
"""
import base64, os
import tiktoken
import dashscope

PAT = r"""(?i:'s|'t|'re|'ve|'m|'ll|'d)|[^\r\n\p{L}\p{N}]?\p{L}+|\p{N}| ?[^\s\p{L}\p{N}]+[\r\n]*|\s*[\r\n]+|\s+(?!\S)|\s+"""
_path = os.path.join(os.path.dirname(dashscope.__file__), "resources", "qwen.tiktoken")
_ranks = {}
for line in open(_path, "rb"):
    if line.strip():
        tok, rank = line.split()
        _ranks[base64.b64decode(tok)] = int(rank)
ENC = tiktoken.Encoding("qwen", pat_str=PAT, mergeable_ranks=_ranks, special_tokens={})


def count(text: str) -> int:
    return len(ENC.encode(text))


def count_messages(messages) -> int:
    return sum(count(m["content"]) + 4 for m in messages) + 3
