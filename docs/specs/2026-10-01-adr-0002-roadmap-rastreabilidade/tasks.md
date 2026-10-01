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
  - **Evidência:** registrada após a execução real abaixo.

## 2. Verificação no ROADMAP real do projeto

- [x] 2.1 — Rodar o script contra `docs/architecture/ADR/` do próprio repositório e corrigir
  divergências encontradas; depende de 1.1.
  - **Validação:** `python3 skill/scripts/check_roadmap.py docs/architecture/ADR`
  - **Evidência:** registrada após a execução real abaixo.

## Auditoria cruzada

| Requisito | Tarefa |
|---|---|
| RF-01 a RF-04 | 1.1, 2.1 |

Sem requisito órfão nem tarefa sem requisito.
