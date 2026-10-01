# Design — adr-std v1.1: comandos por ação dentro do agente

| Campo | Detalhe |
|---|---|
| **Requisitos** | [requirements.md](requirements.md) |
| **Status** | Gate 2 |

## Contrato

### Dados novos (mesmo padrão TSV de `agents.tsv`)

`command_targets.tsv` (raiz do repo) — só os agentes com comando dedicado (RF-01, seção 7):

```
# id          pasta (relativa a ~)         extensao  variavel-argumento
claude-code   .claude/commands              md        $ARGUMENTS
gemini-cli    .gemini/commands              toml      {{args}}
opencode      .config/opencode/commands     md        $ARGUMENTS
continue      .continue/prompts             prompt    {{{ input }}}
```

`commands.tsv` (raiz do repo) — as 10 ações e a descrição curta usada no comando gerado:

```
# acao       descricao-curta
create       Cria um ADR novo em conversa guiada
supersede    Cria o ADR que substitui outro
review       Revisa ADRs contra a norma e o checklist
organize     Reorganiza numeracao, nomes, status e relacoes
link         Registra uma relacao entre dois ADRs
audit        Audita a descricao de arquitetura completa
check        Roda a verificacao automatica
ask          Responde duvidas sobre a norma
new          Cria o esqueleto de um ADR sem perguntas
list         Lista os ADRs de uma pasta
```

### Conteúdo de um arquivo de comando (RNF-02: modelo único)

Todo arquivo de comando tem só a chamada com a ação (RF-16) — nenhuma regra da skill. Uma função
`command_body(acao, descricao, variavel-argumento)` gera o corpo igual para os três formatos
Markdown-like, e o TOML embute o mesmo texto no campo `prompt`:

```
Use a skill adr-std, ação "<acao>", com estes argumentos: <variavel-argumento>
```

- Claude Code / OpenCode (`.md`): frontmatter `---\ndescription: <descricao-curta>\n---` seguido do
  corpo, com um comentário HTML de marcação antes do corpo:
  `<!-- adr-std: gerado automaticamente; não editar à mão -->`.
- Continue (`.prompt`): mesmo frontmatter Markdown, com `name: adr-std-<acao>` e `description`,
  mesmo comentário de marcação.
- Gemini CLI (`.toml`): `# adr-std: gerado automaticamente; não editar à mão` na primeira linha,
  depois `description = "..."` e `prompt = """...""""`.

O comentário de marcação é o que permite ao instalador saber que o arquivo é dele (equivalente ao
`$MARKER` de pasta já usado por `owned_by_us`, adaptado para arquivo único — RF-14, R-02).

## Mudanças em `bin/adr-std` (e paridade em `bin/adr-std.ps1`)

- `cmd_targets_for <id>` — lê `command_targets.tsv`, devolve pasta/extensão/variável (mesmo padrão
  de `agent_field`).
- `command_owned_by_us <arquivo>` — primeira linha do arquivo contém o comentário de marcação.
- `install_commands` — chamada por `cmd_install` quando `NO_COMMANDS=0` (flag `--no-commands`
  inverte); para cada agente selecionado com entrada em `command_targets.tsv`, gera os 10 arquivos
  em `$HOME/<pasta>/adr-std-<acao>.<ext>`; se o arquivo já existe e não tem o comentário de
  marcação, pula e avisa (RF-14); registra cada arquivo criado no estado
  (`command<TAB>id<TAB>caminho`, mesmo formato de `agent<TAB>id<TAB>pasta`).
- `cmd_uninstall` — ao remover um agente, remove também os arquivos `command` registrados para ele,
  só se ainda tiverem o comentário de marcação (dupla checagem de segurança, mesmo espírito de
  `owned_by_us`).
- `parse_args` — nova flag `--no-commands` (RF-15), variável `NO_COMMANDS`.
- Reaproveita `state_put`/`state_lines`/formato TSV já existentes — nenhuma abstração nova de
  armazenamento (Rule of Three: o formato "linha TSV no arquivo de estado" já tem 2 usos — `agent`
  e as chaves simples; `command` é o 3º, mesma estrutura, sem motivo para mudar de formato).

## Estratégia de testes

- `tests/test_cli.sh`: casos novos `install_commands` (gera os 10 arquivos nos 4 agentes com
  comando, conteúdo com a ação certa), `install_no_commands` (`--no-commands` não cria nenhum),
  `install_commands_preserve_foreign` (arquivo alheio não é sobrescrito, aviso mostrado),
  `uninstall_removes_commands` (remove só os registrados e com marcação).
- `tests/test_cli.ps1` (Pester): espelha os mesmos 4 casos.
- `SKILL.md`: instruções de `create`/`supersede` (conversa guiada, rodadas de perguntas, `--ask`,
  `--quick`) e `new`/`list` (sem perguntas) — cobertas por teste de texto em
  `tests/test_check_adr.py` (mesmo padrão já usado para ADR-0001/0003), não por `unittest` de
  comportamento (RNF-03 já registra que a obediência da conversa não é garantida por programa).

## Modelo de domínio

N/A — comandos são arquivos de texto gerados por template a partir de dados tabulares (TSV), sem
entidade de domínio, Value Object ou Agregado. O "estado" (`agent`/`command` no arquivo de estado)
já é uma estrutura existente desde a v1.0; esta spec só adiciona um novo tipo de linha ao mesmo
formato.

## Decisões de design

- Sem biblioteca de template: `command_body` é concatenação de string simples (KISS); os 4 formatos
  cabem em menos de 10 linhas de bash cada.
- `command_targets.tsv` e `commands.tsv` separados de `agents.tsv`: evita misturar duas dimensões
  diferentes (quais agentes existem vs. quais ações existem) numa tabela só.
