# Tarefas — adr-std v1.3: comandos de conversa no terminal

| Campo | Detalhe |
|---|---|
| **Requisitos / Design** | [requirements.md](requirements.md) · [design.md](design.md) |
| **Regra de execução** | Uma tarefa por vez, na ordem; marcar `[x]` só com evidência de teste. |

## 1. Dados e configuração

- [ ] 1.1 — `agent_launch.tsv`, `state_del` e `adr-std config agent`; cobre RF-08, SEG-04.
  - **RED:** `launch_table`, `config_agent` falham (tabela ausente, comando desconhecido).
  - **GREEN:** tabela e `cmd_config` em `bin/adr-std`.
  - **Validação:** `bash tests/test_cli.sh launch_table config_agent`
  - **Evidência:** (a preencher)

## 2. Comandos de conversa (bash)

- [ ] 2.1 — Escolha do agente (explícito, termo parecido, aspas); depende de 1.1. Cobre RF-01, RF-07, RF-11, RF-12, SEG-01.
  - **RED:** `converse_explicit_agent`, `converse_description_with_agent_name`, `converse_similar_agent`, `converse_injection`, `converse_missing_binary`.
  - **Validação:** `bash tests/test_cli.sh converse_explicit_agent converse_description_with_agent_name converse_similar_agent converse_injection converse_missing_binary`
  - **Evidência:** (a preencher)
- [ ] 2.2 — Padrão, menu com memória, erros sem terminal/sem elegível, `--ask`/`--quick`; depende de 2.1. Cobre RF-02 a RF-06, RF-09, RF-10.
  - **RED:** `converse_default_agent`, `converse_menu_last_used`, `converse_no_tty`, `converse_no_eligible`, `converse_ask_quick`.
  - **Validação:** `bash tests/test_cli.sh converse_default_agent converse_menu_last_used converse_no_tty converse_no_eligible converse_ask_quick`
  - **Evidência:** (a preencher)
- [ ] 2.3 — `help`, instalador e pacote com `agent_launch.tsv`; depende de 2.2. Cobre RF-13.
  - **RED:** `help_lists_converse`, `installer_copies_launch_table`, `package_has_command_tables` estendido.
  - **Validação:** `bash tests/test_cli.sh help_lists_converse installer_copies_launch_table package_has_command_tables`
  - **Evidência:** (a preencher)

## 3. Paridade PowerShell

- [ ] 3.1 — Espelhar 1.1 a 2.3 em `bin/adr-std.ps1` e `install.ps1`; depende de 2.3. Cobre RF-14.
  - **Validação:** `pwsh -NoProfile -Command "Invoke-Pester tests/test_cli.ps1 -CI"`
  - **Evidência:** (a preencher)

## 4. Entrega

- [ ] 4.1 — `VERSION` 1.3.0, `CHANGELOG`, README, SKILL.md, ROADMAP; E2E; depende de 3.1. Cobre RF-13.
  - **Validação:** suíte completa, `bash tests/gate.sh static`, `bash package.sh --release /tmp/adr-dist`
  - **Evidência:** (a preencher)

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
