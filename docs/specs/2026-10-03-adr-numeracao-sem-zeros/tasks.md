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

## 3. Script de migração e gancho do update

- [ ] 3.1 — `skill/scripts/migrate_numbering.py`: plano, aplicação, exclusões, opt-out. Cobre RF-16, RF-17, RF-18, RF-19, RF-20, RF-22, D-09, D-10, SEG-05, SEG-07, R-08, R-09; depende de 2.3.
  - **RED:** novo `tests/test_migrate_numbering.py` (projeto temporário, com e sem git): plano sem alterar arquivo; `--apply` renomeia (`git mv` em git, `rename` fora), corrige título, ID, links e menções; só números migrados (`ADR-0042` sem arquivo permanece); `--exclude` protege arquivo; colisão `0001-a.md` + `1-a.md` recusada; número duplicado recusado; árvore suja recusada; segunda execução sem plano; `numbering: padded` não altera; UTF-8 e fim de linha (CRLF) preservados; link simbólico para fora da raiz ignorado; erro no meio da aplicação para e informa. Rode antes de criar o script: falha (módulo inexistente).
  - **GREEN:** `build_plan`, `rewrite`, `apply`, varredura (`git ls-files` ou `os.walk` com exclusões), CLI com `--path`, `--root`, `--apply`, `--exclude`; importa `resolve_folder` de `adr_cli.py`.
  - **REFACTOR:** funções puras separadas da E/S; mensagens em pt-BR.
  - **Validação:** `python3 -m unittest tests.test_migrate_numbering`
  - **Evidência:**

- [ ] 3.2 — Comando `adr-std migrate` em bash e PowerShell; `help`; pacote. Cobre RF-23 (parte `migrate`), RNF-02; depende de 3.1.
  - **RED:** em `tests/test_cli.sh` e `tests/test_cli.ps1`: `migrate` mostra o plano e não altera; `migrate --apply` aplica em projeto temporário; `help` lista `migrate`; sem Python 3 sai com código 6 e indica o checklist manual (mesmo comportamento de `check`).
  - **GREEN:** `cmd_migrate` (`run_python_script`) e função equivalente no PowerShell; `help` e `README.md` (tabela de comandos); conferir que `package.sh` inclui o novo script.
  - **REFACTOR:** reaproveitar `run_python_script` sem duplicar localização de Python.
  - **Validação:** `bash tests/test_cli.sh migrate help`; Pester do bloco `migrate`; `bash tests/gate.sh static`
  - **Evidência:**

- [ ] 3.3 — Gancho do `update`: `maybe_migrate` e `--no-migrate`. Cobre RF-21, RF-23 (parte `update`), D-11, D-12, SEG-06, R-07, R-10, R-11; depende de 3.2.
  - **RED:** em `tests/test_cli.sh` e `tests/test_cli.ps1`, com o instalador falso já usado por `test_update`: sem terminal imprime o plano e `adr-std migrate --apply` sem alterar arquivo; com terminal simulado (`ADR_STD_TTY`) responde `s` e aplica, responde `n` ou vazio e não aplica; `--no-migrate` não calcula plano; `--dry-run` não migra; projeto sem pasta de ADRs ou com `numbering: padded` imprime só "nada a fazer"; sem Python 3 avisa e o `update` mantém o código de saída; falha do instalador não dispara migração.
  - **GREEN:** `maybe_migrate` chamada ao fim de `cmd_update` (e `Invoke-Update`), opção `--no-migrate`, `help`, nota de D-12 no `README.md`.
  - **REFACTOR:** reaproveitar a leitura de terminal do menu.
  - **Validação:** `bash tests/test_cli.sh update update_badsum`; Pester do bloco `update`; `shellcheck` quando disponível
  - **Evidência:**

## 4. Documentação da convenção

- [ ] 4.1 — Template, checklist, guia, `SKILL.md`, `GLOSSARY.md`, `README.md`, `CONTRIBUTING.md`, `tests/cenarios.md` e comentários de código descrevem `<N>-<slug>.md` / `ADR-<N>`, a convenção do projeto como prioridade, o `migrate` e o gancho do `update`. Cobre RF-10; depende de 3.3.
  - **RED:** `git grep -nE 'NNNN|4 dígitos' -- skill README.md GLOSSARY.md CONTRIBUTING.md tests/cenarios.md` retorna ocorrências do padrão antigo (menos as de `Substituído por ADR-NNNN`, que viram `ADR-N`); `SKILL.md` não cita `migrate`.
  - **GREEN:** textos atualizados (`<N>-<titulo-em-kebab-case>.md`, `ADR-<N>`, nota sobre zeros à esquerda só por convenção do projeto e `numbering: padded`, `adr-std migrate`, `update --no-migrate`, exemplos do `README.md` sem zeros); `SKILL.md` ganha a regra para o agente: ao encontrar ADRs com zeros à esquerda, oferecer `adr-std migrate`, mostrar o plano e só aplicar com autorização.
  - **REFACTOR:** conferir que `SKILL.md` e `template-madr.md` continuam coerentes entre si.
  - **Validação:** a busca do RED sem ocorrências do padrão antigo; `python3 skill/scripts/check_adr.py tests/fixtures/1-cache-de-sessao-em-redis.md`; `bash tests/gate.sh static`
  - **Evidência:**

## 5. Migração deste repositório

- [ ] 5.1 — Plano mostrado ao solicitante e `migrate --apply` nos ADRs 1 a 3, com `--exclude` para esta spec e para o ADR-4; ajustes manuais de histórico, "Modificado em" e do ADR-4. Cobre RF-11, RF-12, D-02, D-05, SEG-04, R-02; depende de 4.1 e de todo o trabalho anterior commitado.
  - **RED:** `python3 skill/scripts/check_adr.py docs/architecture/ADR` reprova A1 nos três arquivos `000N-...`; `python3 skill/scripts/migrate_numbering.py --exclude ... ` lista o plano (três renomeações).
  - **GREEN:** plano registrado nesta evidência, `--apply` com árvore commitada, histórico e "Modificado em" dos três ADRs (`Renumeração ADR-000N → ADR-N conforme ADR-4; texto da decisão inalterado`), Relações e Referências do ADR-4.
  - **REFACTOR:** nenhum esperado.
  - **Validação:** `git grep -nE '(^|[^0-9])000[1-3]-[a-z]' -- '*.md'` só com o que `--exclude` protegeu; `check_adr.py` e `check_roadmap.py` verdes na pasta de ADRs; segunda execução do script sem plano; `git diff -M --stat`
  - **Evidência:**

## 6. Entrega

- [ ] 6.1 — `VERSION` 2.0.0, `CHANGELOG` (quebra, migração, correspondência `ADR-0001..0003` → `ADR-1..3`, limitação D-12), os dois ROADMAPs e evidência da etapa 4; suíte completa. Cobre RF-13, D-07, D-12, NR-07, NR-08; depende de 5.1.
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
| RF-16, RF-17, RF-18, RF-19, RF-20, RF-22, D-09, D-10, SEG-05, SEG-07 | 3.1 |
| RF-23 (migrate) | 3.2 |
| RF-21, RF-23 (update), D-11, D-12, SEG-06 | 3.3 |
| RF-10 | 4.1 |
| RF-11, RF-12, SEG-04, D-02, D-05 | 5.1 |
| RF-13, D-07 | 6.1 |
| RF-14 | 2.1 (new/list), 2.3 (organize/link) |
| SEG-03, RNF-01, RNF-02, RNF-03 | 2.1 a 3.3 (verificados nos testes e no `gate.sh static`) |
| NR-01 a NR-08 | 1.1, 1.2, 2.1, 2.3, 6.1 (suíte completa) |
| R-01, R-10 | 6.1 (CHANGELOG, versão major, D-12), 3.3 |
| R-02, R-09 | 3.1, 5.1 |
| R-03 | D-04 (2.1, 2.3) |
| R-04 | 2.2 |
| R-05, R-06 | 1.2 |
| R-07, R-11 | 3.3 |
| R-08 | 3.1 |

Sem requisito órfão nem tarefa sem requisito.

Pontos de atenção:

- **ADR:** o ADR-4 está `Proposto`. Aprovar (`Aceito`) cabe ao decisor; a spec não depende do status para ser implementada, mas o ROADMAP só marca a etapa 4 como `Concluída` com as tarefas feitas e a evidência registrada.
- **Confirmações pendentes:** D-07 (versão 2.0.0; alternativa 1.5.0 com aviso, só afeta 6.1), D-11 (o `update` aplica a migração só com confirmação interativa; aplicar sem confirmação mudaria SEG-06 e 3.3) e D-09 (chave `numbering: padded`).
- **Limitação aceita (D-12):** o primeiro `update` a partir da v1.4 não executa a migração; fica registrada no `CHANGELOG.md` e no `README.md` (tarefas 3.3 e 6.1).
- **Fixture:** a renomeação em 1.1 altera caminhos usados por `tests/test_cli.sh`, `tests/test_cli.ps1`, `CONTRIBUTING.md` e `tests/cenarios.md`; 2.1, 2.3, 3.2 e 3.3 completam o resto desses arquivos.
- **Ordem da migração do repositório:** a tarefa 5.1 só roda com tudo anterior commitado, porque o script recusa árvore suja; o `CHANGELOG.md` da v2.0 (6.1) é escrito depois, para o script não reescrever a correspondência `ADR-0001..0003` → `ADR-1..3`.
