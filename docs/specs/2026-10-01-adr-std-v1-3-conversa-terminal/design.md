# Design — adr-std v1.3: comandos de conversa no terminal

| Campo | Detalhe |
|---|---|
| **Requisitos** | [requirements.md](requirements.md) |
| **Status** | Gate 2 |

## Contrato

Dado novo, `agent_launch.tsv` (raiz; mesmo padrão TSV de `agents.tsv`):

```
# id          binario    flag-do-pedido ("-" = pedido posicional)
claude-code   claude     -
codex         codex      -
gemini-cli    gemini     -i
opencode      opencode   --prompt
```

Estado (`~/.config/adr-std/state`, formato chave<TAB>valor já existente): `default_agent`, `last_agent`. Novo helper `state_del <chave>`.

Funções (bash; PowerShell espelha com verbos aprovados):

- `launch_rows`, `is_launchable id`, `launch_field id n`.
- `eligible_agents`: ids de `state_agents` ∩ `launch_rows`.
- `parse_converse_args action args...` → `AGENT_ARG`, `ASK`, `QUICK`, `TEXT`. Regra D-02 em `leading_agent_term`: exato + seguido de texto → agente; parecido (`similar_agent`: sem espaço, ≥ 4 letras, prefixo/substring de um id) + seguido de texto → erro com sugestão.
- `pick_agent` → prioridade D-01 (explícito → `default_agent` com aviso → menu → erro 3). Menu lê de `ADR_STD_TTY`/`/dev/tty`, como `choose_agents`.
- `launch_agent id action args` → monta `request="Use a skill adr-std, ação \"<ação>\", com estes argumentos: <args>"` e chama `"$bin" [flag] "$request"` (um argumento, SEG-01); registra `last_agent`; propaga o código de saída.
- `cmd_converse action args...` (create/supersede/review/audit/ask) e `cmd_config args...`.

Códigos de saída: 2 uso; 3 sem agente/terminal; 5 binário ausente.

## Modelo de domínio

N/A justificado: orquestração de CLI sobre dados TSV; sem invariantes de domínio nem entidades. Sem Repositório/Agregado.

## Segurança

SEG-01: argumento único, sem `eval`/`sh -c`. SEG-03/04: binário e id vêm só da tabela. Teste de injeção com descrição `x; touch PWNED $(touch PWNED2)` e verificação de que os arquivos não existem e de que o binário falso recebeu a string literal. SEG-02: nenhuma leitura de credencial.

## Estratégia de testes

`tests/test_cli.sh` com `HOME` temporário, binários falsos (`claude`, `codex`...) num diretório do `PATH` que gravam `"$@"` em arquivo, `ADR_STD_TTY` apontando para arquivo de respostas. Casos: `launch_table`, `converse_explicit_agent`, `converse_description_with_agent_name`, `converse_similar_agent`, `converse_default_agent`, `converse_menu_last_used`, `converse_no_tty`, `converse_no_eligible`, `converse_injection`, `converse_ask_quick`, `converse_missing_binary`, `config_agent`, `help_lists_converse`, `installer_copies_launch_table`. Pester: mesmos nomes.
E2E: instalar a skill num HOME temporário, `config agent codex`, `adr-std create "x"` com `codex` falso e conferir o pedido.
