# Requisitos — Atualização automática e silenciosa do ROADMAP (ADR-0003)

| Campo | Detalhe |
|---|---|
| **Data** | 2026-10-01 |
| **ADR de origem** | [ADR-0003](../../architecture/ADR/0003-atualizacao-automatica-do-roadmap-pelo-agente.md) |
| **Status** | Gate 1 |

## Contexto

O ADR-0003 decide que o agente atualiza o ROADMAP sozinho, linha por linha, ao criar/modificar um
ADR ou uma Spec, usando uma heurística de Status baseada na existência de `requirements.md`,
`design.md` e `tasks.md` (e se todas as tarefas de `tasks.md` estão `[x]`). A instrução já foi
escrita em `skill/SKILL.md` (seção "ROADMAP.md (atualização automática)"). Esta spec cobre: (1) a
instrução em si (texto, mesmo molde da tarefa 1.1 do ADR-0001) e (2) a parte mecanicamente
verificável — conferir que o Status registrado bate com a heurística, dado o estado real dos
arquivos no disco.

## Requisitos (EARS)

- **RF-01** — O `SKILL.md` DEVE instruir o agente a atualizar apenas a linha afetada do ROADMAP
  (nunca regenerar a tabela inteira) ao criar ou modificar um ADR ou uma Spec.
- **RF-02** — O `SKILL.md` DEVE descrever a heurística de Status com os 4 valores e seus gatilhos
  (ADR sem Spec → `Não iniciada`; só `requirements.md` → `Só requisitos`; com `design.md` →
  `Em andamento`; `tasks.md` com todas as tarefas `[x]` → `Concluída`).
- **RF-03** — O `SKILL.md` DEVE instruir o agente a informar ao usuário, ao final da ação, que o
  ROADMAP foi atualizado (sem pedir confirmação prévia).
- **RF-04** — Dada uma linha do ROADMAP com link para uma pasta de Spec existente, uma verificação
  mecânica DEVE comparar o Status registrado com o Status esperado pela heurística (com base na
  existência de `requirements.md`/`design.md`/`tasks.md` e no estado de `tasks.md`) e reportar
  divergência quando houver.

## Critério de aceitação (Gherkin)

```gherkin
Cenário: Status "Em andamento" bate com a Spec que tem só requirements+design
  Dado uma pasta de Spec com requirements.md e design.md, sem tasks.md
  E a linha do ROADMAP que a referencia com Status "Em andamento"
  Quando rodo a verificação de heurística
  Então ela reporta OK para essa linha

Cenário: Status desatualizado é detectado
  Dado uma pasta de Spec com requirements.md, design.md e tasks.md com todas as tarefas [x]
  E a linha do ROADMAP que a referencia ainda com Status "Em andamento"
  Quando rodo a verificação de heurística
  Então ela reporta a divergência, indicando o Status esperado "Concluída"

Cenário: Spec "*Pendente*" não gera falso positivo
  Dado uma linha do ROADMAP com Spec Técnica "*Pendente*"
  Quando rodo a verificação de heurística
  Então essa linha é ignorada (nada para comparar)
```

## Fora de escopo

- O script não escreve no ROADMAP (quem atualiza é o agente, por decisão do próprio ADR-0003); o
  script só confere e reporta divergência — automação de escrita violaria a separação "quem decide
  atualizar (agente) vs. quem confere (script)" registrada no design do ADR-0002.
