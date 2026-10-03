# Tarefas — Caminho padrão dos ADRs e personalização (ADR-1)

| Campo | Detalhe |
|---|---|
| **Requisitos / Design** | [requirements.md](requirements.md) · [design.md](design.md) |
| **Regra de execução** | Uma tarefa por vez; marcar `[x]` só com evidência de teste. |

## 1. Verificação

- [x] 1.1 — Teste confirmando a hierarquia completa e ordenada em `SKILL.md`; cobre RF-01, RF-02, RF-04.
  - **RED:** `test_skill_md_documents_path_hierarchy` em `tests/test_check_adr.py`, buscando os 5
    marcadores ("argumento explícito", ".adr-std", "CONVENTIONS.md", "config global", "padrão fixo"
    / `docs/architecture/ADR/`) e exigindo que os índices apareçam em ordem crescente no texto.
    Rodado antes de o teste existir: `NO TESTS RAN` (arquivo de teste ainda não tinha o caso).
  - **GREEN:** teste escrito; `skill/SKILL.md` já contém a seção (implementada antes desta spec,
    commit 2222702); teste passa sem alterar `SKILL.md`.
  - **Validação:** `python3 -m unittest discover -s tests -p 'test_check_adr.py' -v`
  - **Evidência:** RED real: primeira tentativa (`text.index` simples) encontrou "docs/architecture/ADR/"
    e "CONVENTIONS.md" na seção "Antes de tudo" (antes da seção da hierarquia), fora de ordem —
    corrigido restringindo a busca à seção "### Caminho dos ADRs" com busca sequencial a partir do
    cursor anterior. GREEN: 13 de 13 testes do arquivo (11 anteriores + os 2 desta tarefa).
- [x] 1.2 — Teste confirmando que `check_adr.py` aceita pasta fora do padrão `docs/architecture/ADR/`; cobre RF-03.
  - **RED:** `test_check_accepts_custom_folder`, com fixture ADR válido em pasta temporária
    `outra-pasta/custom/` (não `docs/architecture/ADR/`); roda `check(Path(...), DEFAULT_NAME_PATTERN)`
    chamando a função interna do script (mesma técnica dos demais testes do arquivo). Rodado antes
    de existir: `NO TESTS RAN`.
  - **GREEN:** o teste passa sem alterar `check_adr.py` — a função já opera sobre qualquer `Path`
    recebido.
  - **Validação:** `python3 -m unittest discover -s tests -p 'test_check_adr.py' -v`
  - **Evidência:** RED real (ausência). GREEN: 13 de 13 testes do arquivo; nenhuma regressão nos
    11 anteriores.

## Auditoria cruzada

| Requisito | Tarefa |
|---|---|
| RF-01, RF-02, RF-04 | 1.1 |
| RF-03 | 1.2 |

Sem requisito órfão nem tarefa sem requisito.
