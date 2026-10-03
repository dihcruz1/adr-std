# Requisitos — adr-std v2.0: numeração dos ADRs sem zeros à esquerda

| Campo | Detalhe |
|---|---|
| **Data** | 2026-10-03 |
| **ADR de origem** | [ADR-4](../../architecture/ADR/4-numeracao-dos-adrs-sem-zeros-a-esquerda.md) (Proposto) |
| **Status** | Gate 1 |
| **Depende de** | v1.4 (CLI e verificadores atuais) |

## 1. Contexto

O padrão atual de nome é `NNNN-<slug>.md` com ID `ADR-NNNN` (4 dígitos, zeros à esquerda). O ADR-4
decide trocar o padrão para `<N>-<slug>.md` com ID `ADR-<N>` (inteiro positivo sem zeros), migrar os
ADRs deste repositório e manter a convenção do projeto como prioridade.

Evidências do comportamento atual (exploração de 2026-10-03):

- `skill/scripts/check_adr.py`: `DEFAULT_NAME_PATTERN = ^(\d{4})-...` e `STATUS` com `Substituído por ADR-\d{4}`.
- `skill/scripts/check_roadmap.py`: `ADR_FILENAME = ^\d{4}-.+\.md$` fixo, sem opção `--name-pattern`. Um ADR
  fora do padrão é ignorado em silêncio e escapa da checagem de rastreabilidade bidirecional.
- `skill/scripts/adr_cli.py`: `next_number` começa com largura 4 e usa `zfill`; `cmd_organize` ordena por nome
  (alfabético) e força `zfill(4)` no ID e no nome.
- `bin/adr-std` e `bin/adr-std.ps1`: não codificam a largura do número (só repassam `--name-pattern`). Sem
  mudança de código; os testes `tests/test_cli.sh` e `tests/test_cli.ps1` usam nomes `0001-...`.
- Sem zeros à esquerda a ordem alfabética diverge da numérica (`10-` antes de `2-`).

## 2. Decisões fechadas (ADR-4 e respostas do solicitante em 2026-10-03)

| # | Decisão |
|---|---|
| D-01 | Novo padrão: `<N>-<titulo-em-kebab-case>.md`, `N` inteiro positivo sem zeros à esquerda; ID `ADR-<N>`. |
| D-02 | Os ADRs 0001 a 0003 deste repositório são renomeados para 1 a 3, com ID e links atualizados. |
| D-03 | A convenção do projeto (`.adr-std`, `CONVENTIONS.md`, `AGENTS.md`, `--name-pattern`) prevalece sobre o padrão e vale para todas as ferramentas, inclusive `check_roadmap.py` e `organize`. |
| D-04 | A comparação e a ordenação de números são numéricas, nunca alfabéticas. |
| D-05 | Links para os arquivos renomeados são corrigidos em todo o repositório. Menções textuais históricas `ADR-000N` em specs antigas e no `CHANGELOG.md` não são reescritas; o `CHANGELOG.md` registra a correspondência `ADR-0001..0003` → `ADR-1..3`. |
| D-06 | A regra do padrão de nome tem fonte única: `check_roadmap.py` e `adr_cli.py` importam `DEFAULT_NAME_PATTERN` de `check_adr.py` (já é assim em `adr_cli.py`). |
| D-07 | Mudar o padrão que `check_adr.py` aplica por omissão é uma quebra de compatibilidade para projetos com `0001-`; a versão sobe para **2.0.0** (a confirmar pelo solicitante, ver seção 9). |
| D-08 | Largura do número em convenção com zeros à esquerda: quando existe ao menos um ADR com número de zeros à esquerda, `new` e `organize` preservam a largura do maior número já existente; sem ADR existente, o número não leva zeros. |

## 3. Linguagem Ubíqua

| Termo | Significado |
|---|---|
| **Número do ADR** | Inteiro positivo que identifica o ADR, sem zeros à esquerda por padrão (`1`, `12`) |
| **Padrão de nome** | Expressão regular do nome do arquivo; o grupo 1 captura o número (`--name-pattern`) |
| **Convenção do projeto** | Padrão de nome declarado pelo projeto; prevalece sobre o padrão da skill |
| **ID do ADR** | Texto `ADR-<número>` no campo ID do cabeçalho e nas referências cruzadas |
| **Migração** | Renomeação dos ADRs 0001 a 0003 para 1 a 3 com correção de IDs e links |

## 4. Requisitos funcionais (EARS)

- **RF-01 (ubíquo):** O padrão de nome por omissão de `check_adr.py` DEVE aceitar `<N>-<slug-kebab>.md` com `N` inteiro positivo sem zeros à esquerda e DEVE reprovar o item A1 para `0001-x.md`, `01-x.md` e `0-x.md`.
- **RF-02 (ubíquo):** O item A2 DEVE aprovar quando o número do nome do arquivo e o número do ID forem a mesma sequência de dígitos (`1-x.md` com `ADR-1`) e reprovar quando divergirem (`1-x.md` com `ADR-0001`).
- **RF-03 (ubíquo):** O item A3 DEVE aceitar `Substituído por ADR-<N>` com `N` de qualquer largura (`ADR-4`, `ADR-0004`).
- **RF-04 (evento):** QUANDO o usuário passar `--name-pattern` ao `check_adr.py` ou declarar a convenção do projeto, o sistema DEVE aplicar esse padrão e aprovar `0001-x.md` se o padrão o aceitar.
- **RF-05 (evento):** QUANDO o usuário rodar `check_roadmap.py <pasta>`, o sistema DEVE reconhecer como ADR os arquivos que casam com o padrão por omissão; com `--name-pattern <regex>`, DEVE usar esse padrão. O sistema DEVE falhar com código 2 e mensagem em pt-BR se o `<regex>` for inválido.
- **RF-06 (evento):** QUANDO o usuário rodar `adr-std new "<título>"`, o sistema DEVE criar `<N>-<slug>.md` com `N` igual ao maior número existente + 1 (comparação numérica), sem zeros à esquerda, e `ADR-<N>` no cabeçalho; em pasta sem ADRs, `N` é `1`.
- **RF-07 (estado):** ENQUANTO a pasta tiver ADR cujo número tem zeros à esquerda (D-08), `new` DEVE gerar o número com a largura do maior número existente.
- **RF-08 (indesejado):** SE o nome gerado por `new` não casar com o padrão ativo (por exemplo, `--name-pattern '^(\d{4})-...'` em pasta vazia), ENTÃO o sistema DEVE sair com código 1 sem criar arquivo e mostrar o padrão ativo e como corrigir.
- **RF-09 (evento):** QUANDO o usuário rodar `adr-std organize --dry-run`, o sistema DEVE ordenar os ADRs pelo número (numérico), propor nomes e IDs com a mesma largura do D-08 e não propor mudança quando a numeração já for sequencial e consistente (`1`, `2`, ..., `10`).
- **RF-15 (ubíquo):** `adr-std list` e a descoberta de ADRs DEVEM ordenar pelo número (numérico): `2-a.md` antes de `10-b.md`.
- **RF-10 (ubíquo):** O template, o checklist, o guia, o `SKILL.md`, o `GLOSSARY.md`, o `README.md`, o `CONTRIBUTING.md`, `tests/cenarios.md` e `docs/agents/domain.md` DEVEM descrever o padrão `<N>-<slug>.md` / `ADR-<N>` e a convenção do projeto como prioridade.
- **RF-11 (evento):** QUANDO a migração for executada, o sistema DEVE: (a) mostrar o plano de renomeação e as referências afetadas antes de aplicar; (b) renomear com `git mv`; (c) atualizar ID, links, `ROADMAP.md` e o histórico de cada ADR; (d) manter o texto das decisões inalterado.
- **RF-12 (ubíquo):** Após a migração, `check_adr.py` e `check_roadmap.py` DEVEM passar na pasta de ADRs do repositório sem opção extra, e nenhum link para `0001-`, `0002-` ou `0003-` DEVE restar em `docs/`, `skill/`, `tests/` e na raiz (D-05 trata o texto histórico).
- **RF-13 (ubíquo):** `VERSION` DEVE ser `2.0.0` com entrada no `CHANGELOG.md` que descreva a quebra, a migração e a correspondência dos IDs (D-05, D-07).
- **RF-14 (ubíquo):** Paridade bash/PowerShell: `tests/test_cli.sh` e `tests/test_cli.ps1` DEVEM usar os nomes sem zeros e passar (os wrappers não mudam de código).

## 5. Requisitos não funcionais e de segurança

- **SEG-01:** O padrão de nome vindo de `--name-pattern` é regex do usuário, aplicado só com `re.match` sobre nomes de arquivo listados na pasta; nunca é executado nem interpolado em shell. Regex inválido gera erro controlado, sem traceback.
- **SEG-02:** `new` mantém o modo de escrita exclusivo (`"x"`): nunca sobrescreve ADR existente, inclusive quando dois números colidem por largura.
- **SEG-03:** O slug do nome continua restrito a `[a-z0-9-]` (sem travessia de diretório); o número é inteiro, nunca texto livre.
- **SEG-04:** A migração não apaga nenhum ADR e usa só caminhos explícitos no `git add` (AGENTS.md).
- **RNF-01:** Mensagens em pt-BR; código e testes em inglês.
- **RNF-02:** Compatibilidade bash 3.2 (macOS) e PowerShell mantida; nenhuma mudança de sintaxe nos wrappers.
- **RNF-03:** Nenhuma dependência nova; Python 3 só com biblioteca padrão.

## 6. Cenários (Gherkin)

```gherkin
Cenário: padrão novo aprova nome sem zeros
  Dado o arquivo "1-titulo.md" com ID "ADR-1" e conteúdo válido
  Quando rodo check_adr.py sem opções
  Então A1 e A2 passam

Cenário: padrão novo reprova nome com zeros
  Dado o arquivo "0001-titulo.md" com ID "ADR-0001"
  Quando rodo check_adr.py sem opções
  Então A1 falha

Cenário: convenção do projeto com zeros continua válida
  Dado o arquivo "0001-titulo.md" com ID "ADR-0001"
  Quando rodo check_adr.py com --name-pattern '^(\d{4})-.+\.md$'
  Então A1 e A2 passam

Cenário: ID divergente do nome
  Dado o arquivo "1-titulo.md" com ID "ADR-0001"
  Quando rodo check_adr.py sem opções
  Então A2 falha

Cenário: próximo número é numérico
  Dado uma pasta com "2-a.md" e "10-b.md"
  Quando rodo "adr-std new Terceiro"
  Então é criado "11-terceiro.md" com ID "ADR-11"

Cenário: list ordena pelo número
  Dado uma pasta com "10-b.md" e "2-a.md"
  Quando rodo "adr-std list"
  Então ADR-2 aparece antes de ADR-10

Cenário: pasta vazia
  Dado uma pasta sem ADRs
  Quando rodo "adr-std new Primeiro"
  Então é criado "1-primeiro.md" com ID "ADR-1"

Cenário: convenção com zeros preserva a largura
  Dado uma pasta com "0007-a.md"
  Quando rodo "adr-std new Oitavo --name-pattern '^(\d{4})-[a-z0-9-]+\.md$'"
  Então é criado "0008-oitavo.md" com ID "ADR-0008"

Cenário: padrão ativo incompatível em pasta vazia
  Dado uma pasta sem ADRs
  Quando rodo "adr-std new Primeiro --name-pattern '^(\d{4})-[a-z0-9-]+\.md$'"
  Então código 1, nenhum arquivo é criado e a mensagem cita o padrão ativo

Cenário: organize com 10 ADRs
  Dado uma pasta com "1-a.md", ..., "10-j.md" consistentes
  Quando rodo "adr-std organize --dry-run"
  Então a saída informa que a numeração já é consistente

Cenário: organize detecta lacuna
  Dado uma pasta com "1-a.md" e "5-b.md"
  Quando rodo "adr-std organize --dry-run"
  Então o plano propõe "5-b.md -> 2-b.md"

Cenário: check_roadmap respeita o padrão
  Dado um ROADMAP e "1-a.md" sem linha na tabela
  Quando rodo check_roadmap.py sem opções
  Então a saída acusa "1-a.md não tem linha na tabela do ROADMAP"

Cenário: check_roadmap com regex inválido
  Quando rodo check_roadmap.py <pasta> --name-pattern '('
  Então código 2 e mensagem em pt-BR, sem traceback

Cenário: migração sem link quebrado
  Dado os ADRs 1 a 3 já renomeados
  Quando busco por "0001-", "0002-" e "0003-" em docs/, skill/, tests/ e na raiz
  Então não há link para os nomes antigos
```

## 7. Matriz de não-regressão

Comportamentos atuais que devem permanecer, com o teste que os protege:

| # | Comportamento preservado | Teste |
|---|---|---|
| NR-01 | `check_adr.py` aprova a fixture válida e reprova pendências/placeholder | `tests/test_check_adr.py` |
| NR-02 | `--name-pattern` custom aprova nomes fora do padrão | `test_check_adr.py` (caso de pasta custom) |
| NR-03 | `check_roadmap.py` aponta Status inválido, spec ausente e divergência de Status | `tests/test_check_roadmap.py` |
| NR-04 | `link` cria relação recíproca; `list` mostra ID, título, status e data | `test_adr_cli.py`, `test_cli.sh` |
| NR-05 | `new` não sobrescreve ADR existente | `test_adr_cli.py` (modo exclusivo) |
| NR-06 | Resolução de pasta (`--path` > `.adr-std` > config global > padrão) | `test_adr_cli.py`, `test_cli.sh` |
| NR-07 | `config agent` e `config path` | `test_cli.sh`, `test_cli.ps1` |
| NR-08 | Wrappers repassam `--name-pattern` sem alterar | `test_cli.sh`, `test_cli.ps1` |

## 8. Riscos

| # | Risco | Mitigação |
|---|---|---|
| R-01 | Projetos com `0001-` passam a reprovar A1 sem avisar | D-07 (versão major), CHANGELOG com a migração e `--name-pattern`/convenção como saída |
| R-02 | Renomeação deixa link quebrado | RF-11 (plano antes), RF-12 (busca final), `check_roadmap.py` verde |
| R-03 | `10-` antes de `2-` em listagens fora da CLI | D-04; limitação registrada no ADR-4 |
| R-04 | `new` gerar número fora do padrão ativo | RF-08 |
| R-05 | `check_roadmap.py` ignorar ADR fora do padrão em silêncio | RF-05 (padrão compartilhado e opção explícita) |
| R-06 | Regex de usuário inválida derrubar a CLI com traceback | RF-05, SEG-01 |

## 9. Itens para confirmação

- D-07: subir para **2.0.0** (quebra do padrão por omissão). Alternativa: 1.5.0 com aviso no CHANGELOG. Decisão de produto do solicitante.

## 10. Fora do escopo

- Aprovar o ADR-4 (cabe ao decisor).
- Reescrever menções textuais históricas `ADR-000N` em specs antigas e no `CHANGELOG.md` (D-05).
- Renomear os diretórios de specs `2026-10-01-adr-000N-...`.
- Ordenação visual fora da CLI (`ls`, editor).
- Migração de repositórios de terceiros.
- `organize` real: segue em `--dry-run`, como desde a v1.2.
