# Tarefas — adr-std v1.2: comandos mecânicos no terminal

| Campo | Detalhe |
|---|---|
| **Requisitos / Design** | [requirements.md](requirements.md) · [design.md](design.md) |
| **Regra de execução** | Uma tarefa por vez, na ordem; marcar `[x]` só com evidência de teste. |

## 1. CLI Python

- [x] 1.1 — `new` e `list` com SEG-01..03 e `resolve_folder`/`--path`. Cobre RF-01 a RF-04, RF-08, SEG-01 a SEG-03.
  - **RED:** `tests/test_adr_cli.py` (casos new/list/path/traversal/título vazio/sobrescrita).
  - **GREEN:** ajustes em `adr_cli.py`.
  - **Validação:** `python3 -m unittest tests/test_adr_cli.py -v`
  - **Evidência:** RED real: 20 de 23 testes de `tests/test_adr_cli.py` falharam contra o código existente (sem `--path`, sem `resolve_folder`/`write_new_adr`, crash com arquivo vazio). GREEN: `--path`, `resolve_folder` (flag > `.adr-std` > config global > padrão), `write_new_adr` com modo exclusivo, título em linha única, `adr_title` robusto; 23 de 23 (1.1 e 1.2 compartilham o arquivo de teste). Um teste meu estava errado (contava `**Status**` na linha do título); corrigido para contar só linhas de tabela. Suíte unittest total: 47/47.
- [x] 1.2 — `link` e `organize --dry-run`; depende de 1.1. Cobre RF-05 a RF-07, SEG-04.
  - **RED:** casos link recíproco/preserva/atomicidade/tipo inválido; organize plano/sem dry-run.
  - **GREEN:** ajustes em `adr_cli.py`.
  - **Validação:** `python3 -m unittest tests/test_adr_cli.py -v`
  - **Evidência:** Coberto no mesmo arquivo de teste: `link` recíproco, preserva relações, tipo inválido (2), ADR ausente (1), sem escrita parcial quando um dos ADRs não tem o campo; `organize` exige `--dry-run`, plano de renumeração e pasta ausente. Verde junto com 1.1 (ver acima).

## 2. Integração bash

- [x] 2.1 — Despacho em `bin/adr-std` com `run_python_script`, código 6 sem Python e `help`; depende de 1.2. Cobre RF-09, RF-10.
  - **RED:** casos `cli_new_list`, `cli_link_organize`, `cli_no_python`, `help_lists_new_commands` em `tests/test_cli.sh`.
  - **GREEN:** `bin/adr-std`.
  - **Validação:** `bash tests/test_cli.sh cli_new_list cli_link_organize cli_no_python help_lists_new_commands`
  - **Evidência:** RED real: 6 casos novos falharam (`comando desconhecido: new`, código 2 em vez de 6, `.tsv` ausente no instalador e no zip). GREEN: `run_python_script` extraído de `cmd_check` (reuso), `cmd_mechanical`, `help`. `bash tests/test_cli.sh` 44/44 (38 anteriores + 6 novos, 4 deles desta tarefa).
- [x] 2.2 — `.tsv` da v1.1 no instalador e no pacote; depende de 2.1. Cobre RF-11.
  - **RED:** `package_has_command_tables` e `installer_copies_command_tables`.
  - **GREEN:** `install.sh`, `install.ps1`, `package.sh`.
  - **Validação:** `bash tests/test_cli.sh package_has_command_tables installer_copies_command_tables`
  - **Evidência:** Coberto pelos 2 últimos casos RED/GREEN acima: `install.sh` e `package.sh` (lista `required`) agora incluem `commands.tsv` e `command_targets.tsv`; `unzip -Z1` confere os dois e `adr_cli.py`.

## 3. Paridade PowerShell

- [x] 3.1 — Espelhar 2.1 em `bin/adr-std.ps1` e testes Pester; depende de 2.1. Cobre RF-12.
  - **Validação:** `pwsh -NoProfile -Command "Invoke-Pester tests/test_cli.ps1 -CI"`
  - **Evidência:** `bin/adr-std.ps1` (`Invoke-PythonScript`, `Invoke-Mechanical`, help) e `install.ps1` (`.tsv`); Pester 5 com `pwsh` 7.4.6 portátil em `/tmp/pwsh-portable`: **28 de 28** (25 anteriores + 3 novos). Honestidade de processo: os testes Pester foram escritos junto da implementação espelhada (paridade direta do bash, que teve RED real), sem RED separado no PowerShell.

## 4. Entrega

- [x] 4.1 — `VERSION` 1.2.0, `CHANGELOG`, README, SKILL.md (menção ao terminal), ROADMAP; depende de 3.1. Cobre RF-10.
  - **Validação:** `bash tests/gate.sh static`, `bash package.sh --release /tmp/adr-dist`
  - **Evidência:** `VERSION` 1.2.0; `CHANGELOG`, README (seções 5, 6.5, 8, 13, 14), `SKILL.md` (tabela de arquivos) e os dois ROADMAPs atualizados. `bash tests/gate.sh static` e `tag v1.2.0` ok; `bash package.sh --release /tmp/adr-dist` gerou o zip 1.2.0; `check_roadmap.py docs/architecture/ADR` → `[OK] ROADMAP consistente`. Fora do escopo (registrado): `adr-std config path` (ADR-0001, etapa 2) e `organize` real.

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
