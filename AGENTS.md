# Contrato SDD

Aplica-se a agentes, skills, pacotes e wrappers.

## Regras

- Documentação e respostas em pt-BR; código, arquivos, testes e comandos em inglês; Linguagem Ubíqua do domínio.
- Rode `git status` antes de alterar e antes de cada commit; preserve mudanças alheias e comportamento fora do escopo.
- Specs só em `docs/specs/<AAAA-MM-DD>-<nome>/` (`requirements.md`, `design.md`, `tasks.md`); `openspec/changes` é acesso local à mesma fonte; não rode `openspec archive`.
- IDs em `tasks.md` em texto puro (`1.1`), sem negrito ou decoração: verificações automáticas dependem disso.
- DevSecOps: segurança é requisito desde o `requirements.md`, com riscos registrados na spec/ADR; todo CI/CD criado aqui tem gate de segurança antes do deploy.
- Design: reutilize arquitetura e código existentes; precedência: segurança e spec > KISS/YAGNI > padrões.
  - YAGNI mede-se contra o `requirements.md`, nunca contra segurança ou requisitos não funcionais.
  - Rule of Three: abstraia na 3ª ocorrência da mesma regra no repositório (confirme com `cg-search`); regra de segurança tem fonte única desde a 2ª.
  - DDD tático só com invariantes de domínio: entidades ricas e Value Objects imutáveis; Repositório/Gateway só para isolar I/O externo substituível em teste; Agregados e Domain Events só com ADR.

## Autonomia

Avance sozinho pelo fluxo, inclusive commits e merge locais; gates são checkpoints técnicos com evidência registrada no artefato. Autorização expressa e pontual só para: push, deploy, migrations em banco real, uso de segredos, ampliação material de escopo e decisão de produto/arquitetura sem fonte de verdade no repositório. Nunca solicite, gere, exiba ou preencha credenciais reais.

## Fluxo

Demanda simples: implemente com testes. Demanda complexa ou defeito:

1. Explore o código (ver CodeGraph).
2. ADR, se aplicável, revisado → commit 1 (ADR e artefatos diretamente necessários). Sem ADR, não há commit 1.
3. `requirements.md`: EARS/Gherkin; em defeitos, causa-raiz e matriz de não-regressão (Gate 1).
4. `design.md`: contratos, estratégia de testes e seção "Modelo de domínio" (padrões DDD aplicados ou `N/A` justificado) (Gate 2).
5. `tasks.md`: tarefas atômicas, ordenadas por dependência, cada uma com RED, GREEN e validação; registre a execução (uma por vez com subagente, ou independentes em paralelo).
6. Auditoria 360° requisitos ↔ design ↔ tarefas (Gate 3) → commit 2 (só artefatos da spec).
7. TDD (RED → GREEN → REFACTOR); tarefa concluída só com evidência de teste.
8. Testes automáticos da spec inteira, E2E aplicável e auditoria da implementação → commit 3 (implementação, testes e ajustes de `tasks.md`).
9. Integração: `git merge <base>` (ex.: `develop`) na branch de trabalho; conflitos com a skill `resolving-merge-conflicts`, preservando ambas as intenções; testes verdes → merge na base. Testes falhando ou conflito irreconciliável: pare e registre o bloqueio.

Commits: `git add` só com caminhos explícitos do marco (nunca `git add -A`); mensagem sem referência a agente, IA ou ferramentas.

E2E: rode sem autenticação interativa. Se exigir login, confirmação, código ou credencial, registre `E2E bloqueado por autenticação interativa` na spec e na auditoria, rode os demais testes e siga. E2E obrigatório bloqueado impede declarar concluído, commit 3 e merge (commits 1 e 2 seguem); complementar vira lacuna registrada.

## CodeGraph

`cg-agent` e `cg-*` servem só para explorar: não substituem specs, ADRs, gates ou tarefas, nem autorizam alterações ou operações protegidas.

- Antes de explorar muitos arquivos, rode uma vez por tarefa `cg-agent "<resumo abstrato>"` (`--offline` se o planner remoto falhar); repita só se o escopo mudar. O resumo não leva código-fonte, segredos, variáveis de ambiente, diffs nem caminhos absolutos.
- Parta de `symbols`, `impact`, `callers`, `callees`, `context` e `related_tests`; confirme o código real antes de alterar.
- Consultas pontuais: `cg-search`, `cg-info`, `cg-context`, `cg-impact`, `cg-tests`, `cg-callers`, `cg-callees`, com argumentos de `cg-help` ou de arquivo/linha já retornados. Sempre via CLI, nunca MCP.
- Ferramenta indisponível (sandbox/`PATH`): peça execução fora da sandbox sem varrer sistema, históricos ou configurações; persistindo, informe a limitação antes de explorar por outros meios.
- Pedidos só de análise: leia os testes relacionados; execute-os só a pedido ou se necessário para responder.

## Agent skills

### Issue tracker

Issues no GitHub (dihcruz1/adr-std). Veja `docs/agents/issue-tracker.md`.

### Triage labels

Labels padrão do ecossistema Matt Pocock. Veja `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` na raiz + ADRs em `docs/architecture/ADR/`. Veja `docs/agents/domain.md`.