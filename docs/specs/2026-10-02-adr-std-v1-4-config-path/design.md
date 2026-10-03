# Design — adr-std v1.4: `config path`

| Campo | Detalhe |
|---|---|
| **Requisitos** | [requirements.md](requirements.md) |
| **ADR de origem** | [ADR-1](../../architecture/ADR/1-caminho-padrao-dos-adrs-e-personalizacao.md) |
| **Status** | Gate 2 |

## 1. Visão geral

`config path` é um segundo subcomando do `config` já existente (v1.3). Reaproveita o arquivo de
config global, o mecanismo de reescrita linha-a-linha (`state_put`/`state_del` no bash,
`Set-State`/`Remove-State` no PowerShell) e o campo `path` que `resolve_folder` (v1.2) já lê. Nenhuma
estrutura nova de dados, nenhum arquivo novo.

A única sutileza: hoje `read_path_field` (em `adr_cli.py`) procura a linha `path` com o padrão
`^path\s*[:=]\s*(.+?)\s*$` — aceita `path: x` ou `path = x`. O estado da skill grava linhas no formato
TSV (`chave<TAB>valor`), lido com `cut -f`/`-split "\`t"`. Para o `path` gravado por `config path`
ser lido por `resolve_folder` **sem mudar `read_path_field`**, a gravação usa o separador que o regex
aceita: `path: <valor>` (dois pontos e espaço). O estado da skill (`default_agent`, `agent`, etc.)
continua em TSV no mesmo arquivo; as duas convenções convivem porque cada leitor filtra pela sua chave.

> Decisão de design registrada: manter `read_path_field` intacto (já testado na v1.2) e gravar `path`
> no formato que ele já aceita (`path: valor`). Assim a leitura (v1.2) e a nova escrita (v1.4) ficam
> acopladas por um contrato de formato explícito, verificado por um teste de ida-e-volta
> (grava com o CLI, lê com `list`).

## 2. Contrato do comando

```
adr-std config path                 # mostra o path atual ou "nenhuma pasta de ADRs definida"
adr-std config path <pasta>         # grava path: <pasta> na config global
adr-std config path --unset         # remove a linha path
adr-std config <outro>              # código 2, uso: adr-std config <agent|path> ...
```

Códigos de saída: 0 em sucesso (mostrar, gravar, remover, inclusive `--unset` sem nada a remover);
2 em opção desconhecida (`-x` que não seja `--unset`) ou subcomando de `config` inválido.

## 3. Bash (`bin/adr-std`)

- Novas funções de estado para o campo em formato `path:` (o estado existente é TSV; o `path` precisa
  do formato que `read_path_field` lê):
  - `config_path_get`: lê a config global e devolve o valor da primeira linha `path:`/`path=` (mesmo
    regex do Python, reimplementado em `sed`/`grep -P`), ou vazio.
  - `config_path_set <valor>`: remove qualquer linha `path:` anterior e acrescenta `path: <valor>`,
    preservando todas as outras linhas (TSV do estado inclusive). Reusa o padrão de `state_put`
    (reescrever via arquivo temporário), mas filtrando por prefixo `path` em vez de chave TSV.
  - `config_path_unset`: remove as linhas `path:`; preserva o resto.
- `cmd_config` passa a aceitar `path`:
  - `agent` → ramo atual (inalterado).
  - `path` → novo ramo com `""` (mostra), `--unset` (remove), `-*` (código 2), `*` (grava).
  - outro → `die 2 "uso: adr-std config <agent|path> ..."` (mensagem atualizada para citar os dois).

## 4. PowerShell (`bin/adr-std.ps1`)

Espelha o bash: `Get-ConfigPath`, `Set-ConfigPath`, `Remove-ConfigPath` operando sobre `$StateFile`
(linhas `path: ...`, preservando as linhas TSV do estado), e `Invoke-Config` ganha o ramo `path` com
a mesma árvore de decisão. Mensagem de uso idêntica.

## 5. Python (`skill/scripts/adr_cli.py`)

**Sem mudança de código.** `read_path_field` e `resolve_folder` já leem `path:`/`path=` da config
global; esta versão só passa a gravar lá pelo CLI. O teste de ida-e-volta (seção 6) confirma o contrato.

## 6. Estratégia de testes

- `tests/test_cli.sh` (bash), caso novo `config_path`:
  - mostrar sem valor → "nenhuma pasta"; gravar `docs/decisoes` → mostra `docs/decisoes`; a config tem
    exatamente uma linha `path`; `--unset` → volta a "nenhuma pasta"; opção `-x` → código 2; subcomando
    `config caminho` → código 2 com uso citando `agent` e `path`.
  - preserva o agente: `config agent codex` depois `config path docs/x` → o estado mantém
    `default_agent\tcodex` **e** a linha `path: docs/x`.
  - ida-e-volta com a leitura real: `config path <pasta temporária com um ADR>` + `list` sem `--path`
    nem `.adr-std` no `cwd` → `list` acha o ADR naquela pasta (prova RF-05 e o contrato de formato da seção 1).
- `tests/test_cli.ps1` (Pester): os mesmos casos mecânicos (mostrar/gravar/unset/preserva/subcomando
  inválido). O caso de ida-e-volta com `list` depende de Python; roda igual ao bash onde Python existir.
- Regressão: `test_config_agent` (v1.3) continua verde — `config agent` não muda.

## 7. Modelo de domínio (DDD)

**N/A justificado.** Não há invariante de domínio novo: `config path` é E/S sobre um arquivo de
configuração chave-valor já existente, sem entidade rica nem agregado. A regra de precedência
(ADR-1) já vive em `resolve_folder` (função pura, testável) e não muda. Aplicar DDD tático aqui
violaria KISS/YAGNI (AGENTS.md: DDD só com invariante de domínio).

## 8. Impacto e reúso

- Reúso: arquivo de config, mecanismo de reescrita linha-a-linha, `read_path_field`/`resolve_folder`,
  estrutura de `cmd_config`/`Invoke-Config`. É a 2ª ocorrência de "subcomando de config que lê/grava/
  remove uma chave" (a 1ª é `config agent`); ainda **não** é Rule of Three, então não se extrai uma
  abstração genérica de config agora — duas funções irmãs explícitas (`agent`, `path`) são mais claras.
- Sem mudança em instaladores/pacote: nenhum arquivo novo distribuído.
- Documentação: README (nota sobre `config path` e a hierarquia), SKILL.md (hierarquia já descrita;
  acrescenta que a CLI grava o nível 4 com `config path`), CHANGELOG, VERSION, os dois ROADMAPs.
