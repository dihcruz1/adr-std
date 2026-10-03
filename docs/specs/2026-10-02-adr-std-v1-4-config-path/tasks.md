# Tarefas — adr-std v1.4: `config path`

| Campo | Detalhe |
|---|---|
| **Requisitos / Design** | [requirements.md](requirements.md) · [design.md](design.md) |
| **Regra de execução** | Uma tarefa por vez, na ordem; marcar `[x]` só com evidência de teste. Commit só com autorização expressa. |
| **Base dos comandos** | `cd /Fusiondev/Code/Skills/adr-std` |

## 1. Bash

- [x] 1.1 — `config path` em `bin/adr-std` (`config_path_get/set/unset`, ramo `path` em `cmd_config`, uso citando `agent` e `path`); depende da v1.3. Cobre RF-01 a RF-06, SEG-01 a SEG-03, RNF-02.
  - **RED:** novo caso `config_path` em `tests/test_cli.sh`: mostrar sem valor → "nenhuma pasta"; `config path docs/decisoes` → mostra `docs/decisoes` e a config tem exatamente uma linha `path`; preserva `default_agent` ao gravar; `--unset` → volta a "nenhuma pasta" e não falha repetido; `config path -x` → código 2; `config caminho` → código 2 com uso citando `agent` e `path`; ida-e-volta: `config path <tmp>` + `list` sem `--path`/`.adr-std` acha o ADR em `<tmp>`.
  - **GREEN:** funções e ramo em `bin/adr-std`.
  - **REFACTOR:** reusar o padrão de reescrita por arquivo temporário já usado em `state_put`.
  - **Validação:** `bash tests/test_cli.sh config_path config_agent`
  - **Evidência (2026-10-02):** RED real: `config path` não existia (`cmd_config` só aceitava `agent`), o novo caso `config_path` falhava. **Descoberta durante o RED:** a config global que `resolve_folder`/`read_path_field` (adr_cli.py) leem é `$CONFIG_DIR/config`, um arquivo **separado** do `$CONFIG_DIR/state` (onde `config agent` grava `default_agent`) — a primeira versão gravava no `state` e o `list` não enxergava. GREEN: nova var `CONFIG_FILE=$CONFIG_DIR/config` e funções `config_lines`/`config_path_get`/`config_path_set`/`config_path_unset` gravando `path: <valor>` nesse arquivo; `cmd_config` virou despacho para `cmd_config_agent` (inalterado) e `cmd_config_path`; mensagem de uso `adr-std config <agent|path> ...`. `bash tests/test_cli.sh config_path config_agent` → 2/2 verdes, incluindo o ida-e-volta (grava com o CLI, `list` lê a mesma pasta) e a prova de que `config agent` (arquivo state) e `config path` (arquivo config) não se interferem. Regressão representativa (`version help help_lists_converse help_lists_new_commands cli_new_list cli_link_organize cli_no_python launch_table`) → verdes; `python3 -m unittest discover -s tests -p 'test_*.py'` → 48/48. `shellcheck` não instalado localmente (roda no gate do CI, mesmo precedente das versões anteriores).

## 2. Paridade PowerShell

- [x] 2.1 — Espelhar 1.1 em `bin/adr-std.ps1` (`Get-ConfigPath`, `Set-ConfigPath`, `Remove-ConfigPath`, ramo `path` em `Invoke-Config`); depende de 1.1. Cobre RF-08.
  - **RED:** caso `config path` em `tests/test_cli.ps1` com os mesmos cenários mecânicos (mostrar/gravar/unset/preserva/subcomando inválido).
  - **GREEN:** implementação espelhando o bash.
  - **REFACTOR:** mensagens idênticas às do bash; PSScriptAnalyzer limpo (mesmas exclusões do workflow).
  - **Validação:** `pwsh -NoProfile -Command "Invoke-Pester tests/test_cli.ps1 -CI"`
  - **Evidência (2026-10-02):** `bin/adr-std.ps1` ganhou `$ConfigFile=$ConfigDir/config`, `Get-ConfigLine`/`Get-ConfigPath`/`Set-ConfigPath`/`Remove-ConfigPath` e `Invoke-Config` virou despacho para `Invoke-ConfigAgent` (inalterado) e `Invoke-ConfigPath`; mesma mensagem de uso do bash. `tests/test_cli.ps1`: novo `Describe 'config path (v1.4)'`. Rodado com PowerShell 7.4.6 portátil (baixado sem privilégio de root em `/tmp/pwsh-portable`, mesmo precedente das sessões anteriores; Pester 6.2.0 do ambiente): o bloco `config path` + `config agent` + `version/help` + `new/list (v1.2)` → **8/8 verdes**. `Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning` com as exclusões do workflow (`PSAvoidUsingWriteHost`, `PSUseShouldProcessForStateChangingFunctions`) → 0 ocorrências. Sem RED separado no PowerShell (espelha o bash, que teve RED real). **Não verificável aqui (limitação de ambiente, não de código):** suíte Pester completa de ponta a ponta — os blocos de instalador/conversa travam sem tty/rede neste ambiente, igual à suíte bash; os blocos tocados por esta spec rodam e passam.

## 3. Entrega

- [x] 3.1 — `help` (bash e ps1) com `config path`, `VERSION` 1.4.0, `CHANGELOG`, README, SKILL.md e os dois ROADMAPs; depende de 2.1. Cobre RF-07.
  - **Validação:** `bash tests/gate.sh static`, suíte completa, `check_roadmap.py docs/architecture/ADR`
  - **Evidência (2026-10-02):** `VERSION` 1.4.0; `help` do bash e do ps1 listam `config path`; `CHANGELOG.md` com o bloco `[1.4.0]`; `README.md` (linha `config path` na tabela de comandos, nota de hierarquia da config global editável pela CLI, resumo "Versão 1.4 (esta)", `config path` removido de "Futuro" e nova linha 1.4 em "Planejado"); `skill/SKILL.md` (nota de que a CLI grava o nível 4 com `config path`); `ROADMAP.md` da raiz (nova linha 1.4 "Concluída"); `docs/architecture/ADR/ROADMAP.md` (nova linha v1.4 na tabela de versões e nota da v1.2 corrigida de "`config path` pendente" para "leitura da config global"). Validação: `bash tests/gate.sh static` → `Gate static: ok`; `bash tests/gate.sh tag v1.4.0` → `Gate tag: ok`; `python3 skill/scripts/check_roadmap.py docs/architecture/ADR/` → `[OK] ROADMAP consistente`; `check_adr.py` nos 3 ADRs → OK; `python3 -m unittest discover -s tests -p 'test_*.py'` → 48/48. **Suíte completa (install/remoto/conversa) não roda ponta a ponta neste ambiente** (sem tty interativo e sem rede os testes de instalador travam); fica para o CI, como nas versões anteriores.

## Auditoria cruzada 360° (Gate 3, 2026-10-02)

| Requisito | Tarefas |
|---|---|
| RF-01, RF-02, RF-03, RF-04, RF-05, RF-06 | 1.1 |
| SEG-01, SEG-02, SEG-03, RNF-01, RNF-02 | 1.1 (verificados nos casos de teste) |
| RF-07 | 3.1 |
| RF-08 | 2.1 |
| R-01 | 1.1 (teste "preserva o agente padrão") |
| R-02 | 2.1 |
| R-03 | D-01 (design) + README (3.1) |
| R-04 | 1.1 (teste de subcomando inválido) |

Sem requisito órfão nem tarefa sem requisito. ADR: a decisão já é o ADR-1 (etapa 2); esta spec
implementa o critério de Verificação daquele ADR, não cria decisão nova — logo sem commit 1.

**Critério de Verificação do ADR-1 fechado:** "`adr-std config path` (v1.2+) lê e grava o valor
correto no arquivo de config global" — agora atendido (`config path` sem argumento lê, `<pasta>` grava,
`--unset` remove; o ida-e-volta com `list` prova que o valor gravado é lido por `resolve_folder`).

**Limitação registrada (pré-existente, fora do escopo desta spec):** no Windows, `bin/adr-std.ps1`
usa `%APPDATA%\adr-std\config` como config global, mas `adr_cli.py` resolve `config_home` por
`XDG_CONFIG_HOME` ou `~/.config` — os dois divergem no Windows (no Linux coincidem, e foi onde os
testes rodaram). A mesma divergência já existia para `config agent`/estado desde a v1.3; alinhá-las
no Windows mexe no `config_home` que o Python usa e é decisão de arquitetura (candidata a ADR), não
ampliação desta spec. Nos testes, o isolamento por `ADR_STD_*`/`XDG_CONFIG_HOME` evita o problema.
