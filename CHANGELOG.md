# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/); versões seguem o
[Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

## [1.4.1] - 2026-10-03

### Corrigido
- `bin/adr-std` e `tests/test_cli.sh` rodam no bash 3.2 do macOS: sem `mapfile`, sem array associativo,
  sem `grep -P`, `sed -i` com sufixo e `wc -l` sem preenchimento. Antes, a instalação quebrava no macOS.
- Menu de instalação sem escolha (bash e PowerShell) agora indica `--agent` ou `--all` na mensagem de erro.
- Quatro testes negativos do estado nunca falhavam no macOS (`grep -P` inexistente); agora verificam de verdade.
- CI (`release.yml`) verde em Ubuntu, macOS e Windows.

## [1.4.0] - 2026-10-02

### Adicionado
- `adr-std config path [pasta]`: mostra, define (`<pasta>`) ou remove (`--unset`) a pasta de ADRs na
  config global (`~/.config/adr-std/config` ou `%APPDATA%\adr-std\config`), o nível 4 da hierarquia do
  ADR-0001. Fecha a etapa 2 do ADR-0001 (o campo já era lido por `new`, `list`, `link` e `organize`
  desde a v1.2; agora também se grava pela CLI, sem editar o arquivo à mão).
- `adr-std config` agora aceita dois subcomandos (`agent` e `path`); a mensagem de uso lista os dois.
- Paridade no PowerShell (`bin/adr-std.ps1`).

## [1.3.0] - 2026-10-01

### Adicionado
- Comandos de conversa no terminal: `adr-std create`, `supersede`, `review`, `audit` e `ask` abrem um
  agente (Claude Code, Codex, Gemini CLI ou OpenCode) com o pedido inicial que chama a skill. `create` e
  `supersede` repassam `--ask N` e `--quick`.
- Escolha do agente por prioridade: indicado no comando (nome seguido da descrição, ou `--agent`);
  agente padrão (`adr-std config agent <nome>`, `--unset` desfaz, sem argumento mostra); menu com o
  último usado pré-selecionado (Enter repete); sem terminal e sem as anteriores, erro pedindo `--agent`.
  Nome parecido gera sugestão ("quis dizer claude-code?"); descrição entre aspas continua descrição.
- `agent_launch.tsv`: como abrir cada agente pelo terminal (uma linha por agente).
- O pedido vai ao programa do agente como um único argumento, sem `eval` nem shell.
- Paridade no PowerShell; testes unitários agora também rodam no CI (`test_*.py`).

### Corrigido
- `check_adr.py` tratava o `ROADMAP.md` da pasta de ADRs (ADR-0002) como se fosse um ADR e reprovava
  a pasta inteira; agora ele é ignorado, como `README.md` e `CONVENTIONS.md`.

## [1.2.0] - 2026-10-01

### Adicionado
- Comandos mecânicos no terminal, em Python (`skill/scripts/adr_cli.py`): `adr-std new <título>`,
  `list`, `link <ADR-A> <tipo> <ADR-B>` e `organize --dry-run`, com `--path PASTA` e `--name-pattern`.
  A pasta dos ADRs segue o ADR-0001: `--path` > `.adr-std` > config global > `docs/architecture/ADR`.
  Sem Python 3, os comandos avisam (código 6) e indicam o checklist manual.
- `link` grava a relação nos dois ADRs (com o tipo inverso) e não deixa estado parcial; `new` nunca
  sobrescreve arquivo e não grava fora da pasta de ADRs.
- Paridade no PowerShell (`bin/adr-std.ps1`).

### Corrigido
- `install.sh`, `install.ps1` e `package.sh` não incluíam `commands.tsv` e `command_targets.tsv`
  (v1.1): instalar pelo zip ou pelo instalador remoto não criava os comandos de ação no agente.

## [1.1.0] - 2026-10-01

### Adicionado
- Comandos por ação dentro do agente (`/adr-std-create`, `-supersede`, `-review`, `-organize`,
  `-link`, `-audit`, `-check`, `-ask`, `-new`, `-list`) para Claude Code, Gemini CLI, OpenCode e
  Continue; `$adr-std <ação>` no Codex.
  Conversa guiada em `create`/`supersede` com `--ask N` (`-a N`) e `--quick` (`-k`).
- `adr-std install`/`update` criam e removem os arquivos de comando nos agentes que aceitam;
  `--no-commands` instala só a skill; arquivos de terceiros nunca são sobrescritos.
- `skill/scripts/check_roadmap.py`: verifica a consistência do `ROADMAP.md` de arquitetura
  (estrutura, rastreabilidade bidirecional com os ADRs, heurística de Status das Specs).
- ADR-0001 (caminho dos ADRs e personalização), ADR-0002 (ROADMAP como documento central de
  rastreabilidade) e ADR-0003 (atualização automática do ROADMAP) implementados no `SKILL.md`.

## [1.0.0] - 2026-10-01

### Adicionado
- Skill `adr-std`: guia da ISO/IEC/IEEE 42010:2022, template MADR estendido, checklist e `check_adr.py`.
- Comando `adr-std` (bash e PowerShell): `install`, `update`, `uninstall`, `self-uninstall`, `status`,
  `agents`, `check`, `version` e `help`.
- Instaladores `install.sh`/`install.ps1` (modo local e remoto, com conferência de checksum) e pacote
  zip com atalhos de duplo clique para Windows, macOS e Linux.
- Lista de 15 agentes em `agents.tsv`.
- Workflow `release.yml` com gate de segurança (bloqueia arquivo da norma, arquivo grande, `name`
  divergente e tag fora de `VERSION`) e testes em Ubuntu, macOS e Windows.
- Testes automáticos do script (`tests/test_check_adr.py`), do comando (`tests/test_cli.sh`, `tests/test_cli.ps1`)
  e do gate (`tests/gate.sh`).
