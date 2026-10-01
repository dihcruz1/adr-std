# Design — ROADMAP.md como documento central de rastreabilidade (ADR-0002)

| Campo | Detalhe |
|---|---|
| **Requisitos** | [requirements.md](requirements.md) |
| **Status** | Gate 2 |

## Contrato

Novo script `skill/scripts/check_roadmap.py`, só biblioteca padrão (mesmo padrão de
`check_adr.py`), reaproveitado também pelo ADR-0003 (ver
[design do ADR-0003](../2026-10-01-adr-0003-roadmap-automatico/design.md) — um único script cobre
as duas decisões porque a verificação de estrutura (ADR-0002) e a verificação de Status (ADR-0003)
operam sobre a mesma tabela e sobre os mesmos arquivos; separar em dois scripts duplicaria o parser
da tabela Markdown sem ganho — regra de segurança/consistência com fonte única).

```
check_roadmap.py <pasta-de-ADRs> [--specs-root <pasta-de-specs>]
```

- Entrada: pasta de ADRs (default dos testes: `docs/architecture/ADR/`), contendo `ROADMAP.md` e
  os arquivos `NNNN-*.md`.
- Saída: lista `[OK]`/`[FALHA]` por verificação, código de saída `0` (tudo ok) ou `1` (alguma falha).
- Verificações desta spec (RF-01 a RF-04):
  1. Tabela do ROADMAP tem o cabeçalho esperado (6 colunas, nomes exatos).
  2. Todo arquivo `NNNN-*.md` da pasta de ADRs aparece como link na coluna "ADR Base" de alguma
     linha da tabela.
  3. Todo arquivo `NNNN-*.md` tem, em sua seção `## Referências`, uma linha citando `./ROADMAP.md`
     (ou `ROADMAP.md`, sem exigir caminho absoluto — RF-03 só pede link relativo presente).
  4. Toda célula de Status é um dos 4 valores válidos.

## Estratégia de testes

`tests/test_check_roadmap.py` (novo arquivo, mesmo padrão de `test_check_adr.py`): fixtures em
pasta temporária com ROADMAP.md e ADRs sintéticos, cobrindo caso conforme e cada tipo de falha
(cabeçalho errado, ADR sem linha, ADR sem referência de volta, Status fora da lista).

## Modelo de domínio

N/A — script de verificação de texto estruturado (parser de tabela Markdown), sem entidade de
domínio, Value Object ou I/O externo substituível que justifique Repositório/Gateway.

## Decisões de design

- Parser de tabela: linha por linha, split por `|`, sem dependência externa (biblioteca de Markdown
  seria over-engineering para uma tabela de 6 colunas fixas — KISS).
- O script não modifica nada (é só verificação); a atualização do ROADMAP continua sendo ação do
  agente via `SKILL.md` (ADR-0003), não deste script — mantém a separação decidida no ADR-0003
  entre "quem decide atualizar" (agente) e "quem confere" (script, se executável).
