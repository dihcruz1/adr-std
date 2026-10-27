# Issue tracker: Local Markdown em `docs/specs/`

Modo nativo da skill (spec única + um arquivo por ticket), com a raiz trocada de `.scratch/` para `docs/specs/`. Não use `.scratch/`, `gh` nem API de GitHub/Linear.

## Convenções

- Uma mudança por pasta: `docs/specs/<AAAA-MM-DD>-<nome>/` (nome em inglês, minúsculo, com hífens).
- A spec é `docs/specs/<AAAA-MM-DD>-<nome>/spec.md`, no template nativo do `/to-spec`.
- Tickets: um arquivo por ticket em `docs/specs/<AAAA-MM-DD>-<nome>/issues/<NN>-<slug>.md`, numerados de `01`, nunca um arquivo único de tarefas.
- Bloqueios: linha `Blocked by: NN, NN` no topo do ticket. Um ticket está livre quando todos os bloqueadores estão `resolved`.
- Estado: linha `Status:` no topo (`open`/`claimed`/`resolved`). Comentários e evidências (RED/GREEN, comandos, saídas) vão no fim do arquivo, sob `## Comments`.
- Marque um ticket `resolved` só com evidência real de testes.

## Quando uma skill diz "publish to the issue tracker"

Crie o arquivo em `docs/specs/<AAAA-MM-DD>-<nome>/` (e `issues/`, se preciso). Não aplique rótulos de triagem; não há triagem.

Gates do `AGENTS.md`: pare no Gate 1 após o Problem Statement/Solution/User Stories, e no Gate 2 após Implementation/Testing Decisions (seams confirmados), aguardando aprovação. O Gate 3 vem depois do `/to-tickets` e da auditoria cruzada.

## Quando uma skill diz "fetch the relevant ticket"

Leia o arquivo indicado (caminho ou número). Para contexto, leia também o `spec.md` da pasta.

## Operações do `/wayfinder`

- **Mapa:** `docs/specs/<AAAA-MM-DD>-<nome>/map.md` (Notes / Decisions-so-far / Fog).
- **Ticket filho:** `docs/specs/<AAAA-MM-DD>-<nome>/issues/NN-<slug>.md`, com `Type:` (`research`/`prototype`/`grilling`/`task`), `Status:` (`claimed`/`resolved`) e `Blocked by:`.
- **Fronteira:** tickets abertos, livres e sem dono; vence o menor número.
- **Claim:** `Status: claimed` e salvar antes de trabalhar.
- **Resolver:** anexe a resposta em `## Answer`, marque `resolved` e acrescente o ponteiro em Decisions-so-far do `map.md`.

## Commits

Seguem o `AGENTS.md`: commit 1 só com a spec, depois do Gate 3; commit 2 com implementação, testes e tickets. As skills (inclusive `/implement`) não commitam fora desses marcos.
