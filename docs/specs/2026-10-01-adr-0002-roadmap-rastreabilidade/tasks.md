# Tarefas — ROADMAP.md como documento central de rastreabilidade (ADR-0002)

| Campo | Detalhe |
|---|---|
| **Requisitos / Design** | [requirements.md](requirements.md) · [design.md](design.md) |
| **Regra de execução** | Uma tarefa por vez; marcar `[x]` só com evidência de teste. |

## 1. Script de verificação

- [x] 1.1 — Criar `skill/scripts/check_roadmap.py` com verificação de estrutura (cabeçalho,
  presença de cada ADR na tabela, link de volta em "## Referências", valores válidos de Status);
  cobre RF-01 a RF-04.
  - **RED:** `tests/test_check_roadmap.py` com casos: tabela com cabeçalho certo → OK; cabeçalho
    errado → falha; ADR sem linha na tabela → falha nomeando o arquivo; ADR sem link para
    `ROADMAP.md` em "Referências" → falha; Status fora dos 4 valores → falha. Rodado antes do
    script existir: `ModuleNotFoundError`/arquivo inexistente.
  - **GREEN:** script escrito conforme o design.
  - **Validação:** `python3 -m unittest discover -s tests -p 'test_check_roadmap.py' -v`
  - **Evidência:** RED real: `ModuleNotFoundError`/erro de execução (script ainda não existia),
    retorno 2 em vez de 1 nos 9 casos. GREEN: `skill/scripts/check_roadmap.py` criado; 9 de 9
    testes passaram (cabeçalho ok, cabeçalho errado, ADR sem linha, ADR sem link de volta, Status
    inválido — estes 5 cobrem RF-01 a RF-04; os outros 4 casos do arquivo cobrem a heurística de
    Status do ADR-0003, ver spec irmã).

## 2. Verificação no ROADMAP real do projeto

- [x] 2.1 — Rodar o script contra `docs/architecture/ADR/` do próprio repositório e corrigir
  divergências encontradas; depende de 1.1.
  - **Validação:** `python3 skill/scripts/check_roadmap.py docs/architecture/ADR`
  - **Evidência:** `[OK] ROADMAP consistente` — os 3 ADRs têm linha na tabela e link de volta em
    "## Referências"; nenhum Status inválido. Nenhuma divergência encontrada: nada a corrigir.

## Auditoria cruzada

| Requisito | Tarefa |
|---|---|
| RF-01 a RF-04 | 1.1, 2.1 |

Sem requisito órfão nem tarefa sem requisito.
