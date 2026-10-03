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
ADRs deste repositório e manter a convenção do projeto como prioridade. O solicitante acrescentou que o
`adr-std update` deve executar um script Python que adequa a documentação, os links e as referências dos
projetos que já usam a skill (regras 3 a 5 do ADR-4).

Evidências do comportamento atual (exploração de 2026-10-03):

- `skill/scripts/check_adr.py`: `DEFAULT_NAME_PATTERN = ^(\d{4})-...` e `STATUS` com `Substituído por ADR-\d{4}`.
- `skill/scripts/check_roadmap.py`: `ADR_FILENAME = ^\d{4}-.+\.md$` fixo, sem opção `--name-pattern`. Um ADR
  fora do padrão é ignorado em silêncio e escapa da checagem de rastreabilidade bidirecional.
- `skill/scripts/adr_cli.py`: `next_number` começa com largura 4 e usa `zfill`; `cmd_organize` ordena por nome
  (alfabético) e força `zfill(4)` no ID e no nome.
- `bin/adr-std` e `bin/adr-std.ps1`: não codificam a largura do número (só repassam `--name-pattern`). Sem
  mudança de código; os testes `tests/test_cli.sh` e `tests/test_cli.ps1` usam nomes `0001-...`.
- Sem zeros à esquerda a ordem alfabética diverge da numérica (`10-` antes de `2-`).
- `cmd_update` (bash) e `Invoke-Update` (PowerShell) só chamam o instalador (`ADR_STD_REMOTE=1 bash "$DATA_DIR/install.sh"`), que baixa a release e copia `skill/` e `bin/`. O wrapper que roda o `update` é o já instalado: numa atualização de versão anterior à 2.0, é o wrapper antigo, que não conhece a migração.
- Os scripts Python são chamados por `run_python_script` (bash) e função equivalente (PowerShell), que localizam `skill/scripts/` instalada.

## 2. Decisões fechadas (ADR-4 e respostas do solicitante em 2026-10-03)

| # | Decisão |
|---|---|
| D-01 | Novo padrão: `<N>-<titulo-em-kebab-case>.md`, `N` inteiro positivo sem zeros à esquerda; ID `ADR-<N>`. |
| D-02 | Os ADRs 0001 a 0003 deste repositório são migrados para 1 a 3 pelo próprio script de migração (D-10), com plano mostrado antes. |
| D-03 | A convenção do projeto (`.adr-std`, `CONVENTIONS.md`, `AGENTS.md`, `--name-pattern`) prevalece sobre o padrão e vale para todas as ferramentas, inclusive `check_roadmap.py` e `organize`. |
| D-04 | A comparação e a ordenação de números são numéricas, nunca alfabéticas. |
| D-05 | O script reescreve links e menções `ADR-<N>` em todos os `*.md` do projeto, inclusive specs antigas e `CHANGELOG.md`; o que deve ficar intacto (exemplos do formato antigo) é protegido com `--exclude`. O `CHANGELOG.md` da v2.0 registra a correspondência `ADR-0001..0003` → `ADR-1..3` e é escrito depois da migração. |
| D-06 | A regra do padrão de nome tem fonte única: `check_roadmap.py` e `adr_cli.py` importam `DEFAULT_NAME_PATTERN` de `check_adr.py` (já é assim em `adr_cli.py`). |
| D-07 | Mudar o padrão que `check_adr.py` aplica por omissão é uma quebra de compatibilidade para projetos com `0001-`; a versão sobe para **2.0.0** (a confirmar pelo solicitante, ver seção 9). |
| D-08 | Largura do número em convenção com zeros à esquerda: quando existe ao menos um ADR com número de zeros à esquerda, `new` e `organize` preservam a largura do maior número já existente; sem ADR existente, o número não leva zeros. |

| D-09 | O projeto pode declarar que mantém zeros à esquerda com o campo `numbering: padded` no `.adr-std`; o script não migra esse projeto. É a única nova chave de configuração. |
| D-10 | Script de migração `skill/scripts/migrate_numbering.py`, comando `adr-std migrate`: por omissão só mostra o plano (sem alterar arquivo); `--apply` aplica. Mantém o número (`0005-x.md` → `5-x.md`), não renumera nem fecha lacunas. |
| D-11 | O `adr-std update` executa a migração no projeto atual (diretório de trabalho) depois de atualizar a skill: mostra o plano; em terminal interativo pergunta se aplica; sem terminal só imprime o plano e `adr-std migrate --apply`. `update --no-migrate` e `update --dry-run` não migram. |
| D-12 | Limitação aceita: o primeiro `update` a partir de uma versão anterior à 2.0 é conduzido pelo wrapper e pelo instalador antigos e não executa a migração; ela roda no `update` seguinte ou com `adr-std migrate`. Registrada no `CHANGELOG.md` e no `README.md`. |

## 3. Linguagem Ubíqua

| Termo | Significado |
|---|---|
| **Número do ADR** | Inteiro positivo que identifica o ADR, sem zeros à esquerda por padrão (`1`, `12`) |
| **Padrão de nome** | Expressão regular do nome do arquivo; o grupo 1 captura o número (`--name-pattern`) |
| **Convenção do projeto** | Padrão de nome declarado pelo projeto; prevalece sobre o padrão da skill |
| **ID do ADR** | Texto `ADR-<número>` no campo ID do cabeçalho e nas referências cruzadas |
| **Migração** | Renomeação dos ADRs com zeros à esquerda para o número puro (`0001-x.md` → `1-x.md`) com correção de ID, links e referências em todo o `*.md` do projeto |
| **Plano de migração** | Lista de renomeações e de arquivos com referências a corrigir, mostrada antes de aplicar |
| **Raiz do projeto** | Raiz do repositório git (ou o diretório de trabalho, fora de git) onde o script procura `*.md` |

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
- **RF-11 (evento):** QUANDO a migração dos ADRs 1 a 3 deste repositório for executada, o sistema DEVE usar o script de migração (D-10), mostrar o plano antes de aplicar, atualizar o histórico e o campo "Modificado em" de cada ADR migrado e manter o texto das decisões inalterado.
- **RF-12 (ubíquo):** Após a migração, `check_adr.py` e `check_roadmap.py` DEVEM passar na pasta de ADRs do repositório sem opção extra, e nenhum link para `0001-`, `0002-` ou `0003-` DEVE restar em `docs/`, `skill/`, `tests/` e na raiz, e as menções `ADR-000N` DEVEM ter sido corrigidas, exceto nos caminhos protegidos por `--exclude` (D-05).
- **RF-13 (ubíquo):** `VERSION` DEVE ser `2.0.0` com entrada no `CHANGELOG.md` que descreva a quebra, a migração e a correspondência dos IDs (D-05, D-07).
- **RF-16 (evento):** QUANDO o usuário rodar `adr-std migrate` sem `--apply`, o sistema DEVE imprimir o plano (renomeações `0001-x.md -> 1-x.md` e, por arquivo `*.md`, a quantidade de links e referências a corrigir) e NÃO DEVE alterar nenhum arquivo; sem nada a migrar, DEVE informar que a numeração já está adequada e sair com código 0.
- **RF-17 (evento):** QUANDO o usuário rodar `adr-std migrate --apply`, o sistema DEVE: (a) renomear cada ADR de número com zeros à esquerda para o número puro, com `git mv` em repositório git e `rename` fora dele; (b) trocar `ADR-000N` por `ADR-N` no cabeçalho (título e ID) do ADR e nas referências; (c) corrigir os alvos de links Markdown e as menções ao nome antigo do arquivo; (d) imprimir o resumo do que mudou.
- **RF-18 (ubíquo):** O script DEVE reescrever apenas os números dos ADRs migrados (não outros `ADR-<N>`), apenas em `*.md` dentro da raiz do projeto, ignorando `.git`, `node_modules`, `.venv`, `vendor` e os caminhos de `--exclude`; DEVE preservar o restante do texto, a codificação UTF-8 e o fim de linha de cada arquivo.
- **RF-19 (indesejado):** SE o nome de destino já existir, ou dois ADRs tiverem o mesmo número, ENTÃO o script DEVE recusar com código 1, listar o conflito e não alterar nada. SE, em repositório git, algum arquivo a renomear ou reescrever tiver alterações não commitadas, ENTÃO o script DEVE recusar `--apply` com código 1 e listar os arquivos.
- **RF-20 (ubíquo):** O script DEVE ser idempotente: depois de aplicado, nova execução não propõe mudança. Em caso de erro durante a aplicação, DEVE parar, informar o que já foi feito e sair com código 1.
- **RF-21 (evento):** QUANDO o usuário rodar `adr-std update` (sem `--dry-run` e sem `--no-migrate`) e o instalador terminar com sucesso, o sistema DEVE executar `adr-std migrate` (plano) no diretório de trabalho; havendo plano, em terminal interativo DEVE perguntar `Aplicar a migração? [s/N]` e aplicar só com `s`; sem terminal DEVE imprimir o plano e o comando `adr-std migrate --apply`. Falha ou ausência de Python 3 NÃO DEVE reverter a atualização da skill nem alterar o código de saída do `update`; DEVE apenas avisar.
- **RF-22 (estado):** ENQUANTO o `.adr-std` do projeto contiver `numbering: padded`, `migrate` e o gancho do `update` DEVEM informar que o projeto mantém zeros à esquerda e não alterar nada.
- **RF-23 (ubíquo):** `adr-std help` DEVE listar `migrate` e `update --no-migrate`; paridade bash/PowerShell para `migrate` e para o gancho do `update`, verificada em `tests/test_cli.sh` e `tests/test_cli.ps1`.
- **RF-14 (ubíquo):** Paridade bash/PowerShell: `tests/test_cli.sh` e `tests/test_cli.ps1` DEVEM usar os nomes sem zeros e passar (os wrappers não mudam de código).

## 5. Requisitos não funcionais e de segurança

- **SEG-01:** O padrão de nome vindo de `--name-pattern` é regex do usuário, aplicado só com `re.match` sobre nomes de arquivo listados na pasta; nunca é executado nem interpolado em shell. Regex inválido gera erro controlado, sem traceback.
- **SEG-02:** `new` mantém o modo de escrita exclusivo (`"x"`): nunca sobrescreve ADR existente, inclusive quando dois números colidem por largura.
- **SEG-03:** O slug do nome continua restrito a `[a-z0-9-]` (sem travessia de diretório); o número é inteiro, nunca texto livre.
- **SEG-04:** A migração não apaga nenhum ADR e usa só caminhos explícitos no `git add` (AGENTS.md).
- **SEG-05:** O script só lê e escreve dentro da raiz do projeto: caminhos são resolvidos e conferidos contra a raiz; não segue links simbólicos para fora dela; `--exclude` é glob casado com `fnmatch`, nunca executado.
- **SEG-06:** `--apply` nunca roda sem plano calculado antes na mesma execução; o `update` nunca aplica sem confirmação interativa (sem `--yes`, que não existe nesta versão).
- **SEG-07:** O script não faz rede, não executa comandos além de `git mv` e `git status` com argumentos em lista (sem shell), não lê nem grava credenciais.
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

Cenário: migrate mostra o plano sem alterar
  Dado um projeto com "docs/adr/0001-a.md" e "docs/adr/0002-b.md" e um README com "[ADR-0001](docs/adr/0001-a.md)"
  Quando rodo "adr-std migrate"
  Então a saída lista "0001-a.md -> 1-a.md" e "0002-b.md -> 2-b.md" e a contagem de referências no README
  E nenhum arquivo foi alterado

Cenário: migrate aplica
  Dado o mesmo projeto, em git e sem alterações pendentes
  Quando rodo "adr-std migrate --apply"
  Então os arquivos passam a "1-a.md" e "2-b.md" via git mv
  E o ID, o título, os links e as menções "ADR-0001" viram "ADR-1" nos *.md do projeto
  E uma nova execução informa que a numeração já está adequada

Cenário: migrate só troca os números migrados
  Dado um ADR "0001-a.md" e um texto "ADR-0042 (de outro projeto)" sem arquivo correspondente
  Quando rodo "adr-std migrate --apply"
  Então "ADR-0001" vira "ADR-1" e "ADR-0042" permanece

Cenário: migrate recusa colisão
  Dado "0001-a.md" e "1-a.md" na mesma pasta
  Quando rodo "adr-std migrate --apply"
  Então código 1, o conflito é listado e nada é alterado

Cenário: migrate recusa árvore suja
  Dado um arquivo a reescrever com alteração não commitada
  Quando rodo "adr-std migrate --apply"
  Então código 1 e o arquivo é listado

Cenário: projeto que mantém zeros
  Dado o ".adr-std" com "numbering: padded"
  Quando rodo "adr-std migrate"
  Então a saída informa que o projeto mantém zeros e nada é alterado

Cenário: exclude protege exemplos
  Dado "docs/exemplo.md" com "ADR-0001" como exemplo do formato antigo
  Quando rodo "adr-std migrate --apply --exclude 'docs/exemplo.md'"
  Então "docs/exemplo.md" permanece igual

Cenário: update executa a migração em modo plano
  Dado uma atualização bem-sucedida da skill, sem terminal, em um projeto com "0001-a.md"
  Quando rodo "adr-std update"
  Então a saída traz o plano e "adr-std migrate --apply" e nenhum arquivo do projeto muda

Cenário: update com confirmação interativa
  Dado uma atualização bem-sucedida, em terminal, em um projeto com "0001-a.md"
  Quando respondo "s" a "Aplicar a migração? [s/N]"
  Então a migração é aplicada

Cenário: update sem migração
  Quando rodo "adr-std update --no-migrate"
  Então a skill é atualizada e o plano não é calculado

Cenário: migração sem Python
  Dado uma atualização bem-sucedida sem Python 3 disponível
  Quando rodo "adr-std update"
  Então a skill continua atualizada, há um aviso e o código de saída do update não muda

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
| R-07 | O `update` renomear arquivos do projeto sem o usuário perceber | D-10, D-11, SEG-06: plano sempre visível, aplicação só com `--apply` ou confirmação interativa |
| R-08 | Reescrita de texto atingir exemplos do formato antigo ou `ADR-<N>` de outro contexto | RF-18 (só números migrados), `--exclude`, plano com contagem por arquivo |
| R-09 | Perda de alterações do usuário ou impossibilidade de desfazer | RF-19 (recusa árvore suja), `git mv` (desfaz com git); fora de git o plano avisa que não há desfazer |
| R-10 | Primeiro `update` a partir da v1.4 não migrar | D-12 documentado; `adr-std migrate` disponível; teste de texto no README/CHANGELOG |
| R-11 | Projeto que quer manter zeros ser incomodado a cada `update` | D-09/RF-22 e `--no-migrate` |

## 9. Itens para confirmação

- D-07: subir para **2.0.0** (quebra do padrão por omissão). Alternativa: 1.5.0 com aviso no CHANGELOG. Decisão de produto do solicitante.
- D-11: o `update` executa a migração em modo plano e só aplica com confirmação interativa. Escolha de segurança, porque renomear arquivos do projeto exige plano e autorização (SKILL.md). Se o solicitante quiser aplicação automática sem confirmação, é uma mudança de SEG-06 e R-07.
- D-09: nova chave `numbering: padded` no `.adr-std` para projetos que mantêm zeros.

## 10. Fora do escopo

- Aprovar o ADR-4 (cabe ao decisor).
- Migrar de sem zeros para com zeros, renumerar para fechar lacunas ou tratar arquivos que não sejam `*.md` (D-10).
- Opção `--yes` para aplicar a migração sem confirmação no `update` (SEG-06).
- Fazer o primeiro `update` a partir da v1.4 executar a migração (D-12).
- Renomear os diretórios de specs `2026-10-01-adr-000N-...`.
- Ordenação visual fora da CLI (`ls`, editor).
- Migração de repositórios de terceiros.
- `organize` real: segue em `--dry-run`, como desde a v1.2.
