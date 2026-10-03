# Tarefas — Atualização automática e silenciosa do ROADMAP (ADR-3)

| Campo | Detalhe |
|---|---|
| **Requisitos / Design** | [requirements.md](requirements.md) · [design.md](design.md) |
| **Regra de execução** | Uma tarefa por vez; marcar `[x]` só com evidência de teste. |

## 1. Instrução no SKILL.md

- [x] 1.1 — Teste de texto confirmando RF-01, RF-02 e RF-03 em `SKILL.md`; depende de nada (texto
  já escrito antes desta spec, commit 2222702).
  - **RED:** `test_skill_md_documents_roadmap_automation` em `tests/test_check_adr.py`, procurando
    (dentro da seção "### ROADMAP.md"): "apenas a linha", os 4 gatilhos de Status
    ("Não iniciada", "Só requisitos", "Em andamento", "Concluída") e a frase final de aviso ao
    usuário ("ROADMAP atualizado"). Rodado antes de o caso existir: ausência (`NO TESTS RAN` para
    o caso novo).
  - **GREEN:** teste escrito; passa sem alterar `SKILL.md`.
  - **Validação:** `python3 -m unittest discover -s tests -p 'test_check_adr.py' -v`
  - **Evidência:** confirmado por leitura (`grep`-equivalente em Python) que os marcadores já
    estavam presentes em `SKILL.md` antes de escrever o teste; teste escrito e verde de imediato
    (14 de 14 testes do arquivo, 13 anteriores + este), sem alterar `SKILL.md`.

## 2. Heurística de Status no script

- [x] 2.1 — Acrescentar a RF-04 (comparação de Status esperado x registrado) a
  `skill/scripts/check_roadmap.py`, criado na tarefa 1.1 da spec do ADR-2; depende dela.
  - **RED:** casos em `tests/test_check_roadmap.py`: Spec com só `requirements.md` e Status
    "Só requisitos" → OK; Spec com `design.md` e Status desatualizado ("Só requisitos") → falha
    apontando "Em andamento"; Spec com `tasks.md` todo `[x]` e Status "Em andamento" → falha
    apontando "Concluída"; linha com Spec "*Pendente*" → ignorada, sem falha. Rodado antes da
    heurística existir no script: os 3 primeiros falham (script não compara Status).
  - **GREEN:** heurística implementada conforme o design.
  - **Validação:** `python3 -m unittest discover -s tests -p 'test_check_roadmap.py' -v`
  - **Evidência:** RED real: os 3 primeiros casos falharam porque o script ainda não comparava
    Status (`AssertionError: 2 != 1`, nenhuma verificação de heurística implementada). Ajuste de
    rota durante o GREEN: os links de Spec nas fixtures usavam `../specs/...` (estrutura real do
    repositório), mas a fixture de teste colocava `specs/` dentro da própria pasta temporária —
    corrigido o link da fixture para `specs/minha-spec/...` (sem `../`), consistente com a posição
    real do `ROADMAP.md` de teste. GREEN: heurística implementada em `check_roadmap.py`; 9 de 9
    testes de `test_check_roadmap.py`.

## Auditoria cruzada

| Requisito | Tarefa |
|---|---|
| RF-01, RF-02, RF-03 | 1.1 |
| RF-04 | 2.1 |

Sem requisito órfão nem tarefa sem requisito.
