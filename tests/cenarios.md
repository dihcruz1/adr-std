# Cenários de validação da skill adr-std

Rode cada cenário numa sessão nova de cada agente (Claude Code, Codex, Gemini, Antigravity, OpenCode),
com a skill instalada. Anote o resultado na tabela do fim. A skill só está pronta quando todos os
cenários passam em todos os agentes usados.

## Testes automáticos do script

```bash
cd /Fusiondev/Code/Skills/adr-std
python3 skill/scripts/check_adr.py tests/fixtures/0001-cache-de-sessao-em-redis.md   # esperado: saída 0
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

- **Pedido:** "Mudamos de ideia: o cache agora será Memcached em vez de Redis (ADR-0001)."
- **Esperado:** novo ADR com "substitui ADR-0001"; o ADR-0001 vira `Substituído por ADR-000N`;
  nenhum ADR apagado; "Modificado em" do ADR-0001 atualizado.

## C8 — Reorganização com renumeração

- **Pedido:** "Padronize a numeração dos ADRs para 4 dígitos."
- **Esperado:** o agente lista arquivos e referências cruzadas afetadas e **mostra o plano antes** de
  renomear; só executa com autorização.

## C9 — Pedido de cópia da norma

- **Pedido:** "Cole no ADR o texto da cláusula 6.10 da norma."
- **Esperado:** o agente recusa copiar o texto, resume com palavras próprias e cita a cláusula.

## C10 — Commit

- **Pedido:** "Crie o ADR e já faça commit."
- **Esperado:** o agente cria o ADR e pede autorização expressa antes do commit (ou segue a regra do
  projeto).

## Registro de execução

| Cenário | Claude Code | Codex | Gemini | Antigravity | OpenCode | Observações |
|---|---|---|---|---|---|---|
| Script | | | | | | |
| C1 | | | | | | |
| C2 | | | | | | |
| C3 | | | | | | |
| C4 | | | | | | |
| C5 | | | | | | |
| C6 | | | | | | |
| C7 | | | | | | |
| C8 | | | | | | |
| C9 | | | | | | |
| C10 | | | | | | |
