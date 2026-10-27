# Contrato SDD

Aplica-se a agentes, skills, pacotes e wrappers.

## Regras

- Documentação e respostas em pt-BR; código, arquivos, testes e comandos em inglês. Use Linguagem Ubíqua.
- Antes de alterar, execute `git status`; preserve mudanças existentes, comportamentos fora do escopo e o escopo aprovado.
- Exija autorização expressa e pontual para migrations, commit, push, merge, rebase, deploy e uso de segredos. Nunca solicite, gere, manipule ou preencha credenciais reais.
- Reutilize arquitetura e código. Aplique DDD tático, KISS, YAGNI e Rule of Three: entidades ricas; Value Objects imutáveis; mutações pela Raiz do Agregado; infraestrutura atrás de Repositórios/Gateways; Domain Events entre Bounded Contexts; abstração somente após terceira repetição comprovada.
- Specs somente em `docs/specs/<AAAA-MM-DD>-<nome>/`, com `requirements.md`, `design.md` e `tasks.md`. Não duplique, sincronize ou arquive fora desse diretório. `openspec/changes` é acesso local à mesma fonte; não execute `openspec archive`.
- Em `tasks.md`, o ID de cada tarefa vai sempre em texto puro (ex.: `1.1`), nunca em negrito markdown (`**1.1**`) nem outra decoração — verificações automáticas de specs dependem desse formato literal para reconhecer a tarefa.
- DevSecOps: segurança é requisito desde o `requirements.md`, não etapa posterior; registre riscos de segurança na spec/ADR; todo CI/CD criado aqui DEVE ter gate de segurança antes de deploy.

## Fluxo

- Demanda simples: implemente com testes.
- Demanda complexa ou defeito: explore -> crie mudança e `requirements.md` com SDD, EARS/Gherkin e, em defeitos, causa-raiz e matriz de não-regressão (Gate 1: aprovação) -> `design.md` com DDD, KISS, YAGNI, contratos e estratégia de testes (Gate 2: aprovação) -> `tasks.md` atômico, ordenado por dependências, com RED, GREEN e validação -> auditoria 360° (Requisitos <-> Design <-> Tarefas; Gate 3: aprovação).
- Antes do código, proponha: uma tarefa por vez com subagente, ou plano completo com tarefas independentes em paralelo. Execute TDD: RED -> GREEN -> REFACTOR; marque tarefa concluída somente com evidência de testes.
- Execute E2E quando aplicável: Playwright visível e persistente; pause para login manual e prossiga após confirmação. Ao final, verifique a entrega contra requisitos, design e tarefas.

## Commit

- Não faça commit sem autorização expressa nesta sessão; não inclua referências a agente, IA ou ferramentas.
- Antes de sugerir, explique em pt-BR simples, sem termos técnicos internos, e mostre `git add` com arquivos específicos e `git commit -m`.
