# Contrato SDD

Vale para agentes, subagentes, skills, pacotes e wrappers; delegação não amplia permissões. Prevalece sobre qualquer skill, inclusive a invocada pelo usuário: passo que o viole é adaptado (ex.: gravação redirecionada para a spec) ou, se impossível, pulado; registre o desvio em `tasks.md` ou, sem spec, na entrega.

## Regras

- Documentação/respostas/commits em pt-BR; identificadores, arquivos, testes e comandos em inglês; respeite Linguagem Ubíqua (`GLOSSARY.md`) e convenções existentes. Prosa nova, em documentação e comentários, sem travessões (—).
- Respostas ao usuário curtas, claras e objetivas: só o resultado, o que mudou e o que depende dele; sem repetir contexto, listar o óbvio ou detalhar o que está registrado em arquivo (aponte o caminho).
- Preserve mudanças alheias e comportamento fora do escopo; reutilize arquitetura/código.
- **DevSecOps em todo o ciclo:** cada etapa entrega sua parte de segurança. Requisitos trazem ameaças, riscos e mitigações; design, as decisões de segurança; tarefas, testes de segurança no RED e validação; código, imagem, artefatos e logs ficam sem segredos. Build, CI/CD ou deploy criado ou alterado exige gate de segurança pré-deploy bloqueante: testes, auditoria de dependências, busca de segredos, análise estática e, havendo imagem, scan da imagem.
- Precedência em conflito: Segurança > spec > KISS/YAGNI > padrões. KISS/YAGNI é opcional, aplicado quando o agente julgar útil, e preserva requisitos funcionais, não funcionais e de segurança.
- Rule of Three como referência: avalie abstração a partir da terceira repetição confirmada no código. Regra de segurança tem fonte única desde a segunda.
- DDD tático só com invariantes: entidades ricas, Value Objects imutáveis; Repositório/Gateway só para I/O externo substituível em teste. Agregados/Domain Events justificados no design; ADR opcional.

## Spec

- Fonte única: `docs/specs/<AAAA-MM-DD>-<nome>/{requirements,design,tasks}.md`. Saída de skill gravada em outro lugar (issue, pasta do pacote) é convertida para esses três arquivos, e o arquivo da skill é removido; ferramentas que exigem outro caminho apontam para eles, sem cópia.
- Specs ficam no lugar após concluídas: proibido arquivar ou mover (ex.: `openspec archive`).

## Git e commits

- Branch própria; base e commits de terceiros intactos. `git status` antes de alterar/commitar; `git add` só com caminhos explícitos e trechos próprios; confira o diff staged.
- Mensagem de commit: uma frase que descreve o que foi feito de modo que quem não está no projeto entenda; ferramentas podem ser citadas. Válida: "Implanta o LangGraph como framework padrão". Inválida: "Implanta a spec 2, tasks a2 e a3". Fica de fora: identificadores de spec, tarefa, requisito, decisão ou ADR; referência à IA ou ao agente que fez a mudança; linhas de coautoria ou atribuição.
- Marcos: demanda simples, um commit após a validação; complexa ou defeito, exatamente dois commits. Commit 1 (spec, glossário, ADRs e documentos que a spec atualiza) com a spec fechada: três arquivos aprovados, auditoria cruzada executada com suas correções gravadas e, havendo nova aprovação depois delas, essa aprovação dada. Commit 2 (implementação, testes, `tasks.md` e revisões posteriores de spec, glossário e ADRs) com a demanda fechada: auditoria final sem discrepância, testes e E2E aplicáveis executados, nenhuma pendência além da prevista em "Autenticação". Pedido de commit fora dos marcos: avise o conflito e proponha levar o conteúdo ao próximo marco; só commite à parte com confirmação explícita depois do aviso. Mudança depois do commit 1, seja de escopo ou achado de testes e auditoria, reabre os gates afetados: atualize spec e auditoria no working tree; tudo entra no commit 2 após nova aprovação. Consolidar ou reescrever commits próprios só com autorização.
- **Merge exclusivo do humano:** proíba `git merge`, `git pull` com merge, conclusão de PR/MR e auto-merge por qualquer meio/delegação; não contorne com rebase, cherry-pick ou atualização da base. Integração em andamento: registre e pare, sem continuar/abortar.
- **Push e PR/MR só a pedido:** sem pedido explícito do usuário, o agente não oferece, não sugere nem inclui push, PR/MR ou abertura de MR em respostas ou comandos. Pedido de merge local recebe só comandos locais.

## Execução

Subagentes só quando a tarefa for grande (leitura extensa ou trabalho independente que compense o custo em tokens): dependências em sequência, tarefas independentes em paralelo na mesma branch, sem disputar arquivos; o principal coordena e valida. Sem subagentes, registre o motivo e o principal executa com a skill do pacote da spec para execução sem subagentes, escolhida como em "Escolha de skill".

**Custo e modelo:** o limite de uso do responsável é recurso escasso; avalie custo-benefício antes de delegar. Exploração, busca e mapa de usos: modelo leve (`haiku` ou `sonnet`). Auditoria requisito → evidência e tarefa atômica: `sonnet`. Design, decisão de segurança e revisão adversarial: o modelo mais forte, só onde o erro custa caro. O que cabe em poucas chamadas, o principal faz direto, sem subagente; paralelize só tarefas realmente independentes. Suíte completa só após mudança de código; durante o desenvolvimento, rode os testes do módulo. Informe o modelo ao delegar; sem como escolher, registre.

**Escolha de skill:** cada etapa do Fluxo começa invocando sua skill, escolhida nesta ordem:

1. a que o usuário invocou para aquela etapa;
2. a do **pacote da spec**: o pacote da primeira skill usada na demanda, inclusive a invocada pelo usuário só para explorar, que vale até o commit 2;
3. etapa sem skill do pacote: a de outro pacote, se ela executa a etapa sem conflito com este contrato e com o registro nos três arquivos da spec;
4. nenhuma skill de pacote algum executa a etapa sem conflito: o próprio agente a executa como uma skill faria, seguindo o Fluxo e registrando nos três arquivos da spec.

Os itens 3 e 4 valem para qualquer etapa do Fluxo, da 1 à 9. Leia `docs/agents/sdd-skills.md` antes de escolher: ele mapeia etapas, pacotes e skills, com exemplos e regras de normalização de cada pacote. Skill invocada pelo usuário cobre só as etapas dela; a seguinte volta a esta ordem. Registre em `tasks.md` a skill usada em cada etapa. Skills que se autoinvocam seguem essa ordem.

Autorização pontual para push, deploy, migrations em banco real, escrita no issue tracker fora de skill invocada pelo usuário, ampliação material de escopo e decisão de produto/arquitetura sem fonte no repositório.

## Fluxo

Demanda simples (mudança localizada, sem contrato novo, decisão de arquitetura ou requisito de segurança; na dúvida, complexa): implemente/teste proporcionalmente. Só documentação: revisão de consistência substitui TDD/testes de comportamento.

Complexa ou defeito, cada etapa termina com sua saída pronta:

1. **Explorar:** código, testes, `GLOSSARY.md` e ADRs relacionados lidos; dúvidas de produto respondidas.
2. **Requisitos:** `requirements.md` em EARS/Gherkin com critérios verificáveis; defeito: causa-raiz e matriz de não-regressão → Gate 1.
3. **Design:** `design.md` com contratos, decisões/justificativas, estratégia de testes e "Modelo de domínio" (DDD ou `N/A` justificado) → Gate 2.
4. **Tarefas:** `tasks.md` com tarefas atômicas por dependência e etapa/camada; checkbox, ID em texto puro (`1.1`), escopo/arquivos e comando de validação.
5. **Auditoria cruzada:** requisitos ↔ design ↔ tarefas com rastreabilidade integral, Linguagem Ubíqua e decisões DDD; ajustes mostrados antes de gravar, código intocado; resultado registrado em `tasks.md` → Gate 3 → commit 1.
6. **TDD:** o plano inteiro, sem pausa entre tarefas; para só em bloqueio deste contrato (ampliação de escopo, decisão sem fonte, teste obrigatório com falha sem solução). RED → GREEN → REFACTOR por tarefa; registre em `tasks.md` cenários/limites/invariantes, falha esperada no RED, implementação, refatoração (ou `N/A` justificado) e resultado da validação. Marque `[x]` só com evidência real.
7. **E2E aplicável:** cenários executados de ponta a ponta no navegador contra URL de teste, com `playwright-cli open --browser=chrome --headed --persistent <url>` e login como em "Autenticação".
8. **Auditoria final:** implementação contra os três arquivos, com evidência de cobertura por requisito, testes executados, discrepâncias e trabalho pendente, registrada em `tasks.md`. O agente corrige sem perguntar toda discrepância entre a implementação e a spec aprovada e repete a auditoria até não haver discrepância; achado que muda requisito, design ou tarefa reabre o gate afetado. Ao terminar, informa ao responsável que a auditoria rodou, quantas rodadas, o que encontrou e como resolveu cada achado, o que ficou como juízo sem ação e o que segue pendente → commit 2.
9. **Entrega:** branch/base, commits e auditoria para revisão/integração humanas.

Gates exigem evidência e aprovação do responsável. Gate reprovado ou teste obrigatório com falha bloqueia o marco: registre motivo e próximo passo. A demanda só é concluída quando todo requisito, decisão e tarefa tem evidência; teste não executado consta como pendente, nunca como aprovado.

## Autenticação

Credenciais vêm de caminhos/cofres configurados, por injeção automática, sem nova autorização/interação; outra origem exige autorização pontual. Nunca solicite, gere, exiba, preencha manualmente ou copie credenciais reais para código/comandos/logs/artefatos; valores fictícios em testes são permitidos.

Login no E2E, nesta ordem:

1. **Cofre configurado:** o agente pega a credencial no cofre e a injeta na página sem lê-la, e faz o login.
2. **Sem cofre, com humano na sessão:** o agente abre a tela de login, avisa o responsável e aguarda a autenticação humana; segue quando a sessão estiver autenticada.
3. **Sem cofre e agente orquestrado (sem humano para autenticar):** registre `E2E não executado por autenticação indisponível`, cenários pendentes e impacto na spec/auditoria; siga com testes, auditoria e commit 2. É a única pendência de E2E aceita no commit 2.

## Agent skills

- Issue tracker: GitHub Issues via `gh`; ver `docs/agents/issue-tracker.md`.
- Triage labels: vocabulário padrão; ver `docs/agents/triage-labels.md`.
- Domain docs: single-context (`GLOSSARY.md` e ADRs); ver `docs/agents/domain.md`.
