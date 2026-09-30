"""Testes do skill/scripts/check_adr.py (tarefa 1.1)."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "skill" / "scripts" / "check_adr.py"
FIXTURE = ROOT / "tests" / "fixtures" / "0001-cache-de-sessao-em-redis.md"
TEMPLATE = ROOT / "skill" / "references" / "template-madr.md"


def run(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args], capture_output=True, text=True
    )


def write_adr(folder: Path, name: str, text: str) -> Path:
    path = folder / name
    path.write_text(text, encoding="utf-8")
    return path


class CheckAdrTest(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.fixture_text = FIXTURE.read_text(encoding="utf-8")

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def test_conforming_fixture_passes(self):
        self.assertEqual(run(str(FIXTURE)).returncode, 0)

    def test_empty_template_fails_mandatory_items(self):
        result = run(str(TEMPLATE))
        self.assertEqual(result.returncode, 1)
        self.assertIn("[FALHA] B1", result.stdout)

    def test_name_pattern_accepts_legacy_numbering(self):
        text = self.fixture_text.replace("ADR-0001", "ADR-1")
        adr = write_adr(self.tmp, "1-cache-de-sessao.md", text)
        default = run(str(adr))
        legacy = run(str(adr), "--name-pattern", r"^(\d+)-.+\.md$")
        self.assertIn("[FALHA] A1", default.stdout)
        self.assertIn("[OK  ] A1", legacy.stdout)
        self.assertIn("[OK  ] A2", legacy.stdout)

    def test_rationale_inside_decision_is_accepted(self):
        text = self.fixture_text.split("## Justificativa")[0] + (
            "## Prós e contras das opções\n"
            + self.fixture_text.split("## Prós e contras das opções")[1]
        )
        text = text.replace(
            "Escolhemos **Redis com TTL**.",
            "Escolhemos **Redis com TTL**, porque tem expiração nativa.",
        )
        adr = write_adr(self.tmp, "0001-cache-de-sessao-em-redis.md", text)
        result = run(str(adr))
        self.assertIn("[OK  ] B4", result.stdout)
        self.assertIn("dentro da seção Decisão", result.stdout)

    def test_rejected_option_without_reason_fails(self):
        text = self.fixture_text.replace(
            "- **Motivo da rejeição:** não atende o driver de expiração sem código extra.\n", ""
        )
        adr = write_adr(self.tmp, "0001-cache-de-sessao-em-redis.md", text)
        result = run(str(adr))
        self.assertIn("[FALHA] C2", result.stdout)
        self.assertEqual(result.returncode, 2)

    def test_accepted_without_approval_date_fails(self):
        text = self.fixture_text.replace("| **Aprovado em** | 2026-09-10 |", "| **Aprovado em** | pendente |")
        adr = write_adr(self.tmp, "0001-cache-de-sessao-em-redis.md", text)
        self.assertIn("[FALHA] A5", run(str(adr)).stdout)

    def test_directory_skips_template_and_conventions(self):
        write_adr(self.tmp, "0001-cache-de-sessao-em-redis.md", self.fixture_text)
        write_adr(self.tmp, "CONVENTIONS.md", "# convenções")
        write_adr(self.tmp, "_template-madr.md", TEMPLATE.read_text(encoding="utf-8"))
        result = run(str(self.tmp))
        self.assertEqual(result.returncode, 0)
        self.assertNotIn("CONVENTIONS.md", result.stdout)


if __name__ == "__main__":
    unittest.main()
