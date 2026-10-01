# Tarefas — adr-std v1.2: comandos mecânicos no terminal

| Campo | Detalhe |
|---|---|
| **Requisitos / Design** | [requirements.md](requirements.md) · [design.md](design.md) |
| **Regra de execução** | Uma tarefa por vez, na ordem; marcar `[x]` só com evidência de teste. |

## 1. CLI Python

- [ ] 1.1 — `new` e `list` com SEG-01..03 e `resolve_folder`/`--path`. Cobre RF-01 a RF-04, RF-08, SEG-01 a SEG-03.
  - **RED:** `tests/test_adr_cli.py` (casos new/list/path/traversal/título vazio/sobrescrita).
  - **GREEN:** ajustes em `adr_cli.py`.
  - **Validação:** `python3 -m unittest tests/test_adr_cli.py -v`
  - **Evidência:** (a preencher)
- [ ] 1.2 — `link` e `organize --dry-run`; depende de 1.1. Cobre RF-05 a RF-07, SEG-04.
  - **RED:** casos link recíproco/preserva/atomicidade/tipo inválido; organize plano/sem dry-run.
  - **GREEN:** ajustes em `adr_cli.py`.
  - **Validação:** `python3 -m unittest tests/test_adr_cli.py -v`
  - **Evidência:** (a preencher)

## 2. Integração bash

- [ ] 2.1 — Despacho em `bin/adr-std` com `run_python_script`, código 6 sem Python e `help`; depende de 1.2. Cobre RF-09, RF-10.
  - **RED:** casos `cli_new_list`, `cli_link_organize`, `cli_no_python`, `help_lists_new_commands` em `tests/test_cli.sh`.
  - **GREEN:** `bin/adr-std`.
  - **Validação:** `bash tests/test_cli.sh cli_new_list cli_link_organize cli_no_python help_lists_new_commands`
  - **Evidência:** (a preencher)
- [ ] 2.2 — `.tsv` da v1.1 no instalador e no pacote; depende de 2.1. Cobre RF-11.
  - **RED:** `package_has_command_tables` e `installer_copies_command_tables`.
  - **GREEN:** `install.sh`, `install.ps1`, `package.sh`.
  - **Validação:** `bash tests/test_cli.sh package_has_command_tables installer_copies_command_tables`
  - **Evidência:** (a preencher)

## 3. Paridade PowerShell

- [ ] 3.1 — Espelhar 2.1 em `bin/adr-std.ps1` e testes Pester; depende de 2.1. Cobre RF-12.
  - **Validação:** `pwsh -NoProfile -Command "Invoke-Pester tests/test_cli.ps1 -CI"`
  - **Evidência:** (a preencher)

## 4. Entrega

- [ ] 4.1 — `VERSION` 1.2.0, `CHANGELOG`, README, SKILL.md (menção ao terminal), ROADMAP; depende de 3.1. Cobre RF-10.
  - **Validação:** `bash tests/gate.sh static`, `bash package.sh --release /tmp/adr-dist`
  - **Evidência:** (a preencher)

## Auditoria cruzada 360° (Gate 3, 2026-10-01)

| Requisito | Tarefas |
|---|---|
| RF-01, RF-02, RF-03, RF-04, RF-08, SEG-01, SEG-02, SEG-03 | 1.1 |
| RF-05, RF-06, RF-07, SEG-04 | 1.2 |
| RF-09, RF-10 (help) | 2.1 |
| RF-11 | 2.2 (bash) e 3.1 (`install.ps1`) |
| RF-12 | 3.1 |
| RF-10 (VERSION/CHANGELOG) | 4.1 |
| R-01 a R-04 | testes de 1.1, 1.2, 2.2; R-05 permanece pendência externa (v1.0, 6.1) |

Lacunas encontradas e resolvidas no Gate 3: (a) a posição da pasta mudou de posicional para `--path` (ADR-0001), registrado no design; (b) o instalador PowerShell também não copiava os `.tsv` da v1.1, incluído em 3.1; (c) `adr_cli.py` quebrava com ADR de arquivo vazio e aceitava título com quebra de linha, cobertos por SEG-03 e teste. Sem requisito órfão nem tarefa sem requisito. ADR: não aplicável (decisões já registradas em ADR-0001 e no ROADMAP; sem decisão arquitetural nova), portanto sem commit 1.
