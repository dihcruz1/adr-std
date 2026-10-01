"""Testes do skill/scripts/check_roadmap.py (ADR-0002 e ADR-0003)."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "skill" / "scripts" / "check_roadmap.py"

VALID_HEADER = (
    "| Etapa | Assunto | ADR Base | Spec Técnica | Status | Evidência / Validação |\n"
    "|:---:|---|:---:|---|:---:|---|\n"
)

ADR_TEXT = """# ADR-0001: Título de teste

| Campo | Valor |
|---|---|
| **ID** | ADR-0001 |

## Decisão

Texto.

## Referências

- [ROADMAP.md](./ROADMAP.md)
"""

ADR_TEXT_NO_BACKLINK = ADR_TEXT.replace("- [ROADMAP.md](./ROADMAP.md)\n", "")


def run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args], capture_output=True, text=True
    )


class CheckRoadmapTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def write(self, name: str, text: str) -> Path:
        path = self.tmp / name
        path.write_text(text, encoding="utf-8")
        return path

    def test_consistent_roadmap_passes(self):
        self.write("0001-titulo.md", ADR_TEXT)
        self.write(
            "ROADMAP.md",
            VALID_HEADER + "| 1 | Teste | [ADR-0001](0001-titulo.md) | *Pendente* | Não iniciada | — |\n",
        )
        result = run(str(self.tmp))
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_bad_header_fails(self):
        self.write("0001-titulo.md", ADR_TEXT)
        self.write("ROADMAP.md", "| Coluna errada |\n|---|\n")
        result = run(str(self.tmp))
        self.assertEqual(result.returncode, 1)
        self.assertIn("cabeçalho", result.stdout.lower())

    def test_adr_without_roadmap_row_fails(self):
        self.write("0001-titulo.md", ADR_TEXT)
        self.write("ROADMAP.md", VALID_HEADER)
        result = run(str(self.tmp))
        self.assertEqual(result.returncode, 1)
        self.assertIn("0001-titulo.md", result.stdout)

    def test_adr_without_backlink_fails(self):
        self.write("0001-titulo.md", ADR_TEXT_NO_BACKLINK)
        self.write(
            "ROADMAP.md",
            VALID_HEADER + "| 1 | Teste | [ADR-0001](0001-titulo.md) | *Pendente* | Não iniciada | — |\n",
        )
        result = run(str(self.tmp))
        self.assertEqual(result.returncode, 1)
        self.assertIn("Referências", result.stdout)

    def test_invalid_status_value_fails(self):
        self.write("0001-titulo.md", ADR_TEXT)
        self.write(
            "ROADMAP.md",
            VALID_HEADER + "| 1 | Teste | [ADR-0001](0001-titulo.md) | *Pendente* | Em dia | — |\n",
        )
        result = run(str(self.tmp))
        self.assertEqual(result.returncode, 1)
        self.assertIn("Status", result.stdout)

    def _write_spec(self, name: str, files: dict[str, str]) -> Path:
        spec_dir = self.tmp / "specs" / name
        spec_dir.mkdir(parents=True)
        for filename, content in files.items():
            (spec_dir / filename).write_text(content, encoding="utf-8")
        return spec_dir

    def test_status_matches_requirements_only(self):
        self.write("0001-titulo.md", ADR_TEXT)
        self._write_spec("minha-spec", {"requirements.md": "# req"})
        self.write(
            "ROADMAP.md",
            VALID_HEADER
            + "| 1 | Teste | [ADR-0001](0001-titulo.md) | [spec](specs/minha-spec/requirements.md) | Só requisitos | — |\n",
        )
        result = run(str(self.tmp))
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_status_outdated_after_design_is_detected(self):
        self.write("0001-titulo.md", ADR_TEXT)
        self._write_spec("minha-spec", {"requirements.md": "# req", "design.md": "# design"})
        self.write(
            "ROADMAP.md",
            VALID_HEADER
            + "| 1 | Teste | [ADR-0001](0001-titulo.md) | [spec](specs/minha-spec/requirements.md) | Só requisitos | — |\n",
        )
        result = run(str(self.tmp))
        self.assertEqual(result.returncode, 1)
        self.assertIn("Em andamento", result.stdout)

    def test_status_outdated_after_all_tasks_done_is_detected(self):
        self.write("0001-titulo.md", ADR_TEXT)
        self._write_spec(
            "minha-spec",
            {
                "requirements.md": "# req",
                "design.md": "# design",
                "tasks.md": "- [x] 1.1 feito\n  - evidencia: ok\n",
            },
        )
        self.write(
            "ROADMAP.md",
            VALID_HEADER
            + "| 1 | Teste | [ADR-0001](0001-titulo.md) | [spec](specs/minha-spec/requirements.md) | Em andamento | — |\n",
        )
        result = run(str(self.tmp))
        self.assertEqual(result.returncode, 1)
        self.assertIn("Concluída", result.stdout)

    def test_pending_spec_is_ignored_for_status_heuristic(self):
        self.write("0001-titulo.md", ADR_TEXT)
        self.write(
            "ROADMAP.md",
            VALID_HEADER + "| 1 | Teste | [ADR-0001](0001-titulo.md) | *Pendente* | Não iniciada | — |\n",
        )
        result = run(str(self.tmp))
        self.assertEqual(result.returncode, 0, result.stdout)


if __name__ == "__main__":
    unittest.main()
