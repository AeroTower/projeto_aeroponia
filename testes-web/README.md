# Testes web do app e da loja (Chrome, Lighthouse e ZAP)

Dois testes individuais do Fernão que rodam no navegador, contra os sites
publicados no GitHub Pages: **app.aerotower.com.br** e **aerotower.com.br**.
Nenhum dos dois altera dados. Nada aqui roda no CI: as evidências são os
prints e os relatórios que você gera no seu PC.

## CT-DESEMP-03 · Tempo de carregamento (Lighthouse)

O Lighthouse já vem no Chrome: não precisa instalar nada.

**Critérios** (faixas "bom" do Google para Core Web Vitals): nota de
Performance ≥ 90, LCP ≤ 2,5 s, TBT ≤ 200 ms e CLS ≤ 0,1, no modo celular.

1. Abra uma **janela anônima** do Chrome (Ctrl+Shift+N). As extensões ficam
   desligadas e não atrapalham a medição.
2. Entre em https://aerotower.com.br e aperte **F12** › aba **Lighthouse**
   (se não aparecer, clique em `»`).
3. Marque: *Modo* **Navegação**, *Dispositivo* **Celular**, *Categorias*
   **Desempenho** (pode marcar também *Práticas recomendadas*).
4. Clique em **Analisar carregamento da página** e espere (~1 min).
5. Repita **3 vezes** e use a do meio (a nota varia um pouco a cada vez).
6. Anote: nota de Desempenho, FCP, **LCP**, **TBT**, CLS e Speed Index.
   Abra *Diagnóstico* › "Reduza o JavaScript não usado" e "Evite payloads de
   rede enormes" e anote o tamanho total.
7. Prints: o placar com as métricas e a lista de diagnóstico.
   Em ⋮ (canto do relatório) › **Salvar como HTML** guarda o relatório inteiro.
8. Faça o mesmo em https://app.aerotower.com.br (a tela de login).
9. Opcional: repita com *Dispositivo* **Computador** para comparar.

Para conferir o resultado: o site publicado manda ~2,9 MB de `main.dart.js`
mais ~5,2 MB de `canvaskit.wasm` (motor gráfico do Flutter) antes de desenhar
a primeira tela.

## CT-SEG-03 · Varredura passiva com o ZAP + teste de clickjacking

### Parte A · Clickjacking (2 minutos)

1. Abra o arquivo `testes-web/clickjacking.html` no Chrome (dois cliques).
2. Se o app aparecer dentro do quadro tracejado, ele pode ser emoldurado.
3. Prints: opacidade 0,35 (app e isca sobrepostos) e opacidade 0 (só a isca à
   vista). Repita escolhendo a **Loja** no menu.

### Parte B · Varredura com o ZAP (~20 minutos)

O ZAP (OWASP Zed Attack Proxy) é gratuito. A varredura aqui é **passiva**:
o ZAP só olha as respostas enquanto você navega e não manda ataques. A
varredura ativa (com ataques) não deve ser usada nesses sites: eles ficam
nos servidores do GitHub, que não são do grupo.

1. **Instale o Java 17 ou mais novo**, se ainda não tiver. O ZAP exige, e no
   Windows o Java não vem junto. Opção gratuita: *Eclipse Temurin 21*
   (adoptium.net), instalador `.msi`. Confira no PowerShell: `java -version`.
2. Baixe o **ZAP** em zaproxy.org/download › *Windows (64) Installer* e instale.
3. Abra o ZAP. Na pergunta sobre a sessão, escolha *"Não, não quero
   persistir esta sessão agora"*.
4. Na aba **Quick Start**, clique em **Manual Explore**. Em *URL to explore*
   ponha `https://app.aerotower.com.br`, escolha **Chrome** e clique em
   **Launch Browser**. Abre um Chrome que passa pelo ZAP.
5. Nesse Chrome, navegue normalmente por **2 a 3 minutos**: tela de login,
   entrar (Google ou "Entrar sem Google"), lista de torres, painel, plantas,
   HydroBot. Depois abra `https://aerotower.com.br` e passe pela loja, por um
   produto e pelos guias.
6. Volte ao ZAP › aba **Alertas** (embaixo, à esquerda). Os alertas aparecem
   agrupados por risco (Alto, Médio, Baixo, Informativo).
7. Gere o relatório: menu **Relatório** › **Gerar relatório** › modelo
   *Traditional HTML Report* › **Gerar**.
8. Prints: a árvore de **Alertas** expandida e o resumo do relatório HTML
   (quantidade por risco).
9. **Antes de qualquer print, apague ou borre dados pessoais**: e-mail da
   conta, token (`Authorization: Bearer ...`) e e-mails de visitantes.

**Critério:** nenhum alerta de risco Médio ou Alto, e o site não pode ser
emoldurado (parte A).
