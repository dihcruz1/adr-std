# Requisitos — ROADMAP.md como documento central de rastreabilidade (ADR-2)

| Campo | Detalhe |
|---|---|
| **Data** | 2026-10-01 |
| **ADR de origem** | [ADR-2](../../architecture/ADR/2-roadmap-rastreabilidade-etapas-specs.md) |
| **Status** | Gate 1 |

## Contexto

O ADR-2 decide que `docs/architecture/ADR/ROADMAP.md` é o documento central de rastreabilidade
entre ADRs e Specs, com uma tabela de colunas fixas e 4 valores de Status possíveis. O `ROADMAP.md`
já existe (criado junto com os três ADRs). Esta spec cobre a parte mecanicamente verificável: que
a estrutura é respeitada e que a rastreabilidade bidirecional (ADR → ROADMAP, ROADMAP → ADR/Spec)
não quebra silenciosamente.

## Requisitos (EARS)

- **RF-01** — O `ROADMAP.md` DEVE conter a tabela com as colunas: Etapa, Assunto, ADR Base, Spec
  Técnica, Status, Evidência / Validação.
- **RF-02** — Cada ADR em `docs/architecture/ADR/NNNN-*.md` DEVE ter uma linha correspondente na
  tabela do ROADMAP (coluna "ADR Base" com link para o arquivo do ADR).
- **RF-03** — Cada ADR DEVE conter, em sua seção "## Referências", um link relativo para
  `./ROADMAP.md`.
- **RF-04** — O valor da coluna Status DEVE ser um dos 4 valores definidos: `Não iniciada`,
  `Só requisitos`, `Em andamento`, `Concluída`.

A verificação de que o Status reflete corretamente o estado real dos arquivos da Spec (heurística
de inferência) é requisito do ADR-3 — ver
[spec do ADR-3](../2026-10-01-adr-0003-roadmap-automatico/requirements.md) — para não duplicar
a mesma regra em duas specs (regra de segurança/consistência tem fonte única desde a 2ª ocorrência).

## Critério de aceitação (Gherkin)

```gherkin
Cenário: todo ADR tem linha no ROADMAP e referência de volta
  Dado os arquivos docs/architecture/ADR/0001-*.md, 0002-*.md e 0003-*.md
  Quando rodo a verificação de rastreabilidade do ROADMAP
  Então cada um aparece na coluna "ADR Base" da tabela
  E cada um tem link para "./ROADMAP.md" em "## Referências"
```

## Fora de escopo

- Geração automática do ROADMAP a partir do zero (já registrada como limitação do próprio
  ADR-2); esta spec cobre apenas verificação de consistência do que já existe, não geração.
