# ADR-0001: Caminho padrão dos ADRs e personalização por projeto e globalmente

| Campo | Valor |
|---|---|
| **ID** | ADR-0001 |
| **Status** | Aceito |
| **Data da decisão** | 2026-10-01 |
| **Aprovado em** | 2026-10-01 |
| **Modificado em** | — |
| **Decisores** | Diego (solicitante) |
| **Autoridade que aprova** | Diego (solicitante) |
| **Stakeholders afetados** | Mantenedores da skill adr-std; usuários finais (arquitetos e devs que criam ADRs); agentes de IA que usam a skill; colaboradores e contribuidores do repositório |
| **Concerns e aspectos** | Onde a skill deve ler e gravar ADRs? Como projetos legados ou equipes com estrutura própria de diretórios podem usar a skill sem fricção? Como garantir previsibilidade sem engessar o padrão? |
| **Elementos afetados** | `skill/SKILL.md`; `skill/references/guia-42010.md`; `bin/adr-std`; `bin/adr-std.ps1`; comandos `/adr-std-new`, `/adr-std-list`, `/adr-std-create` (v1.1); `adr-std config` (v1.2+) |
| **Relações com outras decisões** | habilita ADR-0002 |

## Contexto e definição do problema

A skill `adr-std` precisa saber onde estão os ADRs do projeto para criar, listar, revisar e verificar arquivos. Sem um padrão fixo, o agente precisa perguntar ao usuário toda vez ou procurar heuristicamente. Sem suporte à personalização, projetos com estrutura de diretório pré-existente (por exemplo, `doc/adr/` ou `docs/decisions/`) precisam adaptar toda a sua estrutura para usar a skill.

## Restrições e suposições

- **Restrição:** O instalador não pode exigir privilégio de administrador para criar ou ler configurações.
- **Restrição:** O comando `adr-std` já usa as variáveis XDG (`XDG_CONFIG_HOME`, `XDG_DATA_HOME`) para configuração global (confirmado no `bin/adr-std`).
- **Suposição:** A maioria dos novos projetos não terá convenção pré-existente; o padrão deve funcionar sem configuração.
- **Suposição:** Projetos podem documentar sua convenção em `docs/architecture/ADR/CONVENTIONS.md` ou em `AGENTS.md`.

## Fatores de decisão (drivers)

- Previsibilidade: usuários e agentes devem saber onde os ADRs serão criados sem precisar verificar.
- Flexibilidade: projetos legados e equipes com padrões próprios não devem ser forçados a mudar sua estrutura.
- Consistência com ferramentas existentes: a skill já segue XDG para configuração global.
- Rastreabilidade: o mesmo padrão de resolução deve ser aplicado em todas as ações da skill (create, list, new, check, organize).
- Alinhamento com a spec v1.1 (RF-17, RF-19): os comandos `/adr-std-new` e `/adr-std-list` precisam de um padrão de caminho definido.

## Opções consideradas

1. **Padrão fixo sem personalização** — a skill sempre usa `docs/architecture/ADR/` e não aceita outra pasta.
2. **Padrão com personalização em dois níveis (global e por projeto)** — padrão `docs/architecture/ADR/`, substituível por configuração do usuário (`~/.config/adr-std/config`) ou do projeto (`.adr-std` na raiz do repositório), com a mesma hierarquia do Git (`flag > local > global > padrão`).
3. **Descoberta automática por heurística** — a skill procura ADRs em pastas conhecidas e usa a primeira que encontrar.

## Decisão

Escolhemos a **Opção 2: padrão com personalização em dois níveis (global e por projeto)**.

A hierarquia de resolução do caminho é:

1. Argumento explícito (ex.: `--path <pasta>` na CLI ou pasta passada no comando do agente).
2. Configuração local do projeto: arquivo `.adr-std` na raiz do repositório com o campo `path`, ou convenção declarada em `docs/architecture/ADR/CONVENTIONS.md` / `AGENTS.md`.
3. Configuração global do usuário: `~/.config/adr-std/config` (Linux/macOS) ou `%APPDATA%\adr-std\config` (Windows).
4. **Padrão fixo: `docs/architecture/ADR/`**

## Justificativa

A Opção 1 (padrão fixo) resolve o caso simples mas cria atrito desnecessário para projetos legados e organizações com padrão corporativo. A Opção 3 (heurística) é frágil: pode selecionar a pasta errada e dificulta a depuração. A Opção 2 é o modelo consolidado do ecossistema (Git, npm, ESLint, editores), já conhecido pelos usuários da skill. Ela aproveita a infraestrutura XDG que o `bin/adr-std` já adota e não acrescenta complexidade ao caso simples (sem configuração = padrão `docs/architecture/ADR/`). Alinha-se diretamente a RF-17 e RF-19 da spec v1.1, que exigem que `new` e `list` resolvam a pasta de ADRs do projeto.

## Prós e contras das opções

### Opção 2 — Personalização em dois níveis (escolhida)
- Prós: flexível para projetos legados; previsível (hierarquia explícita e documentada); sem custo para o caso padrão; consistente com o modelo Git e XDG já usados; resolve RF-17 e RF-19.
- Contras: exige implementação da lógica de resolução na skill e na CLI; mais arquivos de configuração a documentar.

### Opção 1 — Padrão fixo (rejeitada)
- Prós: simples de implementar e documentar.
- Contras: impede adoção em projetos com estrutura existente; obriga refatoração do diretório de documentação.
- **Motivo da rejeição:** Cria atrito real para uma fatia relevante de usuários sem nenhum benefício técnico.

### Opção 3 — Heurística automática (rejeitada)
- Prós: zero configuração.
- Contras: comportamento não determinístico; difícil de depurar; pode selecionar pasta errada silenciosamente.
- **Motivo da rejeição:** Previsibilidade é um driver essencial; heurística a viola.

## Consequências

- **Positivas:** Adoção da skill em projetos legados sem mudança de estrutura; alinhamento com ferramentas do ecossistema.
- **Negativas / custo:** A lógica de resolução de caminho precisa ser implementada no `SKILL.md` (instruções ao agente) e nas versões CLI (v1.2+).
- **Neutras / acompanhar:** Documentar o arquivo `.adr-std` de configuração local no README e no guia.
- **Efeito em outras decisões:**
  - Etapa 1 (v1.1): atualizar o `SKILL.md` para instruir o agente a seguir a hierarquia de resolução. Detalhada na spec v1.1 ([requirements.md](../../specs/2026-09-30-adr-std-v1-1-comandos-no-agente/requirements.md)).
  - Etapa 2 (v1.2+): implementar `adr-std config path` na CLI.

## Verificação

- O agente cria o ADR em `docs/architecture/ADR/` quando não há `.adr-std` nem config global.
- O agente respeita o `path` definido em `.adr-std` na raiz do projeto, criando ADRs na pasta indicada.
- O agente respeita a config global em `~/.config/adr-std/config` quando não há `.adr-std` local.
- O argumento explícito de pasta (quando aplicável) sobrescreve todas as configurações.
- `adr-std config path` (v1.2+) lê e grava o valor correto no arquivo de config global.

## Limitações deste registro

Nenhuma opção de personalização de escopo de workspace (por exemplo, variável de ambiente por sessão) foi avaliada; caso necessária, exige nova decisão. A implementação do `adr-std config` na CLI é escopo da v1.2 e não foi detalhada aqui.

## Histórico de modificações

| Data | Alteração | Autor |
|---|---|---|
| 2026-10-01 | Criação | Diego |
| 2026-10-01 | Aprovação (Status: Aceito) | Diego |

## Referências

- ISO/IEC/IEEE 42010:2022, 6.10.1 e 6.10.2
- [Spec v1.1 — requirements.md](../../specs/2026-09-30-adr-std-v1-1-comandos-no-agente/requirements.md) (RF-17, RF-19)
- [ROADMAP.md](../../../ROADMAP.md)
- [ADR ROADMAP](./ROADMAP.md)
