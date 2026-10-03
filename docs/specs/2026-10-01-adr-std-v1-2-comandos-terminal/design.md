# Design — adr-std v1.2: comandos mecânicos no terminal

| Campo | Detalhe |
|---|---|
| **Requisitos** | [requirements.md](requirements.md) |
| **Status** | Gate 2 |

## Contrato

CLI Python `skill/scripts/adr_cli.py` (código existente retomado, não descartado):

```
adr_cli.py new <título> [--path P] [--name-pattern R]
adr_cli.py list [--path P] [--name-pattern R]
adr_cli.py link <ADR-A> <tipo> <ADR-B> [--path P] [--name-pattern R]
adr_cli.py organize --dry-run [--path P] [--name-pattern R]
```

A pasta passa de posicional para `--path` (ADR-1, nome do argumento explícito). Códigos de saída: 0 ok; 1 recurso ausente; 2 uso inválido; 6 sem Python (só nos wrappers).

`resolve_folder(path_arg, cwd, config_home)` (função pura, testável): `--path` > `.adr-std` no `cwd` > `<config_home>/adr-std/config` > `docs/architecture/ADR`. Campo lido com `^path\s*[:=]\s*(.+)$`.

`bin/adr-std` / `bin/adr-std.ps1`: função `run_python_script <script> args...` extraída de `cmd_check` (já existente), usada por `check`, `new`, `list`, `link`, `organize` (reuso; 5ª ocorrência da mesma regra de localizar Python → fonte única).

Empacotamento: `commands.tsv` e `command_targets.tsv` entram em `install.sh`, `install.ps1` e `package.sh` (`required`).

## Modelo de domínio

N/A justificado: scripts utilitários sem invariantes de domínio além de formato de arquivo; funções puras (`slugify`, `next_number`, `set_relation_field`) bastam. Sem Repositório/Agregado.

## Segurança

Slug restrito a `[a-z0-9-]` (SEG-01); `open(..., "x")` em `new` (modo exclusivo → falha em vez de sobrescrever, SEG-02); título normalizado para linha única (SEG-03); `link` calcula os dois textos antes de gravar (SEG-04).

## Estratégia de testes

- `tests/test_adr_cli.py` (unittest): subprocesso real do script, pasta temporária. Cobre RF-01..08, SEG-01..04 e `resolve_folder`.
- `tests/test_cli.sh`: despacho `new/list/link/organize`, código 6 sem Python (PATH reduzido), `help`, pacote e instalador com os `.tsv`.
- `tests/test_cli.ps1` (Pester): mesmos cenários do despacho no PowerShell.
- E2E: `adr-std new` → `list` → `link` → `organize --dry-run` → `check` num HOME/pasta temporários.
