# Tarefas — resolução da pasta de ADRs a partir da raiz do repositório

Data: 2026-10-22. Requisitos: `requirements.md`; design: `design.md`. Marque `[x]` só com evidência real (comando e resultado) no campo **Evidência** de cada tarefa.

Convenção: cada tarefa de código segue RED → GREEN → REFACTOR. Comandos rodam da raiz do repositório. Testes de integração usam repositórios temporários (`git init -q`) e `XDG_CONFIG_HOME` isolado.

## Etapa 0 — Preparação

- [x] 0.1 Criar a branch `fix/adr-cli-resolucao-de-pasta` a partir do estado atual, sem tocar nos arquivos alheios (`AGENTS.md`, `CLAUDE.md`, `docs/agents/*`, `docs/specs/2026-10-05-close-validation-gaps/`, `openspec/`, `testResults.xml`).
  - Escopo: apenas Git. Validação: `git branch --show-current` e `git status --short` inalterado nos arquivos alheios.
  - Evidência: `git switch -c fix/adr-cli-resolucao-de-pasta` → branch atual `fix/adr-cli-resolucao-de-pasta`; `git status --short` mantém os arquivos alheios como estavam.

## Etapa 1 — Testes RED (reprodução do defeito e matriz)

- [ ] 1.1 Integração em `tests/test_adr_cli.py`: reprodução do briefing e RF-01/RF-02/RF-03/RF-05 (`new` de subpasta sem `.adr-std`, com `.adr-std` relativo na raiz, `--path` relativo e absoluto, fora de git, repositório aninhado).
  - Escopo: `tests/test_adr_cli.py`. Cenários: raiz vs. subpasta; limites: fora de git, `--path` absoluto; invariante: nenhuma pasta criada dentro do `cwd` errado.
  - RED esperado: `new` de subpasta cria `<sub>/docs/architecture/ADR/` e ignora `.adr-std` da raiz → asserções de caminho falham.
  - Validação: `python3 -m pytest tests/test_adr_cli.py -k "Root or Subdir" -q` deve falhar pelos motivos acima.
  - Evidência: _pendente_
- [ ] 1.2 Integração para RF-06/RF-07/RF-08: pasta inexistente (`new` sai 1 sem criar; `new --create` cria e numera 1; `list`, `link`, `organize --dry-run` saem 1 com a mensagem; pasta existente vazia numera 1).
  - Escopo: `tests/test_adr_cli.py`. RED esperado: `new` sai 0 e cria a pasta; `--create` ainda não existe (erro do argparse); `link` devolve "ADR não encontrado".
  - Validação: `python3 -m pytest tests/test_adr_cli.py -k "MissingFolder" -q` deve falhar.
  - Evidência: _pendente_
- [ ] 1.3 Integração para SEG-01: `.adr-std` com `path: ../x` e com absoluto fora da raiz → código 2, nada gravado; absoluto dentro da raiz aceito; config global e `--path` fora da raiz aceitos.
  - Escopo: `tests/test_adr_cli.py`. RED esperado: hoje o `new` grava fora da raiz.
  - Validação: `python3 -m pytest tests/test_adr_cli.py -k "OutsideRoot" -q` deve falhar.
  - Evidência: _pendente_
- [ ] 1.4 Unitários de `repo_root` e `resolve_folder(..., root=)` (inclui `path` relativo da config global contra a raiz, RF-04, e `PATH` sem `git` → `cwd`); ajuste de `test_precedence`, `test_default` e `test_cli_uses_dot_adr_std_in_cwd` (retorno absoluto; `meus-adrs` passa a existir ou a usar `--create`), com a justificativa registrada neste campo.
  - Escopo: `tests/test_adr_cli.py` (`ResolveFolderTest`). RED esperado: `repo_root` inexistente (`AttributeError`) e retorno ainda relativo.
  - Validação: `python3 -m pytest tests/test_adr_cli.py -k "ResolveFolder or RepoRoot" -q` deve falhar.
  - Evidência: _pendente_
- [ ] 1.5 `migrate` (`tests/test_migrate_numbering.py`): caso de não-regressão com `.adr-std` relativo, `--root` e recusa fora da raiz (código 2); executar antes da mudança para confirmar que já passa (baseline) e depois da etapa 3.
  - Escopo: `tests/test_migrate_numbering.py`. RED: N/A justificado, é teste de não-regressão que deve passar antes e depois; registrar a saída da execução-base.
  - Validação: `python3 -m pytest tests/test_migrate_numbering.py -q`.
  - Evidência: _pendente_
- [ ] 1.6 Confirmar que `check_adr.py` e `check_roadmap.py` não chamam `resolve_folder` e que os demais usuários de `args.folder` estão cobertos.
  - Escopo: leitura. Validação: `grep -rn "resolve_folder\|default_root" skill/ bin/` lista só `adr_cli.py` e `migrate_numbering.py`.
  - Evidência: _pendente_

## Etapa 2 — Implementação em `adr_cli.py` (depende de 1.1–1.4)

- [ ] 2.1 `repo_root(cwd)`, `FolderConfigError` e novo `resolve_folder(path_arg, cwd, config_home, root=None)` com retorno absoluto e SEG-01.
  - Escopo: `skill/scripts/adr_cli.py`. GREEN: testes 1.4 e 1.3 (unitários) passam. REFACTOR: remover o `DEFAULT_FOLDER` relativo duplicado do cálculo, se sobrar; senão `N/A` justificado.
  - Validação: `python3 -m pytest tests/test_adr_cli.py -k "ResolveFolder or RepoRoot" -q`.
  - Evidência: _pendente_
- [ ] 2.2 `main` calcula `root`, `args.root` e `args.folder`; captura `FolderConfigError` (stderr, código 2). Não alterar o cálculo de `config_home`.
  - Escopo: `skill/scripts/adr_cli.py` (`main`). GREEN: 1.1 e 1.3 passam.
  - Validação: `python3 -m pytest tests/test_adr_cli.py -k "Root or Subdir or OutsideRoot" -q`.
  - Evidência: _pendente_
- [ ] 2.3 `require_folder`, flag `--create` em `new`, uso em `new`, `list`, `link` e `organize`; atualizar docstring de uso do módulo.
  - Escopo: `skill/scripts/adr_cli.py`. GREEN: 1.2 passa. REFACTOR: substituir os blocos `is_dir()` duplicados de `list`/`organize` por `require_folder` (fonte única).
  - Validação: `python3 -m pytest tests/test_adr_cli.py -q` inteiro verde.
  - Evidência: _pendente_

## Etapa 3 — `migrate` (depende de 2.1)

- [ ] 3.1 `default_root` delega a `repo_root`; chamada de `resolve_folder` com `root=root` dentro de `try/except FolderConfigError` (código 2).
  - Escopo: `skill/scripts/migrate_numbering.py`. GREEN: teste 1.5 continua verde.
  - Validação: `python3 -m pytest tests/test_migrate_numbering.py -q`.
  - Evidência: _pendente_

## Etapa 4 — Paridade Windows

- [ ] 4.1 Caso Pester: `new` a partir de subpasta de repositório temporário cai na pasta da raiz.
  - Escopo: `tests/test_cli.ps1`. RED: executar o caso antes da etapa 2 se houver `pwsh`; sem `pwsh` local, registrar `Pester não executado localmente` e o RED ficará comprovado pelos testes Python equivalentes.
  - Validação: `pwsh -NoProfile -Command "Invoke-Pester tests/test_cli.ps1"` quando disponível (hoje `pwsh` não está instalado nesta máquina); caso contrário, CI Windows (exige push e autorização pontual).
  - Evidência: _pendente_

## Etapa 5 — Documentação e decisões (depende de 2.3)

- [ ] 5.1 `skill/SKILL.md` (Caminho dos ADRs), `README.md` (trecho `.adr-std`/`--path`) e `GLOSSARY.md` (**Raiz do repositório**, `--create`).
  - Validação: revisão de consistência contra `design.md` + `bash tests/gate.sh static`.
  - Evidência: _pendente_
- [ ] 5.2 `CHANGELOG.md`, `[Não lançado]`: Corrigido (pasta resolvida da raiz) e Alterado (`new` não cria pasta inexistente; `--create`).
  - Validação: revisão de consistência; `bash tests/gate.sh static`.
  - Evidência: _pendente_
- [ ] 5.3 Emenda ao ADR-1 (Verificação e Limitações) e linha em `docs/architecture/ADR/ROADMAP.md` (ADR-3); informar ao final.
  - Validação: `python3 skill/scripts/check_adr.py docs/architecture/ADR/*.md` e `python3 skill/scripts/check_roadmap.py docs/architecture/ADR`.
  - Evidência: _pendente_

## Etapa 6 — Validação final e auditoria (depende de tudo)

- [ ] 6.1 Suíte completa: `python3 -m pytest tests -q`, `bash tests/test_cli.sh`, `bash tests/gate.sh static`.
  - Evidência: _pendente_
- [ ] 6.2 Pester no CI Windows: `E2E/Pester não executado` até haver push autorizado; registrar estado e impacto. Concluir só com o job verde.
  - Evidência: _pendente_
- [ ] 6.3 Auditoria da implementação contra os três arquivos: cobertura por requisito (RF-01…RF-10, SEG-01…03, matriz), testes executados, discrepâncias e pendências (inclui a divergência do `--path` relativo do `migrate` e o limite sem `git`), registrada ao final deste arquivo.
  - Evidência: _pendente_

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
| Matriz de não-regressão | 1.1–1.5, 6.1, 6.2 |

## Auditoria cruzada 360° (2026-10-22)

Revisão feita com `/opsx:update` em 2026-10-22 (antes, auditoria direta), sem alterar código. Revisões aplicadas: Gate 2 registrado nos requisitos e no design; D-12 alinhado a `repo_root`; `--path` relativo do `migrate` listado como fora do escopo/pendência; `--create` fora do help dos wrappers citado em RF-10; 1.4 cobre `PATH` sem `git`; 6.3 registra as pendências.

- Rastreabilidade: RF-01…RF-10, SEG-01…03 e D-1…D-12 mapeados para tarefas (tabela acima); nenhuma decisão ou requisito sem tarefa.
- Linguagem Ubíqua: termos do `GLOSSARY.md` (Pasta de ADRs, Precedência de caminho, Config global); **Raiz do repositório** entra na tarefa 5.1.
- DDD: Modelo de domínio `N/A` justificado no design; sem Repositório/Gateway.
- RED/GREEN/REFACTOR/validação presentes em todas as tarefas de código; 1.5 e 4.1 têm RED `N/A`/condicional justificado.
- Ajustes aplicados: comando de 5.3 corrigido (`check_roadmap.py` recebe `adr_dir`); `pwsh` ausente registrado em 4.1; 1.4 passou a citar o caso da config global (RF-04); `requirements.md` corrigido quanto a `list`/`organize` (já saem 1) e códigos de saída.
- Pendência declarada: Pester só no CI Windows, após push com autorização pontual (6.2).
