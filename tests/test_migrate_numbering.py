"""Testes do migrate_numbering.py (numeração dos ADRs sem zeros à esquerda)."""

import contextlib
import io
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "skill" / "scripts"))
import migrate_numbering as mn  # noqa: E402

ADR_TEXT = (
    "# ADR-0001: Usar fila\n\n"
    "| Campo | Valor |\n|---|---|\n| **ID** | ADR-0001 |\n\n"
    "Veja [ADR-0002](0002-b.md) e ADR-0001.\n"
)


def run_main(argv, cwd):
    """Roda main() com cwd e argv controlados; devolve (código, stdout, stderr)."""
    out, err = io.StringIO(), io.StringIO()
    old = os.getcwd()
    os.chdir(cwd)
    try:
        with mock.patch.object(sys, "argv", ["migrate_numbering.py", *argv]):
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                try:
                    code = mn.main()
                except SystemExit as exc:  # argparse
                    code = exc.code
    finally:
        os.chdir(old)
    return code, out.getvalue(), err.getvalue()


def git(cwd, *args):
    return subprocess.run(
        ["git", *args], cwd=cwd, check=True, capture_output=True, text=True
    ).stdout


class Project:
    """Projeto temporário; `use_git` faz git init e commita o estado inicial."""

    def __init__(self, test, files, use_git=False):
        self.tmp = tempfile.TemporaryDirectory()
        test.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        for rel, content in files.items():
            self.write(rel, content)
        self.use_git = use_git
        if use_git:
            git(self.root, "init", "-q")
            git(self.root, "config", "user.name", "Test")
            git(self.root, "config", "user.email", "test@example.com")
            git(self.root, "config", "commit.gpgsign", "false")
            self.commit()

    def write(self, rel, content):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        with open(p, "w", encoding="utf-8", newline="") as f:
            f.write(content)

    def read(self, rel):
        with open(self.root / rel, encoding="utf-8", newline="") as f:
            return f.read()

    def commit(self):
        git(self.root, "add", "-A")
        git(self.root, "commit", "-q", "-m", "init")

    def exists(self, rel):
        return (self.root / rel).exists()


BASE = {
    "docs/adr/0001-a.md": ADR_TEXT,
    "docs/adr/0002-b.md": "# ADR-0002: B\n\n| **ID** | ADR-0002 |\n",
    "README.md": "Ver [ADR-0001](docs/adr/0001-a.md) e ADR-0002.\n",
}


class RewriteTest(unittest.TestCase):
    NAMES = {"0001-a.md": "1-a.md"}
    NUMBERS = {1: 1}

    def test_rewrites_name_and_id(self):
        text = "[ADR-0001](docs/adr/0001-a.md) e ADR-0001"
        new, n = mn.rewrite(text, self.NAMES, self.NUMBERS)
        self.assertEqual(new, "[ADR-1](docs/adr/1-a.md) e ADR-1")
        self.assertEqual(n, 3)

    def test_keeps_other_numbers(self):
        text = "ADR-0042 e ADR-00012 e ADR-0001"
        new, n = mn.rewrite(text, self.NAMES, self.NUMBERS)
        self.assertEqual(new, "ADR-0042 e ADR-00012 e ADR-1")
        self.assertEqual(n, 1)

    def test_does_not_touch_unpadded(self):
        text = "ADR-1 e ADR-12 e 10001-a.md e x0001-a.md"
        new, n = mn.rewrite(text, self.NAMES, self.NUMBERS)
        self.assertEqual(new, text)
        self.assertEqual(n, 0)

    def test_name_requires_delimiter(self):
        new, _ = mn.rewrite("`0001-a.md` (0001-a.md)", self.NAMES, self.NUMBERS)
        self.assertEqual(new, "`1-a.md` (1-a.md)")

    def test_number_followed_by_digit_not_touched(self):
        new, _ = mn.rewrite("ADR-00010", self.NAMES, self.NUMBERS)
        self.assertEqual(new, "ADR-00010")

    def test_wider_padding_is_migrated(self):
        new, n = mn.rewrite("ADR-00001", self.NAMES, self.NUMBERS)
        self.assertEqual(new, "ADR-1")
        self.assertEqual(n, 1)


class PlanRenamesTest(unittest.TestCase):
    def test_renames_only_padded(self):
        renames, conflicts = mn.plan_renames(["0001-a.md", "2-b.md", "0010-c.md", "x.md"])
        self.assertEqual(renames, {"0001-a.md": "1-a.md", "0010-c.md": "10-c.md"})
        self.assertEqual(conflicts, [])

    def test_zero_number_ignored(self):
        renames, _ = mn.plan_renames(["0000-a.md"])
        self.assertEqual(renames, {})

    def test_duplicate_number_is_conflict(self):
        _, conflicts = mn.plan_renames(["0001-a.md", "001-b.md"])
        self.assertTrue(conflicts)

    def test_existing_destination_is_conflict(self):
        _, conflicts = mn.plan_renames(["0001-a.md", "1-a.md"])
        self.assertTrue(any("1-a.md" in c for c in conflicts))


class PlanCliTest(unittest.TestCase):
    def test_plan_does_not_change_files(self):
        p = Project(self, BASE, use_git=True)
        code, out, _ = run_main(["--path", "docs/adr"], p.root)
        self.assertEqual(code, 0)
        self.assertIn("0001-a.md -> 1-a.md", out)
        self.assertIn("0002-b.md -> 2-b.md", out)
        self.assertIn("README.md", out)
        self.assertIn("--apply", out)
        self.assertTrue(p.exists("docs/adr/0001-a.md"))
        self.assertEqual(p.read("README.md"), BASE["README.md"])
        self.assertEqual(git(p.root, "status", "--porcelain"), "")

    def test_plan_outside_git_warns_no_undo(self):
        p = Project(self, BASE)
        code, out, _ = run_main(["--path", "docs/adr"], p.root)
        self.assertEqual(code, 0)
        self.assertIn("não há como desfazer", out)

    def test_nothing_to_migrate(self):
        p = Project(self, {"docs/adr/1-a.md": "# ADR-1: A\n"})
        code, out, _ = run_main(["--path", "docs/adr"], p.root)
        self.assertEqual(code, 0)
        self.assertIn("numeração já adequada", out)

    def test_plan_marker_is_stable_contract_for_update_hook(self):
        # O gancho do `update` (bin/adr-std e bin/adr-std.ps1) detecta "há plano" pela 1ª linha.
        p = Project(self, BASE)
        _, out, _ = run_main(["--path", "docs/adr"], p.root)
        self.assertIn("plano de migração", out.splitlines()[0])
        empty = Project(self, {"docs/adr/1-a.md": "# ADR-1: A\n"})
        _, out, _ = run_main(["--path", "docs/adr"], empty.root)
        self.assertNotIn("plano de migração", out)
        padded = Project(self, {"docs/adr/0001-a.md": "# ADR-0001: A\n", ".adr-std": "numbering: padded\n"})
        _, out, _ = run_main(["--path", "docs/adr"], padded.root)
        self.assertNotIn("plano de migração", out)
        missing = Project(self, {"README.md": "x\n"})
        _, out, _ = run_main([], missing.root)
        self.assertNotIn("plano de migração", out)

    def test_missing_folder_is_nothing_to_do(self):
        p = Project(self, {"README.md": "x\n"})
        code, out, _ = run_main([], p.root)
        self.assertEqual(code, 0)
        self.assertIn("nada a migrar", out)


class ApplyTest(unittest.TestCase):
    def check_applied(self, p):
        self.assertFalse(p.exists("docs/adr/0001-a.md"))
        self.assertTrue(p.exists("docs/adr/1-a.md"))
        self.assertTrue(p.exists("docs/adr/2-b.md"))
        adr = p.read("docs/adr/1-a.md")
        self.assertIn("# ADR-1: Usar fila", adr)
        self.assertIn("| **ID** | ADR-1 |", adr)
        self.assertIn("[ADR-2](2-b.md)", adr)
        self.assertIn("e ADR-1.", adr)
        self.assertEqual(p.read("README.md"), "Ver [ADR-1](docs/adr/1-a.md) e ADR-2.\n")

    def test_apply_with_git_renames(self):
        files = dict(BASE)
        for name in ("docs/adr/0001-a.md", "docs/adr/0002-b.md"):
            files[name] += "Texto da decisão, longo o bastante para o git detectar a renomeação.\n" * 20
        p = Project(self, files, use_git=True)
        code, out, _ = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 0, out)
        self.assertFalse(p.exists("docs/adr/0001-a.md"))
        git(p.root, "add", "-A")
        status = git(p.root, "status", "--porcelain")
        self.assertIn("R  docs/adr/0001-a.md -> docs/adr/1-a.md", status)
        self.assertIn("R  docs/adr/0002-b.md -> docs/adr/2-b.md", status)

    def test_apply_without_git(self):
        p = Project(self, BASE)
        code, out, _ = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 0, out)
        self.check_applied(p)
        self.assertIn("1-a.md", out)

    def test_idempotent(self):
        p = Project(self, BASE)
        run_main(["--path", "docs/adr", "--apply"], p.root)
        code, out, _ = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 0)
        self.assertIn("numeração já adequada", out)
        self.assertNotIn("->", out)

    def test_only_migrated_numbers(self):
        # só o 1 é migrado; ADR-00012 (outro ADR, ainda com zeros) e ADR-0042 (sem arquivo) ficam
        p = Project(
            self,
            {
                "docs/adr/0001-a.md": "# ADR-0001: A\n",
                "notes.md": "ADR-0042 (outro projeto), ADR-00012 e ADR-0001\n",
            },
        )
        code, _, _ = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 0)
        self.assertEqual(p.read("notes.md"), "ADR-0042 (outro projeto), ADR-00012 e ADR-1\n")

    def test_exclude_protects_file(self):
        files = dict(BASE)
        files["docs/exemplo.md"] = "Formato antigo: ADR-0001 em 0001-a.md\n"
        p = Project(self, files)
        code, _, _ = run_main(
            ["--path", "docs/adr", "--apply", "--exclude", "docs/exemplo.md"], p.root
        )
        self.assertEqual(code, 0)
        self.assertEqual(p.read("docs/exemplo.md"), files["docs/exemplo.md"])
        self.assertEqual(p.read("README.md"), "Ver [ADR-1](docs/adr/1-a.md) e ADR-2.\n")

    def test_exclude_glob_with_slashes(self):
        files = dict(BASE)
        files["docs/specs/old/x.md"] = "ADR-0001\n"
        p = Project(self, files)
        code, _, _ = run_main(
            ["--path", "docs/adr", "--apply", "--exclude", "docs/specs/*"], p.root
        )
        self.assertEqual(code, 0)
        self.assertEqual(p.read("docs/specs/old/x.md"), "ADR-0001\n")

    def test_collision_refused_and_nothing_changed(self):
        files = {
            "docs/adr/0001-a.md": "# ADR-0001: A\n",
            "docs/adr/1-a.md": "# ADR-1: A\n",
            "README.md": "ADR-0001\n",
        }
        p = Project(self, files, use_git=True)
        code, out, err = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 1)
        self.assertIn("1-a.md", out + err)
        self.assertEqual(p.read("README.md"), "ADR-0001\n")
        self.assertTrue(p.exists("docs/adr/0001-a.md"))

    def test_collision_also_refused_in_plan_mode_with_exit_1(self):
        files = {"docs/adr/0001-a.md": "x\n", "docs/adr/1-a.md": "y\n"}
        p = Project(self, files)
        code, _, _ = run_main(["--path", "docs/adr"], p.root)
        self.assertEqual(code, 1)

    def test_duplicate_number_refused(self):
        files = {"docs/adr/0001-a.md": "x\n", "docs/adr/001-b.md": "y\n"}
        p = Project(self, files)
        code, out, err = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 1)
        self.assertTrue(p.exists("docs/adr/0001-a.md"))
        self.assertTrue(p.exists("docs/adr/001-b.md"))

    def test_dirty_tree_refused(self):
        p = Project(self, BASE, use_git=True)
        p.write("README.md", BASE["README.md"] + "alteração local\n")
        code, out, err = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 1)
        self.assertIn("README.md", out + err)
        self.assertTrue(p.exists("docs/adr/0001-a.md"))
        self.assertIn("alteração local", p.read("README.md"))

    def test_dirty_unrelated_file_is_fine(self):
        files = dict(BASE)
        files["src/main.py"] = "x = 1\n"
        p = Project(self, files, use_git=True)
        p.write("src/main.py", "x = 2\n")
        code, out, _ = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 0, out)

    def test_padded_optout(self):
        files = dict(BASE)
        files[".adr-std"] = "numbering: padded\n"
        p = Project(self, files)
        code, out, _ = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 0)
        self.assertIn("zeros à esquerda", out)
        self.assertTrue(p.exists("docs/adr/0001-a.md"))
        self.assertEqual(p.read("README.md"), BASE["README.md"])

    def test_padded_optout_with_equals(self):
        files = dict(BASE)
        files[".adr-std"] = "path: docs/adr\nnumbering = padded\n"
        p = Project(self, files)
        code, out, _ = run_main(["--apply"], p.root)
        self.assertEqual(code, 0)
        self.assertIn("zeros à esquerda", out)
        self.assertTrue(p.exists("docs/adr/0001-a.md"))

    def test_preserves_crlf_utf8_and_bom(self):
        crlf = "﻿# ADR-0001: Decisão ação\r\n\r\nVeja ADR-0001 e 0001-a.md\r\n"
        p = Project(self, {"docs/adr/0001-a.md": crlf, "README.md": "ADR-0001\r\nção\r\n"})
        code, _, _ = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 0)
        with open(p.root / "docs/adr/1-a.md", "rb") as f:
            data = f.read()
        self.assertEqual(
            data, "﻿# ADR-1: Decisão ação\r\n\r\nVeja ADR-1 e 1-a.md\r\n".encode("utf-8")
        )
        with open(p.root / "README.md", "rb") as f:
            self.assertEqual(f.read(), "ADR-1\r\nção\r\n".encode("utf-8"))

    def test_symlink_outside_root_is_ignored(self):
        outside = tempfile.TemporaryDirectory()
        self.addCleanup(outside.cleanup)
        target = Path(outside.name) / "ext.md"
        target.write_text("ADR-0001 externo\n", encoding="utf-8")
        p = Project(self, BASE)
        os.symlink(target, p.root / "link.md")
        os.symlink(outside.name, p.root / "linkdir")
        code, _, _ = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 0)
        self.assertEqual(target.read_text(encoding="utf-8"), "ADR-0001 externo\n")

    def test_symlink_outside_root_ignored_in_git(self):
        outside = tempfile.TemporaryDirectory()
        self.addCleanup(outside.cleanup)
        target = Path(outside.name) / "ext.md"
        target.write_text("ADR-0001 externo\n", encoding="utf-8")
        p = Project(self, BASE)
        os.symlink(target, p.root / "link.md")
        p.use_git = True
        git(p.root, "init", "-q")
        git(p.root, "config", "user.name", "Test")
        git(p.root, "config", "user.email", "test@example.com")
        git(p.root, "config", "commit.gpgsign", "false")
        p.commit()
        code, out, _ = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 0, out)
        self.assertEqual(target.read_text(encoding="utf-8"), "ADR-0001 externo\n")

    def test_skips_ignored_dirs_without_git(self):
        files = dict(BASE)
        files["node_modules/x/README.md"] = "ADR-0001\n"
        files[".venv/y.md"] = "ADR-0001\n"
        p = Project(self, files)
        code, _, _ = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 0)
        self.assertEqual(p.read("node_modules/x/README.md"), "ADR-0001\n")
        self.assertEqual(p.read(".venv/y.md"), "ADR-0001\n")

    def test_error_midway_stops_and_reports(self):
        p = Project(self, BASE)
        real = mn.rename_file
        calls = []

        def flaky(root, old, new, use_git):
            calls.append(old)
            if len(calls) == 2:
                raise OSError("falha simulada")
            return real(root, old, new, use_git)

        with mock.patch.object(mn, "rename_file", side_effect=flaky):
            code, out, err = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 1)
        text = out + err
        self.assertIn("falha simulada", text)
        self.assertIn("1-a.md", text)  # o que já foi feito
        self.assertTrue(p.exists("docs/adr/1-a.md"))
        self.assertTrue(p.exists("docs/adr/0002-b.md"))

    def test_error_on_content_write_stops_before_rename(self):
        p = Project(self, BASE)
        with mock.patch.object(mn, "write_text_file", side_effect=OSError("disco cheio")):
            code, out, err = run_main(["--path", "docs/adr", "--apply"], p.root)
        self.assertEqual(code, 1)
        self.assertIn("disco cheio", out + err)
        self.assertTrue(p.exists("docs/adr/0001-a.md"))

    def test_default_folder(self):
        p = Project(
            self,
            {
                "docs/architecture/ADR/0001-a.md": "# ADR-0001: A\n",
                "README.md": "ADR-0001\n",
            },
        )
        code, _, _ = run_main(["--apply"], p.root)
        self.assertEqual(code, 0)
        self.assertTrue(p.exists("docs/architecture/ADR/1-a.md"))
        self.assertEqual(p.read("README.md"), "ADR-1\n")

    def test_folder_from_adr_std_config(self):
        files = {".adr-std": "path: decisoes\n", "decisoes/0003-c.md": "# ADR-0003: C\n"}
        p = Project(self, files)
        with mock.patch.dict(os.environ, {"XDG_CONFIG_HOME": str(p.root / "cfg")}):
            code, _, _ = run_main(["--apply"], p.root)
        self.assertEqual(code, 0)
        self.assertTrue(p.exists("decisoes/3-c.md"))

    def test_root_option_and_git_toplevel(self):
        p = Project(self, BASE, use_git=True)
        (p.root / "sub").mkdir()
        # a partir de um subdiretório, a raiz é a do git
        code, _, _ = run_main(["--apply", "--path", str(p.root / "docs/adr")], p.root / "sub")
        self.assertEqual(code, 0)
        self.assertEqual(p.read("README.md"), "Ver [ADR-1](docs/adr/1-a.md) e ADR-2.\n")
        # --root explícito
        q = Project(self, BASE)
        code, _, _ = run_main(["--root", str(q.root), "--path", "docs/adr", "--apply"], q.root.parent)
        self.assertEqual(code, 0)
        self.assertTrue(q.exists("docs/adr/1-a.md"))

    def test_invalid_root_exits_2(self):
        p = Project(self, BASE)
        code, _, err = run_main(["--root", str(p.root / "nao-existe")], p.root)
        self.assertEqual(code, 2)
        self.assertIn("adr-std migrate", err)

    def test_folder_outside_root_exits_2(self):
        p = Project(self, BASE)
        code, _, err = run_main(["--path", "/tmp"], p.root)
        self.assertEqual(code, 2)

    def test_unknown_argument_exits_2(self):
        p = Project(self, BASE)
        code, _, _ = run_main(["--bogus"], p.root)
        self.assertEqual(code, 2)


if __name__ == "__main__":
    unittest.main()
