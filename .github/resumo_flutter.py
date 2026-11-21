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


def _faixas(numeros):
    """[3, 4, 5, 9] -> "3-5, 9"."""
    faixas, inicio, anterior = [], None, None
    for n in numeros + [None]:
        if inicio is None:
            inicio = anterior = n
        elif n is not None and n == anterior + 1:
            anterior = n
        else:
            faixas.append(f"{inicio}" if inicio == anterior else f"{inicio}-{anterior}")
            inicio = anterior = n
    return ", ".join(faixas)


def cobertura(lcov):
    arquivos, atual = {}, None
    sem_teste = {}
    for linha in Path(lcov).read_text(encoding="utf-8").splitlines():
        if linha.startswith("SF:"):
            atual = linha[3:]
            arquivos[atual] = [0, 0]
            sem_teste[atual] = []
        elif linha.startswith("DA:") and linha.split(",")[1].strip() == "0":
            sem_teste[atual].append(int(linha[3:].split(",")[0]))
        elif linha.startswith("LF:"):
            arquivos[atual][0] = int(linha[3:])
        elif linha.startswith("LH:"):
            arquivos[atual][1] = int(linha[3:])
    return arquivos, sem_teste


def main(relatorio, lcov, minimo="90"):
    total, falhas = contar_testes(relatorio)
    linhas = ["| Tipo | Testes | Passaram | Falharam |", "|---|---:|---:|---:|"]
    for nome in list(TIPOS.values()) + ["Outros"]:
        if total[nome]:
            linhas.append(f"| {nome} | {total[nome]} | {total[nome] - falhas[nome]} | {falhas[nome]} |")
    soma, soma_falhas = sum(total.values()), sum(falhas.values())
    linhas.append(f"| **Total** | **{soma}** | **{soma - soma_falhas}** | **{soma_falhas}** |")

    arquivos, sem_teste = cobertura(lcov)
    existentes = {str(p).replace("\\", "/") for p in Path("lib").rglob("*.dart")}
    medidos = {a.replace("\\", "/") for a in arquivos}
    fora = sorted(e for e in existentes if not any(m.endswith(e) for m in medidos))

    lf = sum(v[0] for v in arquivos.values())
    lh = sum(v[1] for v in arquivos.values())
    taxa = 100 * lh / lf if lf else 0
    linhas += ["", f"**Cobertura de código:** {taxa:.1f}% ({lh} de {lf} linhas; meta: {minimo}%)", "",
               "| Arquivo | Linhas | Cobertas | % | Linhas sem teste |", "|---|---:|---:|---:|---|"]
    for arquivo, (f, h) in sorted(arquivos.items(), key=lambda i: (i[1][1] / i[1][0]) if i[1][0] else 1):
        linhas.append(f"| `{arquivo}` | {f} | {h} | {100 * h / f if f else 100:.0f}% | {_faixas(sem_teste[arquivo])} |")
    if fora:
        linhas += ["", "Sem linha executável no lcov (só constantes ou não carregados): "
                   + ", ".join(f"`{f}`" for f in fora)]
    print("\n".join(linhas))

    if soma_falhas or taxa < float(minimo):
        sys.exit(1)


if __name__ == "__main__":
    main(*sys.argv[1:4])
