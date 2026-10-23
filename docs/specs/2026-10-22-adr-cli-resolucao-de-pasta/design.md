# Design — resolução da pasta de ADRs a partir da raiz do repositório

Data: 2026-10-22. Requisitos: `requirements.md` (Gate 1 aprovado). Status: Gate 2 aprovado em 2026-10-22.

## Visão geral

Mudança confinada a `skill/scripts/adr_cli.py` (e à chamada em `skill/scripts/migrate_numbering.py`). Os wrappers `bin/adr-std` e `bin/adr-std.ps1` repassam os argumentos ao Python e não mudam (D-11). A resolução da raiz passa a ser feita uma vez, em `main`, e entregue aos comandos junto de `args.folder`.

## Contratos

### `repo_root(cwd: Path) -> Path` (novo, em `adr_cli.py`)

`git -C <cwd> rev-parse --show-toplevel`; saída não vazia e código 0 devolvem `Path(saída).resolve()`. Sem `git` no PATH (`FileNotFoundError`), fora de repositório ou erro: `cwd.resolve()` (D-1, D-9). Sem heurística de busca por `.adr-std`.

`migrate_numbering.default_root` passa a delegar a `repo_root` (fonte única, D-12). O `run_git` do `migrate` permanece, pois é usado em `in_git` e no `git mv`.

### `resolve_folder(path_arg, cwd, config_home, root=None) -> Path` (alterado)

Devolve sempre caminho **absoluto resolvido**. `root` omitido vale `repo_root(cwd)`; o `migrate` passa o `root` que já calculou (respeita `--root`).

Precedência inalterada (ADR-1): `--path` > `.adr-std` > config global > padrão.

| Origem | Leitura | Resolução |
|---|---|---|
| `--path` | `path_arg` | absoluto: como está; relativo: `cwd / path_arg` (D-2) |
| `.adr-std` | `root / ".adr-std"` | absoluto: como está; relativo: `root / path`; fora de `root` → `FolderConfigError` (D-3, D-10) |
| config global | `config_home/adr-std/config` | absoluto: como está; relativo: `root / path`; sem restrição à raiz (D-3, D-10) |
| padrão | `DEFAULT_FOLDER` | `root / DEFAULT_FOLDER` |

`.adr-std` com `path` absoluto também cai em SEG-01: se o absoluto resolvido não estiver sob `root`, é erro. A checagem usa `resolved.is_relative_to(root)` sobre caminhos já resolvidos (cobre `..` e symlink).

`FolderConfigError(ValueError)`: mensagem em pt-BR com o `path` e a raiz. `main` a captura, imprime `adr-std: ...` em stderr e sai com **2**. O `migrate` a captura no ponto da chamada e mantém o código 2 que já devolve para pasta fora da raiz.

### `main` e comandos

- `main` calcula `root = repo_root(Path.cwd())`, `args.root = root`, `args.folder = resolve_folder(args.path_arg, Path.cwd(), config_home, root)`. O cálculo de `config_home` (XDG) **não muda** aqui; a spec 2026-10-05-close-validation-gaps é dona dessa linha e continua intacta.
- `require_folder(args) -> int | None` (novo, privado): se `not args.folder.is_dir()`, imprime em stderr `adr-std: pasta de ADRs não encontrada: <pasta> (raiz: <raiz>). Use --path para indicar outra pasta.` e devolve 1; senão `None`. `new` acrescenta ` ou --create para criá-la` à mensagem.
- `cmd_new`: após validar o título, chama `require_folder` a menos que `args.create`; `mkdir(parents=True, exist_ok=True)` só roda com `--create` (RF-07). Pasta existente, mesmo vazia, segue o fluxo atual.
- `cmd_list`, `cmd_organize`: trocam o bloco `if not folder.is_dir()` por `require_folder` (mesmo código 1, mensagem uniforme).
- `cmd_link`: chama `require_folder` antes de `find_adr_file` (hoje cairia em "ADR não encontrado").
- Parser: `--create` só em `new` (`action="store_true"`, `help` em pt-BR).

### `migrate_numbering.py`

`folder = (root / resolve_folder(None, root, config_home)).resolve()` vira `folder = resolve_folder(None, root, config_home, root=root)` dentro de `try/except FolderConfigError` (código 2, mesmo prefixo). `--path` relativo passa a ser resolvido só contra o `cwd` (RF-12, revisão de D-8), sem a alternativa da raiz; `under(folder, root)` e `numbering: padded`.

## Decisões e justificativas

- **Raiz via git em vez de busca por `.adr-std`**: determinística e igual à que o `migrate` já usa (D-1). Evita reabrir a rejeição do ADR-1 a heurísticas para a *pasta*.
- **Fonte única de `repo_root`**: pela precedência do AGENTS.md (segurança com fonte única desde a segunda repetição), a restrição à raiz do SEG-01 e a raiz do `migrate` dependem do mesmo cálculo.
- **`root` como parâmetro opcional** de `resolve_folder`: o `migrate` aceita `--root` que pode não ser o toplevel; ancorar de novo em `repo_root` mudaria seu resultado.
- **Retorno absoluto**: elimina o `Path` relativo que originou o defeito; testes de `resolve_folder` ficam determinísticos.
- **Código 1 para pasta inexistente**: preserva o contrato atual de `list`/`organize`; código 2 fica para configuração inválida (SEG-01), como já faz o `migrate`.
- **Sem alteração nos wrappers**: o help deles não menciona `--create`; a flag é documentada no `--help` do Python, README, SKILL.md e CHANGELOG. Trade-off: quem só lê o `adr-std help` não vê `--create`, mas a mensagem de erro da própria falha o sugere. Incluí-la exigiria mexer no help dos dois wrappers e nos testes de help do Pester (fonte do bloqueio da v2.0.0), sem ganho que justifique agora.
- **Sem DDD tático**: ver abaixo.

## Modelo de domínio

`N/A`: a mudança é uma função de resolução de caminho e validações de borda de CLI, sem entidade, invariante de agregado nem Value Object com ciclo de vida. "Pasta de ADRs" e "Precedência de caminho (ADR-1)" já estão no `GLOSSARY.md`; acrescenta-se ao glossário o termo **Raiz do repositório** (definição: toplevel do git, ou o diretório atual fora de repositório) e a menção a `--create`. Sem Repositório/Gateway: o `git` é chamado direto por `subprocess`, e os testes usam repositórios temporários reais.

## Segurança

- SEG-01 implementada em `resolve_folder` (único ponto) com caminhos resolvidos.
- SEG-02: `mkdir` só em `new --create`.
- `subprocess` com lista de argumentos, sem shell; `cwd` vem de `Path.cwd()`.
- Riscos residuais: repositório aninhado/submódulo usa a raiz mais interna (documentado); `git` ausente reproduz o defeito em subpasta (documentado em SKILL.md, README e ADR-1 Limitações).

## Estratégia de testes

Unitário (`tests/test_adr_cli.py`, `ResolveFolderTest`, `root` explícito, sem git):
- precedência com caminhos absolutos; `path` relativo de `.adr-std` e da config global contra a raiz; `--path` relativo contra o `cwd`; `--path` absoluto exato.
- `.adr-std` com `../x` e com absoluto fora da raiz → `FolderConfigError`; absoluto dentro da raiz aceito; config global e `--path` fora da raiz aceitos.
- `repo_root`: repositório temporário (`git init`), subpasta → toplevel; fora de repositório → `cwd`; `PATH` sem `git` → `cwd`.

Integração (`CliTestCase`/`run`, repositórios temporários com `git init -q`, `XDG_CONFIG_HOME` isolado):
- reprodução do briefing (RED): `new` de subpasta cai em `<raiz>/docs/architecture/ADR` e respeita `.adr-std` da raiz.
- `list`, `link`, `organize --dry-run` de subpasta operam na pasta da raiz.
- pasta inexistente: `new` sai 1 sem criar nada; `new --create` cria e numera 1; `list`/`link`/`organize --dry-run` saem 1 com a mensagem; pasta existente vazia: `new` numera 1.
- fora de git: `cwd` como raiz; repositório aninhado: raiz do mais interno.
- `.adr-std` fora da raiz: código 2, nada gravado.
- `migrate`: teste existente de pasta/recusa fora da raiz segue verde; novo caso confirma `.adr-std` relativo e `--root`.

Testes existentes ajustados e justificados no registro das tarefas: `test_precedence` (retorno absoluto), `test_default` (agora `root/docs/architecture/ADR`), `test_cli_uses_dot_adr_std_in_cwd` (a pasta `meus-adrs` não existe; passa a usar `--create` ou a criar a pasta, e ganha a variante de subpasta). Qualquer outro teste que dependa de `new` criar a pasta em silêncio é identificado na execução do RED e tratado do mesmo modo.

Pester (`tests/test_cli.ps1`): um caso `new` a partir de subpasta de repositório temporário cai na pasta da raiz (D-11). Conclusão só com o CI Windows verde; sem `pwsh` local, o item fica pendente até o CI rodar (nenhum push sem autorização pontual).

Validação do conjunto: `python3 -m pytest tests`, `bash tests/test_cli.sh`, `bash tests/gate.sh static`.

## Correção correlata (RF-11) e alinhamento do `migrate` (RF-12)

`skill/scripts/check_roadmap.py`: `TASK_LINE` passa a `re.MULTILINE`. Teste: spec com título, tarefa concluída e tarefa pendente deve exigir `Em andamento` no ROADMAP. Verificado que as demais specs vinculadas ao ROADMAP seguem consistentes após a correção.

## Documentação a alinhar

- `skill/SKILL.md` (Caminho dos ADRs): raiz via git, relativo à raiz no `.adr-std`/config, `--path` relativo ao `cwd`, `--create`, limite sem git (rodar da raiz ou `--path` absoluto).
- `README.md` (trecho do `.adr-std`/`--path`), `GLOSSARY.md`, `CHANGELOG.md` (`[Não lançado]`: Corrigido e Alterado).
- Emenda ao ADR-1 (Verificação e Limitações) e linha correspondente em `docs/architecture/ADR/ROADMAP.md` (ADR-3), sem ADR novo (D-7).

## Ordem de implementação (insumo do `tasks.md`)

1. RED de integração (reprodução + pasta inexistente) → 2. `repo_root` + `resolve_folder` + `FolderConfigError` → 3. `require_folder`, `--create` e comandos → 4. `migrate` → 5. Pester → 6. documentação, ADR-1, ROADMAP → 7. validação do conjunto e auditoria.
