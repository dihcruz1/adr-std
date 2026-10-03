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
par de funções em `adr_cli.py`, usado por `new` e `organize`. Os wrappers `bin/adr-std` e
`bin/adr-std.ps1` não mudam de código: repassam `--name-pattern` ao Python.

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

### 2.4 Wrappers e instalação

Sem mudança de código em `bin/adr-std`, `bin/adr-std.ps1`, instaladores e `packaging/`. Os testes
`tests/test_cli.sh` e `tests/test_cli.ps1` passam a usar nomes sem zeros.

## 3. Migração dos ADRs 1 a 3 (RF-11, RF-12)

Executada como tarefa própria, depois de o código aceitar o novo padrão:

1. **Plano** (mostrado antes de aplicar): `git mv` de cada arquivo (`0001-x.md` → `1-x.md` etc.) e a lista de
   arquivos com referência afetada (obtida por `git grep` dos nomes antigos e de `ADR-000[1-3]`).
2. **Aplicação**, em ordem:
   a. `git mv` dos três arquivos.
   b. Nos três ADRs: título `# ADR-N:`, campo ID, "Relações com outras decisões", menções no corpo, links
      de Referências, "Modificado em" = 2026-10-03 e uma linha em "Histórico de modificações"
      (`Renumeração ADR-000N → ADR-N conforme ADR-4; texto da decisão inalterado`). O sentido da decisão não muda.
   c. Links (e menções textuais vivas) em `docs/architecture/ADR/ROADMAP.md`, `docs/agents/domain.md`,
      `skill/SKILL.md`, `README.md`, `GLOSSARY.md`, comentários de código e testes.
   d. Links de caminho para os nomes antigos em specs históricas (apenas o alvo do link, D-05); menções
      textuais `ADR-000N` nelas e no `CHANGELOG.md` ficam como estão.
   e. `ADR-4`: Referências e Relações apontam para `ADR-1`, `ADR-2`, `ADR-3`.
3. **Verificação:** `git grep -nE '(^|[^0-9])000[1-3]-[a-z]' -- docs skill tests README.md GLOSSARY.md CONTRIBUTING.md`
   sem links para os nomes antigos; `check_adr.py` e `check_roadmap.py` verdes na pasta de ADRs.

A migração não usa `sed` em massa sobre a árvore inteira: cada arquivo é editado com substituições
explícitas e revisado no `git diff` (AGENTS.md: preservar mudanças e comportamento fora do escopo).

## 4. Estratégia de testes

| Alvo | Arquivo | Casos novos / alterados |
|---|---|---|
| `check_adr.py` | `tests/test_check_adr.py` | fixture renomeada para `1-cache-de-sessao-em-redis.md` com `ADR-1`; A1 reprova `0001-`, `01-`, `0-`; A2 reprova `1-x.md` com `ADR-0001`; `--name-pattern` de 4 dígitos aprova `0001-`; STATUS aceita `ADR-4` e `ADR-0004` |
| `check_roadmap.py` | `tests/test_check_roadmap.py` | nomes `1-titulo.md` e links `[ADR-1](1-titulo.md)`; `--name-pattern` custom; regex inválida → 2; ADR `1-a.md` sem linha é acusado (não mais ignorado) |
| `adr_cli.py` | `tests/test_adr_cli.py` | `new` em pasta vazia → `1-`; com `2-` e `10-` → `11-`; com `0007-` e padrão de 4 dígitos → `0008-`; padrão incompatível em pasta vazia → código 1 sem arquivo; `organize` com 1..10 consistente; lacuna `1`,`5` → `5-b.md -> 2-b.md`; `list` ordena `2` antes de `10` |
| CLI bash | `tests/test_cli.sh` | nomes `1-usar-fila.md`, `ADR-1`/`ADR-2`; `organize` com `5-dois.md -> 2-dois.md`; fixture `1-...` |
| CLI PowerShell | `tests/test_cli.ps1` | mesmos nomes e asserts do bash |
| Migração | comando de verificação da seção 3 | busca sem link antigo; `check_adr.py` e `check_roadmap.py` verdes |

Regressão (matriz NR-01 a NR-08 dos requisitos): suíte Python completa (`python3 -m unittest discover -s tests -p 'test_*.py'`),
casos relevantes de `tests/test_cli.sh`, `tests/test_cli.ps1` e `bash tests/gate.sh static`.

## 5. Segurança (DevSecOps)

- Regex de usuário: só `re.match` em nomes de arquivo; compilação protegida (erro controlado, sem traceback).
  Risco de ReDoS limitado ao próprio usuário local; sem entrada remota (SEG-01). Registrado como risco aceito.
- Número é inteiro; o slug é `[a-z0-9-]`: sem travessia de diretório (SEG-03).
- Escrita exclusiva e `git mv` com caminhos explícitos; nada é apagado (SEG-02, SEG-04).
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
- Sem arquivo novo distribuído; sem mudança em instaladores.
- Documentação alterada: template, checklist, guia (seções 12 e 13), `SKILL.md`, `GLOSSARY.md`, `README.md`,
  `CONTRIBUTING.md`, `tests/cenarios.md`, `docs/agents/domain.md`, `CHANGELOG.md`, `VERSION`, os dois ROADMAPs.
