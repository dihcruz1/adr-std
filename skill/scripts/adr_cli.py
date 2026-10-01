#!/usr/bin/env python3
"""Comandos mecânicos da skill adr-std no terminal (v1.2): new, list, link, organize.

Mesma lógica de parsing e de nome de arquivo de check_adr.py (reaproveitada por importação,
mesmo diretório). Pasta dos ADRs (ADR-0001): --path > `.adr-std` (campo `path`) > config global
(campo `path`) > docs/architecture/ADR. A convenção em `CONVENTIONS.md`/`AGENTS.md` (texto livre)
é lida só pelo agente, via SKILL.md.

Uso:
    python3 adr_cli.py new <título> [--path PASTA] [--name-pattern REGEX]
    python3 adr_cli.py list [--path PASTA] [--name-pattern REGEX]
    python3 adr_cli.py link <ADR-A> <tipo> <ADR-B> [--path PASTA] [--name-pattern REGEX]
    python3 adr_cli.py organize --dry-run [--path PASTA] [--name-pattern REGEX]
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import unicodedata
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_adr import DEFAULT_NAME_PATTERN, HEADER_ROW, IGNORED_FILES, parse  # noqa: E402

TITLE_LINE = re.compile(r"^#\s+ADR-\d+:\s*(.+?)\s*$")

RECIPROCAL = {
    "restringe": "é restringido por",
    "influencia": "é influenciado por",
    "habilita": "é habilitado por",
    "dispara": "é disparado por",
    "força": "é forçado por",
    "engloba": "é englobado por",
    "refina": "é refinado por",
    "conflita com": "conflita com",
    "expõe": "é exposto por",
    "é compatível com": "é compatível com",
    "substitui": "substituído por",
}


DEFAULT_FOLDER = Path("docs/architecture/ADR")
PATH_FIELD = re.compile(r"^path\s*[:=]\s*(.+?)\s*$")


def read_path_field(config_file: Path) -> Path | None:
    if not config_file.is_file():
        return None
    for line in config_file.read_text(encoding="utf-8").splitlines():
        m = PATH_FIELD.match(line.strip())
        if m:
            return Path(m.group(1))
    return None


def resolve_folder(path_arg: str | None, cwd: Path, config_home: Path) -> Path:
    """Precedência do ADR-0001: --path > .adr-std local > config global > padrão."""
    if path_arg:
        return Path(path_arg)
    return (
        read_path_field(cwd / ".adr-std")
        or read_path_field(config_home / "adr-std" / "config")
        or DEFAULT_FOLDER
    )


def slugify(title: str) -> str:
    normalized = unicodedata.normalize("NFKD", title).encode("ascii", "ignore").decode("ascii")
    slug = re.sub(r"[^a-z0-9]+", "-", normalized.lower()).strip("-")
    return re.sub(r"-+", "-", slug) or "adr"


def list_adrs(folder: Path, name_pattern: re.Pattern[str]) -> list[Path]:
    files = []
    for f in sorted(folder.glob("*.md")):
        if f.name in IGNORED_FILES or f.name.startswith("_"):
            continue
        if name_pattern.match(f.name):
            files.append(f)
    return files


def next_number(folder: Path, name_pattern: re.Pattern[str]) -> str:
    width = 4
    best = 0
    if folder.exists():
        for f in list_adrs(folder, name_pattern):
            m = name_pattern.match(f.name)
            if not m:
                continue
            num = m.group(1)
            width = max(width, len(num))
            best = max(best, int(num))
    return str(best + 1).zfill(width)


ADR_SECTIONS = [
    "Contexto e definição do problema",
    "Restrições e suposições",
    "Fatores de decisão (drivers)",
    "Opções consideradas",
    "Decisão",
    "Justificativa",
    "Prós e contras das opções",
    "Consequências",
    "Verificação",
    "Limitações deste registro",
]


def build_adr_skeleton(number: str, title: str, today: str) -> str:
    adr_id = f"ADR-{number}"
    lines = [
        f"# {adr_id}: {title}",
        "",
        "| Campo | Valor |",
        "|---|---|",
        f"| **ID** | {adr_id} |",
        "| **Status** | Proposto |",
        f"| **Data da decisão** | {today} |",
        "| **Aprovado em** | pendente |",
        "| **Modificado em** | — |",
        "| **Decisores** | pendente |",
        "| **Autoridade que aprova** | pendente |",
        "| **Stakeholders afetados** | pendente |",
        "| **Concerns e aspectos** | pendente |",
        "| **Elementos afetados** | pendente |",
        "| **Relações com outras decisões** | pendente |",
        "",
    ]
    for section in ADR_SECTIONS:
        lines += [f"## {section}", "", "pendente", ""]
    lines += [
        "## Histórico de modificações",
        "",
        "| Data | Alteração | Autor |",
        "|---|---|---|",
        f"| {today} | Criação | pendente |",
        "",
        "## Referências",
        "",
        "pendente",
        "",
    ]
    return "\n".join(lines)


def write_new_adr(folder: Path, number: str, title: str, today: str) -> Path:
    """Grava o esqueleto; modo exclusivo ("x") nunca sobrescreve um arquivo existente."""
    path = folder / f"{number}-{slugify(title)}.md"
    with path.open("x", encoding="utf-8") as f:
        f.write(build_adr_skeleton(number, title, today))
    return path


def cmd_new(args: argparse.Namespace) -> int:
    title = " ".join(args.title.split())
    if not title:
        print("adr-std: o título não pode ser vazio", file=sys.stderr)
        return 2
    folder = args.folder
    folder.mkdir(parents=True, exist_ok=True)
    number = next_number(folder, args.name_pattern)
    path = write_new_adr(folder, number, title, date.today().isoformat())
    print(f"criado: {path}")
    return 0


def adr_title(text: str, fallback: str) -> str:
    first = text.splitlines()[0] if text else ""
    m = TITLE_LINE.match(first)
    return m.group(1) if m else fallback


def cmd_list(args: argparse.Namespace) -> int:
    folder = args.folder
    if not folder.is_dir():
        print(f"adr-std: pasta não encontrada: {folder}", file=sys.stderr)
        return 1
    files = list_adrs(folder, args.name_pattern)
    if not files:
        print(f"nenhum ADR encontrado em {folder}")
        return 0
    print(f"{'ID':<10} {'STATUS':<12} {'DATA':<12} TÍTULO")
    for f in files:
        text = f.read_text(encoding="utf-8")
        header, _ = parse(text)
        print(
            f"{header.get('ID', '?'):<10} {header.get('Status', '?'):<12} "
            f"{header.get('Data da decisão', '?'):<12} {adr_title(text, f.stem)}"
        )
    return 0


def set_relation_field(text: str, relation_text: str) -> str | None:
    lines = text.splitlines()
    for i, line in enumerate(lines):
        m = HEADER_ROW.match(line)
        if m and m.group(1).strip() == "Relações com outras decisões":
            current = m.group(2).strip()
            new_value = relation_text if current in ("", "pendente", "—") else f"{current}; {relation_text}"
            lines[i] = f"| **Relações com outras decisões** | {new_value} |"
            return "\n".join(lines) + ("\n" if text.endswith("\n") else "")
    return None


def cmd_link(args: argparse.Namespace) -> int:
    folder = args.folder
    tipo = args.tipo.strip()
    if tipo not in RECIPROCAL:
        print(
            f"adr-std: tipo de relação desconhecido: {tipo!r}. Use um de: {', '.join(RECIPROCAL)}",
            file=sys.stderr,
        )
        return 2
    path_a = find_adr_file(folder, args.adr_a, args.name_pattern)
    path_b = find_adr_file(folder, args.adr_b, args.name_pattern)
    if path_a is None:
        print(f"adr-std: ADR não encontrado: {args.adr_a}", file=sys.stderr)
        return 1
    if path_b is None:
        print(f"adr-std: ADR não encontrado: {args.adr_b}", file=sys.stderr)
        return 1
    text_a = set_relation_field(path_a.read_text(encoding="utf-8"), f"{tipo} {args.adr_b}")
    text_b = set_relation_field(path_b.read_text(encoding="utf-8"), f"{RECIPROCAL[tipo]} {args.adr_a}")
    if text_a is None or text_b is None:
        print("adr-std: campo 'Relações com outras decisões' não encontrado num dos ADRs", file=sys.stderr)
        return 1
    path_a.write_text(text_a, encoding="utf-8")
    path_b.write_text(text_b, encoding="utf-8")
    print(f"relação registrada: {args.adr_a} {tipo} {args.adr_b}")
    print(f"relação recíproca: {args.adr_b} {RECIPROCAL[tipo]} {args.adr_a}")
    return 0


def find_adr_file(folder: Path, adr_id: str, name_pattern: re.Pattern[str]) -> Path | None:
    for f in list_adrs(folder, name_pattern):
        header, _ = parse(f.read_text(encoding="utf-8"))
        if header.get("ID") == adr_id:
            return f
    return None


def cmd_organize(args: argparse.Namespace) -> int:
    if not args.dry_run:
        print(
            "adr-std: organize só está disponível em --dry-run nesta versão; "
            "a reorganização real fica fora do escopo da v1.2",
            file=sys.stderr,
        )
        return 2
    folder = args.folder
    if not folder.is_dir():
        print(f"adr-std: pasta não encontrada: {folder}", file=sys.stderr)
        return 1
    files = list_adrs(folder, args.name_pattern)
    plan = []
    for i, f in enumerate(sorted(files, key=lambda p: p.name), start=1):
        header, _ = parse(f.read_text(encoding="utf-8"))
        expected_id = f"ADR-{str(i).zfill(4)}"
        if header.get("ID") != expected_id or not f.name.startswith(str(i).zfill(4)):
            slug = slugify(adr_title(f.read_text(encoding="utf-8"), f.stem))
            plan.append((f.name, f"{str(i).zfill(4)}-{slug}.md"))
    if not plan:
        print("(simulação) nenhuma mudança necessária: numeração já consistente")
        return 0
    print("(simulação) plano de reorganização:")
    for old, new in plan:
        print(f"  {old} -> {new}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)

    def add_common(p: argparse.ArgumentParser) -> None:
        p.add_argument("--path", dest="path_arg", help="pasta dos ADRs")
        p.add_argument("--name-pattern", default=DEFAULT_NAME_PATTERN, dest="name_pattern_raw")

    p_new = sub.add_parser("new")
    p_new.add_argument("title")
    add_common(p_new)

    add_common(sub.add_parser("list"))

    p_link = sub.add_parser("link")
    p_link.add_argument("adr_a")
    p_link.add_argument("tipo")
    p_link.add_argument("adr_b")
    add_common(p_link)

    p_org = sub.add_parser("organize")
    p_org.add_argument("--dry-run", action="store_true", dest="dry_run")
    add_common(p_org)

    args = ap.parse_args()
    args.name_pattern = re.compile(args.name_pattern_raw)
    config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
    args.folder = resolve_folder(args.path_arg, Path.cwd(), config_home)

    handlers = {"new": cmd_new, "list": cmd_list, "link": cmd_link, "organize": cmd_organize}
    return handlers[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
