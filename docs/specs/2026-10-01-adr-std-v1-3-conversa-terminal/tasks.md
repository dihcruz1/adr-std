# Tarefas — adr-std v1.3: comandos de conversa no terminal

| Campo | Detalhe |
|---|---|
| **Requisitos / Design** | [requirements.md](requirements.md) · [design.md](design.md) |
| **Regra de execução** | Uma tarefa por vez, na ordem; marcar `[x]` só com evidência de teste. |

## 1. Dados e configuração

- [x] 1.1 — `agent_launch.tsv`, `state_del` e `adr-std config agent`; cobre RF-08, SEG-04.
  - **RED:** `launch_table`, `config_agent` falham (tabela ausente, comando desconhecido).
  - **GREEN:** tabela e `cmd_config` em `bin/adr-std`.
  - **Validação:** `bash tests/test_cli.sh launch_table config_agent`
  - **Evidência:** RED real: `launch_table` e `config_agent` falharam (tabela ausente; `comando desconhecido: config`). GREEN: `agent_launch.tsv` (4 agentes), `launch_rows`/`is_launchable`/`launch_field`, `state_del`, `cmd_config`. Verdes na suíte final (59/59).

## 2. Comandos de conversa (bash)

- [x] 2.1 — Escolha do agente (explícito, termo parecido, aspas); depende de 1.1. Cobre RF-01, RF-07, RF-11, RF-12, SEG-01.
  - **RED:** `converse_explicit_agent`, `converse_description_with_agent_name`, `converse_similar_agent`, `converse_injection`, `converse_missing_binary`.
  - **Validação:** `bash tests/test_cli.sh converse_explicit_agent converse_description_with_agent_name converse_similar_agent converse_injection converse_missing_binary`
  - **Evidência:** RED real: no início da fase, os 15 casos novos de v1.3 falharam (`comando desconhecido`). GREEN: `parse_converse_args` (regra D-02, `similar_agent`), `launch_agent` com o pedido como argumento único. `converse_explicit_agent`, `converse_gemini_and_opencode_flags` (`-i`/`--prompt`), `converse_description_with_agent_name`, `converse_similar_agent`, `converse_injection` (`$(...)`, `;` e crases não executam nada), `converse_missing_binary` (código 5) verdes.
- [x] 2.2 — Padrão, menu com memória, erros sem terminal/sem elegível, `--ask`/`--quick`; depende de 2.1. Cobre RF-02 a RF-06, RF-09, RF-10.
  - **RED:** `converse_default_agent`, `converse_menu_last_used`, `converse_no_tty`, `converse_no_eligible`, `converse_ask_quick`.
  - **Validação:** `bash tests/test_cli.sh converse_default_agent converse_menu_last_used converse_no_tty converse_no_eligible converse_ask_quick`
  - **Evidência:** GREEN: `pick_agent` (explícito > padrão com aviso > menu com último usado pré-selecionado; Enter repete), erros 3 sem terminal e sem agente elegível, `--ask`/`--quick` repassados só em create/supersede, `ask` sem pergunta recusado. Casos `converse_default_agent`, `converse_menu_last_used`, `converse_no_tty`, `converse_no_eligible`, `converse_ask_quick` verdes. Um RED intermediário: `help_lists_converse` falhou porque o help listava os cinco comandos numa linha só; ajustado para uma linha por comando (mais legível). `bash tests/test_cli.sh` → 59/59. `shellcheck` 0.11 estático: limpo (dois avisos de info nos testes tratados com `disable` justificado e `mapfile`/`while read`).
- [x] 2.3 — `help`, instalador e pacote com `agent_launch.tsv`; depende de 2.2. Cobre RF-13.
  - **RED:** `help_lists_converse`, `installer_copies_launch_table`, `package_has_command_tables` estendido.
  - **Validação:** `bash tests/test_cli.sh help_lists_converse installer_copies_launch_table package_has_command_tables`
  - **Evidência:** `agent_launch.tsv` em `install.sh`, `install.ps1` e `package.sh` (`required`); `installer_copies_launch_table` verde; `unzip -Z1` do `package.sh --release` lista `agent_launch.tsv`, `commands.tsv`, `command_targets.tsv` e `adr_cli.py`. Help com os cinco comandos e `config`.

## 3. Paridade PowerShell

- [x] 3.1 — Espelhar 1.1 a 2.3 em `bin/adr-std.ps1` e `install.ps1`; depende de 2.3. Cobre RF-14.
  - **Validação:** `pwsh -NoProfile -Command "Invoke-Pester tests/test_cli.ps1 -CI"`
  - **Evidência:** `bin/adr-std.ps1` (`Read-ConverseArg`, `Select-LaunchAgent`, `Start-LaunchAgent`, `Invoke-Config`, `Remove-State`) e `install.ps1`. Pester 5 / `pwsh` 7.4.6 portátil: **42 de 42**. Os testes que abrem binário falso (shell script) ficam `-Skip` em Windows real (`$env:OS -eq 'Windows_NT'`) — lacuna registrada: lá só rodam config, sugestão de nome parecido, sem terminal/sem elegível e o instalador. Em PowerShell < 7.3 as aspas internas do pedido são escapadas à mão (não testável aqui). PSScriptAnalyzer (`Error,Warning`, excluindo as 2 regras do workflow) → 0 ocorrências. Sem RED separado no PowerShell (espelha o bash, que teve RED real).

## 4. Entrega

- [x] 4.1 — `VERSION` 1.3.0, `CHANGELOG`, README, SKILL.md, ROADMAP; E2E; depende de 3.1. Cobre RF-13.
  - **Validação:** suíte completa, `bash tests/gate.sh static`, `bash package.sh --release /tmp/adr-dist`
  - **Evidência:** `VERSION` 1.3.0; `CHANGELOG`, README (seção 8 com a regra de escolha do agente, 13, 14), `tests/cenarios.md` (T1–T3, abrir agente real é manual — R-03) e os dois ROADMAPs. Pendências desta spec resolvidas na própria sessão: (a) `check_adr.py` reprovava o `ROADMAP.md` da pasta de ADRs — RED `test_folder_scan_ignores_roadmap`, GREEN com `ROADMAP.md` em `IGNORED_FILES`; (b) workflow só rodava `test_check_adr.py` — agora `test_*.py`. E2E visível em `HOME` temporário a partir do **zip** descompactado: install, `new`/`list`/`link`/`organize --dry-run`, `config agent codex`, `create --quick` abriu o codex falso com o pedido correto, sem terminal → código 3. Suíte final: bash 59/59, unittest 48/48, Pester 42/42, `gate.sh static` e `tag v1.3.0` ok, `package.sh --release` ok, `check_roadmap.py` ok, `check_adr.py docs/architecture/ADR` sem falhas nos 3 ADRs. SEG-02: nenhuma leitura de credencial no código novo (conferido por grep de token, secret, password e api key nos trechos novos: só o parâmetro `$Tokens` do PowerShell aparece).

## Auditoria cruzada 360° (Gate 3, 2026-10-01)

| Requisito | Tarefas |
|---|---|
| RF-08, SEG-04 | 1.1 |
| RF-01, RF-07, RF-11, RF-12, SEG-01, SEG-03 | 2.1 |
| RF-02 a RF-06, RF-09, RF-10 | 2.2 |
| RF-13 | 2.3 e 4.1 |
| RF-14 | 3.1 |
| SEG-02 | por construção (nenhum código lê credencial); conferido na revisão final de 4.1 |
| R-01 a R-04 | `converse_injection`, `launch_table`, `converse_similar_agent`; R-03 é verificação manual registrada |

Lacunas resolvidas: o ponto "como cada agente aceita pedido inicial" do ROADMAP foi fechado com `--help` real dos quatro CLIs; a sugestão de nome parecido ganhou critério objetivo (sem espaço, ≥ 4 letras) para não barrar descrições comuns. Sem requisito órfão nem tarefa sem requisito. ADR: não aplicável (decisões no ROADMAP); sem commit 1.
