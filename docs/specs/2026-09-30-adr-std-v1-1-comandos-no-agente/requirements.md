# Requisitos — adr-std v1.1: comandos por ação dentro do agente

| Campo | Detalhe |
|---|---|
| **Data** | 2026-09-30 |
| **Status** | Gate 1 aprovado (2026-10-01, por delegação expressa desta sessão); ver [design.md](design.md) e [tasks.md](tasks.md) |
| **Depende de** | v1.0 publicada e validada em ao menos dois agentes ([spec da v1.0](../2026-09-30-adr-std-v1-0/)) |
| **Contexto** | [ROADMAP.md](../../../ROADMAP.md) |

## 1. Contexto

Na v1.0, a skill é ativada por pedido em linguagem natural ou pelo comando genérico `/adr-std` (Claude Code) e
`$adr-std` (Codex). A v1.1 acrescenta um comando por ação, para o uso ficar previsível e fácil de ensinar aos colegas.

## 2. Decisões fechadas pelo solicitante

| # | Decisão |
|---|---|
| D-01 | Formato `/adr-std-<ação>`, um comando por ação, mantendo também o `/adr-std <texto livre>` |
| D-02 | Ações: `create`, `supersede`, `review`, `organize`, `link`, `audit`, `check`, `ask`, `new`, `list` |
| D-03 | `create` e `supersede` conduzem conversa guiada, com perguntas e sugestões no meio e no fim |
| D-04 | `--ask N` define quantas perguntas por rodada; `--quick` não faz nenhuma pergunta |
| D-05 | Nome `supersede` (e não `replace`) |
| D-06 | Codex: `$adr-std <ação>`; sem comandos separados |
| D-07 | A lógica fica na skill; cada comando só a chama com a ação definida |
| D-08 | `new` e `list` existem no agente já na v1.1 (decidido em 2026-09-30). No terminal, eles só chegam na v1.2 |

## 3. Propostas adotadas por "pode executar" (confirmar no Gate 1)

| # | Proposta |
|---|---|
| P-01 | Nomes curtos `-a N` (`--ask N`) e `-k` (`--quick`) |
| P-02 | `--ask`: padrão 3, faixa de 1 a 10 (fora da faixa usa o valor mais próximo e avisa) |
| P-03 | `--quick` com `--ask`: vale o `--quick`, o `--ask` é ignorado e o agente avisa |
| P-04 | `--quick` e `--ask` valem no `create` e no `supersede` |
| P-05 | O instalador cria os arquivos de comando nos agentes que aceitam (`adr-std install` na v1.1); `--no-commands` instala só a skill |
| P-06 | Os arquivos de comando só são ativados pelo usuário, nunca pelo agente por conta própria |

## 4. Comandos

| Comando | O que faz | Altera arquivos? |
|---|---|---|
| `/adr-std-create <decisão>` | Cria um ADR novo em conversa guiada; confere se é decisão essencial e única; status `Proposto`; roda a verificação | Sim, cria o arquivo |
| `/adr-std-supersede <ADR> [descrição]` | Cria o ADR que substitui outro; marca o antigo como `Substituído por`; atualiza datas; não apaga nada | Sim |
| `/adr-std-review <arquivo-ou-pasta>` | Revisa ADRs contra a norma e o checklist; relata com a origem de cada exigência | Não |
| `/adr-std-organize <pasta>` | Reorganiza numeração, nomes, status e relações; mostra o plano e só executa com autorização | Sim, com autorização |
| `/adr-std-link <ADR> <tipo> <ADR>` | Registra uma relação entre ADRs, com o tipo, nos dois lados | Sim |
| `/adr-std-audit` | Audita a descrição de arquitetura contra a cláusula 6 inteira | Não |
| `/adr-std-check <arquivo-ou-pasta>` | Roda a verificação automática e explica as falhas | Não |
| `/adr-std-ask <pergunta>` | Responde dúvidas sobre a norma, citando a cláusula | Não |
| `/adr-std-new <título>` | Cria o arquivo do ADR vazio a partir do template (próximo número, status `Proposto`, campos `pendente`), sem perguntas nem sugestões | Sim, cria o arquivo |
| `/adr-std-list [pasta]` | Lista os ADRs da pasta (ID, título, status, data da decisão) | Não |
| `/adr-std <texto livre>` | A skill deduz a tarefa | Depende |

## 5. Linguagem Ubíqua

| Termo | Significado |
|---|---|
| **Comando de ação** | Arquivo pequeno em um agente que chama a skill `adr-std` com uma ação definida |
| **Ação** | Uma das dez tarefas da skill (`create`, `supersede`...) |
| **Rodada** | Grupo de perguntas feito de uma vez na conversa guiada |
| **Sugestão** | Ideia do agente (alternativa, risco, relação) que só entra no ADR se o usuário aceitar |
| **Pendente** | Campo do ADR que o usuário não informou; nunca é preenchido por invenção |

## 6. Requisitos funcionais (EARS)

- **RF-01 (evento):** QUANDO o usuário chamar `/adr-std-<ação>` num agente que aceita comandos, o agente DEVE executar a ação correspondente pelas regras da skill.
- **RF-02 (evento):** QUANDO o usuário chamar `/adr-std-create` sem `--quick`, o agente DEVE (a) resumir o que entendeu, (b) avisar se a decisão parece trivial, se são duas decisões ou se já existe ADR relacionado, (c) conduzir perguntas em rodadas de até N perguntas, (d) apresentar o rascunho com os campos faltantes como `pendente`, e (e) ao gravar, rodar a verificação e apresentar sugestões finais.
- **RF-03 (ubíquo):** As sugestões (alternativas não citadas, stakeholders esquecidos, riscos, ADRs relacionados a atualizar, decisões derivadas, como verificar) DEVEM aparecer marcadas como sugestão, e NENHUMA DEVE entrar no ADR sem aceite do usuário.
- **RF-04 (ubíquo):** O agente NÃO DEVE inventar decisores, datas, alternativas nem justificativas; o que faltar fica `pendente`.
- **RF-05 (evento):** QUANDO o usuário disser "gere com o que temos" (ou equivalente), o agente DEVE encerrar as perguntas e gravar o rascunho com as pendências marcadas.
- **RF-06 (opção):** ONDE `--ask N` for informado, o agente DEVE fazer no máximo N perguntas por rodada; sem número, DEVE usar 3; fora de 1 a 10, DEVE usar o valor mais próximo e avisar.
- **RF-07 (opção):** ONDE `--quick` for informado, o agente NÃO DEVE fazer nenhuma pergunta: monta o ADR só com a descrição, marca o resto `pendente` (inclusive decisão e justificativa, que a norma exige) e, ao final, lista as pendências obrigatórias pela norma, as sugestões e o comando para completar (`/adr-std-review <arquivo>`).
- **RF-08 (indesejado):** SE `--quick` vier sem descrição, ENTÃO o agente DEVE avisar e NÃO DEVE criar o arquivo.
- **RF-09 (indesejado):** SE `--quick` e `--ask` vierem juntos, ENTÃO o agente DEVE seguir o `--quick` e avisar que ignorou o `--ask`.
- **RF-10 (ubíquo):** O `/adr-std-supersede` DEVE seguir o mesmo fluxo e as mesmas opções do `create`, marcar o ADR antigo como `Substituído por ADR-NNNN` e atualizar "Modificado em", sem apagar o antigo.
- **RF-11 (ubíquo):** O status do ADR criado DEVE ser `Proposto`; só o decisor aprova.
- **RF-12 (indesejado):** SE a ação `organize` for pedida, ENTÃO o agente DEVE mostrar o plano e só executar com autorização expressa.
- **RF-13 (evento):** QUANDO o usuário executar `adr-std install` (ou `update`) com a v1.1, o instalador DEVE criar os arquivos de comando nos agentes que aceitam (lista na seção 7), registrar cada um no estado e removê-los no `uninstall`.
- **RF-14 (indesejado):** SE já existir um comando `/adr-std-*` que o adr-std não criou, ENTÃO o instalador NÃO DEVE sobrescrevê-lo e DEVE avisar.
- **RF-15 (opção):** ONDE `--no-commands` for informado, o instalador DEVE instalar só a skill.
- **RF-16 (ubíquo):** Os arquivos de comando NÃO DEVEM conter regras da skill; só a chamada com a ação e os argumentos.
- **RF-17 (evento):** QUANDO o usuário chamar `/adr-std-new <título>`, o agente DEVE criar um único arquivo a partir de `template-madr.md`, com o próximo número pela convenção do projeto, o ID, o título, status `Proposto`, "Data da decisão" com a data de hoje e todos os demais campos como `pendente`, sem fazer perguntas e sem alterar outros arquivos.
- **RF-18 (indesejado):** SE o título vier vazio, ENTÃO o agente DEVE avisar e NÃO DEVE criar o arquivo.
- **RF-19 (evento):** QUANDO o usuário chamar `/adr-std-list [pasta]`, o agente DEVE listar os ADRs da pasta (ou da pasta de ADRs do projeto, se nenhuma for indicada) com ID, título, status e data da decisão, sem alterar nenhum arquivo.
- **RF-20 (indesejado):** SE a pasta de `list` não existir ou não tiver ADRs, ENTÃO o agente DEVE dizer isso e NÃO DEVE criar a pasta.

## 7. Como cada agente recebe os comandos (a confirmar no design)

| Agente | Mecanismo | Arquivo de comando | Variável de argumento |
|---|---|---|---|
| Claude Code | Markdown em `commands/`, frontmatter YAML opcional | `~/.claude/commands/adr-std-<ação>.md` | `$ARGUMENTS` |
| Gemini CLI | TOML com chave `prompt` | `~/.gemini/commands/adr-std-<ação>.toml` | `{{args}}` |
| OpenCode | Markdown com frontmatter YAML (`description`, etc.) | `~/.config/opencode/commands/adr-std-<ação>.md` | `$ARGUMENTS` |
| Continue | Arquivo `.prompt` (Markdown com frontmatter `name`/`description`) em `.continue/prompts/` | `~/.continue/prompts/adr-std-<ação>.prompt` | `{{{ input }}}` |
| Codex | Chamada por `$`; sem comandos separados | Nenhum (`$adr-std <ação>`) | — |
| Antigravity | Workflows, que serão desativados em 2026-11-01 | Nenhum | — |
| Demais | Sem comandos; pedido em linguagem natural | Nenhum | — |

Cada `/adr-std-<ação>` de Claude Code, Gemini CLI, OpenCode e Continue é um arquivo, então a v1.1
cria 10 arquivos por agente nesses quatro. Fontes (pesquisadas em 2026-10-01): documentação oficial
de cada agente (Claude Code, `docs.anthropic.com/en/docs/claude-code/slash-commands`; Gemini CLI,
`gemini-cli.xyz/docs/en/cli/custom-commands`; OpenCode, repositório `sst/opencode`,
`packages/web/.../commands.mdx`; Continue, `docs.continue.dev/customization/slash-commands`).
**Continue** é adicionado nesta spec à lista de agentes com comando dedicado (a tabela original da
seção 2026-09-30 deixava a pasta "a confirmar"; resolvido no Gate 2 por pesquisa, sem necessidade
de decisão do solicitante — é fato documentado publicamente, não escolha de produto).

## 8. Critérios de aceite (Gherkin)

```gherkin
Cenário: criação guiada com número de perguntas
  Dado a skill instalada no Claude Code
  Quando o usuário chama "/adr-std-create --ask 2 Trocar Redis por Memcached"
  Então o agente faz no máximo 2 perguntas por rodada
  E sugere ao menos uma alternativa que o usuário não citou
  E não grava nenhuma sugestão sem aceite

Cenário: modo rápido sem perguntas
  Quando o usuário chama "/adr-std-create --quick Trocar Redis por Memcached. Motivo: custo."
  Então o agente não faz nenhuma pergunta
  E grava o ADR com status Proposto, campos não informados como pendente
  E lista as pendências obrigatórias pela norma e as sugestões

Cenário: modo rápido sem descrição
  Quando o usuário chama "/adr-std-create --quick"
  Então o agente avisa e não cria arquivo

Cenário: substituição
  Quando o usuário chama "/adr-std-supersede ADR-0003"
  Então o ADR antigo passa a "Substituído por ADR-NNNN" e nenhum ADR é apagado

Cenário: esqueleto sem perguntas
  Quando o usuário chama "/adr-std-new Trocar Redis por Memcached"
  Então o agente cria um único arquivo com o próximo número, status Proposto e campos pendente
  E não faz perguntas nem altera outros arquivos

Cenário: listagem
  Quando o usuário chama "/adr-std-list docs/architecture/ADR"
  Então o agente mostra ID, título, status e data de cada ADR e não altera arquivos

Cenário: instalador não sobrescreve comando alheio
  Dado um arquivo ~/.claude/commands/adr-std-create.md que o adr-std não criou
  Quando o usuário executa "adr-std install claude-code"
  Então o arquivo não é alterado e um aviso é mostrado
```

## 9. Requisitos não funcionais

- **RNF-01:** Sem `--no-commands`, instalar os comandos não exige privilégio de administrador.
- **RNF-02:** Os arquivos de comando são gerados de um único modelo, para não divergirem entre agentes.
- **RNF-03:** O comportamento de perguntas (`--ask`, `--quick`) é regra do `SKILL.md`, seguida pelo agente; a obediência será verificada pelos cenários de teste, não garantida por programa.

## 10. Segurança

| # | Risco | Tratamento |
|---|---|---|
| R-01 | Argumentos do usuário injetados no arquivo de comando | Os arquivos não interpolam texto do usuário no instalador; o agente recebe os argumentos em tempo de uso |
| R-02 | Sobrescrever comando de outra origem | RF-14: marcador e registro no estado; nunca sobrescreve |
| R-03 | Agente executar ação destrutiva por engano | `organize` só com autorização; `create` nunca apaga; nenhum comando faz commit |
| R-04 | Sugestão do agente virar fato no ADR | RF-03 |
| R-05 | Informação inventada | RF-04 |

## 11. Fora do escopo da v1.1

`new`, `list`, `link` e `organize` como comandos do terminal, feitos por programa (v1.2); a v1.1 traz `new` e `list` só dentro do agente; comandos de conversa no terminal, agente padrão e menu com
memória (v1.3); comandos para agentes fora da tabela da seção 7.

## 12. Pontos em aberto

1. ~~`new` e `list` no agente já na v1.1?~~ **Resolvido em 2026-09-30: sim** (D-08).
   **Resolvido em 2026-10-01 (Gate 2):** nenhum script auxiliar — o agente lista o diretório e lê
   os cabeçalhos dos ADRs diretamente (mesma leitura que já faz para revisar), sem script Python
   novo. Motivo: a v1.2 já vai trazer `adr-std new`/`list` mecânicos em Python
   (`docs/architecture/ADR/ROADMAP.md`, etapa v1.2); criar um script auxiliar agora, só para o
   agente, duplicaria a mesma lógica que a v1.2 vai reimplementar como CLI de verdade — violaria
   YAGNI medido contra este `requirements.md` (nenhum requisito aqui pede script, só que a ação
   funcione) e Rule of Three (ainda não há 3 ocorrências da mesma regra de numeração no repo: hoje
   só existe no `check_adr.py`, que verifica, não numera).
2. ~~Pasta global de prompts do Continue e formato exato do arquivo.~~ **Resolvido em 2026-10-01**
   (Gate 2, pesquisa): ver seção 7.
3. ~~Como cada agente repassa os argumentos do comando para o texto do arquivo.~~ **Resolvido em
   2026-10-01** (Gate 2, pesquisa): ver coluna "Variável de argumento" da seção 7.
4. Como medir, nos cenários de teste, que o agente respeita o limite de perguntas (`--ask`,
   `--quick`). **Continua em aberto — bloqueio documentado:** não é mecanicamente verificável por
   teste automático (depende do comportamento de um modelo de linguagem numa conversa guiada, não
   de um programa determinístico). Fica como critério de aceite manual nos cenários de uso
   (`tests/cenarios.md`), fora do alcance de `unittest`/`test_cli.sh`/Pester. Não bloqueia o Gate 2
   nem a implementação: RNF-03 já registra essa limitação ("a obediência será verificada pelos
   cenários de teste, não garantida por programa").
