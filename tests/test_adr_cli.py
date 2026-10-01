"""Testes do skill/scripts/adr_cli.py (v1.2, tarefas 1.1 e 1.2)."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "skill" / "scripts" / "adr_cli.py"
sys.path.insert(0, str(ROOT / "skill" / "scripts"))
import adr_cli  # noqa: E402


def run(*args: str, cwd: Path | None = None, env: dict | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args], capture_output=True, text=True, cwd=cwd, env=env
    )


class CliTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = Path(self._tmp.name)
        self.adrs = self.root / "adrs"
        self.adrs.mkdir()

    def new(self, title: str) -> subprocess.CompletedProcess:
        return run("new", title, "--path", str(self.adrs))

    def read(self, name: str) -> str:
        return (self.adrs / name).read_text(encoding="utf-8")


class NewTest(CliTestCase):
    def test_numbers_next_adr_and_fills_skeleton(self) -> None:
        self.new("Primeiro")
        (self.adrs / "0003-outro.md").write_text("# ADR-0003: Outro\n", encoding="utf-8")
        r = self.new("Usar fila")
        self.assertEqual(r.returncode, 0, r.stderr)
        text = self.read("0004-usar-fila.md")
        self.assertIn("# ADR-0004: Usar fila", text)
        self.assertIn("| **Status** | Proposto |", text)
        self.assertIn("| **Decisores** | pendente |", text)

    def test_skeleton_passes_header_parse(self) -> None:
        self.new("Usar fila")
        r = run("list", "--path", str(self.adrs))
        self.assertIn("ADR-0001", r.stdout)
        self.assertIn("Proposto", r.stdout)

    def test_empty_title_is_rejected(self) -> None:
        r = self.new("   ")
        self.assertEqual(r.returncode, 2)
        self.assertEqual(list(self.adrs.iterdir()), [])

    def test_title_cannot_escape_folder(self) -> None:
        r = self.new("../../evil/x")
        self.assertEqual(r.returncode, 0, r.stderr)
        created = list(self.adrs.iterdir())
        self.assertEqual(len(created), 1)
        self.assertEqual(created[0].parent.resolve(), self.adrs.resolve())
        self.assertFalse((self.root / "evil").exists())

    def test_title_newline_stays_single_line(self) -> None:
        self.new("Linha um\n| **Status** | Aceito |")
        first = self.read("0001-linha-um-status-aceito.md").splitlines()
        self.assertTrue(first[0].startswith("# ADR-0001: Linha um"))
        self.assertEqual(sum(1 for line in first if line.startswith("| **Status**")), 1)

    def test_never_overwrites(self) -> None:
        self.new("Mesmo")
        before = self.read("0001-mesmo.md")
        with self.assertRaises(FileExistsError):
            adr_cli.write_new_adr(self.adrs, "0001", "Mesmo", "2026-01-01")
        self.assertEqual(self.read("0001-mesmo.md"), before)

    def test_creates_missing_folder(self) -> None:
        target = self.root / "novo" / "adr"
        r = run("new", "A", "--path", str(target))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((target / "0001-a.md").exists())

    def test_custom_name_pattern(self) -> None:
        (self.adrs / "ADR7-x.md").write_text("x", encoding="utf-8")
        pattern = r"^ADR(\d+)-.*\.md$"
        n = adr_cli.next_number(self.adrs, __import__("re").compile(pattern))
        self.assertEqual(n, "0008")


class ListTest(CliTestCase):
    def test_lists_id_status_date_title(self) -> None:
        self.new("Usar fila")
        r = run("list", "--path", str(self.adrs))
        self.assertEqual(r.returncode, 0)
        self.assertIn("Usar fila", r.stdout)
        self.assertIn("Proposto", r.stdout)

    def test_missing_folder_is_error_1(self) -> None:
        r = run("list", "--path", str(self.root / "nao-existe"))
        self.assertEqual(r.returncode, 1)
        self.assertIn("pasta não encontrada", r.stderr)

    def test_empty_folder_is_ok(self) -> None:
        r = run("list", "--path", str(self.adrs))
        self.assertEqual(r.returncode, 0)
        self.assertIn("nenhum ADR", r.stdout)

    def test_empty_file_does_not_crash(self) -> None:
        (self.adrs / "0001-vazio.md").write_text("", encoding="utf-8")
        r = run("list", "--path", str(self.adrs))
        self.assertEqual(r.returncode, 0, r.stderr)


class ResolveFolderTest(CliTestCase):
    def test_precedence(self) -> None:
        cfg_home = self.root / "cfg"
        (cfg_home / "adr-std").mkdir(parents=True)
        (cfg_home / "adr-std" / "config").write_text("path = global/dir\n", encoding="utf-8")
        proj = self.root / "proj"
        proj.mkdir()
        self.assertEqual(adr_cli.resolve_folder(None, proj, cfg_home), Path("global/dir"))
        (proj / ".adr-std").write_text("path: local/dir\n", encoding="utf-8")
        self.assertEqual(adr_cli.resolve_folder(None, proj, cfg_home), Path("local/dir"))
        self.assertEqual(adr_cli.resolve_folder("flag/dir", proj, cfg_home), Path("flag/dir"))

    def test_default(self) -> None:
        self.assertEqual(
            adr_cli.resolve_folder(None, self.root, self.root / "cfg"), Path("docs/architecture/ADR")
        )

    def test_cli_uses_dot_adr_std_in_cwd(self) -> None:
        proj = self.root / "proj"
        proj.mkdir()
        (proj / ".adr-std").write_text("path = meus-adrs\n", encoding="utf-8")
        env = {**os.environ, "XDG_CONFIG_HOME": str(self.root / "nocfg")}
        r = run("new", "Algo", cwd=proj, env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((proj / "meus-adrs" / "0001-algo.md").exists())


class LinkTest(CliTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.new("Um")
        self.new("Dois")

    def link(self, a: str, tipo: str, b: str) -> subprocess.CompletedProcess:
        return run("link", a, tipo, b, "--path", str(self.adrs))

    def test_reciprocal_relation(self) -> None:
        r = self.link("ADR-0001", "restringe", "ADR-0002")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("| **Relações com outras decisões** | restringe ADR-0002 |", self.read("0001-um.md"))
        self.assertIn("é restringido por ADR-0001", self.read("0002-dois.md"))

    def test_preserves_existing_relations(self) -> None:
        self.link("ADR-0001", "refina", "ADR-0002")
        self.new("Tres")
        self.link("ADR-0001", "restringe", "ADR-0003")
        self.assertIn("refina ADR-0002; restringe ADR-0003", self.read("0001-um.md"))

    def test_unknown_type_changes_nothing(self) -> None:
        before = self.read("0001-um.md")
        r = self.link("ADR-0001", "inventada", "ADR-0002")
        self.assertEqual(r.returncode, 2)
        self.assertEqual(self.read("0001-um.md"), before)

    def test_missing_adr_changes_nothing(self) -> None:
        before = (self.read("0001-um.md"), self.read("0002-dois.md"))
        r = self.link("ADR-0001", "restringe", "ADR-0099")
        self.assertEqual(r.returncode, 1)
        self.assertEqual((self.read("0001-um.md"), self.read("0002-dois.md")), before)

    def test_no_partial_write_when_field_missing(self) -> None:
        broken = self.read("0002-dois.md").replace("Relações com outras decisões", "Outro campo")
        (self.adrs / "0002-dois.md").write_text(broken, encoding="utf-8")
        before = self.read("0001-um.md")
        r = self.link("ADR-0001", "restringe", "ADR-0002")
        self.assertEqual(r.returncode, 1)
        self.assertEqual(self.read("0001-um.md"), before)


class OrganizeTest(CliTestCase):
    def test_requires_dry_run(self) -> None:
        r = run("organize", "--path", str(self.adrs))
        self.assertEqual(r.returncode, 2)

    def test_plan_for_gap_and_no_changes(self) -> None:
        self.new("Um")
        self.new("Dois")
        r = run("organize", "--dry-run", "--path", str(self.adrs))
        self.assertIn("nenhuma mudança", r.stdout)
        (self.adrs / "0002-dois.md").rename(self.adrs / "0005-dois.md")
        before = sorted(p.name for p in self.adrs.iterdir())
        r = run("organize", "--dry-run", "--path", str(self.adrs))
        self.assertIn("0005-dois.md -> 0002-dois.md", r.stdout)
        self.assertEqual(sorted(p.name for p in self.adrs.iterdir()), before)

    def test_missing_folder(self) -> None:
        r = run("organize", "--dry-run", "--path", str(self.root / "x"))
        self.assertEqual(r.returncode, 1)


if __name__ == "__main__":
    unittest.main()
