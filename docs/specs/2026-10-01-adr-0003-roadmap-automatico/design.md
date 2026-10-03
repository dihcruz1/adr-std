# Design — Atualização automática e silenciosa do ROADMAP (ADR-3)

| Campo | Detalhe |
|---|---|
| **Requisitos** | [requirements.md](requirements.md) |
| **Status** | Gate 2 |

## Contrato

Reaproveita `skill/scripts/check_roadmap.py` (mesmo script do
[design do ADR-2](../2026-10-01-adr-0002-roadmap-rastreabilidade/design.md)), acrescentando a
verificação de heurística de Status (RF-04):

- Para cada linha cuja coluna "Spec Técnica" seja um link Markdown (não `*Pendente*`), resolve a
  pasta da Spec relativa à posição do `ROADMAP.md`.
- Calcula o Status esperado:
  - sem `requirements.md` → não compara (ADR ainda sem Spec, fora do alcance desta verificação).
  - `requirements.md` sem `design.md` → `Só requisitos`.
  - `design.md` sem `tasks.md` → `Em andamento`.
  - `tasks.md` existe: todas as linhas `- [x]` (nenhuma `- [ ]` de tarefa de primeiro nível) →
    `Concluída`; caso contrário → `Em andamento`.
- Compara com o Status da célula; reporta `[FALHA]` com o valor esperado quando divergir.

Teste de texto sobre `SKILL.md` para RF-01 a RF-03 (mesmo molde da tarefa 1.1 do ADR-1): procura
as frases-chave ("apenas a linha", os 4 gatilhos de Status, a frase de aviso final ao usuário) na
seção "### ROADMAP.md (atualização automática)".

## Estratégia de testes

`tests/test_check_roadmap.py` (mesmo arquivo da spec do ADR-2, já que é o mesmo script) ganha
os casos de heurística de Status, com pastas de Spec sintéticas em diretório temporário.
`tests/test_check_adr.py` ganha o teste de texto sobre `SKILL.md` para RF-01/02/03 (mesmo padrão
da tarefa 1.1 do ADR-1 — reaproveita o arquivo de testes já usado para esse tipo de verificação,
evitando um terceiro lugar para "testes de texto sobre SKILL.md").

## Modelo de domínio

N/A — mesma natureza do ADR-2 (verificação de texto estruturado), sem entidade de domínio nova.

## Decisões de design

- A regra "`- [ ]` de tarefa de primeiro nível" ignora sub-itens de evidência (linhas indentadas
  começando com espaço antes do `-`), para não confundir bullets de evidência dentro de uma tarefa
  concluída com tarefas pendentes — mesmo formato de `tasks.md` já usado nas specs deste repositório
  (ver `docs/specs/2026-09-30-adr-std-v1-0/tasks.md`, onde toda evidência vem indentada).
