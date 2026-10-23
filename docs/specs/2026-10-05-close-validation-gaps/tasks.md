# Tarefas — fechamento de pendências

Branch: fix/spec-pending-validation (recriada em 2026-10-22 a partir da main em d858ee9; a anterior estava integrada e foi apagada). Mudanças alheias em AGENTS.md, .gitignore e docs/agents preservadas.

- [x] 1.1 Auditar requirements/design/tasks e registrar Gate 3 (feito com `/opsx:update` em 2026-10-22); escopo: esta spec. Validação: revisão cruzada independente e `git diff --check`. Depende dos Gates 1/2. Após aprovação, commit 1 somente desta spec e apontador openspec/changes.
- [ ] 2.1 Corrigir resolução global e testar não regressão; escopo: skill/scripts/adr_cli.py, skill/scripts/migrate_numbering.py, tests/test_adr_cli.py, tests/test_migrate_numbering.py, tests/test_cli.ps1. Depende de 1.1. Validação: `python3 -m unittest discover -s tests -p 'test_*.py'`, `bash tests/test_cli.sh`, Pester quando disponível. RED/GREEN/REFACTOR serão registrados com resultados reais.
- [ ] 3.1 Validar e registrar lacunas Windows nativas; escopo: tests/test_cli.ps1 e evidências desta spec. Depende de 2.1 para editar o mesmo arquivo; inspeção somente leitura pode anteceder. Validação: Pester em Windows real (NTFS, .cmd, PATH, integração e conversa); aceita-se o job `test-windows` do CI (D-06). Registro de indisponibilidade mantém esta tarefa aberta. Corrigir skips indevidos de update e o inconclusivo sem terminal, reproduzindo RED antes do ajuste.
- [ ] 3.2 Executar cenários reais em dois agentes, --ask/--quick e conversa; escopo: tests/cenarios.md e evidências. Depende de 1.1. Validação: matriz C1–C11 × dois agentes, --ask 0/1/11 e --quick com/sem descrição; T1–T3 por agente aplicável. Saídas/arquivos inspecionados; autenticação indisponível registrada mantém validação correspondente aberta.
- [ ] 3.3 Confirmar CI, releases e artefatos; escopo: evidências, specs históricas, ROADMAP.md. Depende de 1.1. Validação: `gh release view`, `gh run view`, checksum dos artefatos. Publicação ausente permanece pendente de autorização pontual.
- [ ] 3.4 Destino do `testResults.xml` (RF-07, D-07): registrar o resumo como evidência, ignorar o arquivo no `.gitignore` e removê-lo do disco; escopo: `.gitignore` (só a linha própria), esta spec. Validação: `git check-ignore -v testResults.xml`.
- [ ] 5.1 Preparar a versão 3.0.0 (RF-08, D-08); escopo: `VERSION`, `CHANGELOG.md`. Depende de 2.1, 3.1 e 4.1. Validação: `bash tests/gate.sh static`, `bash tests/test_cli.sh`; nenhuma tag ou push sem autorização pontual.
- [ ] 4.1 Consolidar estados e auditoria por requisito; escopo: specs históricas, ROADMAP.md, tests/cenarios.md, esta spec. Depende de 2.1 e resultados de 3.x. Validação: `git diff --check`, `python3 skill/scripts/check_roadmap.py docs/architecture/ADR`, `bash tests/gate.sh static`. Revisão de consistência substitui TDD das alterações apenas textuais. Commit 2 de implementação/testes/auditoria; não incluir AGENTS.md alheio.

## Rastreabilidade

RF-01/RF-02/RF-03 e SEG-01/02 → D-01/02/03 → 2.1; RF-04 → D-03/04 → 3.1; RF-05 → D-05 → 3.2; RF-06 → D-04 → 3.3/4.1; RF-07 → D-07 → 3.4; RF-08 → D-08 → 5.1; SEG-03/04 → todas as tarefas.

## Gate 3

2026-10-05: `/opsx:update` indisponível. 2026-10-22: revisão feita com `/opsx:update`; ajustes aplicados (base e branch, D-06 a D-08, RF-07, RF-08, tarefas 3.4 e 5.1, nota sobre a spec 2026-10-22). Gate 3 satisfeito.

## Evidências preliminares (antes da implementação)

- Baseline Python: `python3 -m unittest discover -s tests -p 'test_*.py'` → 110 aprovados em 2026-10-05.
- Release pública v2.0.1: SHA256 `fc5e148cc44b25cb216531e3ffd0f8a015e264d6e63255efa056803f10fe18cf` coincide; instalação Linux em HOME/XDG temporários para Claude Code e Codex, version/status/check (19 itens), uninstall seletivo e self-uninstall aprovados, todos saída 0. Isto não comprova as quatro formas/sistemas nem a release v1.0.0.
- Nenhum Windows remoto documentado no repositório; host Linux. PowerShell portátil 7.4.6 disponível para validação parcial, Pester 5.6.1 já instalado.
- Revisão independente identificou e ajustou cobertura por cenário, distinção bloqueio/conclusão, baseline de CI, exigência de Windows nativo, sequência de edição, contrato de fallback e marcos de commit.
