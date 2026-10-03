# Design — adr-std v2.0: numeração dos ADRs sem zeros à esquerda

| Campo | Detalhe |
|---|---|
| **Requisitos** | [requirements.md](requirements.md) |
| **ADR de origem** | [ADR-4](../../architecture/ADR/4-numeracao-dos-adrs-sem-zeros-a-esquerda.md) |
| **Status** | Gate 2 |

## 1. Visão geral

A mudança é de convenção, não de arquitetura. A regra do padrão de nome vive em `check_adr.py`
(`DEFAULT_NAME_PATTERN`), que `adr_cli.py` já importa; `check_roadmap.py` passa a importar a mesma
constante (D-06) e ganha `--name-pattern`. A regra de **largura do número** (D-08) nasce em um único
par de funções em `adr_cli.py`, usado por `new` e `organize`. Um script novo,
`skill/scripts/migrate_numbering.py`, adequa os projetos existentes (D-10); os wrappers ganham o
comando `adr-std migrate` e um gancho no final do `update` (D-11). Fora isso, os wrappers só repassam
`--name-pattern` ao Python.

## 2. Contratos

### 2.1 `skill/scripts/check_adr.py`

```python
DEFAULT_NAME_PATTERN = r"^([1-9]\d*)-[a-z0-9]+(?:-[a-z0-9]+)*\.md$"
STATUS = re.compile(r"^(Proposto|Aceito|Rejeitado|Obsoleto|Substituído por ADR-\d+)$")
```

- O grupo 1 continua sendo o número; A1 e A2 não mudam de lógica. A2 compara os dígitos do nome com os do
  ID (`ADR-(\d+)`), então funciona para `1`/`ADR-1` e para convenções com zeros (`0001`/`ADR-0001`).
- `STATUS` aceita `ADR-\d+` (qualquer largura) para tolerar convenções com zeros (RF-03).
- Sem mudança na CLI do script.

### 2.2 `skill/scripts/check_roadmap.py`

- `from check_adr import DEFAULT_NAME_PATTERN` (mesmo mecanismo de `sys.path` já usado em `adr_cli.py`).
- Remove `ADR_FILENAME`; a função de verificação recebe `name_pattern: re.Pattern[str]`.
- Nova opção `--name-pattern REGEX` (default `DEFAULT_NAME_PATTERN`). Regex inválida: mensagem
  `check_roadmap: --name-pattern inválido: <motivo>` em stderr e saída `2` (SEG-01, RF-05).
- Saídas existentes (0 ok, 1 falha de consistência) inalteradas.

### 2.3 `skill/scripts/adr_cli.py`

Funções novas (únicas fontes da largura, D-08):

```python
def number_of(path: Path, name_pattern: re.Pattern[str]) -> str | None:
    """Grupo 1 do padrão sobre o nome do arquivo, ou None."""

def number_width(numbers: list[str]) -> int:
    """Maior largura entre os números com zeros à esquerda; 0 se nenhum tiver."""

def format_number(n: int, width: int) -> str:
    return str(n).zfill(width)   # width 0 -> sem preenchimento
```

- `list_adrs` ordena por `(int(número), nome)`; arquivos cujo grupo 1 não for inteiro ordenam por nome
  depois dos numéricos (ordenação estável, nunca levanta exceção por padrão de usuário sem grupo numérico).
- `next_number`: `best = max(int)`, `width = number_width(...)`, devolve `format_number(best + 1, width)`.
  Pasta inexistente ou sem ADRs: `"1"`.
- `cmd_new`: após calcular o número, monta `f"{number}-{slug}.md"` e confere com `args.name_pattern`;
  se não casar, imprime em stderr `adr-std: o nome gerado '<nome>' não casa com o padrão ativo
  '<padrão>'; ajuste --name-pattern ou crie o ADR manualmente` e retorna `1` sem criar arquivo (RF-08).
  A criação continua em modo exclusivo (`"x"`, SEG-02).
- `cmd_organize`: `files` já vem ordenado numericamente; `width = number_width(...)`;
  `expected_id = f"ADR-{format_number(i, width)}"`; o nome esperado usa o mesmo número formatado. O teste
  `startswith` vira comparação exata do número (`number_of(f) == formatado`), evitando falso positivo
  entre `1` e `10`.
- `TITLE_LINE` (`ADR-\d+`) já aceita qualquer largura: sem mudança.

### 2.4 `skill/scripts/migrate_numbering.py` (novo)

```
migrate_numbering.py [--path PASTA] [--root RAIZ] [--apply] [--exclude GLOB]...
```

- `--path`: pasta de ADRs; por omissão, `resolve_folder` de `adr_cli.py` (importado; ADR-1, fonte única da
  precedência). `--root`: raiz do projeto; por omissão, `git rev-parse --show-toplevel` a partir do
  diretório de trabalho, ou o próprio diretório fora de git.
- Saída: `0` (plano mostrado, nada a fazer ou aplicado), `1` (conflito, árvore suja, erro na aplicação),
  `2` (argumento inválido).

Algoritmo (funções puras primeiro, E/S nas pontas):

1. `plan = build_plan(folder, root, excludes)`:
   - ADRs a migrar: arquivos de `folder` que casam `^0+(\d+)-([a-z0-9-]+)\.md$` (e `int` > 0). O novo nome é
     `<int>-<slug>.md`. Número duplicado entre os migrados, ou nome de destino já existente: `Conflict`.
   - Mapa `old_name -> new_name` e `old_number -> new_number` só para os ADRs migrados (RF-18).
   - Para cada `*.md` sob `root` (ver varredura abaixo): `rewrite(text, maps)` devolve o texto novo e a
     contagem de substituições. `rewrite` troca, nesta ordem: (1) o nome antigo do arquivo, como token
     delimitado (`(?<![A-Za-z0-9_-])0001-slug\.md`), pelo novo; (2) `ADR-0*<N>\b` por `ADR-<N>` quando `<N>`
     é um número migrado e a ocorrência é `ADR-` seguida de zeros à esquerda (formato antigo).
   - `Plan` guarda renomeações, `{arquivo: contagem}` e conflitos. Nada é gravado.
2. Varredura: `git ls-files '*.md'` quando há git (respeita `.gitignore`); senão `os.walk` ignorando `.git`,
   `node_modules`, `.venv` e `vendor`. Cada caminho é resolvido e precisa estar sob `root` (SEG-05); links
   simbólicos que saem da raiz são ignorados. `--exclude` usa `fnmatch` sobre o caminho relativo.
3. Opt-out: se `<root>/.adr-std` tiver `numbering: padded`, imprime que o projeto mantém zeros e sai com `0` (RF-22).
4. `apply(plan)`:
   - Recusa se `plan.conflicts`; em git, recusa se `git status --porcelain -- <arquivos afetados>` não for vazio
     (RF-19). Comandos git por `subprocess.run([...])`, sem shell (SEG-07).
   - Primeiro reescreve o conteúdo dos arquivos (antes do `git mv`, para o conteúdo e o nome nunca ficarem
     inconsistentes se um erro ocorrer no meio), depois renomeia com `git mv` (git) ou `Path.rename` (fora de git).
     Erro: para, imprime o que já foi feito, sai `1` (RF-20).
   - Preserva UTF-8, BOM e fim de linha originais: lê e grava em bytes decodificados com `newline=""`.
5. Idempotência: depois de aplicado, não há arquivo com zeros à esquerda nem `ADR-0\d+` de número migrado, e o
   plano fica vazio (RF-20).
6. Dependência: `from adr_cli import resolve_folder` (e `check_adr`), mesma importação por `sys.path` já usada
   em `adr_cli.py`. Sem dependência nova (RNF-03).

### 2.5 Wrappers (`bin/adr-std`, `bin/adr-std.ps1`) e gancho do `update`

- `adr-std migrate [--apply] [--path PASTA] [--exclude GLOB]...`: nova função `cmd_migrate` que usa
  `run_python_script migrate_numbering.py migrate "$@"` (PowerShell: função equivalente). Entra no `help` e na
  lista de comandos (`commands.tsv` não muda se ele só trata comandos de agente; confirmar na tarefa 3.2).
- `update` ganha a opção `--no-migrate`. Depois de `ADR_STD_REMOTE=1 bash "$installer" ...` terminar com
  sucesso e se não for `--dry-run` nem `--no-migrate`, chama `maybe_migrate`:
  1. Executa `migrate_numbering.py` sem `--apply` no diretório de trabalho e captura a saída e o código.
  2. Plano vazio ou projeto `numbering: padded` ou diretório sem pasta de ADRs: não imprime nada além de uma linha
     curta ("migração: nada a fazer").
  3. Com plano: imprime o plano; se houver terminal (mesma regra do menu: `ADR_STD_TTY` ou `/dev/tty`), pergunta
     `Aplicar a migração? [s/N]` e, só com `s`/`S`, roda `--apply`; sem terminal, imprime
     `adr-std migrate --apply`.
  4. Qualquer falha dessa etapa (sem Python 3, código ≠ 0) vira aviso em pt-BR; o código de saída do `update`
     continua o do instalador (RF-21).
- Limitação D-12: o gancho só existe no wrapper novo; o primeiro `update` a partir de ≤1.4 usa o wrapper antigo.
  `README.md` e `CHANGELOG.md` dizem para rodar `adr-std update` de novo ou `adr-std migrate`.
- Instaladores, `packaging/` e `agents.tsv` não mudam: `skill/scripts/migrate_numbering.py` já é copiado com
  `skill/`. Conferir na tarefa 3.2 que o pacote (`package.sh`) inclui o novo arquivo.

## 3. Migração dos ADRs 1 a 3 deste repositório (RF-11, RF-12)

Usa o próprio script (D-02, D-10), depois de o código aceitar o novo padrão:

1. **Plano:** `python3 skill/scripts/migrate_numbering.py --exclude 'docs/specs/2026-10-03-adr-numeracao-sem-zeros/*' --exclude 'docs/architecture/ADR/4-*'`
   mostra as três renomeações e as contagens por arquivo; o plano é registrado na evidência da tarefa e
   mostrado ao solicitante.
2. **Aplicação:** a mesma linha com `--apply`, com a árvore commitada (o script recusa árvore suja).
3. **Ajustes manuais:** `ADR-4` (Relações e Referências apontam para `ADR-1`, `ADR-2`, `ADR-3`; o texto que
   descreve o formato antigo fica) e o histórico/"Modificado em" dos três ADRs migrados
   (`Renumeração ADR-000N → ADR-N conforme ADR-4; texto da decisão inalterado`). O script só corrige número e
   link; não cria linha de histórico.
4. **Verificação:** `git grep -nE '(^|[^0-9])000[1-3]-[a-z]' -- '*.md'` sem links para os nomes antigos
   (exceto o que `--exclude` protegeu); `check_adr.py` e `check_roadmap.py` verdes na pasta de ADRs; segunda
   execução do script sem plano.

## 4. Estratégia de testes

| Alvo | Arquivo | Casos novos / alterados |
|---|---|---|
| `check_adr.py` | `tests/test_check_adr.py` | fixture renomeada para `1-cache-de-sessao-em-redis.md` com `ADR-1`; A1 reprova `0001-`, `01-`, `0-`; A2 reprova `1-x.md` com `ADR-0001`; `--name-pattern` de 4 dígitos aprova `0001-`; STATUS aceita `ADR-4` e `ADR-0004` |
| `check_roadmap.py` | `tests/test_check_roadmap.py` | nomes `1-titulo.md` e links `[ADR-1](1-titulo.md)`; `--name-pattern` custom; regex inválida → 2; ADR `1-a.md` sem linha é acusado (não mais ignorado) |
| `adr_cli.py` | `tests/test_adr_cli.py` | `new` em pasta vazia → `1-`; com `2-` e `10-` → `11-`; com `0007-` e padrão de 4 dígitos → `0008-`; padrão incompatível em pasta vazia → código 1 sem arquivo; `organize` com 1..10 consistente; lacuna `1`,`5` → `5-b.md -> 2-b.md`; `list` ordena `2` antes de `10` |
| CLI bash | `tests/test_cli.sh` | nomes `1-usar-fila.md`, `ADR-1`/`ADR-2`; `organize` com `5-dois.md -> 2-dois.md`; fixture `1-...` |
| CLI PowerShell | `tests/test_cli.ps1` | mesmos nomes e asserts do bash |
| Script de migração | `tests/test_migrate_numbering.py` (novo) | plano sem alterar; `--apply` renomeia (com e sem git), corrige ID, título, links e menções; só números migrados; `--exclude`; colisão e árvore suja recusadas; idempotência; `numbering: padded`; UTF-8 e fim de linha preservados; arquivo fora da raiz (link simbólico) ignorado; sem Python ou erro de IO não deixa estado pela metade |
| Wrappers | `tests/test_cli.sh`, `tests/test_cli.ps1` | `migrate` (plano e `--apply`); `update` com instalador falso: sem terminal imprime plano e comando, com terminal simulado (`ADR_STD_TTY`) aplica só com `s`, `--no-migrate` não calcula plano, `--dry-run` não migra, sem Python avisa e mantém o código de saída |
| Migração do repositório | verificação da seção 3 | busca sem link antigo; `check_adr.py` e `check_roadmap.py` verdes; segunda execução sem plano |

Regressão (matriz NR-01 a NR-08 dos requisitos): suíte Python completa (`python3 -m unittest discover -s tests -p 'test_*.py'`),
casos relevantes de `tests/test_cli.sh`, `tests/test_cli.ps1` e `bash tests/gate.sh static`.

## 5. Segurança (DevSecOps)

- Regex de usuário: só `re.match` em nomes de arquivo; compilação protegida (erro controlado, sem traceback).
  Risco de ReDoS limitado ao próprio usuário local; sem entrada remota (SEG-01). Registrado como risco aceito.
- Número é inteiro; o slug é `[a-z0-9-]`: sem travessia de diretório (SEG-03).
- Escrita exclusiva e `git mv` com caminhos explícitos; nada é apagado (SEG-02, SEG-04).
- Script de migração: opera só sob a raiz do projeto, resolve caminhos e ignora links simbólicos para fora
  (SEG-05); `subprocess` sem shell; plano sempre antes de aplicar e confirmação no `update` (SEG-06, SEG-07);
  recusa colisão e árvore suja (RF-19). Risco residual: fora de git não há desfazer; o plano avisa.
- CI (`release.yml`) e `tests/gate.sh static` continuam como gate de segurança antes do deploy; nenhum workflow novo.

## 6. Modelo de domínio (DDD)

**N/A justificado.** O Número do ADR é um valor simples (inteiro + largura de apresentação) sem
invariante de domínio além de "maior + 1, sem reuso", já expressa em `next_number` (função pura e
testável). Value Object ou Entidade rica seria superengenharia (AGENTS.md: DDD só com invariante de
domínio; KISS/YAGNI contra o `requirements.md`).

## 7. Impacto e reúso

- Reúso: `DEFAULT_NAME_PATTERN` (já importado por `adr_cli.py`), `list_adrs`, `parse`, `slugify`.
- Rule of Three: a regra "padrão de nome do ADR" aparecia 2 vezes (`check_adr.py` e `ADR_FILENAME` em
  `check_roadmap.py`); a regra de segurança/consistência de nome ganha fonte única desde já (D-06).
  A largura do número aparecia em `next_number` e `cmd_organize` (2 ocorrências, mesma regra): as funções
  de 2.3 centralizam porque `check_adr`-`adr_cli` já dividem o mesmo domínio e o risco é divergência de
  formato entre `new` e `organize`. Não há abstração além disso.
- Arquivo novo distribuído: `skill/scripts/migrate_numbering.py` (já coberto pela cópia de `skill/`); sem mudança em instaladores.
- Reúso: `resolve_folder` e `parse` de `adr_cli.py`/`check_adr.py`; a lógica de terminal do menu (`ADR_STD_TTY`) no gancho do `update`.
- Documentação alterada: template, checklist, guia (seções 12 e 13), `SKILL.md`, `GLOSSARY.md`, `README.md`,
  `CONTRIBUTING.md`, `tests/cenarios.md`, `docs/agents/domain.md`, `CHANGELOG.md`, `VERSION`, os dois ROADMAPs, e a tabela de comandos do `README.md` (`migrate`, `update --no-migrate`).
