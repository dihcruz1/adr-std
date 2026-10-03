# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/); versões seguem o
[Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

## [2.0.0] - 2026-10-03

### Alterado (quebra de compatibilidade)
- O padrão de numeração dos ADRs passa a ser `<N>-<titulo-em-kebab-case>.md` com ID `ADR-<N>`, sem zeros à
  esquerda (ADR-4). `check_adr.py` reprova `0001-x.md` por omissão (A1); quem mantém zeros declara a convenção
  (`--name-pattern`, `.adr-std` com `numbering: padded`, `CONVENTIONS.md` ou `AGENTS.md`).
- `check_roadmap.py` deixa de ignorar em silêncio ADRs fora do padrão `\d{4}`: usa o mesmo padrão do `check_adr.py`
  e ganha `--name-pattern`. Regex inválida sai com código 2 e mensagem em pt-BR.
- `adr-std new` numera por maior número + 1 (comparação numérica), sem zeros; em convenção com zeros preserva a
  largura. `adr-std list` e `organize --dry-run` ordenam pelo número (`2` antes de `10`). `new` recusa criar quando o
  nome gerado não casa com o padrão ativo.
- Os ADRs deste repositório foram renumerados pelo próprio script de migração: `ADR-0001..0003` passaram a
  `ADR-1..3` (arquivos `1-...md` a `3-...md`), com IDs, links e referências corrigidos. Os registros antigos deste
  changelog e das specs foram atualizados pelo script; o texto das decisões não mudou.

### Adicionado
- `adr-std migrate [--apply] [--path PASTA] [--root RAIZ] [--exclude GLOB]`: renomeia ADRs com zeros à esquerda
  (`0001-x.md` → `1-x.md`, mesmo número, sem renumerar) e corrige ID, links e referências nos `*.md` do projeto.
  Por omissão só mostra o plano; recusa colisão de nome e arquivos com alterações não commitadas (em git).
  Script: `skill/scripts/migrate_numbering.py`.
- `adr-std update` mostra o plano de migração do projeto atual depois de atualizar a skill e só aplica com
  confirmação interativa (`Aplicar a migração? [s/N]`); `update --no-migrate` pula a etapa e
  `numbering: padded` no `.adr-std` mantém os zeros. Falha nessa etapa só avisa e não muda o código de saída do `update`.
- Paridade no PowerShell (`bin/adr-std.ps1`).

### Corrigido
- `bin/adr-std` termina com `exit $?` na mesma linha da chamada de `main`: o `update` pode substituir o próprio
  arquivo enquanto o bash ainda o lê.

### Notas de migração
- O primeiro `adr-std update` a partir da v1.4 é executado pelo wrapper e pelo instalador antigos e não
  roda a migração; rode `adr-std update` de novo ou `adr-std migrate`.
- Projetos que querem manter `0001-`: `numbering: padded` no `.adr-std` e `--name-pattern '^(\d{4})-.+\.md$'`
  no `check`.

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
  ADR-1. Fecha a etapa 2 do ADR-1 (o campo já era lido por `new`, `list`, `link` e `organize`
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
- `check_adr.py` tratava o `ROADMAP.md` da pasta de ADRs (ADR-2) como se fosse um ADR e reprovava
  a pasta inteira; agora ele é ignorado, como `README.md` e `CONVENTIONS.md`.

## [1.2.0] - 2026-10-01

### Adicionado
- Comandos mecânicos no terminal, em Python (`skill/scripts/adr_cli.py`): `adr-std new <título>`,
  `list`, `link <ADR-A> <tipo> <ADR-B>` e `organize --dry-run`, com `--path PASTA` e `--name-pattern`.
  A pasta dos ADRs segue o ADR-1: `--path` > `.adr-std` > config global > `docs/architecture/ADR`.
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
- ADR-1 (caminho dos ADRs e personalização), ADR-2 (ROADMAP como documento central de
  rastreabilidade) e ADR-3 (atualização automática do ROADMAP) implementados no `SKILL.md`.

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
