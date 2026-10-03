# Tarefas — adr-std v2.0: numeração dos ADRs sem zeros à esquerda

| Campo | Detalhe |
|---|---|
| **Requisitos / Design** | [requirements.md](requirements.md) · [design.md](design.md) |
| **Regra de execução** | Uma tarefa por vez, na ordem; marcar `[x]` só com evidência de teste. `git add` só com caminhos explícitos. Sem push. |
| **Base dos comandos** | `cd /Fusiondev/Code/Skills/adr-std` |
| **E2E** | N/A: a skill é CLI e documentação; os testes de CLI (bash e PowerShell) cobrem o fluxo ponta a ponta sem autenticação |

## 1. Verificadores

- [ ] 1.1 — `check_adr.py`: padrão de nome sem zeros e status `ADR-\d+`; renomear a fixture. Cobre RF-01, RF-02, RF-03, RF-04, NR-01, NR-02.
  - **RED:** em `tests/test_check_adr.py`, a fixture passa a `tests/fixtures/1-cache-de-sessao-em-redis.md` com `ADR-1`; casos novos: A1 reprova `0001-`, `01-` e `0-`; A2 reprova `1-x.md` com `ADR-0001`; `--name-pattern '^(\d{4})-.+\.md$'` aprova `0001-x.md` com `ADR-0001`; STATUS aceita `Substituído por ADR-4` e `ADR-0004`. Rode antes de mudar o código: falha.
  - **GREEN:** `DEFAULT_NAME_PATTERN = ^([1-9]\d*)-...`, `STATUS` com `ADR-\d+`; `git mv` da fixture e atualização das referências ao caminho dela (`tests/test_cli.sh`, `tests/test_cli.ps1`, `CONTRIBUTING.md`, `tests/cenarios.md`) e do ID `ADR-1` dentro dela.
  - **REFACTOR:** nenhum esperado.
  - **Validação:** `python3 -m unittest tests.test_check_adr`
  - **Evidência:**

- [ ] 1.2 — `check_roadmap.py`: usar o padrão compartilhado e aceitar `--name-pattern`. Cobre RF-05, SEG-01, R-05, R-06, NR-03; depende de 1.1.
  - **RED:** em `tests/test_check_roadmap.py`, nomes `1-titulo.md` e links `[ADR-1](1-titulo.md)`; casos novos: ADR `1-a.md` sem linha na tabela é acusado; `--name-pattern` custom reconhece `0001-a.md`; `--name-pattern '('` sai com código 2, mensagem em pt-BR e sem `Traceback`.
  - **GREEN:** importar `DEFAULT_NAME_PATTERN` de `check_adr`, remover `ADR_FILENAME`, passar `name_pattern` à verificação, nova opção e tratamento de `re.error`.
  - **REFACTOR:** conferir com `cg-search` que não resta outro `\d{4}` de nome de ADR em `skill/scripts/`.
  - **Validação:** `python3 -m unittest tests.test_check_roadmap`
  - **Evidência:**

## 2. CLI

- [ ] 2.1 — `adr_cli.py`: `number_of`, `number_width`, `format_number`, `list_adrs` e `next_number` numéricos; `new` sem zeros. Cobre RF-06, RF-07, RF-15, D-04, D-08, NR-04, NR-05, NR-06, RF-14 (parte `new` e `list`); depende de 1.1.
  - **RED:** em `tests/test_adr_cli.py`: `new` em pasta vazia cria `1-`; com `2-a.md` e `10-b.md` cria `11-` (e `ADR-11`); com `0007-a.md` e `--name-pattern '^(\d{4})-[a-z0-9-]+\.md$'` cria `0008-` e `ADR-0008`; `list` ordena `2` antes de `10`; helpers de número com testes diretos. Em `tests/test_cli.sh` e `tests/test_cli.ps1`: asserts do `new` passam a `1-usar-fila.md` e `ADR-1`.
  - **GREEN:** funções novas e uso em `list_adrs`/`next_number`; `new` grava `ADR-<N>`.
  - **REFACTOR:** `build_adr_skeleton` e `write_new_adr` continuam recebendo o número como texto.
  - **Validação:** `python3 -m unittest tests.test_adr_cli` e `bash tests/test_cli.sh cli_new_list`
  - **Evidência:**

- [ ] 2.2 — `new` recusa nome fora do padrão ativo. Cobre RF-08, SEG-02; depende de 2.1.
  - **RED:** em `tests/test_adr_cli.py`: pasta vazia com `--name-pattern '^(\d{4})-[a-z0-9-]+\.md$'` retorna código 1, não cria arquivo e a mensagem cita o padrão; colisão de nome continua protegida pelo modo exclusivo.
  - **GREEN:** verificação do nome gerado em `cmd_new` antes de gravar.
  - **REFACTOR:** nenhum esperado.
  - **Validação:** `python3 -m unittest tests.test_adr_cli`
  - **Evidência:**

- [ ] 2.3 — `organize --dry-run` numérico e consistente com a largura. Cobre RF-09, RF-14 (parte `organize` e `link`), D-04, D-08; depende de 2.1.
  - **RED:** em `tests/test_adr_cli.py`: pasta `1-a.md`..`10-j.md` consistente → "numeração já consistente"; `1-a.md` e `5-b.md` → plano `5-b.md -> 2-b.md`; ID divergente é proposto; convenção com zeros preserva a largura. Em `tests/test_cli.sh` e `tests/test_cli.ps1`: `link ADR-1 restringe ADR-2`, `5-dois.md -> 2-dois.md`.
  - **GREEN:** `cmd_organize` com ordenação numérica, `format_number`, comparação exata do número.
  - **REFACTOR:** remover `zfill(4)` e `startswith` residuais.
  - **Validação:** `python3 -m unittest tests.test_adr_cli` e `bash tests/test_cli.sh cli_link_organize`
  - **Evidência:**

## 3. Documentação da convenção

- [ ] 3.1 — Template, checklist, guia, `SKILL.md`, `GLOSSARY.md`, `README.md`, `CONTRIBUTING.md`, `tests/cenarios.md` e comentários de código descrevem `<N>-<slug>.md` / `ADR-<N>` e a convenção do projeto como prioridade. Cobre RF-10; depende de 2.3.
  - **RED:** `git grep -nE 'NNNN|4 dígitos' -- skill README.md GLOSSARY.md CONTRIBUTING.md tests/cenarios.md` retorna ocorrências do padrão antigo (menos as de `Substituído por ADR-NNNN`, que viram `ADR-N`).
  - **GREEN:** textos atualizados (`<N>-<titulo-em-kebab-case>.md`, `ADR-<N>`, nota sobre zeros à esquerda só por convenção do projeto, exemplos do `README.md` sem zeros).
  - **REFACTOR:** conferir que `SKILL.md` e `template-madr.md` continuam coerentes entre si.
  - **Validação:** a busca do RED sem ocorrências do padrão antigo; `python3 skill/scripts/check_adr.py tests/fixtures/1-cache-de-sessao-em-redis.md`; `bash tests/gate.sh static`
  - **Evidência:**

## 4. Migração dos ADRs 1 a 3

- [ ] 4.1 — Plano de migração mostrado ao solicitante e `git mv` dos três ADRs com ID, título, relações, links, histórico e "Modificado em". Cobre RF-11 (a, b, c, d); depende de 2.3 e 3.1.
  - **RED:** `python3 skill/scripts/check_adr.py docs/architecture/ADR` reprova A1 nos três arquivos `000N-...` com o padrão novo.
  - **GREEN:** plano registrado nesta evidência (arquivos renomeados e arquivos com referência afetada, via `git grep`), `git mv`, edição explícita dos três ADRs; o texto da decisão não muda.
  - **REFACTOR:** nenhum esperado.
  - **Validação:** `python3 skill/scripts/check_adr.py docs/architecture/ADR` e `git diff -M --stat`
  - **Evidência:**

- [ ] 4.2 — Referências em `ROADMAP.md` (ADRs), `docs/agents/domain.md`, specs históricas (só alvos de link), `ADR-4` e demais documentos vivos. Cobre RF-11 (c, d, e), RF-12, D-05; depende de 4.1.
  - **RED:** `git grep -nE '\]\((\.\./)*[a-z/.-]*000[1-3]-[a-z]' -- docs skill tests README.md GLOSSARY.md CONTRIBUTING.md` retorna links para os nomes antigos.
  - **GREEN:** links e menções vivas atualizados com edições explícitas; menções textuais históricas em specs antigas e no `CHANGELOG.md` mantidas (D-05).
  - **REFACTOR:** nenhum esperado.
  - **Validação:** a busca do RED sem resultados; `python3 skill/scripts/check_roadmap.py docs/architecture/ADR`; `python3 skill/scripts/check_adr.py docs/architecture/ADR`
  - **Evidência:**

## 5. Entrega

- [ ] 5.1 — `VERSION` 2.0.0, `CHANGELOG`, os dois ROADMAPs e evidência da etapa 4; suíte completa. Cobre RF-13, D-07, NR-07, NR-08; depende de 4.2.
  - **Validação:** `python3 -m unittest discover -s tests -p 'test_*.py'`; `bash tests/test_cli.sh` (casos que rodam sem tty e sem rede, como nas versões anteriores); Pester dos blocos tocados; `bash tests/gate.sh static`; `bash tests/gate.sh tag v2.0.0`; `check_roadmap.py` e `check_adr.py` na pasta de ADRs.
  - **Evidência:**

## Auditoria cruzada 360° (Gate 3, 2026-10-03)

| Requisito | Tarefas |
|---|---|
| RF-01, RF-02, RF-03, RF-04 | 1.1 |
| RF-05, SEG-01 | 1.2 |
| RF-06, RF-07, RF-15, D-04, D-08 | 2.1 |
| RF-08, SEG-02 | 2.2 |
| RF-09 | 2.3 |
| RF-10 | 3.1 |
| RF-11, RF-12, SEG-04, D-02, D-05 | 4.1, 4.2 |
| RF-13, D-07 | 5.1 |
| RF-14 | 2.1 (new/list), 2.3 (organize/link) |
| SEG-03, RNF-01, RNF-02, RNF-03 | 2.1 a 2.3 (verificados nos testes e no `gate.sh static`) |
| NR-01 a NR-08 | 1.1, 1.2, 2.1, 2.3, 5.1 (suíte completa) |
| R-01 | 5.1 (CHANGELOG, versão major) |
| R-02 | 4.1, 4.2 |
| R-03 | D-04 (2.1, 2.3) |
| R-04 | 2.2 |
| R-05, R-06 | 1.2 |

Sem requisito órfão nem tarefa sem requisito.

Pontos de atenção:

- **ADR:** o ADR-4 está `Proposto`. Aprovar (`Aceito`) cabe ao decisor; a spec não depende do status para ser implementada, mas o ROADMAP só marca a etapa 4 como `Concluída` com as tarefas feitas e a evidência registrada.
- **Confirmação pendente:** D-07 (versão 2.0.0). Alternativa 1.5.0 com aviso; não muda as tarefas além de 5.1.
- **Fixture:** a renomeação em 1.1 altera caminhos usados por `tests/test_cli.sh`, `tests/test_cli.ps1`, `CONTRIBUTING.md` e `tests/cenarios.md`; 2.1 e 2.3 completam o resto desses arquivos.
