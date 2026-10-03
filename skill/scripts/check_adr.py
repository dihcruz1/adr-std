#!/usr/bin/env python3
"""Verifica os itens mecânicos do checklist da skill adr-std.

Cobre os itens marcados com [auto] em references/checklist.md. Os demais
exigem leitura humana ou do agente.

Uso:
    python3 check_adr.py <arquivo-ou-pasta> [...] [--name-pattern REGEX]

Saída (código):
    0  todos os itens verificados passaram
    1  falhou ao menos um requisito da norma (N-DEVE)
    2  falharam apenas recomendações (N-DEVERIA) ou regras da skill (S)
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

DEFAULT_NAME_PATTERN = r"^([1-9]\d*)-[a-z0-9]+(?:-[a-z0-9]+)*\.md$"
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
STATUS = re.compile(
    r"^(Proposto|Aceito|Rejeitado|Obsoleto|Substituído por ADR-\d+)$"
)
HEADER_ROW = re.compile(r"^\|\s*\*\*(.+?)\*\*\s*\|\s*(.*?)\s*\|\s*$")
SECTION = re.compile(r"^##\s+(.+?)\s*$")
PLACEHOLDER = re.compile(r"<(?!https?://)[^<>\n]+>")
INLINE_CODE = re.compile(r"`[^`\n]*`")
# Rótulos do estilo MADR do projeto que equivalem aos rótulos da skill.
HEADER_ALIASES = {"Preocupações (concerns)": "Concerns e aspectos", "Data": "Data da decisão"}


def has_placeholder(text: str) -> bool:
    """Marcador de template (<...>) fora de código em linha: `<AAAA-MM-DD>` num caminho não conta."""
    return bool(PLACEHOLDER.search(INLINE_CODE.sub("", text)))
RATIONALE_MARKER = re.compile(r"\b(porque|pois|justificativa|rationale|because)\b", re.IGNORECASE)
IGNORED_FILES = {"template-madr.md", "_template-madr.md", "CONVENTIONS.md", "README.md", "ROADMAP.md"}


@dataclass
class Result:
    code: str
    origin: str  # N-DEVE, N-DEVERIA ou S
    ok: bool
    message: str


def parse(text: str) -> tuple[dict[str, str], dict[str, str]]:
    header: dict[str, str] = {}
    sections: dict[str, list[str]] = {}
    current = None
    for line in text.splitlines():
        m = SECTION.match(line)
        if m:
            current = re.sub(r"^\d+(?:\.\d+)*\.?\s+", "", m.group(1).strip())
            sections[current] = []
            continue
        if current is None:
            h = HEADER_ROW.match(line)
            if h:
                label = h.group(1).strip()
                header.setdefault(HEADER_ALIASES.get(label, label), h.group(2).strip())
        else:
            sections[current].append(line)
    return header, {k: "\n".join(v) for k, v in sections.items()}


def guide_lines(lines: list[str]) -> set[int]:
    """Índices das linhas de blocos de citação que começam com '> Guia'."""
    found, in_guide = set(), False
    for i, ln in enumerate(lines):
        stripped = ln.lstrip()
        if stripped.startswith("> Guia") or (in_guide and stripped.startswith(">")):
            found.add(i)
            in_guide = True
        else:
            in_guide = False
    return found


def meaningful(body: str) -> str:
    lines = body.splitlines()
    guides = guide_lines(lines)
    lines = [
        ln for i, ln in enumerate(lines)
        if i not in guides and ln.strip() and not has_placeholder(ln)
    ]
    return "\n".join(lines).strip()


def find_section(sections: dict[str, str], prefix: str) -> str | None:
    for name, body in sections.items():
        if name.lower().startswith(prefix.lower()):
            return body
    return None


def filled(value: str | None) -> bool:
    return bool(value) and not has_placeholder(value)


def check(path: Path, name_pattern: re.Pattern[str]) -> list[Result]:
    text = path.read_text(encoding="utf-8")
    header, sections = parse(text)
    r: list[Result] = []

    m = name_pattern.match(path.name)
    r.append(Result("A1", "S", bool(m), "nome do arquivo segue a convenção"))

    adr_id = header.get("ID", "")
    id_num = re.fullmatch(r"ADR-(\d+)", adr_id)
    same = bool(m and id_num and m.group(1) == id_num.group(1))
    r.append(Result("A2", "N-DEVERIA", same, f"ID do cabeçalho ({adr_id or 'ausente'}) coincide com o arquivo"))

    status = header.get("Status", "")
    r.append(Result("A3", "S", bool(STATUS.match(status)), f"Status válido ({status or 'ausente'})"))

    r.append(Result("A4", "N-DEVERIA", bool(DATE.match(header.get("Data da decisão", ""))), "Data da decisão em AAAA-MM-DD"))

    approved = header.get("Aprovado em", "")
    ok_a5 = bool(DATE.match(approved)) or (approved.startswith("pendente") and not status.startswith("Aceito"))
    r.append(Result("A5", "N-DEVERIA", ok_a5, "Aprovado em preenchido (data obrigatória se Aceito)"))

    modified = header.get("Modificado em", "")
    r.append(Result("A6", "N-DEVERIA", bool(DATE.match(modified)) or modified == "—", "Modificado em preenchido"))

    all_lines = text.splitlines()
    guides = guide_lines(all_lines)
    leftovers = [
        i + 1 for i, ln in enumerate(all_lines)
        if i in guides or has_placeholder(ln)
    ]
    r.append(Result("A7", "S", not leftovers, "sem instruções do template restantes"
                    + (f" (linhas {leftovers[:5]})" if leftovers else "")))

    decision = find_section(sections, "Decisão")
    r.append(Result("B1", "N-DEVE", bool(decision and meaningful(decision)), "seção Decisão preenchida (6.10.1)"))

    rationale = find_section(sections, "Justificativa")
    if rationale and meaningful(rationale):
        r.append(Result("B4", "N-DEVE", True, "justificativa preenchida (6.10.2)"))
    else:
        inline = bool(decision and RATIONALE_MARKER.search(meaningful(decision)))
        r.append(Result("B4", "N-DEVE", inline,
                        "justificativa dentro da seção Decisão (6.10.2; confirme na leitura)" if inline
                        else "justificativa não encontrada em seção própria nem na Decisão; "
                        "confirme na leitura se está referenciada em outra seção (6.10.2)"))

    options = meaningful(find_section(sections, "Opções consideradas") or "")
    n_options = max(
        len(re.findall(r"(?m)^\s*\d+\.\s+\S", options)),   # lista numerada
        len(re.findall(r"(?m)^\|\s*\d+\s*\|", options)),    # tabela com coluna de número
    )
    single = re.search(r"única|apenas uma|só havia", options, re.IGNORECASE)
    r.append(Result("C1", "N-DEVERIA", n_options >= 2 or bool(single),
                    f"ao menos duas opções ou justificativa de opção única ({n_options} encontradas)"))

    pros = find_section(sections, "Prós e contras") or ""
    rejected = re.split(r"(?m)^###\s+", pros)
    missing = [
        blk.splitlines()[0] for blk in rejected[1:]
        if "rejeitada" in blk.splitlines()[0].lower() and "motivo da rejeição" not in blk.lower()
    ]
    r.append(Result("C2", "N-DEVERIA", not missing,
                    "opções rejeitadas têm motivo" + (f" (faltando: {missing})" if missing else "")))

    for code, field, origin in [
        ("D1", "Decisores", "N-DEVERIA"),
        ("D4", "Concerns e aspectos", "N-DEVERIA"),
        ("D6", "Elementos afetados", "N-DEVERIA"),
    ]:
        r.append(Result(code, origin, filled(header.get(field)), f"{field} preenchido"))

    for code, prefix, origin, label in [
        ("D3", "Restrições e suposições", "N-DEVERIA", "Restrições e suposições"),
        ("E1", "Consequências", "N-DEVERIA", "Consequências"),
        ("E3", "Verificação", "S", "Verificação"),
        ("E4", "Limitações deste registro", "N-DEVERIA", "Limitações deste registro"),
    ]:
        body = find_section(sections, prefix)
        r.append(Result(code, origin, bool(body and meaningful(body)), f"seção {label} preenchida"))

    r.append(Result("E5", "N-DEVERIA", find_section(sections, "Referências") is not None, "seção Referências existe"))
    return r


def collect(targets: list[str]) -> list[Path]:
    files: list[Path] = []
    for t in targets:
        p = Path(t)
        if p.is_dir():
            files += sorted(f for f in p.glob("*.md") if f.name not in IGNORED_FILES and not f.name.startswith("_"))
        elif p.is_file():
            files.append(p)
        else:
            print(f"aviso: {t} não encontrado", file=sys.stderr)
    return files


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("targets", nargs="+", help="arquivos ADR ou pastas")
    ap.add_argument("--name-pattern", default=DEFAULT_NAME_PATTERN,
                    help="regex do nome do arquivo; o grupo 1 deve capturar o número")
    args = ap.parse_args()
    pattern = re.compile(args.name_pattern)

    worst = 0
    for path in collect(args.targets):
        results = check(path, pattern)
        failed = [x for x in results if not x.ok]
        print(f"\n{path}")
        for x in results:
            mark = "OK  " if x.ok else "FALHA"
            print(f"  [{mark}] {x.code} ({x.origin}) {x.message}")
        if any(x.origin == "N-DEVE" for x in failed):
            worst = 1
        elif failed and worst == 0:
            worst = 2
    print("\nItens sem [auto] no checklist.md exigem leitura.")
    return worst


if __name__ == "__main__":
    sys.exit(main())
