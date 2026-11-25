"""Resumo dos testes individuais que acham defeitos, para o GITHUB_STEP_SUMMARY.

Le o JUnit XML do pytest (ou o JSON do `flutter test --file-reporter json:`)
e escreve uma tabela: teste, resultado e a primeira linha do erro. "Falhou"
aqui e o esperado enquanto o defeito existir; "Passou" quer dizer que o
defeito foi corrigido e o teste pode perder a marca `defeito`.

Uso: python resumo_defeitos.py relatorio-defeitos.xml|.json
"""
import json
import os
import sys
import xml.etree.ElementTree as ET


def _linhas_junit(caminho):
    for caso in ET.parse(caminho).getroot().iter("testcase"):
        nome = f"{caso.get('classname', '').split('.')[-1]}::{caso.get('name')}"
        erro = caso.find("failure") if caso.find("failure") is not None else caso.find("error")
        if erro is not None:
            msg = (erro.get("message") or erro.text or "").strip().splitlines()
            yield nome, "❌ Falhou (defeito confirmado)", msg[0] if msg else ""
        elif caso.find("skipped") is not None:
            yield nome, "⏭️ Pulado", ""
        else:
            yield nome, "✅ Passou (defeito corrigido?)", ""


def _linhas_flutter(caminho):
    nomes, erros, resultados = {}, {}, {}
    for linha in open(caminho, encoding="utf-8"):
        try:
            ev = json.loads(linha)
        except ValueError:
            continue
        if ev.get("type") == "testStart":
            nomes[ev["test"]["id"]] = ev["test"]["name"]
        elif ev.get("type") == "error":
            erros.setdefault(ev["testID"], ev.get("error", ""))
        elif ev.get("type") == "testDone" and not ev.get("hidden"):
            resultados[ev["testID"]] = ev.get("result")
    for tid, resultado in resultados.items():
        msg = (erros.get(tid) or "").strip().splitlines()
        msg = next((m.strip() for m in msg if m.strip() and not m.startswith("══")), "")
        estado = "✅ Passou (defeito corrigido?)" if resultado == "success" else "❌ Falhou (defeito confirmado)"
        yield nomes.get(tid, tid), estado, msg


def main(caminho):
    if not os.path.exists(caminho):
        # Sem nenhum teste com a marca/tag "defeito", o flutter test nem cria o
        # relatorio: todos os defeitos achados ate agora foram corrigidos.
        print("## Testes individuais que acham defeitos\n")
        print("Nenhum teste com a marca `defeito`: os defeitos achados foram corrigidos.")
        return
    linhas = list(_linhas_flutter(caminho) if caminho.endswith(".json") else _linhas_junit(caminho))
    falhas = sum(1 for _, e, _ in linhas if e.startswith("❌"))
    print("## Testes individuais que acham defeitos\n")
    print(f"{falhas} de {len(linhas)} falharam de propósito: cada falha é um defeito "
          "ainda aberto (fichas no TESTES.md).\n")
    print("| Teste | Resultado | Primeira linha do erro |")
    print("|---|---|---|")
    for nome, estado, msg in linhas:
        msg = msg.replace("|", "\\|")[:160]
        print(f"| `{nome}` | {estado} | {msg} |")


if __name__ == "__main__":
    main(sys.argv[1])
