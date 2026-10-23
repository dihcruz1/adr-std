# Tarefas — fechamento de pendências

Branch: fix/spec-pending-validation (recriada em 2026-10-22 a partir da main em d858ee9; a anterior estava integrada e foi apagada). Mudanças alheias em AGENTS.md, .gitignore e docs/agents preservadas.

- [x] 1.1 Auditar requirements/design/tasks e registrar Gate 3 (feito com `/opsx:update` em 2026-10-22); escopo: esta spec. Validação: revisão cruzada independente e `git diff --check`. Depende dos Gates 1/2. Após aprovação, commit 1 somente desta spec e apontador openspec/changes.
- [x] 2.1 Corrigir resolução global e testar não regressão; escopo: skill/scripts/adr_cli.py, skill/scripts/migrate_numbering.py, tests/test_adr_cli.py, tests/test_migrate_numbering.py, tests/test_cli.ps1. Depende de 1.1. Validação: `python3 -m unittest discover -s tests -p 'test_*.py'`, `bash tests/test_cli.sh`, Pester quando disponível. RED/GREEN/REFACTOR serão registrados com resultados reais.
  - Evidência: RED: `GlobalConfigHomeTest` (5) e `test_global_config_comes_from_appdata_on_windows` (migrate) falharam (`global_config_home` inexistente; entradas `adr_cli.main`/`migrate_numbering.main` com `sys.platform=win32` ignoravam APPDATA). GREEN: `global_config_home()` em `adr_cli.py`, usada por `adr_cli.main` e `migrate_numbering.main`; `python3 -m pytest tests -q` → `143 passed, 10 subtests`; `bash tests/test_cli.sh` → `72 passaram`. REFACTOR: removidos os dois cálculos duplicados de XDG. Regressão do `path` relativo da config global (spec 2026-10-22) coberta pelos testes existentes.
- [ ] 3.1 Validar e registrar lacunas Windows nativas; escopo: tests/test_cli.ps1 e evidências desta spec. Depende de 2.1 para editar o mesmo arquivo; inspeção somente leitura pode anteceder. Validação: Pester em Windows real (NTFS, .cmd, PATH, integração e conversa); aceita-se o job `test-windows` do CI (D-06). Registro de indisponibilidade mantém esta tarefa aberta. Corrigir skips indevidos de update e o inconclusivo sem terminal, reproduzindo RED antes do ajuste.
  - Evidência: RED: Pester local (PowerShell 7.6.8 no Linux, Pester 6.2.0) antes do ajuste → `Passed: 49, Skipped: 7, Inconclusive: 1` (sete casos do `update` pulados sempre, porque `$HasPython` só existia no `BeforeAll`; um inconclusivo no teste sem terminal). GREEN local: `$HasPython` calculado na fase Discovery e stdin redirecionado com `ADR_STD_ANSWER` removido, exigindo código 3 → `Passed: 57, Failed: 0, Skipped: 0, Inconclusive: 0`. Caso novo `config path gravado pelo wrapper em APPDATA é lido por new e list` roda só no Windows (`-Skip:($env:OS -ne 'Windows_NT')`). Windows nativo: PENDENTE do job `test-windows` (tarefa aberta até o CI).
- [ ] 3.2 Executar cenários reais em dois agentes, --ask/--quick e conversa; escopo: tests/cenarios.md e evidências. Depende de 1.1. Validação: matriz C1–C11 × dois agentes, --ask 0/1/11 e --quick com/sem descrição; T1–T3 por agente aplicável. Saídas/arquivos inspecionados; autenticação indisponível registrada mantém validação correspondente aberta.
  - Evidência (parcial, tarefa aberta): Claude Code, `claude -p`, repositórios descartáveis: Script (`check_adr.py` saída 0 e 1) passou; C1, C2, C3, C4, C5, C6, C8 e C9 passaram; C7 passou pelo plano (substitui ADR-1, nada apagado); C11 falhou na rodada 1 porque o `SKILL.md` listava `migrate` em `adr_cli.py` (defeito de documentação, corrigido) e passou na rodada 2 (plano mostrado, `--apply` só com autorização; variante `numbering: padded` não migrou); C10 inconclusivo, com tendência a falhar (o agente pediu a decisão e não pediu autorização expressa para o commit). Codex: 12 execuções com saída 1 antes de agir (modelo `gpt-6-sol` do config não aceito pela conta ChatGPT): `E2E não executado por autenticação indisponível`. Pendentes e abertos: Codex (C1–C11), Gemini/Antigravity/OpenCode, `--ask` 0/1/11, `--quick` com/sem descrição, T1–T3, e C10 com a decisão no pedido. Relatório bruto no scratchpad da sessão (`cenarios/RELATORIO.md`); resumo em `tests/cenarios.md`.
- [x] 3.3 Confirmar CI, releases e artefatos; escopo: evidências, specs históricas, ROADMAP.md. Depende de 1.1. Validação: `gh release view`, `gh run view`, checksum dos artefatos. Publicação ausente permanece pendente de autorização pontual.
  - Evidência: `gh release list` → releases só de v2.0.1 e v1.4.1; tags v1.0.0 a v2.0.0 existem sem release publicada (v1.0.0 segue sem publicação; nenhuma publicação feita sem autorização pontual). v2.0.1: assets `adr-std.zip` e `adr-std.zip.sha256`, publicada em 2026-10-05T10:33:29Z, checksum conferido na evidência preliminar. CI: run 37296457938 (tag v2.0.1) verde; PR da spec 2026-10-22, run 39886693509 no SHA d858ee9: Gate, Testes ubuntu, macOS e Windows `success`, `Publicar release` `skipped`. v2.0.0 falhou no CI (run 37140021696) e nunca foi publicada.
- [x] 3.4 Destino do `testResults.xml` (RF-07, D-07): registrar o resumo como evidência, ignorar o arquivo no `.gitignore` e removê-lo do disco; escopo: `.gitignore` (só a linha própria), esta spec. Validação: `git check-ignore -v testResults.xml`.
  - Evidência: Resumo do `testResults.xml` de 2026-10-05 (NUnit, Pester em Linux, PowerShell 7.4.6, Pester 5.6.1): 56 testes, 0 erros, 0 falhas, 0 inconclusivos, 7 ignorados (os sete casos do `update` descritos em 3.1), `nunit-version` 2.5.8.0, 12:34:08. Arquivo removido do disco (cópia só no scratchpad da sessão) e `testResults.xml` incluído no `.gitignore`; `git check-ignore -v testResults.xml` → `.gitignore:36`.
- [x] 5.1 Preparar a versão 3.0.0 (RF-08, D-08); escopo: `VERSION`, `CHANGELOG.md`. Depende de 2.1, 3.1 e 4.1. Validação: `bash tests/gate.sh static`, `bash tests/test_cli.sh`; nenhuma tag ou push sem autorização pontual.
  - Evidência: `VERSION` → `3.0.0`; `CHANGELOG.md` com a seção `[3.0.0] - 2026-10-22` (Alterado com quebra de compatibilidade, Adicionado, Corrigido); `[Não lançado]` vazio. `bash tests/gate.sh static` → `Gate static: ok`; `bash tests/test_cli.sh` → `72 passaram`. Sem tag, push de tag ou publicação (dependem de autorização pontual).
- [ ] 4.1 Consolidar estados e auditoria por requisito; escopo: specs históricas, ROADMAP.md, tests/cenarios.md, esta spec. Depende de 2.1 e resultados de 3.x. Validação: `git diff --check`, `python3 skill/scripts/check_roadmap.py docs/architecture/ADR`, `bash tests/gate.sh static`. Revisão de consistência substitui TDD das alterações apenas textuais. Commit 2 de implementação/testes/auditoria; não incluir AGENTS.md alheio.
  - Evidência: ver a seção "Auditoria por requisito" abaixo (tarefa fechada só para o que tem evidência; 3.1 e 3.2 permanecem abertas).

## Rastreabilidade

RF-01/RF-02/RF-03 e SEG-01/02 → D-01/02/03 → 2.1; RF-04 → D-03/04 → 3.1; RF-05 → D-05 → 3.2; RF-06 → D-04 → 3.3/4.1; RF-07 → D-07 → 3.4; RF-08 → D-08 → 5.1; SEG-03/04 → todas as tarefas.

## Gate 3

2026-10-05: `/opsx:update` indisponível. 2026-10-22: revisão feita com `/opsx:update`; ajustes aplicados (base e branch, D-06 a D-08, RF-07, RF-08, tarefas 3.4 e 5.1, nota sobre a spec 2026-10-22). Gate 3 satisfeito.

## Evidências preliminares (antes da implementação)

- Baseline Python: `python3 -m unittest discover -s tests -p 'test_*.py'` → 110 aprovados em 2026-10-05.
- Release pública v2.0.1: SHA256 `fc5e148cc44b25cb216531e3ffd0f8a015e264d6e63255efa056803f10fe18cf` coincide; instalação Linux em HOME/XDG temporários para Claude Code e Codex, version/status/check (19 itens), uninstall seletivo e self-uninstall aprovados, todos saída 0. Isto não comprova as quatro formas/sistemas nem a release v1.0.0.
- Nenhum Windows remoto documentado no repositório; host Linux. PowerShell portátil 7.4.6 disponível para validação parcial, Pester 5.6.1 já instalado.
- Revisão independente identificou e ajustou cobertura por cenário, distinção bloqueio/conclusão, baseline de CI, exigência de Windows nativo, sequência de edição, contrato de fallback e marcos de commit.

## Auditoria por requisito (2026-10-22)

| Requisito | Evidência | Resultado |
|---|---|---|
| RF-01 (APPDATA no Windows; XDG nos demais) | `GlobalConfigHomeTest`, `test_cli_main_reads_appdata_on_windows`, `test_global_config_comes_from_appdata_on_windows`; 143 testes Python verdes | Atendido (Python); Windows nativo pendente de CI |
| RF-02 (resolução compartilhada, precedência preservada) | `global_config_home()` usada por `adr_cli.main` e `migrate_numbering.main`; `ResolveFolderTest::test_precedence` | Atendido |
| RF-03 (gravação do wrapper lida pela CLI/migração) | Caso Pester só Windows escrito; unitários cobrem a leitura | Parcial: falta o job `test-windows` |
| RF-04 (identificar junção NTFS, `.cmd`, PATH e conversa; sem tratar skip como aprovação) | Pester local 57 passados, 0 pulados, 0 inconclusivos (antes 49/7/1); casos nativos dependem do CI Windows | Parcial |
| RF-05 (cenários reais em dois agentes) | Claude Code: Script, C1–C9 e C11 passaram, C10 inconclusivo; Codex bloqueado por modelo/conta | Aberto |
| RF-06 (releases e CI por evidência externa) | tarefa 3.3 | Atendido |
| RF-07 (`testResults.xml`) | tarefa 3.4 | Atendido |
| RF-08 (número da versão) | `VERSION` 3.0.0 e `CHANGELOG.md`; tag e publicação não feitas | Atendido (preparo) |

Pendências: job `test-windows` no CI (exige push e PR, autorizados em 2026-10-22 apenas para a reescrita; o push da branch ainda depende de autorização); cenários do Codex e dos demais agentes; `--ask`/`--quick`/T1–T3 interativos; C10 com a decisão no pedido.
