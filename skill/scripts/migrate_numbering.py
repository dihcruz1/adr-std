#!/usr/bin/env python3
"""Migra a numeração dos ADRs para o formato sem zeros à esquerda (v2.0).

Renomeia `0001-<slug>.md` para `1-<slug>.md` (mantém o número, não renumera nem fecha lacunas) e
corrige, em todos os `*.md` do projeto, o nome antigo do arquivo (links) e o ID `ADR-0001` -> `ADR-1`,
só para os ADRs migrados. Sem `--apply` apenas mostra o plano e não altera nada.

Pasta dos ADRs: --path > `.adr-std` (campo `path`) > config global > docs/architecture/ADR
(mesma precedência do adr_cli.py). Raiz do projeto: --root > raiz do repositório git > diretório atual.
Projeto com `numbering: padded` no `.adr-std` mantém os zeros à esquerda e não é migrado.

Uso:
    python3 migrate_numbering.py [--path PASTA] [--root RAIZ] [--apply] [--exclude GLOB]...

Saída: 0 (plano mostrado, nada a fazer ou aplicado), 1 (conflito, árvore suja ou erro na aplicação),
2 (argumento inválido).
Contrato com o gancho do `update`: havendo plano, a primeira linha da saída contém "plano de migração";
nos demais casos (nada a fazer, padded, sem pasta) essa expressão não aparece.
"""

from __future__ import annotations

import argparse
import fnmatch
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from adr_cli import resolve_folder  # noqa: E402

PREFIX = "adr-std migrate:"
PADDED_ADR = re.compile(r"^0+(\d+)-([a-z0-9-]+)\.md$")
PADDED_OPTOUT = re.compile(r"^numbering\s*[:=]\s*padded\s*$")
OLD_ID = re.compile(r"(?<![A-Za-z0-9])ADR-(0\d*)(?!\d)")
IGNORED_DIRS = {".git", "node_modules", ".venv", "vendor"}


@dataclass
class Plan:
    renames: dict[str, str] = field(default_factory=dict)  # nome antigo -> nome novo
    counts: dict[str, int] = field(default_factory=dict)  # *.md (relativo à raiz) -> referências
    contents: dict[str, str] = field(default_factory=dict)  # *.md -> texto novo (só os alterados)
    conflicts: list[str] = field(default_factory=list)
    skipped: list[str] = field(default_factory=list)
    folder_rel: str = ""

    @property
    def empty(self) -> bool:
        return not self.renames and not self.counts


# ---------------------------------------------------------------- funções puras


def plan_renames(names: list[str]) -> tuple[dict[str, str], list[str]]:
    """Define as renomeações e os conflitos a partir dos nomes de arquivo da pasta de ADRs."""
    renames: dict[str, str] = {}
    by_number: dict[int, str] = {}
    conflicts: list[str] = []
    existing = set(names)
    for name in sorted(names):
        m = PADDED_ADR.match(name)
        if not m or int(m.group(1)) == 0:
            continue
        number = int(m.group(1))
        new = f"{number}-{m.group(2)}.md"
        if number in by_number:
            conflicts.append(f"número duplicado {number}: {by_number[number]} e {name}")
            continue
        by_number[number] = name
        renames[name] = new
    for old, new in list(renames.items()):
        if new in existing:
            conflicts.append(f"destino já existe: {old} -> {new}")
    migrated = set(by_number)
    for name in sorted(existing):
        m = re.match(r"^([1-9]\d*)-[a-z0-9-]+\.md$", name)
        if m and int(m.group(1)) in migrated and name not in renames.values():
            conflicts.append(
                f"número {m.group(1)} já em uso por {name}: {by_number[int(m.group(1))]} colidiria"
            )
    return renames, conflicts


def rewrite(text: str, name_map: dict[str, str], number_map: dict[int, int]) -> tuple[str, int]:
    """Troca o nome antigo dos arquivos e `ADR-0*N` dos ADRs migrados; devolve (texto, contagem)."""
    count = 0
    if name_map:
        alternation = "|".join(re.escape(n) for n in sorted(name_map, key=len, reverse=True))
        pattern = re.compile(rf"(?<![A-Za-z0-9_-])({alternation})(?![A-Za-z0-9_-])")

        def by_name(m: re.Match[str]) -> str:
            return name_map[m.group(1)]

        text, n = pattern.subn(by_name, text)
        count += n

    def by_id(m: re.Match[str]) -> str:
        old = int(m.group(1))
        if old in number_map:
            return f"ADR-{number_map[old]}"
        return m.group(0)

    changed = 0

    def counted(m: re.Match[str]) -> str:
        nonlocal changed
        new = by_id(m)
        if new != m.group(0):
            changed += 1
        return new

    text = OLD_ID.sub(counted, text)
    return text, count + changed


def is_padded_optout(config_text: str) -> bool:
    return any(PADDED_OPTOUT.match(line.strip()) for line in config_text.splitlines())


def excluded(rel: str, excludes: list[str]) -> bool:
    return any(fnmatch.fnmatch(rel, pattern) for pattern in excludes)


# ---------------------------------------------------------------- E/S


def run_git(root: Path, *args: str) -> subprocess.CompletedProcess[str] | None:
    try:
        return subprocess.run(
            ["git", *args], cwd=root, capture_output=True, text=True, check=False
        )
    except OSError:
        return None


def in_git(root: Path) -> bool:
    r = run_git(root, "rev-parse", "--is-inside-work-tree")
    return bool(r and r.returncode == 0 and r.stdout.strip() == "true")


def default_root(cwd: Path) -> Path:
    r = run_git(cwd, "rev-parse", "--show-toplevel")
    if r and r.returncode == 0 and r.stdout.strip():
        return Path(r.stdout.strip()).resolve()
    return cwd.resolve()


def under(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def list_markdown(root: Path, use_git: bool) -> list[str]:
    """Caminhos `*.md` relativos à raiz (posix), sem sair da raiz (SEG-05)."""
    candidates: list[str] = []
    r = run_git(root, "ls-files", "-z", "*.md") if use_git else None
    if r is not None and r.returncode == 0:
        candidates = [p for p in r.stdout.split("\0") if p]
    else:
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = sorted(d for d in dirnames if d not in IGNORED_DIRS)
            for f in sorted(filenames):
                if f.endswith(".md"):
                    candidates.append(Path(dirpath, f).relative_to(root).as_posix())
    result: list[str] = []
    seen: set[Path] = set()
    for rel in candidates:
        full = root / rel
        try:
            resolved = full.resolve(strict=True)
        except OSError:
            continue
        if not under(resolved, root) or not resolved.is_file() or resolved in seen:
            continue
        seen.add(resolved)
        result.append(rel)
    return result


def read_text_file(path: Path) -> str:
    with open(path, encoding="utf-8", newline="") as f:
        return f.read()


def write_text_file(path: Path, text: str) -> None:
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def rename_file(root: Path, old: str, new: str, use_git: bool) -> None:
    if use_git:
        r = subprocess.run(
            ["git", "mv", "--", old, new], cwd=root, capture_output=True, text=True, check=False
        )
        if r.returncode != 0:
            raise OSError(f"git mv {old} {new} falhou: {r.stderr.strip()}")
    else:
        (root / old).rename(root / new)


def build_plan(folder: Path, root: Path, excludes: list[str], use_git: bool = False) -> Plan:
    """Calcula o plano: renomeações, conflitos e textos reescritos. Não grava nada."""
    plan = Plan(folder_rel=folder.relative_to(root).as_posix())
    names = sorted(p.name for p in folder.iterdir() if p.is_file()) if folder.is_dir() else []
    plan.renames, plan.conflicts = plan_renames(names)
    if not plan.renames:
        return plan
    name_map = plan.renames
    number_map = {int(PADDED_ADR.match(n).group(1)): int(PADDED_ADR.match(n).group(1)) for n in name_map}
    for rel in list_markdown(root, use_git):
        if excluded(rel, excludes):
            continue
        try:
            text = read_text_file(root / rel)
        except (UnicodeDecodeError, OSError):
            plan.skipped.append(rel)
            continue
        new_text, n = rewrite(text, name_map, number_map)
        if n and new_text != text:
            plan.counts[rel] = n
            plan.contents[rel] = new_text
    return plan


def affected_paths(plan: Plan) -> list[str]:
    paths = {f"{plan.folder_rel}/{old}" if plan.folder_rel != "." else old for old in plan.renames}
    paths.update(plan.counts)
    return sorted(paths)


def dirty_files(root: Path, paths: list[str]) -> list[str]:
    r = run_git(root, "status", "--porcelain", "--", *paths)
    if r is None or r.returncode != 0:
        return [f"(não foi possível consultar o git: {r.stderr.strip() if r else 'git ausente'})"]
    return [line for line in r.stdout.splitlines() if line.strip()]


def print_plan(plan: Plan, use_git: bool) -> None:
    print(f"{PREFIX} plano de migração (nada foi alterado)")
    print("Renomeações:")
    for old, new in sorted(plan.renames.items(), key=lambda kv: int(PADDED_ADR.match(kv[0]).group(1))):
        print(f"  {old} -> {new}")
    if plan.counts:
        print("Referências a corrigir:")
        for rel, n in sorted(plan.counts.items()):
            print(f"  {rel}: {n}")
    for rel in plan.skipped:
        print(f"Ignorado (não é UTF-8 legível): {rel}")
    if not use_git:
        print("Aviso: fora de repositório git não há como desfazer; faça uma cópia antes de aplicar.")
    print("Para aplicar: adr-std migrate --apply")


def apply_plan(plan: Plan, root: Path, use_git: bool) -> int:
    done: list[str] = []

    def fail(exc: Exception) -> int:
        print(f"{PREFIX} erro na aplicação: {exc}", file=sys.stderr)
        print(f"{PREFIX} parou; já feito: " + ("; ".join(done) if done else "nada"))
        print(f"{PREFIX} corrija a causa e rode de novo (as etapas já feitas são idempotentes).")
        return 1

    for rel, text in sorted(plan.contents.items()):
        try:
            write_text_file(root / rel, text)
        except OSError as exc:
            return fail(exc)
        done.append(f"conteúdo de {rel} ({plan.counts[rel]} referências)")
    folder = plan.folder_rel
    for old, new in sorted(plan.renames.items()):
        prefix = "" if folder == "." else f"{folder}/"
        try:
            rename_file(root, f"{prefix}{old}", f"{prefix}{new}", use_git)
        except OSError as exc:
            return fail(exc)
        done.append(f"{old} -> {new}")
    print(f"{PREFIX} migração aplicada:")
    for item in done:
        print(f"  {item}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(prog="migrate_numbering.py", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--path", dest="path_arg", help="pasta dos ADRs")
    ap.add_argument("--root", help="raiz do projeto (por omissão, raiz do git ou diretório atual)")
    ap.add_argument("--apply", action="store_true", help="aplica a migração (sem isto só mostra o plano)")
    ap.add_argument("--exclude", action="append", default=[], metavar="GLOB",
                    help="caminho (relativo à raiz) cujo conteúdo não é reescrito; repetível")
    args = ap.parse_args()

    cwd = Path.cwd().resolve()
    root = Path(args.root).resolve() if args.root else default_root(cwd)
    if not root.is_dir():
        print(f"{PREFIX} --root inválido: {root} não é um diretório", file=sys.stderr)
        return 2

    config = root / ".adr-std"
    if config.is_file():
        try:
            if is_padded_optout(config.read_text(encoding="utf-8")):
                print(f"{PREFIX} o projeto mantém zeros à esquerda (numbering: padded); nada a fazer.")
                return 0
        except (OSError, UnicodeDecodeError):
            pass

    if args.path_arg:
        folder = (cwd / args.path_arg).resolve()
        if not folder.exists() and not Path(args.path_arg).is_absolute():
            folder = (root / args.path_arg).resolve()  # relativo à raiz, se não existe no cwd
    else:
        config_home = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
        folder = (root / resolve_folder(None, root, config_home)).resolve()
    if not under(folder, root):
        print(f"{PREFIX} a pasta de ADRs ({folder}) está fora da raiz ({root})", file=sys.stderr)
        return 2
    if not folder.is_dir():
        print(f"{PREFIX} pasta de ADRs não encontrada ({folder}); nada a migrar.")
        return 0

    use_git = in_git(root)
    plan = build_plan(folder, root, args.exclude, use_git)

    if plan.conflicts:
        print(f"{PREFIX} conflitos; nada foi alterado:")
        for c in plan.conflicts:
            print(f"  {c}")
        return 1
    if plan.empty:
        print(f"{PREFIX} numeração já adequada; nada a migrar.")
        return 0
    if not args.apply:
        print_plan(plan, use_git)
        return 0

    if use_git:
        dirty = dirty_files(root, affected_paths(plan))
        if dirty:
            print(f"{PREFIX} há alterações não commitadas nos arquivos afetados; commit ou stash antes:")
            for line in dirty:
                print(f"  {line}")
            return 1
    print(f"{PREFIX} aplicando a migração ({len(plan.renames)} renomeações)")
    return apply_plan(plan, root, use_git)


if __name__ == "__main__":
    sys.exit(main())
