# ADR-0003: Atualização automática e silenciosa do ROADMAP.md pelo agente

| Campo | Valor |
|---|---|
| **ID** | ADR-0003 |
| **Status** | Aceito |
| **Data da decisão** | 2026-10-01 |
| **Aprovado em** | 2026-10-01 |
| **Modificado em** | — |
| **Decisores** | Diego (solicitante) |
| **Autoridade que aprova** | Diego (solicitante) |
| **Stakeholders afetados** | Mantenedores da skill adr-std; usuários finais (arquitetos e devs que criam ADRs); agentes de IA que usam a skill |
| **Concerns e aspectos** | O ROADMAP.md fica desatualizado se depender de atualização manual. Como o agente deve manter o ROADMAP sincronizado com os ADRs e Specs sem criar fricção no fluxo de trabalho? Quando atualizar? Linha por linha ou regenerar tudo? O usuário precisa confirmar? |
| **Elementos afetados** | `skill/SKILL.md`; `skill/references/guia-42010.md`; ações `/adr-std-create`, `/adr-std-supersede`, `/adr-std-new`; qualquer ação da skill que crie ou modifique um ADR ou Spec; `docs/architecture/ADR/ROADMAP.md` |
| **Relações com outras decisões** | refina ADR-0002 |

## Contexto e definição do problema

O ADR-0002 decidiu que `docs/architecture/ADR/ROADMAP.md` é o documento central de rastreabilidade entre ADRs, etapas e specs. Porém, a ADR-0002 deixou como limitação registrada que a geração automática do ROADMAP não foi avaliada e exigiria nova decisão. A decisão aqui é: o ROADMAP deve ser automaticamente preenchido e mantido pelo agente sempre que ele criar ou modificar um ADR ou uma Spec, sem intervenção manual e sem pedir confirmação ao usuário.

## Restrições e suposições

- **Restrição:** O agente não pode fazer commit nem push sem autorização expressa (proibição geral da skill).
- **Restrição:** A lógica de atualização do ROADMAP é regra da skill (`SKILL.md`), não código externo — o agente a executa ao ler as instruções.
- **Suposição:** O ROADMAP segue a estrutura de tabela definida no ADR-0002.
- **Suposição:** O agente consegue detectar, ao criar ou modificar um ADR ou Spec, se o ROADMAP já contém uma linha para aquele ADR/Spec ou se precisa criar uma nova.
- **Suposição:** A atualização silenciosa não omite informação relevante — o agente menciona ao usuário ao final da ação que o ROADMAP foi atualizado (sem pedir confirmação prévia).

## Fatores de decisão (drivers)

- **Manutenabilidade:** ROADMAP manual tende a ficar desatualizado; automação elimina o risco.
- **Baixa fricção:** Pedir confirmação a cada atualização de ROADMAP interrompe o fluxo de criar ADRs — o custo supera o benefício.
- **Rastreabilidade imediata:** O ROADMAP deve refletir o estado real do projeto imediatamente após cada ação da skill.
- **Granularidade correta:** Atualizar apenas a linha afetada é mais seguro do que regenerar todo o documento (evita sobrescrever personalizações manuais de outras linhas).

## Opções consideradas

1. **Atualização manual pelo usuário** — o agente não toca o ROADMAP; o usuário o atualiza quando quiser.
2. **Atualização automática e silenciosa, linha por linha** — o agente atualiza apenas a linha do ADR ou Spec afetado, como parte da ação de criar/modificar, sem pedir confirmação; menciona ao final que atualizou.
3. **Atualização automática com confirmação** — o agente propõe a atualização do ROADMAP e só executa se o usuário confirmar.
4. **Regeneração completa por comando explícito** — o ROADMAP só é atualizado quando o usuário chamar `/adr-std-roadmap`.

## Decisão

Escolhemos a **Opção 2: atualização automática e silenciosa, linha por linha**.

**Regra para o agente:**

> Sempre que o agente criar ou modificar um ADR **ou** uma Spec como parte de uma ação da skill, ele DEVE:
> 1. Localizar ou criar a linha correspondente no `docs/architecture/ADR/ROADMAP.md`.
> 2. Atualizar os campos **ADR Base**, **Spec Técnica** e **Status** com base no que foi criado/modificado.
> 3. Não alterar linhas de outros ADRs ou Specs que não foram tocados nesta ação.
> 4. Ao concluir a ação principal, informar ao usuário que o ROADMAP foi atualizado (sem pedir confirmação prévia).

**Status a usar no ROADMAP:**

| Situação detectada | Status no ROADMAP |
|---|---|
| ADR criado, sem Spec ainda | `Não iniciada` |
| Spec aberta com apenas `requirements.md` | `Só requisitos` |
| Spec com `design.md` criado | `Em andamento` |
| Spec com `tasks.md` e todas as tarefas marcadas `[x]` | `Concluída` |

## Justificativa

A Opção 1 (manual) foi a situação anterior ao ADR-0002 e resulta em ROADMAP desatualizado. A Opção 3 (com confirmação) cria fricção desnecessária em toda criação de ADR — o usuário já autorizou a ação principal e a atualização do ROADMAP é consequência natural. A Opção 4 (comando explícito) é complementar mas insuficiente como única estratégia. A Opção 2 equilibra automação sem surpresa (o usuário é informado ao final) e granularidade segura (só a linha afetada é tocada). É consistente com o comportamento esperado de ferramentas de automação de documentação no ecossistema.

## Prós e contras das opções

### Opção 2 — Automática e silenciosa, linha por linha (escolhida)
- Prós: ROADMAP sempre atualizado; zero fricção no fluxo de criação de ADR; granularidade segura; usuário informado ao final.
- Contras: o agente precisa interpretar o estado da Spec (lendo se `design.md` e `tasks.md` existem); pode errar a inferência de status em casos ambíguos.

### Opção 1 — Manual (rejeitada)
- Prós: simples; sem risco de atualização errada pelo agente.
- Contras: ROADMAP tende a ficar desatualizado; elimina o principal benefício do documento.
- **Motivo da rejeição:** Reintroduz o problema que o ADR-0002 resolveu.

### Opção 3 — Automática com confirmação (rejeitada)
- Prós: mais segura; usuário tem controle total.
- Contras: cria interrupção desnecessária em cada criação de ADR; o ROADMAP pode ficar desatualizado se o usuário recusar ou esquecer.
- **Motivo da rejeição:** Fricção excessiva sem benefício real de segurança para uma operação de baixo risco (atualizar uma linha de tabela Markdown).

### Opção 4 — Regeneração por comando explícito (rejeitada como estratégia única)
- Prós: controle total; útil para sincronização após edições manuais em massa.
- Contras: depende de o usuário lembrar de executar o comando; o ROADMAP fica desatualizado entre as execuções.
- **Motivo da rejeição:** Pode ser implementada como complemento futuro (ex.: `/adr-std-roadmap` para sincronização completa), mas não substitui a atualização automática.

## Consequências

- **Positivas:** ROADMAP sempre reflete o estado real; zero esforço manual de manutenção do documento de rastreabilidade.
- **Negativas / custo:** A skill precisa de novas instruções no `SKILL.md` descrevendo: quando atualizar, como inferir o status da Spec (existência de `requirements.md`, `design.md`, `tasks.md`), e como informar o usuário ao final.
- **Neutras / acompanhar:** Casos em que o agente infere incorretamente o status da Spec devem ser tratados: o usuário pode corrigir manualmente a linha; uma futura Opção 4 (`/adr-std-roadmap`) pode ressincronizar tudo.
- **Efeito em outras decisões:**
  - Refina ADR-0002 (que deixou a automação como ponto em aberto).
  - Afeta a implementação da v1.1: as instruções de `create`, `supersede` e `new` no `SKILL.md` devem incluir o passo de atualização do ROADMAP.

## Verificação

- Ao executar `/adr-std-create`, o agente cria o ADR e, sem perguntar, adiciona ou atualiza a linha correspondente no ROADMAP com Status `Não iniciada`.
- Ao criar `requirements.md` de uma nova Spec, o agente atualiza a linha do ROADMAP para `Só requisitos`.
- Ao criar `design.md`, o agente atualiza para `Em andamento`.
- Ao detectar que todas as tarefas de `tasks.md` estão marcadas `[x]`, o agente atualiza para `Concluída`.
- O agente não altera linhas de outros ADRs ou Specs que não foram tocados na ação.
- Ao final de cada ação que tocou o ROADMAP, o agente informa: *"ROADMAP atualizado: [linha afetada]."*

## Limitações deste registro

A inferência de status a partir da existência de arquivos (`requirements.md`, `design.md`, `tasks.md`) é uma heurística: projetos que usam outros nomes de arquivo podem ter status inferido incorretamente. Uma futura configuração de nomes de arquivo da Spec pode resolver isso, mas exige nova decisão. O comando `/adr-std-roadmap` para regeneração completa não foi especificado aqui; se necessário, exige nova decisão.

## Histórico de modificações

| Data | Alteração | Autor |
|---|---|---|
| 2026-10-01 | Criação | Diego |
| 2026-10-01 | Aprovação (Status: Aceito) | Diego |

## Referências

- ISO/IEC/IEEE 42010:2022, 6.10.1 e 6.10.2
- [ADR-0002](0002-roadmap-rastreabilidade-etapas-specs.md) (refinado por esta decisão)
- [Spec v1.1 — requirements.md](../../specs/2026-09-30-adr-std-v1-1-comandos-no-agente/requirements.md) (RF-17, implementação de `new` e `list`)
- [ROADMAP de arquitetura](./ROADMAP.md)
