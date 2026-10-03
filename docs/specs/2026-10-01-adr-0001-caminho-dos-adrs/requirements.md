# Requisitos — Caminho padrão dos ADRs e personalização (ADR-1)

| Campo | Detalhe |
|---|---|
| **Data** | 2026-10-01 |
| **ADR de origem** | [ADR-1](../../architecture/ADR/1-caminho-padrao-dos-adrs-e-personalizacao.md) |
| **Status** | Gate 1 |

## Contexto

O ADR-1 decide a hierarquia de resolução do caminho onde a skill lê e grava ADRs
(`argumento explícito > .adr-std local > CONVENTIONS.md/AGENTS.md > config global > padrão fixo`).
Esta spec detalha como essa hierarquia é instruída ao agente (via `SKILL.md`) e verificada.

Como a resolução de caminho é uma decisão sobre **onde o agente procura/cria arquivos**, e não um
formato de conteúdo que um script possa inferir sozinho (o agente é quem lê `.adr-std`,
`CONVENTIONS.md`, `AGENTS.md` e a config global, e decide), a parte mecânica verificável é limitada:
confirmar que as instruções existem no `SKILL.md` na ordem certa e que o script de verificação
aceita caminho explícito (nível 1 da hierarquia) sem exigir um layout fixo.

## Requisitos (EARS)

- **RF-01** — Quando o agente for criar, listar ou verificar ADRs, o `SKILL.md` DEVE instruir a
  resolução do caminho na ordem: argumento explícito → `.adr-std` (campo `path`) → convenção em
  `CONVENTIONS.md`/`AGENTS.md` → config global (`~/.config/adr-std/config` ou
  `%APPDATA%\adr-std\config`) → padrão `docs/architecture/ADR/`.
- **RF-02** — Quando nenhuma personalização existir, o agente DEVE usar `docs/architecture/ADR/`
  sem perguntar ao usuário.
- **RF-03** — `scripts/check_adr.py` DEVE aceitar um caminho de pasta ou arquivo explícito como
  argumento (nível 1 da hierarquia), continuando a funcionar com qualquer convenção de pastas —
  ele não presume `docs/architecture/ADR/` fixo.
- **RF-04** — Quando o `SKILL.md` descrever a hierarquia, a ordem e os 5 níveis DEVEM aparecer
  de forma idêntica à decisão do ADR-1 (sem nível omitido ou fora de ordem).

## Critério de aceitação (Gherkin)

```gherkin
Cenário: SKILL.md contém a hierarquia completa e na ordem certa
  Dado o arquivo skill/SKILL.md
  Quando procuro a seção "Caminho dos ADRs"
  Então encontro os 5 níveis na ordem: explícito, .adr-std, CONVENTIONS/AGENTS, config global, padrão

Cenário: check_adr.py aceita pasta fora do padrão
  Dado uma pasta "outra-pasta/" com um ADR válido
  Quando executo "check_adr.py outra-pasta/"
  Então a verificação roda normalmente e retorna 0
```

## Fora de escopo (YAGNI vs. este requirements.md)

- Implementar `adr-std config path` na CLI (v1.2+, já registrado no ADR-1 como efeito futuro).
- Qualquer leitura automática de `.adr-std`/config global por `check_adr.py` — o script já aceita
  caminho explícito (RF-03), e quem resolve os outros 4 níveis é o agente via `SKILL.md`, não o
  script (decisão do próprio ADR-1: a lógica de resolução vive nas instruções da skill).
