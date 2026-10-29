# Skills SDD por etapa

Mapa das etapas do fluxo do `AGENTS.md` para as skills dos pacotes instalados. Ordem da linha = preferência.

`*` = só o usuário invoca. `+` = skills usadas juntas como uma opção.

A ordem de escolha está na seção "Execução" do `AGENTS.md`: skill invocada pelo usuário, skill do **pacote da spec** (o da primeira skill usada na demanda), skill de outro pacote e, por fim, o próprio agente. Vale para todas as etapas.

Exemplos:

- **Matt Pocock:** explorar com `grill-with-docs` (1), requisitos com `to-spec` (2), design com `to-spec` (3), tarefas com `to-tickets` (4); sem skill de auditoria no pacote, auditar com `opsx:update` (5, OpenSpec); implementar com `implement-spec` ou `implement` (6).
- **OpenSpec:** `opsx:propose` (2 a 4), `opsx:update` (5), `opsx:apply` + `tdd` (6).
- **Sem skill em pacote algum:** o agente executa a etapa (ex.: 9, entrega).

Skill marcada com `*`, quando escolhida pela ordem e não pelo usuário, é executada pelo agente lendo o `SKILL.md` dela.

| Etapa | Skills, em ordem | Normalização |
|---|---|---|
| 1. Explorar | `opsx:explore`, `grill-with-docs`*, `brainstorming` | achados vão para `requirements.md`/`design.md`; glossário e ADRs nos seus caminhos |
| 1–2. Defeito | `diagnosing-bugs`, `systematic-debugging` | causa-raiz e matriz de não-regressão em `requirements.md` |
| 2. Requisitos | `opsx:propose`, `to-spec`*, `brainstorming` | cria `docs/specs/<AAAA-MM-DD>-<nome>/` e grava só `requirements.md`: requisitos EARS, critérios Gherkin verificáveis, ameaças, riscos e mitigações, fora do escopo; para no Gate 1. `opsx:propose` gera só este artefato, não os três de uma vez; `to-spec` converte problema, solução e histórias em requisitos EARS e critérios Gherkin |
| 3. Design | `opsx:propose`, `to-spec`*, `brainstorming` | grava só `design.md`: contratos, decisões e justificativas, decisões de segurança, estratégia de testes com os seams e "Modelo de domínio"; para no Gate 2. `to-spec` roda de novo e grava aqui as decisões de implementação e de testes |
| 4. Tarefas | `opsx:propose`, `to-tickets`*, `writing-plans` | grava só `tasks.md`: tarefas atômicas por dependência e etapa/camada, com checkbox, ID em texto puro (`1.1`), escopo e arquivos, e comando de validação, incluindo os testes de segurança no RED. `to-tickets`: cada ticket vira um grupo numerado (`1`, `2`…) na ordem dos bloqueios, e seus critérios de aceite viram as tarefas (`1.1`, `1.2`…); os caminhos de arquivo, que a skill evita, são exigidos pelo contrato |
| 5. Auditoria cruzada | `opsx:update` | serve a spec de qualquer pacote: `openspec/changes` aponta para `docs/specs` e o schema reconhece os três arquivos; o `.openspec.yaml` não é exigido |
| 6. TDD | `opsx:apply` + `tdd`, `implement-spec`* (com subagentes) ou `implement`* (sem), `test-driven-development` | seams da estratégia de testes do `design.md` aprovado contam como confirmados; subagentes só em tarefa grande, senão o principal implementa com a skill do pacote para execução sem subagentes (`implement`; no OpenSpec, o próprio `opsx:apply`); plano inteiro sem pausa, salvo bloqueio do contrato |
| 7. E2E | `playwright-cli` (`open --browser=chrome --headed --persistent <url>`) | — |
| 8. Auditoria final | `code-review`, `requesting-code-review` | sem commit novo: diff = `git diff <commit 1>` mais arquivos não rastreados; spec = pasta em `docs/specs` |

Commits feitos por qualquer skill são suprimidos; commits só nos marcos. Proibidas: `opsx:archive`, `opsx:sync`, `finishing-a-development-branch`; ignore sugestões de arquivar das demais.

## Pacotes

- **OpenSpec**: `opsx:<x>` no Claude Code = `opsx-<x>` no OpenCode = `openspec-<x>` em `.agents/skills/` (exceções: `openspec-apply-change`, `openspec-update-change`, `openspec-archive-change`, `openspec-sync-specs`). `openspec/changes` é link para `docs/specs`; `openspec/config.yaml` define o schema dos três arquivos. `opsx:apply` é um laço sequencial, sem orquestração de subagentes, mas não os proíbe: o principal roda o laço e delega a subagentes as tarefas independentes, e marca `[x]` após validar. Das pausas da skill, valem só as que são bloqueio do contrato.
- **Matt Pocock**: configurado por `/setup-matt-pocock-skills`. `to-spec` (etapas 2 e 3) e `to-tickets` (etapa 4) gravam nos três arquivos da spec, não no tracker nem em `.scratch/`; issues e tickets, se publicados, só rastreiam. Na etapa 6, `implement-spec` (com subagentes) roda sem worktrees, branches por ticket, merges, commits, PR nem fechamento de tickets: os subagentes trabalham na branch da spec com arquivos disjuntos, cada um com `tdd`; `implement` (sem subagentes) não commita. O `code-review` das duas fica para a etapa 8. Publicar no issue tracker, como as duas fazem por padrão, exige autorização pontual quando a skill não foi invocada pelo usuário.
- **Superpowers**: `brainstorming` e `writing-plans` gravam em `docs/superpowers/` por padrão; o conteúdo vai para os três arquivos da spec.

Novo pacote: acrescente suas skills na linha da etapa e, se gravar fora de `docs/specs`, a regra de normalização.
