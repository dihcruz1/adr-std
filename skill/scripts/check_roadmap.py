#!/usr/bin/env python3
"""Verifica a consistência do ROADMAP.md de arquitetura (ADR-0002 e ADR-0003).

Cobre: estrutura da tabela, rastreabilidade bidirecional entre ADRs e o
ROADMAP, valores válidos de Status e a heurística de Status das Specs
referenciadas. Não escreve nada — só confere e reporta.

Uso:
    python3 check_roadmap.py <pasta-de-ADRs>

Saída (código):
    0  nenhuma divergência encontrada
    1  ao menos uma divergência encontrada
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

VALID_STATUSES = {"Não iniciada", "Só requisitos", "Em andamento", "Concluída"}
EXPECTED_HEADER_COLUMNS = [
    "Etapa",
    "Assunto",
    "ADR Base",
    "Spec Técnica",
    "Status",
    "Evidência / Validação",
]
ADR_FILENAME = re.compile(r"^\d{4}-.+\.md$")
TABLE_ROW = re.compile(r"^\|(.+)\|\s*$")
TASK_LINE = re.compile(r"^- \[([ x])\]\s+\S")


def split_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def find_table_rows(roadmap_text: str) -> tuple[list[str] | None, list[list[str]]]:
    lines = roadmap_text.splitlines()
    header = None
    rows: list[list[str]] = []
    in_table = False
    for line in lines:
        match = TABLE_ROW.match(line)
        if not match:
            in_table = False
            continue
        cells = split_row(line)
        if header is None:
            header = cells
            in_table = True
            continue
        if in_table and set("".join(cells)) <= set(":- "):
            continue  # linha separadora (|---|---|)
        if in_table:
            rows.append(cells)
    return header, rows


def expected_status(spec_dir: Path) -> str | None:
    if not (spec_dir / "requirements.md").exists():
        return None
    if not (spec_dir / "design.md").exists():
        return "Só requisitos"
    tasks = spec_dir / "tasks.md"
    if not tasks.exists():
        return "Em andamento"
    text = tasks.read_text(encoding="utf-8")
    pending = any(m.group(1) == " " for m in TASK_LINE.finditer(text))
    return "Em andamento" if pending else "Concluída"


def check(adr_dir: Path) -> list[str]:
    failures: list[str] = []
    roadmap_path = adr_dir / "ROADMAP.md"
    if not roadmap_path.exists():
        return [f"ROADMAP.md não encontrado em {adr_dir}"]

    header, rows = find_table_rows(roadmap_path.read_text(encoding="utf-8"))
    if header != EXPECTED_HEADER_COLUMNS:
        failures.append(
            f"cabeçalho da tabela não corresponde ao esperado: {header}"
        )
        return failures  # sem cabeçalho confiável, não dá para seguir

    adr_base_cells = " ".join(row[2] for row in rows if len(row) > 2)
    status_by_row = []
    for row in rows:
        if len(row) < 6:
            continue
        status_by_row.append(row)
        status = row[4]
        if status not in VALID_STATUSES:
            failures.append(f"Status inválido na linha '{row[0]}': '{status}'")

    for adr_file in sorted(adr_dir.glob("*.md")):
        if adr_file.name == "ROADMAP.md" or not ADR_FILENAME.match(adr_file.name):
            continue
        if adr_file.name not in adr_base_cells:
            failures.append(f"{adr_file.name} não tem linha na tabela do ROADMAP (coluna ADR Base)")
        adr_text = adr_file.read_text(encoding="utf-8")
        refs_section = adr_text.split("## Referências")[-1] if "## Referências" in adr_text else ""
        if "ROADMAP.md" not in refs_section:
            failures.append(f"{adr_file.name} não cita ./ROADMAP.md em '## Referências'")

    spec_link = re.compile(r"\[.*?\]\((.+?)\)")
    for row in status_by_row:
        spec_cell = row[3]
        if spec_cell.strip() == "*Pendente*":
            continue
        match = spec_link.search(spec_cell)
        if not match:
            continue
        spec_target = (roadmap_path.parent / match.group(1)).resolve()
        spec_dir = spec_target if spec_target.is_dir() else spec_target.parent
        expected = expected_status(spec_dir)
        if expected is not None and expected != row[4]:
            failures.append(
                f"Status desatualizado na linha '{row[0]}': registrado '{row[4]}', esperado '{expected}'"
            )

    return failures


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("adr_dir", help="pasta com o ROADMAP.md e os ADRs")
    args = ap.parse_args()

    failures = check(Path(args.adr_dir))
    if not failures:
        print("[OK] ROADMAP consistente")
        return 0
    for failure in failures:
        print(f"[FALHA] {failure}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
