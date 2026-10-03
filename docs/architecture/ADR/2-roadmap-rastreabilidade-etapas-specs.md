# ADR-2: ROADMAP.md como documento central de rastreabilidade de etapas e specs

| Campo | Valor |
|---|---|
| **ID** | ADR-2 |
| **Status** | Aceito |
| **Data da decisão** | 2026-10-01 |
| **Aprovado em** | 2026-10-01 |
| **Modificado em** | 2026-10-03 |
| **Decisores** | Diego (solicitante) |
| **Autoridade que aprova** | Diego (solicitante) |
| **Stakeholders afetados** | Mantenedores da skill adr-std; usuários finais (arquitetos e devs que criam ADRs); agentes de IA que usam a skill; colaboradores e contribuidores do repositório |
| **Concerns e aspectos** | Como acompanhar se uma etapa prevista num ADR já virou spec e se foi implementada corretamente? Como manter a rastreabilidade bidirecional entre decisões de arquitetura, especificações técnicas e entregas de código, sem poluir os ADRs individuais com informações de acompanhamento de execução? |
| **Elementos afetados** | `docs/architecture/ADR/ROADMAP.md` (novo); ADRs individuais (seções `## Consequências` e `## Referências`); Specs em `docs/specs/` |
| **Relações com outras decisões** | é habilitado por ADR-1; é refinado por ADR-3 |

## Contexto e definição do problema

A ISO/IEC/IEEE 42010:2022 e a skill `adr-std` proíbem registrar andamento de implementação no campo `Status` do ADR. Ao mesmo tempo, ao planejar a evolução de uma ferramenta como a `adr-std` em etapas (v1.0, v1.1, v1.2...), a equipe precisa saber rapidamente: qual etapa já tem uma spec? qual já foi implementada? qual ainda está sem spec? Um ADR que prevê várias etapas não tem onde registrar esse ciclo de vida da execução.

## Restrições e suposições

- **Restrição:** Os ADRs individuais não podem conter tabelas de acompanhamento de tarefas nem campos de status de execução (norma ISO 42010, skill `adr-std`, seção 12.6 do guia).
- **Restrição:** Links entre documentos devem usar caminhos relativos padrão Markdown, não caminhos específicos de IDE (como `vscode-resource`).
- **Suposição:** O projeto segue a estrutura `docs/architecture/ADR/` para ADRs e `docs/specs/` para especificações técnicas.
- **Suposição:** O ROADMAP.md é um documento vivo, atualizado a cada nova spec aberta ou etapa concluída.

## Fatores de decisão (drivers)

- Rastreabilidade: possibilitar navegar de uma decisão arquitetural até a spec que a detalha e até a evidência de implementação, e vice-versa.
- Separação de responsabilidades: o ADR registra a decisão (imutável após aceito); o ROADMAP registra o progresso (mutável).
- Localização: o documento de acompanhamento deve ser encontrável naturalmente por quem consulta os ADRs.
- Bidirecionalidade: uma spec deve apontar para o ADR que a originou; o ROADMAP é o nó central.
- Manutenabilidade: o ROADMAP deve ser atualizado por humanos e por agentes de IA sem ambiguidade.

## Opções consideradas

1. **Nenhum documento central — rastreabilidade apenas por links nos ADRs e nas specs**: cada ADR aponta para sua(s) spec(s) em `## Referências`; cada spec aponta de volta para o ADR. Sem documento central.
2. **ROADMAP.md na raiz do projeto** (`./ROADMAP.md`): documento central na raiz, visível de qualquer parte do projeto.
3. **ROADMAP.md dentro da pasta dos ADRs** (`docs/architecture/ADR/ROADMAP.md`): documento central co-localizado com os ADRs, encontrável por quem navega pela pasta de decisões.

## Decisão

Escolhemos a **Opção 3: `docs/architecture/ADR/ROADMAP.md`**.

O ROADMAP.md é uma **matriz de rastreabilidade e execução** com a seguinte estrutura mínima de colunas:

| Etapa | Assunto | ADR Base | Spec Técnica | Status | Evidência / Validação |
|:---:|---|:---:|---|:---:|---|

Os valores de **Status** possíveis são: `Não iniciada`, `Só requisitos`, `Em andamento`, `Concluída`.

**Rastreabilidade bidirecional:**
- O ROADMAP aponta para cada ADR e para cada Spec (links relativos).
- Cada ADR aponta para o ROADMAP em `## Referências`.
- Cada Spec declara o ADR de origem no seu cabeçalho.

## Justificativa

A Opção 1 (sem documento central) distribui a rastreabilidade entre dezenas de arquivos e dificulta a visão geral. A Opção 2 (raiz) mistura o ROADMAP de arquitetura com o `ROADMAP.md` de produto/releases que a `adr-std` já possui na raiz (ver `ROADMAP.md` existente). A Opção 3 co-localiza o documento de acompanhamento com os ADRs que ele referencia, mantém a separação entre o ROADMAP de produto (raiz) e o de arquitetura (dentro da pasta ADR), e é encontrável naturalmente por qualquer colaborador que navegue pela pasta de decisões. A estrutura de tabela é simples o suficiente para ser mantida por humanos e por agentes de IA.

## Prós e contras das opções

### Opção 3 — `docs/architecture/ADR/ROADMAP.md` (escolhida)
- Prós: co-localizado com os ADRs; separado do ROADMAP de produto da raiz; estrutura de tabela simples; rastreabilidade bidirecional clara.
- Contras: requer atualização manual a cada nova spec ou etapa concluída; não é gerado automaticamente.

### Opção 1 — Sem documento central (rejeitada)
- Prós: zero arquivo novo; cada documento é autossuficiente.
- Contras: visão geral do progresso exige leitura de todos os ADRs; difícil responder "quais etapas ainda não têm spec?".
- **Motivo da rejeição:** Não atende ao concern de rastreabilidade com visão geral.

### Opção 2 — `./ROADMAP.md` na raiz (rejeitada)
- Prós: altamente visível.
- Contras: conflita com o `ROADMAP.md` de produto já existente na raiz do repositório; mistura duas preocupações distintas.
- **Motivo da rejeição:** Conflito real com arquivo existente.

## Consequências

- **Positivas:** Rastreabilidade completa em um único lugar; visão clara do que já virou spec e do que foi implementado; separação limpa entre decisão (ADR) e execução (ROADMAP + Spec).
- **Negativas / custo:** O ROADMAP precisa ser mantido manualmente; se não for atualizado, torna-se desatualizado. Recomenda-se que cada PR que abre uma nova spec também atualize o ROADMAP.
- **Neutras / acompanhar:** Verificar se ferramentas de CI/CD podem validar automaticamente que cada spec referencia um ADR de origem.
- **Efeito em outras decisões:**
  - ADR-1 habilita esta decisão (o ROADMAP referencia ADRs pela pasta padrão definida nele).
  - O ROADMAP criado por esta decisão é o documento de acompanhamento das etapas das specs v1.0 a v1.3 já planejadas.

## Verificação

- O arquivo `docs/architecture/ADR/ROADMAP.md` existe com a tabela definida nesta decisão.
- Cada ADR possui link para o ROADMAP em sua seção `## Referências`.
- Cada Spec em `docs/specs/` declara o ADR de origem no seu cabeçalho.
- O ROADMAP usa apenas caminhos relativos Markdown válidos (sem `vscode-resource` nem URLs absolutas de IDE).
- Ao abrir uma nova spec, o ROADMAP é atualizado na mesma PR/commit.

## Limitações deste registro

Não foi avaliada geração automática do ROADMAP por script (ex.: a partir dos ADRs existentes e das pastas de specs); caso necessário, exige nova decisão. O formato da coluna "Evidência" não foi padronizado além do texto livre; uma padronização futura pode exigir nova decisão.

## Histórico de modificações

| Data | Alteração | Autor |
|---|---|---|
| 2026-10-01 | Criação | Diego |
| 2026-10-01 | Aprovação (Status: Aceito) | Diego |
| 2026-10-03 | Renumeração ADR-0002 → ADR-2 conforme ADR-4; texto da decisão inalterado | Diego |

## Referências

- ISO/IEC/IEEE 42010:2022, 6.10.1 e 6.10.2 (seção de decisões: status descreve a decisão, não a implementação)
- [ADR-1](1-caminho-padrao-dos-adrs-e-personalizacao.md) (habilita esta decisão)
- [Spec v1.1 — requirements.md](../../specs/2026-09-30-adr-std-v1-1-comandos-no-agente/requirements.md)
- [ROADMAP do produto](../../../ROADMAP.md)
- [ADR-3](3-atualizacao-automatica-do-roadmap-pelo-agente.md) (refina esta decisão — automação do ROADMAP)
- [ROADMAP de arquitetura (criado por esta decisão)](./ROADMAP.md)
