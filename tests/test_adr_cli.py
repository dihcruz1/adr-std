"""Testes do skill/scripts/adr_cli.py (v1.2, tarefas 1.1 e 1.2; v2.0, tarefa 2.1)."""

import os
import re
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
        (self.adrs / "3-outro.md").write_text("# ADR-3: Outro\n", encoding="utf-8")
        r = self.new("Usar fila")
        self.assertEqual(r.returncode, 0, r.stderr)
        text = self.read("4-usar-fila.md")
        self.assertIn("# ADR-4: Usar fila", text)
        self.assertIn("| **Status** | Proposto |", text)
        self.assertIn("| **Decisores** | pendente |", text)

    def test_skeleton_passes_header_parse(self) -> None:
        self.new("Usar fila")
        r = run("list", "--path", str(self.adrs))
        self.assertIn("ADR-1", r.stdout)
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
        first = self.read("1-linha-um-status-aceito.md").splitlines()
        self.assertTrue(first[0].startswith("# ADR-1: Linha um"))
        self.assertEqual(sum(1 for line in first if line.startswith("| **Status**")), 1)

    def test_never_overwrites(self) -> None:
        self.new("Mesmo")
        before = self.read("1-mesmo.md")
        with self.assertRaises(FileExistsError):
            adr_cli.write_new_adr(self.adrs, "1", "Mesmo", "2026-01-01")
        self.assertEqual(self.read("1-mesmo.md"), before)

    def test_creates_missing_folder(self) -> None:
        target = self.root / "novo" / "adr"
        r = run("new", "A", "--path", str(target))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((target / "1-a.md").exists())

    def test_custom_name_pattern(self) -> None:
        (self.adrs / "ADR7-x.md").write_text("x", encoding="utf-8")
        pattern = r"^ADR(\d+)-.*\.md$"
        n = adr_cli.next_number(self.adrs, re.compile(pattern))
        self.assertEqual(n, "8")

    def test_empty_folder_starts_at_1(self) -> None:
        r = self.new("Primeiro")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.adrs / "1-primeiro.md").exists())

    def test_numeric_max_not_lexical(self) -> None:
        (self.adrs / "2-a.md").write_text("x", encoding="utf-8")
        (self.adrs / "10-b.md").write_text("x", encoding="utf-8")
        r = self.new("Terceiro")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("# ADR-11: Terceiro", self.read("11-terceiro.md"))

    def test_padded_pattern_keeps_width(self) -> None:
        (self.adrs / "0007-a.md").write_text("x", encoding="utf-8")
        r = run("new", "Outro", "--path", str(self.adrs), "--name-pattern", r"^(\d{4})-[a-z0-9-]+\.md$")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("# ADR-0008: Outro", self.read("0008-outro.md"))

    def test_incompatible_active_pattern_refuses_without_creating(self) -> None:
        pattern = r"^(\d{4})-[a-z0-9-]+\.md$"
        r = run("new", "Primeiro", "--path", str(self.adrs), "--name-pattern", pattern)
        self.assertEqual(r.returncode, 1)
        self.assertIn("1-primeiro.md", r.stderr)
        self.assertIn(pattern, r.stderr)
        self.assertEqual(list(self.adrs.iterdir()), [])

    def test_incompatible_active_pattern_does_not_create_missing_folder(self) -> None:
        target = self.root / "novo" / "adr"
        pattern = r"^(\d{4})-[a-z0-9-]+\.md$"
        r = run("new", "A", "--path", str(target), "--name-pattern", pattern)
        self.assertEqual(r.returncode, 1)
        self.assertIn(pattern, r.stderr)
        self.assertFalse(target.exists())
        self.assertFalse((self.root / "novo").exists())

    def test_name_collision_still_refused_by_exclusive_mode(self) -> None:
        self.new("Mesmo")
        before = self.read("1-mesmo.md")
        with self.assertRaises(FileExistsError):
            adr_cli.write_new_adr(self.adrs, "1", "Mesmo", "2026-01-01")
        self.assertEqual(self.read("1-mesmo.md"), before)


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
        (self.adrs / "1-vazio.md").write_text("", encoding="utf-8")
        r = run("list", "--path", str(self.adrs))
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_orders_numerically(self) -> None:
        for name in ("10-b.md", "2-a.md"):
            (self.adrs / name).write_text("x", encoding="utf-8")
        r = run("list", "--path", str(self.adrs))
        self.assertEqual(r.returncode, 0, r.stderr)
        names = [f.name for f in adr_cli.list_adrs(self.adrs, re.compile(adr_cli.DEFAULT_NAME_PATTERN))]
        self.assertEqual(names, ["2-a.md", "10-b.md"])

    def test_non_numeric_group_sorts_last_without_error(self) -> None:
        for name in ("zeta.md", "alfa.md", "3-c.md"):
            (self.adrs / name).write_text("x", encoding="utf-8")
        pattern = re.compile(r"^(\d+|[a-z]+)(?:-.*)?\.md$")
        names = [f.name for f in adr_cli.list_adrs(self.adrs, pattern)]
        self.assertEqual(names, ["3-c.md", "alfa.md", "zeta.md"])
        no_group = re.compile(r"^[a-z0-9-]+\.md$")
        adr_cli.list_adrs(self.adrs, no_group)
        self.assertEqual(len(adr_cli.list_adrs(self.adrs, no_group)), 3)


class NumberHelpersTest(unittest.TestCase):
    PATTERN = re.compile(r"^(\d+)-[a-z0-9-]+\.md$")

    def test_number_of(self) -> None:
        self.assertEqual(adr_cli.number_of(Path("0007-a.md"), self.PATTERN), "0007")
        self.assertEqual(adr_cli.number_of(Path("10-a.md"), self.PATTERN), "10")
        self.assertIsNone(adr_cli.number_of(Path("a-10.md"), self.PATTERN))

    def test_number_width(self) -> None:
        self.assertEqual(adr_cli.number_width(["1", "10", "2"]), 0)
        self.assertEqual(adr_cli.number_width([]), 0)
        self.assertEqual(adr_cli.number_width(["0007", "10"]), 4)
        self.assertEqual(adr_cli.number_width(["01", "0003"]), 4)

    def test_format_number(self) -> None:
        self.assertEqual(adr_cli.format_number(8, 4), "0008")
        self.assertEqual(adr_cli.format_number(8, 0), "8")
        self.assertEqual(adr_cli.format_number(12345, 4), "12345")


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
        self.assertTrue((proj / "meus-adrs" / "1-algo.md").exists())


class LinkTest(CliTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.new("Um")
        self.new("Dois")

    def link(self, a: str, tipo: str, b: str) -> subprocess.CompletedProcess:
        return run("link", a, tipo, b, "--path", str(self.adrs))

    def test_reciprocal_relation(self) -> None:
        r = self.link("ADR-1", "restringe", "ADR-2")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("| **Relações com outras decisões** | restringe ADR-2 |", self.read("1-um.md"))
        self.assertIn("é restringido por ADR-1", self.read("2-dois.md"))

    def test_preserves_existing_relations(self) -> None:
        self.link("ADR-1", "refina", "ADR-2")
        self.new("Tres")
        self.link("ADR-1", "restringe", "ADR-3")
        self.assertIn("refina ADR-2; restringe ADR-3", self.read("1-um.md"))

    def test_unknown_type_changes_nothing(self) -> None:
        before = self.read("1-um.md")
        r = self.link("ADR-1", "inventada", "ADR-2")
        self.assertEqual(r.returncode, 2)
        self.assertEqual(self.read("1-um.md"), before)

    def test_missing_adr_changes_nothing(self) -> None:
        before = (self.read("1-um.md"), self.read("2-dois.md"))
        r = self.link("ADR-1", "restringe", "ADR-99")
        self.assertEqual(r.returncode, 1)
        self.assertEqual((self.read("1-um.md"), self.read("2-dois.md")), before)

    def test_no_partial_write_when_field_missing(self) -> None:
        broken = self.read("2-dois.md").replace("Relações com outras decisões", "Outro campo")
        (self.adrs / "2-dois.md").write_text(broken, encoding="utf-8")
        before = self.read("1-um.md")
        r = self.link("ADR-1", "restringe", "ADR-2")
        self.assertEqual(r.returncode, 1)
        self.assertEqual(self.read("1-um.md"), before)


class OrganizeTest(CliTestCase):
    def test_requires_dry_run(self) -> None:
        r = run("organize", "--path", str(self.adrs))
        self.assertEqual(r.returncode, 2)

    def organize(self, *extra: str) -> subprocess.CompletedProcess:
        return run("organize", "--dry-run", "--path", str(self.adrs), *extra)

    def test_plan_for_gap_and_no_changes(self) -> None:
        self.new("Um")
        self.new("Dois")
        r = self.organize()
        self.assertIn("nenhuma mudança", r.stdout)
        (self.adrs / "2-dois.md").rename(self.adrs / "5-dois.md")
        before = sorted(p.name for p in self.adrs.iterdir())
        r = self.organize()
        self.assertIn("5-dois.md -> 2-dois.md", r.stdout)
        self.assertEqual(sorted(p.name for p in self.adrs.iterdir()), before)

    def test_consistent_folder_with_ten_adrs(self) -> None:
        for title in "ABCDEFGHIJ":
            self.new(title)
        self.assertTrue((self.adrs / "10-j.md").exists())
        self.assertIn("ADR-10", self.read("10-j.md"))
        r = self.organize()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("numeração já consistente", r.stdout)

    def test_gap_between_one_and_five(self) -> None:
        self.new("A")
        self.new("B")
        (self.adrs / "2-b.md").rename(self.adrs / "5-b.md")
        r = self.organize()
        self.assertIn("5-b.md -> 2-b.md", r.stdout)
        self.assertNotIn("1-a.md ->", r.stdout)

    def test_divergent_id_is_proposed(self) -> None:
        self.new("A")
        self.new("B")
        path = self.adrs / "2-b.md"
        path.write_text(path.read_text(encoding="utf-8").replace("ADR-2", "ADR-7"), encoding="utf-8")
        r = self.organize()
        self.assertIn("2-b.md -> 2-b.md", r.stdout)
        self.assertNotIn("1-a.md ->", r.stdout)

    def test_zero_padded_convention_preserves_width(self) -> None:
        pattern = r"^(\d{4})-[a-z0-9-]+\.md$"
        for n, slug in (("0001", "a"), ("0002", "b")):
            (self.adrs / f"{n}-{slug}.md").write_text(
                f"# ADR-{n}: {slug.upper()}\n\n| **ID** | ADR-{n} |\n", encoding="utf-8"
            )
        r = self.organize("--name-pattern", pattern)
        self.assertIn("numeração já consistente", r.stdout)
        (self.adrs / "0002-b.md").rename(self.adrs / "0005-b.md")
        r = self.organize("--name-pattern", pattern)
        self.assertIn("0005-b.md -> 0002-b.md", r.stdout)

    def test_missing_folder(self) -> None:
        r = run("organize", "--dry-run", "--path", str(self.root / "x"))
        self.assertEqual(r.returncode, 1)


if __name__ == "__main__":
    unittest.main()
