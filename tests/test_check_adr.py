"""Testes do skill/scripts/check_adr.py (tarefa 1.1)."""

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "skill" / "scripts" / "check_adr.py"
SKILL_MD = ROOT / "skill" / "SKILL.md"
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

    def test_project_style_labels_are_accepted(self):
        text = self.fixture_text.replace("| **Data da decisão** |", "| **Data** |").replace(
            "| **Concerns e aspectos** |", "| **Preocupações (concerns)** |"
        )
        adr = write_adr(self.tmp, "0001-cache-de-sessao-em-redis.md", text)
        result = run(str(adr))
        self.assertIn("[OK  ] A4", result.stdout)
        self.assertIn("[OK  ] D4", result.stdout)
        self.assertEqual(result.returncode, 0)

    def test_placeholders_inside_inline_code_are_not_leftovers(self):
        text = self.fixture_text.replace(
            "A sessão de conversa fica em memória",
            "Specs ficam em `docs/specs/<AAAA-MM-DD>-<nome>/`. A sessão de conversa fica em memória",
        )
        adr = write_adr(self.tmp, "0001-cache-de-sessao-em-redis.md", text)
        self.assertIn("[OK  ] A7", run(str(adr)).stdout)

    def test_pending_approval_with_explanation_is_ok_only_when_not_accepted(self):
        pending = self.fixture_text.replace(
            "| **Aprovado em** | 2026-09-10 |", "| **Aprovado em** | pendente — falta a aprovação do solicitante |"
        )
        proposed = write_adr(self.tmp, "0001-cache-de-sessao-em-redis.md", pending.replace("| **Status** | Aceito |", "| **Status** | Proposto |"))
        self.assertIn("[OK  ] A5", run(str(proposed)).stdout)
        accepted = write_adr(self.tmp, "0001-cache-de-sessao-em-redis.md", pending)
        self.assertIn("[FALHA] A5", run(str(accepted)).stdout)

    def test_real_placeholder_outside_code_is_still_a_leftover(self):
        text = self.fixture_text.replace(
            "A sessão de conversa fica em memória", "<descreva o contexto>. A sessão de conversa fica em memória"
        )
        adr = write_adr(self.tmp, "0001-cache-de-sessao-em-redis.md", text)
        self.assertIn("[FALHA] A7", run(str(adr)).stdout)

    def test_skill_md_documents_path_hierarchy(self):
        text = SKILL_MD.read_text(encoding="utf-8")
        section = text.split("### Caminho dos ADRs")[1].split("### ROADMAP.md")[0]
        markers = [
            "Argumento explícito",
            ".adr-std",
            "CONVENTIONS.md",
            "~/.config/adr-std/config",
            "docs/architecture/ADR/",
        ]
        positions = []
        cursor = 0
        for marker in markers:
            cursor = section.index(marker, cursor)
            positions.append(cursor)
        self.assertEqual(positions, sorted(positions))

    def test_skill_md_documents_roadmap_automation(self):
        text = SKILL_MD.read_text(encoding="utf-8")
        section = text.split("### ROADMAP.md")[1].split("## Tarefas")[0]
        for marker in [
            "apenas",
            "Não iniciada",
            "Só requisitos",
            "Em andamento",
            "Concluída",
            "ROADMAP atualizado",
        ]:
            self.assertIn(marker, section)

    def test_skill_md_documents_action_commands(self):
        text = SKILL_MD.read_text(encoding="utf-8")
        section = text.split("## Comandos de ação (v1.1)")[1].split("## Tarefas")[0]
        for marker in [
            "--ask",
            "--quick",
            "pendente",
            "sugestão",
            "Proposto",
            "nunca apagar",
            "sem perguntas",
        ]:
            self.assertIn(marker, section)

    def test_check_accepts_custom_folder(self):
        custom = self.tmp / "outra-pasta" / "custom"
        custom.mkdir(parents=True)
        write_adr(custom, "0001-cache-de-sessao-em-redis.md", self.fixture_text)
        result = run(str(custom))
        self.assertEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
