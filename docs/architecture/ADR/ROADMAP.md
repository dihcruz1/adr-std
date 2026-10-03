# Roadmap de Decisões de Arquitetura — adr-std

Este documento acompanha a transição das decisões arquiteturais em etapas de implementação, registrando quais já geraram uma especificação técnica e quais foram implementadas.

> **Separação de responsabilidades:**
> Os ADRs individuais registram **o que foi decidido e por quê** (imutável após aceito).
> Este ROADMAP registra **o andamento da execução** (mutável a cada entrega).
> Nunca coloque status de implementação no campo `Status` de um ADR.

---

## Tabela de rastreabilidade

| Etapa | Assunto | ADR Base | Spec Técnica | Status | Evidência / Validação |
|:---:|---|:---:|---|:---:|---|
| **1** | Caminho padrão dos ADRs e personalização por projeto e globalmente | [ADR-1](1-caminho-padrao-dos-adrs-e-personalizacao.md) | [spec](../../specs/2026-10-01-adr-0001-caminho-dos-adrs/requirements.md) | Concluída | `SKILL.md` já traz a hierarquia; `tests/test_check_adr.py` (13/13) cobre texto e `check_adr.py` com pasta custom |
| **2** | ROADMAP.md como documento central de rastreabilidade de etapas e specs | [ADR-2](2-roadmap-rastreabilidade-etapas-specs.md) | [spec](../../specs/2026-10-01-adr-0002-roadmap-rastreabilidade/requirements.md) | Concluída | `skill/scripts/check_roadmap.py` + `tests/test_check_roadmap.py` (9/9); rodado contra este ROADMAP: `[OK] ROADMAP consistente` |
| **3** | Atualização automática e silenciosa do ROADMAP pelo agente | [ADR-3](3-atualizacao-automatica-do-roadmap-pelo-agente.md) | [spec](../../specs/2026-10-01-adr-0003-roadmap-automatico/requirements.md) | Concluída | `SKILL.md` instrui a regra; `check_roadmap.py` confere a heurística de Status (`tests/test_check_roadmap.py`, casos de divergência) |
| **4** | Numeração dos ADRs sem zeros à esquerda (`1-titulo.md`, `ADR-1`) | [ADR-4](4-numeracao-dos-adrs-sem-zeros-a-esquerda.md) | [spec](../../specs/2026-10-03-adr-numeracao-sem-zeros/requirements.md) | Concluída | `check_adr.py`/`check_roadmap.py`/`adr_cli.py` e `migrate_numbering.py` com testes (110 Python, 72 bash); ADRs 1 a 3 migrados pelo script; ADR-4 aprovado (Aceito) em 2026-10-03 |

---

## Etapas planejadas das specs de produto

As versões do produto adr-std e o seu estado de execução estão no [ROADMAP do produto](../../../ROADMAP.md).
As etapas abaixo rastreiam a relação entre as versões e as decisões arquiteturais que as baseiam. O status de cada versão tem fonte única no ROADMAP do produto, para não divergir.

| Versão | Assunto | ADR(s) Relacionado(s) | Spec |
|:---:|---|:---:|---|
| **v1.0** | Skill, instalação, CLI (`install`, `update`, `uninstall`, `status`, `agents`, `check`) | — | [2026-09-30-adr-std-v1-0](../../specs/2026-09-30-adr-std-v1-0/) |
| **v1.1** | Comandos por ação dentro do agente (`/adr-std-create`, `-new`, `-list` etc.) | [ADR-1](1-caminho-padrao-dos-adrs-e-personalizacao.md) | [2026-09-30-adr-std-v1-1-comandos-no-agente](../../specs/2026-09-30-adr-std-v1-1-comandos-no-agente/) |
| **v1.2** | Comandos mecânicos no terminal em Python (`new`, `list`, `link`, `organize --dry-run`; leitura da config global do ADR-1) | [ADR-1](1-caminho-padrao-dos-adrs-e-personalizacao.md) | [2026-10-01-adr-std-v1-2-comandos-terminal](../../specs/2026-10-01-adr-std-v1-2-comandos-terminal/) |
| **v1.3** | Comandos de conversa no terminal; agente padrão e menu com memória | [ADR-1](1-caminho-padrao-dos-adrs-e-personalizacao.md) | [2026-10-01-adr-std-v1-3-conversa-terminal](../../specs/2026-10-01-adr-std-v1-3-conversa-terminal/) |
| **v1.4** | `adr-std config path`: escrita da config global pela CLI (nível 4 do ADR-1, etapa 2) | [ADR-1](1-caminho-padrao-dos-adrs-e-personalizacao.md) | [2026-10-02-adr-std-v1-4-config-path](../../specs/2026-10-02-adr-std-v1-4-config-path/) |
| **v2.0** | Numeração dos ADRs sem zeros à esquerda; `adr-std migrate` e migração mostrada pelo `update` | [ADR-4](4-numeracao-dos-adrs-sem-zeros-a-esquerda.md) | [2026-10-03-adr-numeracao-sem-zeros](../../specs/2026-10-03-adr-numeracao-sem-zeros/) |

---

## Como atualizar este documento

1. **Nova spec aberta:** adicione ou atualize a linha correspondente com o link para a spec e mude o Status para `Só requisitos`.
2. **Gate de design aprovado:** mude para `Em andamento`.
3. **Etapa concluída e validada:** mude para `Concluída` e preencha a coluna `Evidência / Validação`.
4. **Links:** use sempre caminhos relativos Markdown (ex.: `ADR-1` apontando para o arquivo `1-titulo-da-decisao.md` da mesma pasta), nunca URLs absolutas de IDE.

---

## Valores de Status

| Valor | Significado |
|---|---|
| `Não iniciada` | Nenhuma spec aberta; etapa apenas prevista no ADR |
| `Só requisitos` | Spec aberta com `requirements.md`; sem `design.md` nem `tasks.md` |
| `Em andamento` | Spec com design aprovado; tarefas em execução |
| `Concluída` | Todas as tarefas feitas e validadas pela evidência |
