# ADR-4: Numeração dos ADRs sem zeros à esquerda

| Campo | Valor |
|---|---|
| **ID** | ADR-4 |
| **Status** | Proposto |
| **Data da decisão** | 2026-10-03 |
| **Aprovado em** | pendente |
| **Modificado em** | — |
| **Decisores** | Diego (solicitante) |
| **Autoridade que aprova** | Diego (solicitante) |
| **Stakeholders afetados** | Mantenedores da skill adr-std; usuários finais (arquitetos e devs que criam ADRs); agentes de IA que usam a skill |
| **Concerns e aspectos** | Qual é a convenção padrão de numeração dos ADRs: `0001-titulo.md` ou `1-titulo.md`? O ID interno acompanha o nome do arquivo? O que acontece com os ADRs já existentes e com projetos que usam outra convenção? |
| **Elementos afetados** | `skill/scripts/check_adr.py`; `skill/scripts/check_roadmap.py`; `skill/scripts/adr_cli.py`; `skill/SKILL.md`; `skill/references/template-madr.md`, `checklist.md` e `guia-42010.md`; `GLOSSARY.md`; `docs/agents/domain.md`; `tests/`; ADRs 1 a 3 (atuais 0001 a 0003) e `docs/architecture/ADR/ROADMAP.md` |
| **Relações com outras decisões** | influencia ADR-0001, ADR-0002 e ADR-0003 (nomes de arquivo e links serão renomeados); é compatível com a precedência de caminho do ADR-0001 |

## Contexto e definição do problema

Hoje o padrão da skill é `NNNN-<titulo-em-kebab-case>.md`, com 4 dígitos e zeros à esquerda (`0001-...`) e ID `ADR-0001`. O padrão está fixo em `check_adr.py` (`\d{4}`), em `check_roadmap.py` (`ADR_FILENAME`) e na renumeração de `adr_cli.py` (`zfill(4)`). O solicitante quer numerar os ADRs sequencialmente sem zeros à esquerda (`1-titulo.md`, ID `ADR-1`). Como mudar o padrão sem quebrar a verificação, a renumeração, os links e os projetos que já usam outra convenção?

## Restrições e suposições

- **Restrição:** nenhum ADR é apagado e links entre ADRs e specs não podem quebrar (SKILL.md, "Revisar ou reorganizar ADRs").
- **Restrição:** renomear arquivos exige plano mostrado antes e autorização; neste caso, o solicitante autorizou o renomeio dos ADRs 0001 a 0003.
- **Restrição:** a convenção do projeto prevalece sobre o padrão da skill (precedência do ADR-0001 e SKILL.md, passo 4 de "Criar um ADR").
- **Suposição:** o número é sempre inteiro positivo, sequencial, maior existente + 1, sem reuso.
- **Suposição:** sem zeros à esquerda, a ordem alfabética do sistema de arquivos deixa de coincidir com a ordem numérica (`10-` antes de `2-`); a ordenação por número passa a ser responsabilidade das ferramentas da skill.

## Fatores de decisão (drivers)

- **Preferência do solicitante:** numeração sequencial simples, sem zeros à esquerda.
- **Coerência:** nome do arquivo, ID interno e referências cruzadas com a mesma forma (`1-...`, `ADR-1`).
- **Compatibilidade:** projetos com outra convenção continuam funcionando por `--name-pattern` ou pela convenção declarada.
- **Segurança de links:** a migração dos ADRs existentes não pode deixar referência quebrada.
- **Fonte única:** a regra de numeração deve viver em um só lugar no código, e não em cada script.

## Opções consideradas

1. **Manter `NNNN` com 4 dígitos como padrão** (situação atual).
2. **Novo padrão sem zeros à esquerda (`1-titulo.md`, `ADR-1`)**, migrando os ADRs existentes; zeros à esquerda ficam como opção por convenção do projeto.
3. **Padrão configurável, mantendo 4 dígitos como padrão** e apenas garantindo que `1-` funcione de ponta a ponta.
4. **Nome sem zeros e ID interno com zeros** (`1-titulo.md` com `ADR-0001`).

## Decisão

Escolhemos a **Opção 2**: o padrão de numeração dos ADRs passa a ser `<N>-<titulo-em-kebab-case>.md`, com `N` inteiro positivo sem zeros à esquerda, e o ID interno e as referências usam a mesma forma (`ADR-<N>`).

Regras:

> 1. O próximo número é o maior número existente + 1 e nunca é reutilizado. A comparação é numérica, não alfabética.
> 2. Projetos que declaram outra convenção (`.adr-std`, `CONVENTIONS.md`, `AGENTS.md`, `--name-pattern`) mantêm a sua; a ferramenta respeita o padrão informado em todos os comandos, inclusive `check_roadmap.py` e a renumeração.
> 3. Os ADRs deste repositório (0001 a 0003) são renomeados para 1 a 3, com IDs e links atualizados em um único passo, com plano mostrado antes.

## Justificativa

A Opção 2 atende à preferência do solicitante e mantém nome, ID e referência com a mesma forma (driver de coerência). A Opção 1 ignora a preferência. A Opção 3 deixa o padrão como está e empurra a mudança para cada projeto, sem atender à decisão. A Opção 4 gera divergência permanente entre nome e ID e obrigaria o item A2 do checklist a aceitar duas formas. Migrar os ADRs existentes evita um repositório com numeração mista; o custo é concentrado em uma renomeação com plano e verificação de links. Manter a convenção do projeto como prioridade preserva a compatibilidade com quem usa zeros à esquerda.

## Prós e contras das opções

### Opção 2 — Sem zeros à esquerda, com migração (escolhida)
- Prós: atende à preferência; nome, ID e referências coerentes; sem numeração mista no repositório.
- Contras: ordenação alfabética deixa de refletir a numérica; renomeia ADRs aceitos e quebra links externos ao repositório; exige alterar testes e fixtures.

### Opção 1 — Manter 4 dígitos (rejeitada)
- Prós: ordenação alfabética correta até 9999; nenhuma migração.
- Contras: não atende à preferência do solicitante.
- **Motivo da rejeição:** contraria a decisão do solicitante.

### Opção 3 — Configurável, padrão 4 dígitos (rejeitada)
- Prós: nenhuma migração; compatível com o que existe.
- Contras: o padrão da skill continua com zeros; cada projeto precisa configurar.
- **Motivo da rejeição:** não muda o padrão que o solicitante quer.

### Opção 4 — Nome sem zeros, ID com zeros (rejeitada)
- Prós: menos referências internas para alterar.
- Contras: divergência permanente entre nome e ID; regra A2 mais complexa.
- **Motivo da rejeição:** quebra a coerência entre nome do arquivo e ID.

## Consequências

- **Positivas:** numeração simples e coerente em nome, ID e referências; regra de numeração em fonte única.
- **Negativas / custo:** renomeação dos ADRs 0001 a 0003 e atualização de links no ROADMAP, nas specs e em `docs/agents/domain.md`; links externos ao repositório para os nomes antigos quebram; mudança em scripts, template, checklist, guia, SKILL.md, glossário, testes e fixtures.
- **Neutras / acompanhar:** `ls` e listagens do editor passam a ordenar `10-` antes de `2-`; a CLI da skill ordena numericamente. Projetos legados com zeros à esquerda precisam do padrão declarado na convenção para continuar passando na verificação.
- **Efeito em outras decisões:** o texto dos ADRs 1 a 3 mantém a decisão; só o ID, o nome do arquivo e os links mudam, e o "Histórico de modificações" de cada um registra a renumeração. O ADR-0002 e o ADR-0003 citam `ADR-0001` e afins no corpo; essas referências passam a `ADR-1` e afins.

## Verificação

- `check_adr.py` aprova `1-titulo.md` com ID `ADR-1` e reprova `0001-titulo.md` e `01-titulo.md` quando usado o padrão da skill.
- Com `--name-pattern` ou convenção declarada de 4 dígitos, `check_adr.py` e `check_roadmap.py` aprovam `0001-titulo.md`.
- `adr-std new` numera o ADR seguinte por maior número + 1, em ordem numérica, inclusive com `9-` e `10-` na mesma pasta.
- `adr-std organize --dry-run` propõe nomes sem zeros à esquerda.
- Após a migração, `check_adr.py` e `check_roadmap.py` passam na pasta de ADRs do repositório e nenhum link para `0001-`, `0002-` ou `0003-` permanece em `docs/`, `skill/`, `tests/` e na raiz.

## Limitações deste registro

Não decide a política de ordenação visual fora das ferramentas da skill (por exemplo, `ls`). Não cobre migração de repositórios de terceiros. O impacto exato nos bins `bin/adr-std` e `bin/adr-std.ps1` será confirmado na spec; se ela mostrar impacto relevante, ele é tratado ali.

## Histórico de modificações

| Data | Alteração | Autor |
|---|---|---|
| 2026-10-03 | Criação (Status: Proposto) | Diego |

## Referências

- ISO/IEC/IEEE 42010:2022, 6.10.1 e 6.10.2
- [ADR-0001](0001-caminho-padrao-dos-adrs-e-personalizacao.md)
- [ADR-0002](0002-roadmap-rastreabilidade-etapas-specs.md)
- [ADR-0003](0003-atualizacao-automatica-do-roadmap-pelo-agente.md)
- [ROADMAP de arquitetura](./ROADMAP.md)
