# Tarefas — resolução da pasta de ADRs a partir da raiz do repositório

Data: 2026-10-22. Requisitos: `requirements.md`; design: `design.md`. Marque `[x]` só com evidência real (comando e resultado) no campo **Evidência** de cada tarefa.

Convenção: cada tarefa de código segue RED → GREEN → REFACTOR. Comandos rodam da raiz do repositório. Testes de integração usam repositórios temporários (`git init -q`) e `XDG_CONFIG_HOME` isolado.

## Etapa 0 — Preparação

- [x] 0.1 Criar a branch `fix/adr-cli-resolucao-de-pasta` a partir do estado atual, sem tocar nos arquivos alheios (`AGENTS.md`, `CLAUDE.md`, `docs/agents/*`, `docs/specs/2026-10-05-close-validation-gaps/`, `openspec/`, `testResults.xml`).
  - Escopo: apenas Git. Validação: `git branch --show-current` e `git status --short` inalterado nos arquivos alheios.
  - Evidência: `git switch -c fix/adr-cli-resolucao-de-pasta` → branch atual `fix/adr-cli-resolucao-de-pasta`; `git status --short` mantém os arquivos alheios como estavam.

## Etapa 1 — Testes RED (reprodução do defeito e matriz)

- [x] 1.1 Integração em `tests/test_adr_cli.py`: reprodução do briefing e RF-01/RF-02/RF-03/RF-05 (`new` de subpasta sem `.adr-std`, com `.adr-std` relativo na raiz, `--path` relativo e absoluto, fora de git, repositório aninhado).
  - Escopo: `tests/test_adr_cli.py`. Cenários: raiz vs. subpasta; limites: fora de git, `--path` absoluto; invariante: nenhuma pasta criada dentro do `cwd` errado.
  - RED esperado: `new` de subpasta cria `<sub>/docs/architecture/ADR/` e ignora `.adr-std` da raiz → asserções de caminho falham.
  - Validação: `python3 -m pytest tests/test_adr_cli.py -k "Root or Subdir" -q` deve falhar pelos motivos acima.
  - Evidência: RED: `python3 -m pytest tests/test_adr_cli.py` com as classes novas e sem a implementação → `23 failed, 44 passed`; `SubdirTest::test_new_from_subdir_without_config_uses_root_default`, `..._honors_adr_std_at_root` e `..._numbers_after_existing_adrs_from_subdir` falharam com `False is not true` (o ADR não estava em `<raiz>/...`), reproduzindo o defeito. Os casos de `--path` relativo/absoluto e fora de git passaram já no RED (não-regressão). GREEN: ver 2.2.
- [x] 1.2 Integração para RF-06/RF-07/RF-08: pasta inexistente (`new` sai 1 sem criar; `new --create` cria e numera 1; `list`, `link`, `organize --dry-run` saem 1 com a mensagem; pasta existente vazia numera 1).
  - Escopo: `tests/test_adr_cli.py`. RED esperado: `new` sai 0 e cria a pasta; `--create` ainda não existe (erro do argparse); `link` devolve "ADR não encontrado".
  - Validação: `python3 -m pytest tests/test_adr_cli.py -k "MissingFolder" -q` deve falhar.
  - Evidência: RED: `new` sem a pasta saiu 0 (`0 != 1`) e `--create` foi rejeitado pelo argparse (`unrecognized arguments: --create`); `list`/`link`/`organize` falharam pela mensagem nova. GREEN: ver 2.3.
- [x] 1.3 Integração para SEG-01: `.adr-std` com `path: ../x` e com absoluto fora da raiz → código 2, nada gravado; absoluto dentro da raiz aceito; config global e `--path` fora da raiz aceitos.
  - Escopo: `tests/test_adr_cli.py`. RED esperado: hoje o `new` grava fora da raiz.
  - Validação: `python3 -m pytest tests/test_adr_cli.py -k "OutsideRoot" -q` deve falhar.
  - Evidência: RED: `.adr-std` fora da raiz gravava fora (`new --create` não existia; sem a flag, a mensagem esperada não saiu). GREEN: ver 2.2.
- [x] 1.4 Unitários de `repo_root` e `resolve_folder(..., root=)` (inclui `path` relativo da config global contra a raiz, RF-04, e `PATH` sem `git` → `cwd`); ajuste de `test_precedence`, `test_default` e `test_cli_uses_dot_adr_std_in_cwd` (retorno absoluto; `meus-adrs` passa a existir ou a usar `--create`), com a justificativa registrada neste campo.
  - Escopo: `tests/test_adr_cli.py` (`ResolveFolderTest`). RED esperado: `repo_root` inexistente (`AttributeError`) e retorno ainda relativo.
  - Validação: `python3 -m pytest tests/test_adr_cli.py -k "ResolveFolder or RepoRoot" -q` deve falhar.
  - Evidência: RED: `TypeError`/`AttributeError` (`resolve_folder` sem `root`, `repo_root` inexistente). Testes existentes ajustados e justificados: `test_precedence` e `test_default` (retorno agora absoluto, ancorado em `root`); `test_cli_uses_dot_adr_std_in_cwd` (a pasta `meus-adrs` agora precisa existir, pois `new` não cria em silêncio); `NewTest.test_creates_missing_folder` e `test_incompatible_active_pattern_does_not_create_missing_folder` (passam a usar `--create`); `ListTest.test_missing_folder_is_error_1` (mensagem uniforme "pasta de ADRs não encontrada"). GREEN: ver 2.1.
- [x] 1.5 `migrate` (`tests/test_migrate_numbering.py`): caso de não-regressão com `.adr-std` relativo, `--root` e recusa fora da raiz (código 2); executar antes da mudança para confirmar que já passa (baseline) e depois da etapa 3.
  - Escopo: `tests/test_migrate_numbering.py`. RED: N/A justificado, é teste de não-regressão que deve passar antes e depois; registrar a saída da execução-base.
  - Validação: `python3 -m pytest tests/test_migrate_numbering.py -q`.
  - Evidência: Baseline antes da mudança: `python3 -m pytest tests/test_migrate_numbering.py -q` → `40 passed`. Os testes existentes já cobrem pasta padrão, `.adr-std`, `--root` e recusa de `--path` fora da raiz; acrescentado `test_adr_std_path_outside_root_exits_2` (SEG-01 no `migrate`). Depois da etapa 3: `41 passed`.
- [x] 1.6 Confirmar que `check_adr.py` e `check_roadmap.py` não chamam `resolve_folder` e que os demais usuários de `args.folder` estão cobertos.
  - Escopo: leitura. Validação: `grep -rn "resolve_folder\|default_root" skill/ bin/` lista só `adr_cli.py` e `migrate_numbering.py`.
  - Evidência: `grep -rn "resolve_folder\|default_root" skill/ bin/` → só `skill/scripts/adr_cli.py` e `skill/scripts/migrate_numbering.py`; `check_adr.py`, `check_roadmap.py` e os wrappers não chamam `resolve_folder`.

## Etapa 2 — Implementação em `adr_cli.py` (depende de 1.1–1.4)

- [x] 2.1 `repo_root(cwd)`, `FolderConfigError` e novo `resolve_folder(path_arg, cwd, config_home, root=None)` com retorno absoluto e SEG-01.
  - Escopo: `skill/scripts/adr_cli.py`. GREEN: testes 1.4 e 1.3 (unitários) passam. REFACTOR: remover o `DEFAULT_FOLDER` relativo duplicado do cálculo, se sobrar; senão `N/A` justificado.
  - Validação: `python3 -m pytest tests/test_adr_cli.py -k "ResolveFolder or RepoRoot" -q`.
  - Evidência: `python3 -m pytest tests/test_adr_cli.py -k "ResolveFolder or RepoRoot" -q` verde (parte de `62 passed, 5 subtests passed`). REFACTOR: N/A justificado, `DEFAULT_FOLDER` segue como única fonte do padrão e é ancorado em `root` dentro de `resolve_folder`.
- [x] 2.2 `main` calcula `root`, `args.root` e `args.folder`; captura `FolderConfigError` (stderr, código 2). Não alterar o cálculo de `config_home`.
  - Escopo: `skill/scripts/adr_cli.py` (`main`). GREEN: 1.1 e 1.3 passam.
  - Validação: `python3 -m pytest tests/test_adr_cli.py -k "Root or Subdir or OutsideRoot" -q`.
  - Evidência: `python3 -m pytest tests/test_adr_cli.py -q` → `62 passed, 5 subtests passed` (inclui `SubdirTest`, `OutsideRootTest`); `main` não toca no cálculo de `config_home`.
- [x] 2.3 `require_folder`, flag `--create` em `new`, uso em `new`, `list`, `link` e `organize`; atualizar docstring de uso do módulo.
  - Escopo: `skill/scripts/adr_cli.py`. GREEN: 1.2 passa. REFACTOR: substituir os blocos `is_dir()` duplicados de `list`/`organize` por `require_folder` (fonte única).
  - Validação: `python3 -m pytest tests/test_adr_cli.py -q` inteiro verde.
  - Evidência: `python3 -m pytest tests -q` → `135 passed, 10 subtests passed`. REFACTOR: `require_folder` substituiu os blocos `is_dir()` duplicados de `list`/`organize` e foi reutilizado em `new` e `link`.

## Etapa 3 — `migrate` (depende de 2.1)

- [x] 3.1 `default_root` delega a `repo_root`; chamada de `resolve_folder` com `root=root` dentro de `try/except FolderConfigError` (código 2).
  - Escopo: `skill/scripts/migrate_numbering.py`. GREEN: teste 1.5 continua verde.
  - Validação: `python3 -m pytest tests/test_migrate_numbering.py -q`.
  - Evidência: `python3 -m pytest tests/test_migrate_numbering.py -q` → `41 passed`; `default_root` delega a `repo_root`; `FolderConfigError` → código 2 com prefixo `adr-std migrate:`.

## Etapa 4 — Paridade Windows

- [x] 4.1 Caso Pester: `new` a partir de subpasta de repositório temporário cai na pasta da raiz.
  - Escopo: `tests/test_cli.ps1`. RED: executar o caso antes da etapa 2 se houver `pwsh`; sem `pwsh` local, registrar `Pester não executado localmente` e o RED ficará comprovado pelos testes Python equivalentes.
  - Validação: `pwsh -NoProfile -Command "Invoke-Pester tests/test_cli.ps1"` quando disponível (hoje `pwsh` não está instalado nesta máquina); caso contrário, CI Windows (exige push e autorização pontual).
  - Evidência: caso `new de subpasta de repositório grava na pasta de ADRs da raiz` escrito em `tests/test_cli.ps1`, e os dois casos que usavam `new` sem pasta passaram a usar `--create`. RED/GREEN executados com PowerShell 7.6.8 (Linux, tarball oficial com `sha256` conferido, em diretório temporário) e Pester 6.2.0: com o `adr_cli.py` anterior o caso falhou (`P=0 F=1`); com o atual passou (`P=1 F=0`). Suíte completa `tests/test_cli.ps1`: `Passed: 49, Failed: 0, Skipped: 7, Inconclusive: 1`. Não é Windows: junção NTFS e `.cmd` seguem para o CI (6.2).

## Etapa 5 — Documentação e decisões (depende de 2.3)

- [x] 5.1 `skill/SKILL.md` (Caminho dos ADRs), `README.md` (trecho `.adr-std`/`--path`) e `GLOSSARY.md` (**Raiz do repositório**, `--create`).
  - Validação: revisão de consistência contra `design.md` + `bash tests/gate.sh static`.
  - Evidência: `skill/SKILL.md`, `README.md` e `GLOSSARY.md` atualizados (raiz via git, `path` relativo, `--path` relativo, `--create`, limite sem `git`, termo **Raiz do repositório**); `bash tests/gate.sh static` → `Gate static: ok`.
- [x] 5.2 `CHANGELOG.md`, `[Não lançado]`: Corrigido (pasta resolvida da raiz) e Alterado (`new` não cria pasta inexistente; `--create`).
  - Validação: revisão de consistência; `bash tests/gate.sh static`.
  - Evidência: `CHANGELOG.md` `[Não lançado]` com Corrigido (raiz, `path` relativo, SEG-01) e Alterado (`new` sem criar pasta; `--create`; códigos de `list`/`link`/`organize`); `bash tests/gate.sh static` → ok.
- [x] 5.3 Emenda ao ADR-1 (Verificação e Limitações) e linha em `docs/architecture/ADR/ROADMAP.md` (ADR-3); informar ao final.
  - Validação: `python3 skill/scripts/check_adr.py docs/architecture/ADR/[0-9]*.md` (o glob `*.md` inclui o `ROADMAP.md`, que não é ADR) e `python3 skill/scripts/check_roadmap.py docs/architecture/ADR`.
  - Evidência: Emenda registrada no ADR-1 (Verificação, Limitações, histórico, `Modificado em`) e linha `5` no `docs/architecture/ADR/ROADMAP.md` (`Em andamento`). `check_adr.py docs/architecture/ADR/[0-9]*.md` → código 0 nos quatro ADRs (as 17 "falhas" vistas antes eram do `ROADMAP.md`, incluído por engano pelo glob `*.md`; não havia pendência). `check_roadmap.py` → `[OK] ROADMAP consistente` após a correção de RF-11 (tarefa 7.1; antes acusava a linha 5 por defeito do script).

## Etapa 6 — Validação final e auditoria (depende de tudo)

- [x] 6.1 Suíte completa: `python3 -m pytest tests -q`, `bash tests/test_cli.sh`, `bash tests/gate.sh static`.
  - Evidência: `python3 -m pytest tests -q` → `135 passed, 10 subtests passed`; `bash tests/test_cli.sh` → `72 passaram, 0 falharam` (os dois casos que usavam `new` sem pasta passaram a usar `--create`); `bash tests/gate.sh static` → `Gate static: ok`.
- [x] 6.2 Pester no CI Windows: `E2E/Pester não executado` até haver push autorizado; registrar estado e impacto. Concluir só com o job verde.
  - Evidência: PR https://github.com/dihcruz1/adr-std/pull/1, [run 39885417688](https://github.com/dihcruz1/adr-std/actions/runs/39885417688) no SHA 5ec0024: Gate de segurança, Testes (ubuntu-latest), Testes (macos-latest) e Testes (Windows) `SUCCESS`; Publicar release `SKIPPED` (só roda em tag).
- [x] 6.3 Auditoria da implementação contra os três arquivos: cobertura por requisito (RF-01…RF-10, SEG-01…03, matriz), testes executados, discrepâncias e pendências (inclui a divergência do `--path` relativo do `migrate` e o limite sem `git`), registrada ao final deste arquivo.
  - Evidência: seção "Auditoria da implementação" abaixo.

## Etapa 7 — Defeito correlato (RF-11)

- [x] 7.1 `check_roadmap.py`: `TASK_LINE` com `re.MULTILINE` e teste de regressão.
  - Escopo: `skill/scripts/check_roadmap.py`, `tests/test_check_roadmap.py`, `CHANGELOG.md`, `docs/architecture/ADR/ROADMAP.md`.
  - RED: com o script anterior, `test_pending_task_after_title_and_done_tasks_is_in_progress` falhou (`1 failed, 12 passed`). GREEN: com a correção, `python3 -m pytest tests -q` → `136 passed`; `python3 skill/scripts/check_roadmap.py docs/architecture/ADR` → `[OK] ROADMAP consistente` (a linha 5 em `Em andamento` passa a ser a esperada). REFACTOR: N/A, mudança de uma linha.
  - Validação: `python3 -m pytest tests/test_check_roadmap.py -q`.
  - Evidência: ver RED/GREEN acima.

- [x] 8.1 `migrate`: `--path` relativo só contra o `cwd` (RF-12, D-8 revisada).
  - Escopo: `skill/scripts/migrate_numbering.py`, `tests/test_migrate_numbering.py`, `CHANGELOG.md`.
  - RED: `test_relative_path_is_relative_to_cwd_only` falhou com o código anterior (o `migrate` caía na raiz). GREEN: `python3 -m pytest tests -q` → `137 passed`; `bash tests/test_cli.sh` → `72 passaram`. REFACTOR: removido o desvio para a raiz. O teste `test_root_option_and_git_toplevel` passou a usar `--path` absoluto no trecho de `--root`, pois dependia do desvio.
  - Validação: `python3 -m pytest tests/test_migrate_numbering.py -q`.
  - Evidência: ver RED/GREEN acima.

## Rastreabilidade

| Requisito | Tarefas |
|---|---|
| RF-01, RF-02, RF-03, RF-04, RF-05 | 1.1, 1.4, 2.1, 2.2 |
| RF-06, RF-07, RF-08 | 1.2, 2.3 |
| RF-09 | 1.5, 1.6, 3.1 |
| RF-10, D-7 | 5.1, 5.2, 5.3 |
| SEG-01 | 1.3, 1.4, 2.1, 2.2 |
| SEG-02 | 1.2, 2.3 |
| SEG-03, D-11 | 0.1, 4.1, 6.2 |
| RF-11 | 7.1 |
| RF-12 | 8.1 |
| Matriz de não-regressão | 1.1–1.5, 6.1, 6.2 |

## Auditoria cruzada 360° (2026-10-22)

Revisão feita com `/opsx:update` em 2026-10-22 (antes, auditoria direta), sem alterar código. Revisões aplicadas: Gate 2 registrado nos requisitos e no design; D-12 alinhado a `repo_root`; `--path` relativo do `migrate` listado como fora do escopo/pendência; `--create` fora do help dos wrappers citado em RF-10; 1.4 cobre `PATH` sem `git`; 6.3 registra as pendências.

- Rastreabilidade: RF-01…RF-10, SEG-01…03 e D-1…D-12 mapeados para tarefas (tabela acima); nenhuma decisão ou requisito sem tarefa.
- Linguagem Ubíqua: termos do `GLOSSARY.md` (Pasta de ADRs, Precedência de caminho, Config global); **Raiz do repositório** entra na tarefa 5.1.
- DDD: Modelo de domínio `N/A` justificado no design; sem Repositório/Gateway.
- RED/GREEN/REFACTOR/validação presentes em todas as tarefas de código; 1.5 e 4.1 têm RED `N/A`/condicional justificado.
- Ajustes aplicados: comando de 5.3 corrigido (`check_roadmap.py` recebe `adr_dir`); `pwsh` ausente registrado em 4.1; 1.4 passou a citar o caso da config global (RF-04); `requirements.md` corrigido quanto a `list`/`organize` (já saem 1) e códigos de saída.
- Pendência declarada: Pester só no CI Windows, após push com autorização pontual (6.2).

## Auditoria da implementação (2026-10-22)

E2E real (CLI, sem navegador; E2E de navegador N/A): reprodução do briefing em repositório temporário com o `adr_cli.py` alterado. De `docs/architecture/ADR/`, `new "Segundo"` com `.adr-std` (`path: meus-adrs`) na raiz gravou `meus-adrs/1-segundo.md`; sem `.adr-std`, `new "Terceiro"` gravou `docs/architecture/ADR/2-terceiro.md` (numeração correta, nenhuma pasta aninhada); com a pasta removida, `new "X"` saiu com código 1 e mensagem com a pasta e a raiz, sem criar nada.

| Requisito | Evidência | Resultado |
|---|---|---|
| RF-01, RF-02 | `SubdirTest` (padrão, `.adr-std` relativo na raiz, numeração após ADRs existentes) | Atendido |
| RF-03 | `SubdirTest::test_path_arg_*`, `ResolveFolderTest::test_path_arg_is_relative_to_cwd_and_absolute_is_exact` | Atendido |
| RF-04 | `ResolveFolderTest::test_precedence`, `test_global_config_relative_path_is_relative_to_root`, `SubdirTest::test_global_config_relative_path_is_relative_to_root` | Atendido |
| RF-05 | `RepoRootTest` (fora de git, sem `git` no PATH, aninhado), `SubdirTest::test_outside_git_*` | Atendido |
| RF-06, RF-07 | `MissingFolderTest` (erro 1 sem criar; `--create` numera 1; pasta vazia existente numera 1) | Atendido |
| RF-08 | `MissingFolderTest::test_other_commands_*` (`list`, `link`, `organize --dry-run`) | Atendido |
| RF-09 | `grep` de 1.6; `tests/test_migrate_numbering.py` 41 verdes | Atendido |
| RF-10 | SKILL.md, README, GLOSSARY, ADR-1, CHANGELOG revisados contra o design | Atendido |
| SEG-01 | `OutsideRootTest`, `ResolveFolderTest::*outside_root*`, `test_adr_std_path_outside_root_exits_2` (migrate) | Atendido |
| SEG-02 | `MissingFolderTest::test_new_fails_without_creating_anything` | Atendido |
| SEG-03 | repositórios temporários; sem push, release ou deploy | Atendido |
| RF-12 | `test_relative_path_is_relative_to_cwd_only` | Atendido |
| RF-11 | `test_pending_task_after_title_and_done_tasks_is_in_progress`; ROADMAP consistente | Atendido |
| Matriz, linha Windows (Pester) | Pester no Linux (RED/GREEN do caso e suíte 49 aprovados) e job Windows do CI verde (run 39885417688) | Atendido |

Testes executados: `python3 -m pytest tests -q` → 137 passed, 10 subtests; `bash tests/test_cli.sh` → 72 passaram; `bash tests/gate.sh static` → ok.

Discrepâncias e pendências:
- **CI Windows**: verde no run 39885417688 (SHA 5ec0024), além do Pester local no Linux (PowerShell 7.6.8, Pester 6.2.0). 6.2 concluída.
- `check_roadmap.py`: defeito de `TASK_LINE` corrigido nesta spec (RF-11, tarefa 7.1).
- D-8 revisada: o `--path` relativo do `migrate` agora vale só contra o `cwd` (RF-12, tarefa 8.1); sem divergência.
- Limite documentado (D-9): sem `git`, de uma subpasta, vale o `cwd`; rodar da raiz ou usar `--path` absoluto.
- `check_adr.py`: sem falhas nos ADRs (as 17 vistas antes eram do `ROADMAP.md`, incluído pelo glob `*.md`).
