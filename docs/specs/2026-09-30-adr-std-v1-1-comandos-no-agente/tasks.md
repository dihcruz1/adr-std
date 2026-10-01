# Tarefas — adr-std v1.1: comandos por ação dentro do agente

| Campo | Detalhe |
|---|---|
| **Requisitos / Design** | [requirements.md](requirements.md) · [design.md](design.md) |
| **Regra de execução** | Uma tarefa por vez, na ordem; marcar `[x]` só com evidência de teste. |

## 1. Dados

- [x] 1.1 — Criar `commands.tsv` e `command_targets.tsv`; cobre base de RF-01, RF-13.
  - **RED:** `test_cli.sh` caso `command_tables` falha (arquivos ausentes).
  - **GREEN:** arquivos conforme o design.
  - **Validação:** `bash tests/test_cli.sh command_tables`
  - **Evidência:** criados `commands.tsv` (10 ações, 2 colunas) e `command_targets.tsv` (4 agentes,
    4 colunas); `✓ command_tables`.

## 2. Comando `adr-std install` com comandos de ação (bash)

- [x] 2.1 — `install_commands`, `cmd_targets_for`, `command_owned_by_us`, flag `--no-commands`; depende de 1.1. Cobre RF-01, RF-13, RF-14, RF-15, RF-16, RNF-01, RNF-02, R-01, R-02.
  - **RED:** casos: `install_commands` (instala `claude-code` → 10 arquivos em `~/.claude/commands/`
    com `description` e `$ARGUMENTS`); `install_no_commands` (`--no-commands` não cria nenhum);
    `install_commands_preserve_foreign` (arquivo `adr-std-create.md` sem o comentário de marcação
    não é sobrescrito, aviso mostrado); `install_commands_all_agents` (`gemini-cli` gera `.toml`
    com `{{args}}`, `continue` gera `.prompt` com `{{{ input }}}`).
  - **GREEN:** implementação em `bin/adr-std`.
  - **Validação:** `bash tests/test_cli.sh install_commands install_no_commands install_commands_preserve_foreign install_commands_all_agents`
  - **Evidência:** RED real: os 4 casos falharam (arquivo de comando ausente; `opção desconhecida:
    --no-commands`; aviso de arquivo alheio ausente). GREEN: `command_rows`, `cmd_target_rows`,
    `command_marker_line`, `command_owned_by_us`, `command_file_content`, `install_commands` e a
    flag `--no-commands` implementados em `bin/adr-std`; 4 de 4 verdes. Suíte completa sem regressão
    (38/38 depois da tarefa 2.2).
- [x] 2.2 — `uninstall` remove os comandos registrados; depende de 2.1. Cobre RF-13 (remoção), R-02.
  - **RED:** caso `uninstall_removes_commands` (após instalar com comandos, `uninstall claude-code`
    remove os 10 arquivos; um arquivo alheio sem marcação permanece).
  - **GREEN:** implementação em `cmd_uninstall`.
  - **Validação:** `bash tests/test_cli.sh uninstall_removes_commands`
  - **Evidência:** RED real (comando não removido/arquivo alheio apagado por engano, teste falhava
    por ausência de `rm`). GREEN: `state_add_command`/`state_del_commands_for` implementados,
    chamados em `cmd_uninstall`; 1 de 1 verde; arquivo alheio sem marcação preservado.

## 3. Paridade PowerShell

- [x] 3.1 — Espelhar 2.1 e 2.2 em `bin/adr-std.ps1`; depende de 2.2. Cobre os mesmos requisitos no Windows.
  - **RED/GREEN:** mesmos 5 cenários de 2.1/2.2, em `tests/test_cli.ps1` (Pester).
  - **Validação:** `pwsh -NoProfile -Command "Invoke-Pester tests/test_cli.ps1"`

## 4. Instruções da skill (`SKILL.md`)

- [x] 4.1 — Seção "Comandos de ação (v1.1)" com as regras de `create`/`supersede` (rodadas de
  perguntas, `--ask N`, `--quick`) e `new`/`list` (sem perguntas); depende de nada. Cobre RF-02 a
  RF-12, RF-17 a RF-20.
  - **RED:** teste de texto em `tests/test_check_adr.py` procurando os marcadores: `--ask`,
    `--quick`, "pendente", "sugestão", "Proposto", "não apaga" (supersede), "sem perguntas" (new).
  - **GREEN:** seção escrita em `SKILL.md`.
  - **Validação:** `python3 -m unittest discover -s tests -p 'test_check_adr.py' -v`
  - **Evidência:** RED real: primeira tentativa do marcador "não apaga" não encontrada no texto
    escrito (o texto real diz "nunca apagar") — corrigido o marcador do teste. GREEN: 15 de 15
    testes de `test_check_adr.py`.

## 5. Publicação

- [x] 5.1 — `VERSION` → `1.1.0`, `CHANGELOG.md` atualizado; depende de 4.1.
  - **Validação:** `cat VERSION`; revisão do `CHANGELOG.md`.
  - **Evidência:** `VERSION` = `1.1.0`. `CHANGELOG.md` ganhou as seções `[1.1.0]` e `[1.0.0]`
    (esta última estava registrada como "Não lançado" por engano, apesar de já publicada — corrigido
    nesta tarefa). Efeito colateral encontrado e corrigido: `tests/test_cli.sh` tinha
    `gate.sh tag v1.0.0` com a versão escrita literalmente; corrigido para ler `VERSION` em tempo de
    execução (`"v$(cat "$ROOT/VERSION")"`), senão quebraria a cada bump de versão. Suíte completa
    depois do bump: `bash tests/test_cli.sh` 38/38; `python3 -m unittest discover -s tests -p 'test_check_*.py'` 24/24.

## Auditoria cruzada

| Requisito | Tarefa |
|---|---|
| RF-01, RF-13 a RF-16 | 1.1, 2.1, 2.2, 3.1 |
| RF-02 a RF-12, RF-17 a RF-20 | 4.1 |
| RNF-01, RNF-02 | 2.1 |
| RNF-03 | Fora de alcance mecânico (ver requirements.md, seção 12, item 4) |
| R-01, R-02 | 2.1, 2.2 |
| R-03, R-04, R-05 | Já cobertos por RF-03, RF-04, RF-12 (regra do agente, sem mudança mecânica) |

Sem requisito órfão. Item 4 da seção 12 (medir limite de perguntas) permanece bloqueio documentado,
fora do alcance de teste automático desta spec.
