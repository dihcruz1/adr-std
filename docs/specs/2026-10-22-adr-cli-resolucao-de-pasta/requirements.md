# Requisitos — resolução da pasta de ADRs a partir da raiz do repositório

Data: 2026-10-22. Fonte: `briefing.md` (defeito observado no projeto `led-bomb-monitor`), ADR-1 e rodadas de decisão com o responsável (Q1–Q12, todas aceitas). Status: Gate 1 e Gate 2 aprovados em 2026-10-22 (ajuste posterior: premissa de `list` em RF-08 e códigos de saída, conferidos no código).

## Causa-raiz

Em `skill/scripts/adr_cli.py`:

1. `DEFAULT_FOLDER` é um `Path` relativo e é resolvido contra o `cwd`.
2. `resolve_folder` lê `.adr-std` só em `cwd`, embora `SKILL.md`, README e ADR-1 digam "na raiz do repositório"; o campo `path` também volta relativo ao `cwd`.
3. `cmd_new` faz `mkdir(parents=True, exist_ok=True)` sem checar a existência da pasta; em pasta vazia a numeração recomeça em 1. O erro de caminho vira um ADR válido com número errado, e `list` sai com código 0.

Os testes `ResolveFolderTest.test_default` e `test_cli_uses_dot_adr_std_in_cwd` fixam o comportamento defeituoso. O wrapper `bin/adr-std.ps1` delega `new/list/link/organize` ao mesmo `adr_cli.py`; a correção vale nos dois sistemas. `migrate_numbering.py` já tem `default_root` (`git rev-parse --show-toplevel`, fallback `cwd`) e chama `resolve_folder(None, root, …)`.

## Decisões aceitas

| ID | Decisão |
|---|---|
| D-1 | Raiz = `git rev-parse --show-toplevel`; sem git ou fora de repositório, raiz = `cwd`. Sem busca heurística por `.adr-std`. |
| D-2 | `--path` relativo é sempre relativo ao `cwd`; absoluto vale como está. |
| D-3 | `path:` relativo (`.adr-std` ou config global) é relativo à raiz; absoluto vale como está. |
| D-4 | `new` com pasta inexistente: erro e nenhuma criação; `--create` cria e numera a partir de 1. |
| D-5 | `list`, `link` e `organize` com pasta inexistente: erro, código diferente de zero. |
| D-6 | Correção (patch) com mudança de contrato visível, registrada em `[Não lançado]` do CHANGELOG; número da release é decisão do responsável. |
| D-7 | Emenda ao ADR-1 (Verificação e Limitações), sem ADR novo; ROADMAP atualizado (ADR-3). |
| D-8 | `migrate` só adapta a chamada a `resolve_folder`; o `--path` relativo dele (tenta `cwd`, depois raiz) fica fora do escopo, registrado como divergência pendente. |
| D-9 | Sem git no PATH, fallback silencioso para o `cwd`; limite documentado. |
| D-10 | `path:` do `.adr-std` que resolva fora da raiz é erro (código 2). `--path` e config global não têm essa restrição. |
| D-11 | `bin/adr-std.ps1` não muda; um caso Pester novo; conclusão só com CI Windows verde. |
| D-12 | `repo_root` em `adr_cli.py` é a fonte única da raiz; o `default_root` do `migrate` delega a ele (exceção de segurança da precedência). Sem DDD tático. |

## Requisitos verificáveis (EARS)

- **RF-01:** QUANDO `new`, `list`, `link` ou `organize` rodar sem `--path` e sem `.adr-std`/config global com `path`, o sistema DEVE usar `<raiz>/docs/architecture/ADR`, independentemente do `cwd`.
- **RF-02:** QUANDO houver `.adr-std` na raiz com `path` relativo, o sistema DEVE usar `<raiz>/<path>`, mesmo com `cwd` em subpasta; `path` absoluto DEVE ser usado como está.
- **RF-03:** QUANDO `--path` for informado, o sistema DEVE usá-lo com a maior precedência: absoluto exato, relativo contra o `cwd`.
- **RF-04:** A precedência `--path` > `.adr-std` > config global > padrão DEVE ser preservada; `path` relativo da config global DEVE ser resolvido contra a raiz.
- **RF-05:** QUANDO fora de repositório git ou sem `git` no PATH, o sistema DEVE usar o `cwd` como raiz, sem erro.
- **RF-06:** QUANDO a pasta resolvida não existir, `new` DEVE terminar com código 1 (o mesmo de `list`), mensagem em pt-BR com a pasta e a raiz resolvidas e a sugestão de `--create` ou `--path`, sem criar nada.
- **RF-07:** QUANDO `new --create` for usado e a pasta não existir, o sistema DEVE criá-la e numerar a partir de 1. Pasta existente, mesmo vazia, DEVE manter o comportamento atual.
- **RF-08:** QUANDO a pasta resolvida não existir, `list`, `link` e `organize` (inclusive `--dry-run`) DEVEM terminar com código 1 e a mesma mensagem de RF-06, sem a sugestão de `--create`. Hoje `list` e `organize` já saem com 1 ("pasta não encontrada") e `link` com 1 ("ADR não encontrado"); o requisito uniformiza a mensagem e a preserva como contrato.
- **RF-09:** `check_adr.py` e `check_roadmap.py` DEVEM manter o comportamento atual (exceto RF-11); `migrate` DEVE manter o resultado atual (pasta resolvida, recusa fora da raiz, `numbering: padded`).
- **RF-10 (documentação):** `SKILL.md`, README (trecho de `.adr-std`/`--path`), ADR-1 e CHANGELOG DEVEM descrever o comportamento final, incluindo o limite sem git (rodar da raiz ou usar `--path` absoluto). `--create` é documentado no `--help` do Python, README, SKILL.md e CHANGELOG, e não no help dos wrappers (D-11).
- **RF-11 (defeito correlato, incluído em 2026-10-22):** QUANDO o `tasks.md` de uma spec tiver título ou tarefas concluídas antes de uma tarefa pendente (`- [ ]`), `check_roadmap.py` DEVE esperar o status `Em andamento`. Causa-raiz: `TASK_LINE` sem `re.MULTILINE` só examinava o início do arquivo, e toda spec resultava `Concluída`.

### Segurança

- **SEG-01:** QUANDO o `path` do `.adr-std` (arquivo versionado, potencialmente não confiável) resolver fora da raiz (`..` ou absoluto), o sistema DEVE falhar com código 2 e não gravar nada. `--path` (intenção explícita) e a config global (arquivo do usuário) ficam fora dessa restrição.
- **SEG-02:** `mkdir` só ocorre com `--create`; nunca criar árvore em silêncio.
- **SEG-03:** testes em repositórios temporários, sem credenciais; sem push, release ou deploy.

Riscos e mitigações: (1) repositório aninhado/submódulo usa a raiz do repo mais interno, o que é determinístico e documentado; (2) `git` ausente reproduz o defeito em subpasta, e a mitigação é documentação; (3) `new` deixa de criar a pasta inexistente (hoje cria em silêncio), o que é mudança de contrato registrada no CHANGELOG; `list` só saía com 0 no defeito porque a pasta errada existia (criada por `new`).

## Matriz de não-regressão

| Cenário | Esperado após a correção |
|---|---|
| `cwd` = raiz, sem `.adr-std` | `<raiz>/docs/architecture/ADR` (igual a hoje) |
| `cwd` = raiz, `.adr-std` com `path` | pasta do `path` (igual a hoje) |
| `cwd` = subpasta, sem `.adr-std` | `<raiz>/docs/architecture/ADR` (hoje: pasta errada) |
| `cwd` = subpasta, `.adr-std` na raiz | `<raiz>/<path>` (hoje: ignora o arquivo) |
| `--path` absoluto, qualquer `cwd` | exatamente essa pasta (igual a hoje) |
| `--path` relativo, subpasta | relativo ao `cwd` |
| config global com `path` relativo, subpasta | `<raiz>/<path>` |
| precedência `--path` > `.adr-std` > global > padrão | preservada |
| fora de repositório git / sem `git` | `cwd` como raiz |
| repositório aninhado/submódulo | raiz do repo mais interno |
| `.adr-std` com `path: ../x` ou absoluto | erro, código 2 (SEG-01) |
| pasta inexistente: `new` / `new --create` | erro (código 1) sem criar / cria e numera de 1 |
| pasta inexistente: `list`, `link`, `organize --dry-run` | erro, código 1 |
| pasta existente e vazia | `new` numera de 1 sem erro |
| `list`, `link`, `organize --dry-run` de subpasta | operam na pasta da raiz |
| `check_adr.py`, `check_roadmap.py` | sem mudança de resolução de pasta (não chamam `resolve_folder`); `check_roadmap.py` só corrige a heurística de status (RF-11) |
| `migrate` | mesmo resultado; o `--path` relativo fica como está (D-8) |
| Windows (Pester) | `new` de subpasta cai na pasta da raiz; CI verde |

## Fora do escopo

Numeração (ADR-4), formato do ADR, lógica do `migrate` além da chamada (inclusive o `--path` relativo dele, que tenta `cwd` e depois a raiz e diverge de D-2; pendência registrada na auditoria 6.3), projeto `led-bomb-monitor`. E2E de navegador N/A: produto CLI sem interface web.
