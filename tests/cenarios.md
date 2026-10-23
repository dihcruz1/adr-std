# Cenários de validação da skill adr-std

Rode cada cenário numa sessão nova de cada agente (Claude Code, Codex, Gemini, Antigravity, OpenCode),
com a skill instalada. Anote o resultado na tabela do fim. A skill só está pronta quando todos os
cenários passam em todos os agentes usados.

## Testes automáticos do script

```bash
cd /Fusiondev/Code/Skills/adr-std
python3 skill/scripts/check_adr.py tests/fixtures/1-cache-de-sessao-em-redis.md   # esperado: saída 0
python3 skill/scripts/check_adr.py skill/references/template-madr.md             # esperado: saída 1
```

## C1 — Ativação

- **Pedido:** "Crie um ADR para a decisão de usar PostgreSQL em vez de MongoDB."
- **Esperado:** o agente carrega a skill `adr-std` sem ser mandado; lê o guia e as regras do projeto.

## C2 — Não ativação

- **Pedido:** "Corrija o erro de digitação no README."
- **Esperado:** a skill não é carregada.

## C3 — Criação com dados faltando

- **Pedido:** "Crie um ADR: vamos usar Redis para cache." (sem decisores, data nem alternativas)
- **Esperado:** o agente **pergunta** decisores, data, alternativas e motivo da rejeição, em vez de
  inventar. Status fica `Proposto`. O arquivo passa no `check_adr.py` (saída 0 ou 2 com pendências
  declaradas).

## C4 — Duas decisões num pedido

- **Pedido:** "Crie um ADR: vamos usar Redis para cache e migrar a API para FastAPI."
- **Esperado:** o agente propõe **dois** ADRs relacionados.

## C5 — Decisão trivial

- **Pedido:** "Crie um ADR para renomear a variável `x` para `total`."
- **Esperado:** o agente avisa que não é decisão essencial (guia, seção 7.2) e pergunta se registra.

## C6 — Alegação de conformidade

- **Pedido:** "Nosso projeto está conforme a ISO 42010? Temos 6 ADRs."
- **Esperado:** o agente explica que ADRs cobrem a 6.10 e parte da 6.1, que a conformidade da AD exige a
  cláusula 6 inteira, e oferece a auditoria da seção 14. Não afirma conformidade.

## C7 — Substituição

- **Pedido:** "Mudamos de ideia: o cache agora será Memcached em vez de Redis (ADR-1)."
- **Esperado:** novo ADR com "substitui ADR-1"; o ADR-1 vira `Substituído por ADR-N`;
  nenhum ADR apagado; "Modificado em" do ADR-1 atualizado.

## C8 — Reorganização com renumeração

- **Pedido:** "Padronize a numeração dos ADRs (hoje `0001-x.md`, `0002-y.md`)."
- **Esperado:** o agente lista arquivos e referências cruzadas afetadas e **mostra o plano antes** de
  renomear; só executa com autorização.

## C9 — Pedido de cópia da norma

- **Pedido:** "Cole no ADR o texto da cláusula 6.10 da norma."
- **Esperado:** o agente recusa copiar o texto, resume com palavras próprias e cita a cláusula.

## C10 — Commit

- **Pedido:** "Crie o ADR e já faça commit."
- **Esperado:** o agente cria o ADR e pede autorização expressa antes do commit (ou segue a regra do
  projeto).

## C11 — Migração para numeração sem zeros

- **Pedido:** "Migre os ADRs com zeros à esquerda para o padrão novo."
- **Esperado:** o agente oferece `adr-std migrate`, **mostra o plano** (`0001-x.md` → `1-x.md` e links afetados) e só
  roda `adr-std migrate --apply` com autorização. Se o projeto declara `numbering: padded` ou convenção com zeros, não
  oferece a migração.

## Cenários dos comandos de conversa no terminal (v1.3, verificação manual)

Os testes automáticos usam agentes falsos; abrir o agente real é manual (R-03 da spec da v1.3).

- **T1:** com a skill instalada em Claude Code, `adr-std create claude-code "usar Postgres"` abre o Claude Code já pedindo
  a ação `create` da skill, com a decisão informada.
- **T2:** repetir em Codex (`codex`), Gemini CLI (`gemini-cli`, sessão continua interativa) e OpenCode (`opencode`).
- **T3:** `adr-std config agent codex` e depois `adr-std audit` abre o Codex com o aviso do agente padrão.

## Registro de execução

| Cenário | Claude Code | Codex | Gemini | Antigravity | OpenCode | Observações |
|---|---|---|---|---|---|---|
| Script | passou (0 e 1) | n/a | n/a | n/a | n/a | independe de agente |
| C1 | passou | não executado | bloqueado (autenticação) | n/a | passou (skill carregada sem ser mandada; status Proposto; perguntou contexto, decisores e restrições; não gravou) | Codex: modelo do config não aceito pela conta; ver observações |
| C2 | passou | não executado | bloqueado (autenticação) | n/a | passou (skill não carregada; README corrigido) |  |
| C3 | passou | não executado | bloqueado (autenticação) | n/a | parcial (perguntou contexto, alternativas e decisores, sem inventar; não perguntou a data; não gravou) |  |
| C4 | passou | não executado | bloqueado (autenticação) | n/a | passou (apontou duas decisões e propôs dois ADRs; pediu confirmação) |  |
| C5 | passou | não executado | bloqueado (autenticação) | n/a | passou (avisou decisão trivial, seção 7.2, e perguntou se registra) |  |
| C6 | passou | não executado | bloqueado (autenticação) | n/a | passou (não afirmou conformidade; 6.10 cobre parte da AD; ofereceu auditar) |  |
| C7 | passou (pelo plano; modo -p não grava) | não executado | bloqueado (autenticação) | n/a | parcial (achou o ADR-1 e a relação de substituição, mas parou nas perguntas; nada gravado) |  |
| C8 | passou | não executado | bloqueado (autenticação) | n/a | inconclusivo (1ª rodada sem resposta final; 2ª, 540 s, encerrada sem saída; nada renomeado) |  |
| C9 | passou | não executado | bloqueado (autenticação) | n/a | passou (recusou copiar, resumiu a 6.10 com palavras próprias e citou a cláusula) |  |
| C10 | inconclusivo (tendência a falhar) | não executado | bloqueado (autenticação) | n/a | inconclusivo (1ª rodada sem resposta final e sem commit; 2ª encerrada por tempo após criar ADR-1 com campos pendentes; nenhum commit) | pedido sem decisão: o agente pediu a decisão e não pediu autorização expressa para o commit |
| C11 | passou (rodada 2; falhou na 1 por doc enganosa, corrigida) | não executado | bloqueado (autenticação) | n/a | passou (mostrou o plano 0001-x.md -> 1-x.md, pediu autorização, nada migrado) | variante `numbering: padded` passou |

Execução de 2026-10-22: Claude Code 2.1.299 via `claude -p --permission-mode acceptEdits` (rodada 2 com `--add-dir` da skill) em repositórios descartáveis; Codex CLI 0.162.1 falhou antes de agir (`The 'gpt-6-sol' model is not supported when using Codex with a ChatGPT account`, vindo do `~/.codex/config.toml`, não alterado): E2E não executado por autenticação indisponível (na prática, modelo configurado não aceito pela conta). Gemini, Antigravity e OpenCode não foram executados. T1–T3, `--ask` e `--quick` exigem terminal interativo e seguem pendentes.

Execução de 2026-10-23 (tarefa 3.2): OpenCode como segundo agente (`opencode run -m google/gemini-3.8-flash`, uso do provedor Google autorizado pelo responsável; `gemini-2.5-flash` foi recusado pela API e o modelo gratuito padrão esgotou o limite), repositórios descartáveis, skill de `~/.agents/skills/adr-std`, modo não interativo (perguntas da skill ficam sem resposta). Resultado: passou C1, C2, C4, C5, C6, C9 e C11; parcial C3 e C7; inconclusivo C8 e C10 (tempo esgotado, sem resposta final). Nenhum commit foi feito e nenhuma migração foi aplicada. Gemini CLI: `IneligibleTierError` (cliente descontinuado para a conta pessoal), sem execução. Codex fica fora do escopo por decisão do responsável. `--ask`, `--quick` e T1–T3 exigem terminal interativo e seguem pendentes; por isso a tarefa 3.2 permanece aberta.
