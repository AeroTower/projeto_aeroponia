"""Resumo dos testes Flutter: quantos por tipo e cobertura (evidencia para o relatorio).

Uso (depois de `flutter test --coverage --file-reporter json:relatorio-testes.json`):

    python .github/resumo_flutter.py relatorio-testes.json coverage/lcov.info 90

Imprime a tabela em Markdown (vai para a aba Actions) e termina com erro se
algum teste falhou ou se a cobertura ficou abaixo do minimo.
"""
import json
import sys
from collections import Counter
from pathlib import Path

TIPOS = {
    "unitarios": "Unitário",
    "integracao": "Integração",
    "funcionais": "Funcional",
    "aceitacao": "Aceitação",
    "desempenho": "Desempenho",
    "seguranca": "Segurança",
}


def contar_testes(relatorio):
    suites, testes, total, falhas = {}, {}, Counter(), Counter()
    for linha in Path(relatorio).read_text(encoding="utf-8").splitlines():
        try:
            evento = json.loads(linha)
        except ValueError:
            continue
        tipo = evento.get("type")
        if tipo == "suite":
            suites[evento["suite"]["id"]] = evento["suite"].get("path") or ""
        elif tipo == "testStart":
            teste = evento["test"]
            testes[teste["id"]] = suites.get(teste.get("suiteID"), "")
        elif tipo == "testDone" and not evento.get("hidden") and not evento.get("skipped"):
            partes = Path(testes.get(evento["testID"], "")).parts
            nome = next((TIPOS[p] for p in partes if p in TIPOS), "Outros")
            total[nome] += 1
            if evento.get("result") != "success":
                falhas[nome] += 1
    return total, falhas


def cobertura(lcov):
    arquivos, atual = {}, None
    for linha in Path(lcov).read_text(encoding="utf-8").splitlines():
        if linha.startswith("SF:"):
            atual = linha[3:]
            arquivos[atual] = [0, 0]
        elif linha.startswith("LF:"):
            arquivos[atual][0] = int(linha[3:])
        elif linha.startswith("LH:"):
            arquivos[atual][1] = int(linha[3:])
    return arquivos


def main(relatorio, lcov, minimo="90"):
    total, falhas = contar_testes(relatorio)
    linhas = ["| Tipo | Testes | Passaram | Falharam |", "|---|---:|---:|---:|"]
    for nome in list(TIPOS.values()) + ["Outros"]:
        if total[nome]:
            linhas.append(f"| {nome} | {total[nome]} | {total[nome] - falhas[nome]} | {falhas[nome]} |")
    soma, soma_falhas = sum(total.values()), sum(falhas.values())
    linhas.append(f"| **Total** | **{soma}** | **{soma - soma_falhas}** | **{soma_falhas}** |")

    arquivos = cobertura(lcov)
    existentes = {str(p).replace("\\", "/") for p in Path("lib").rglob("*.dart")}
    medidos = {a.replace("\\", "/") for a in arquivos}
    fora = sorted(e for e in existentes if not any(m.endswith(e) for m in medidos))

    lf = sum(v[0] for v in arquivos.values())
    lh = sum(v[1] for v in arquivos.values())
    taxa = 100 * lh / lf if lf else 0
    linhas += ["", f"**Cobertura de código:** {taxa:.1f}% ({lh} de {lf} linhas; meta: {minimo}%)", "",
               "| Arquivo | Linhas | Cobertas | % |", "|---|---:|---:|---:|"]
    for arquivo, (f, h) in sorted(arquivos.items(), key=lambda i: (i[1][1] / i[1][0]) if i[1][0] else 1):
        linhas.append(f"| `{arquivo}` | {f} | {h} | {100 * h / f if f else 100:.0f}% |")
    if fora:
        linhas += ["", "⚠️ Arquivos que nenhum teste carregou: " + ", ".join(f"`{f}`" for f in fora)]
    print("\n".join(linhas))

    if soma_falhas or fora or taxa < float(minimo):
        sys.exit(1)


if __name__ == "__main__":
    main(*sys.argv[1:4])
