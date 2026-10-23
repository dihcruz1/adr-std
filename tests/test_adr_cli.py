"""Testes do skill/scripts/adr_cli.py (v1.2, tarefas 1.1 e 1.2; v2.0, tarefa 2.1)."""

import os
import re
import subprocess
import sys
import tempfile
import unittest
import unittest.mock
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

    def env(self) -> dict:
        """Ambiente sem config global do usuário."""
        return {**os.environ, "XDG_CONFIG_HOME": str(self.root / "nocfg")}

    def git_repo(self) -> Path:
        repo = self.root / "repo"
        repo.mkdir()
        subprocess.run(["git", "init", "-q", str(repo)], check=True)
        return repo


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
        r = run("new", "A", "--path", str(target), "--create")
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
        r = run("new", "A", "--path", str(target), "--create", "--name-pattern", pattern)
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
        self.assertIn("pasta de ADRs não encontrada", r.stderr)

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
        self.assertEqual(adr_cli.resolve_folder(None, proj, cfg_home, proj), proj / "global" / "dir")
        (proj / ".adr-std").write_text("path: local/dir\n", encoding="utf-8")
        self.assertEqual(adr_cli.resolve_folder(None, proj, cfg_home, proj), proj / "local" / "dir")
        self.assertEqual(adr_cli.resolve_folder("flag/dir", proj, cfg_home, proj), proj / "flag" / "dir")

    def test_default(self) -> None:
        self.assertEqual(
            adr_cli.resolve_folder(None, self.root, self.root / "cfg", self.root),
            self.root / "docs" / "architecture" / "ADR",
        )

    def test_path_arg_is_relative_to_cwd_and_absolute_is_exact(self) -> None:
        root, sub = self.root / "proj", self.root / "proj" / "sub"
        sub.mkdir(parents=True)
        cfg = self.root / "cfg"
        self.assertEqual(adr_cli.resolve_folder("x", sub, cfg, root), sub / "x")
        outside = self.root / "fora"
        self.assertEqual(adr_cli.resolve_folder(str(outside), sub, cfg, root), outside)

    def test_global_config_relative_path_is_relative_to_root(self) -> None:
        root, sub = self.root / "proj", self.root / "proj" / "sub"
        sub.mkdir(parents=True)
        cfg = self.root / "cfg"
        (cfg / "adr-std").mkdir(parents=True)
        (cfg / "adr-std" / "config").write_text("path = g/adrs\n", encoding="utf-8")
        self.assertEqual(adr_cli.resolve_folder(None, sub, cfg, root), root / "g" / "adrs")

    def test_adr_std_path_outside_root_is_rejected(self) -> None:
        root = self.root / "proj"
        root.mkdir()
        cfg = self.root / "cfg"
        for value in ("../x", str(self.root / "fora")):
            (root / ".adr-std").write_text(f"path: {value}\n", encoding="utf-8")
            with self.assertRaises(adr_cli.FolderConfigError):
                adr_cli.resolve_folder(None, root, cfg, root)

    def test_adr_std_absolute_path_inside_root_is_accepted(self) -> None:
        root = self.root / "proj"
        root.mkdir()
        (root / ".adr-std").write_text(f"path: {root / 'dentro'}\n", encoding="utf-8")
        self.assertEqual(adr_cli.resolve_folder(None, root, self.root / "cfg", root), root / "dentro")

    def test_global_config_and_path_arg_may_leave_root(self) -> None:
        root = self.root / "proj"
        root.mkdir()
        cfg = self.root / "cfg"
        (cfg / "adr-std").mkdir(parents=True)
        (cfg / "adr-std" / "config").write_text("path = ../g\n", encoding="utf-8")
        self.assertEqual(adr_cli.resolve_folder(None, root, cfg, root), self.root / "g")
        self.assertEqual(adr_cli.resolve_folder("../y", root, cfg, root), self.root / "y")

    def test_cli_uses_dot_adr_std_in_cwd(self) -> None:
        proj = self.root / "proj"
        (proj / "meus-adrs").mkdir(parents=True)
        (proj / ".adr-std").write_text("path = meus-adrs\n", encoding="utf-8")
        r = run("new", "Algo", cwd=proj, env=self.env())
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((proj / "meus-adrs" / "1-algo.md").exists())


class GlobalConfigHomeTest(CliTestCase):
    """Configuração global por plataforma (ADR-1): APPDATA no Windows; XDG nos demais."""

    def home(self, platform: str, **env: str) -> Path:
        with unittest.mock.patch.object(sys, "platform", platform):
            with unittest.mock.patch.dict(os.environ, env, clear=True):
                return adr_cli.global_config_home()

    def test_windows_prefers_test_override_then_appdata(self) -> None:
        r = str(self.root)
        self.assertEqual(self.home("win32", ADR_STD_APPDATA=f"{r}/t", APPDATA=f"{r}/a", XDG_CONFIG_HOME=f"{r}/x"), Path(f"{r}/t"))
        self.assertEqual(self.home("win32", APPDATA=f"{r}/a", XDG_CONFIG_HOME=f"{r}/x"), Path(f"{r}/a"))

    def test_windows_without_appdata_uses_profile_roaming(self) -> None:
        r = str(self.root)
        self.assertEqual(self.home("win32", ADR_STD_HOME=f"{r}/h", USERPROFILE=f"{r}/u"), Path(f"{r}/h/AppData/Roaming"))
        self.assertEqual(self.home("win32", USERPROFILE=f"{r}/u"), Path(f"{r}/u/AppData/Roaming"))

    def test_windows_empty_variables_count_as_absent(self) -> None:
        r = str(self.root)
        self.assertEqual(self.home("win32", ADR_STD_APPDATA="", APPDATA="", USERPROFILE=f"{r}/u"), Path(f"{r}/u/AppData/Roaming"))

    def test_posix_uses_xdg_then_dot_config_and_ignores_appdata(self) -> None:
        r = str(self.root)
        for platform in ("linux", "darwin"):
            self.assertEqual(self.home(platform, XDG_CONFIG_HOME=f"{r}/x", APPDATA=f"{r}/a", ADR_STD_APPDATA=f"{r}/t"), Path(f"{r}/x"))
            self.assertEqual(self.home(platform, HOME=r, APPDATA=f"{r}/a"), Path(r) / ".config")

    def test_cli_main_reads_appdata_on_windows(self) -> None:
        repo = self.git_repo()
        (repo / "do-appdata").mkdir()
        (repo / "do-xdg").mkdir()
        appdata, xdg = self.root / "appdata", self.root / "xdg"
        for base, folder in ((appdata, "do-appdata"), (xdg, "do-xdg")):
            (base / "adr-std").mkdir(parents=True)
            (base / "adr-std" / "config").write_text(f"path: {folder}\n", encoding="utf-8")
        env = {**os.environ, "APPDATA": str(appdata), "XDG_CONFIG_HOME": str(xdg)}
        with unittest.mock.patch.object(sys, "platform", "win32"), unittest.mock.patch.dict(os.environ, env):
            with unittest.mock.patch.object(sys, "argv", ["adr_cli.py", "new", "W"]):
                old = os.getcwd()
                os.chdir(repo)
                try:
                    self.assertEqual(adr_cli.main(), 0)
                finally:
                    os.chdir(old)
        self.assertTrue((repo / "do-appdata" / "1-w.md").exists())
        self.assertFalse((repo / "do-xdg" / "1-w.md").exists())


class RepoRootTest(CliTestCase):
    def test_git_subdir_returns_toplevel(self) -> None:
        repo = self.git_repo()
        sub = repo / "docs" / "architecture" / "ADR"
        sub.mkdir(parents=True)
        self.assertEqual(adr_cli.repo_root(sub), repo.resolve())

    def test_outside_git_returns_cwd(self) -> None:
        plain = self.root / "avulsa"
        plain.mkdir()
        self.assertEqual(adr_cli.repo_root(plain), plain.resolve())

    def test_without_git_in_path_returns_cwd(self) -> None:
        repo = self.git_repo()
        with unittest.mock.patch.dict(os.environ, {"PATH": str(self.root / "vazio")}):
            self.assertEqual(adr_cli.repo_root(repo), repo.resolve())

    def test_nested_repository_uses_innermost_root(self) -> None:
        outer = self.git_repo()
        inner = outer / "vendor" / "lib"
        inner.mkdir(parents=True)
        subprocess.run(["git", "init", "-q", str(inner)], check=True)
        self.assertEqual(adr_cli.repo_root(inner), inner.resolve())


class SubdirTest(CliTestCase):
    """Defeito: de subpasta, a pasta dos ADRs era resolvida contra o cwd (RF-01 a RF-05)."""

    def setUp(self) -> None:
        super().setUp()
        self.repo = self.git_repo()
        self.default = self.repo / "docs" / "architecture" / "ADR"
        self.default.mkdir(parents=True)
        self.sub = self.default
        self.env_ = self.env()

    def test_new_from_subdir_without_config_uses_root_default(self) -> None:
        r = run("new", "Segundo", cwd=self.sub, env=self.env_)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.default / "1-segundo.md").exists())
        self.assertFalse((self.sub / "docs").exists())

    def test_new_numbers_after_existing_adrs_from_subdir(self) -> None:
        (self.default / "10-existente.md").write_text("# ADR-10: Existente\n", encoding="utf-8")
        r = run("new", "Proximo", cwd=self.sub, env=self.env_)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.default / "11-proximo.md").exists())

    def test_new_from_subdir_honors_adr_std_at_root(self) -> None:
        (self.repo / "meus-adrs").mkdir()
        (self.repo / ".adr-std").write_text("path: meus-adrs\n", encoding="utf-8")
        r = run("new", "Segundo", cwd=self.sub, env=self.env_)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.repo / "meus-adrs" / "1-segundo.md").exists())

    def test_path_arg_relative_is_relative_to_cwd(self) -> None:
        (self.sub / "outra").mkdir()
        r = run("new", "Rel", "--path", "outra", cwd=self.sub, env=self.env_)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.sub / "outra" / "1-rel.md").exists())

    def test_path_arg_absolute_is_exact_from_any_cwd(self) -> None:
        r = run("new", "Abs", "--path", str(self.adrs), cwd=self.sub, env=self.env_)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.adrs / "1-abs.md").exists())

    def test_list_link_and_organize_operate_on_root_folder_from_subdir(self) -> None:
        run("new", "Um", cwd=self.repo, env=self.env_)
        run("new", "Dois", cwd=self.repo, env=self.env_)
        sub = self.default
        listed = run("list", cwd=sub, env=self.env_)
        self.assertEqual(listed.returncode, 0, listed.stderr)
        self.assertIn("ADR-2", listed.stdout)
        linked = run("link", "ADR-1", "restringe", "ADR-2", cwd=sub, env=self.env_)
        self.assertEqual(linked.returncode, 0, linked.stderr)
        org = run("organize", "--dry-run", cwd=sub, env=self.env_)
        self.assertEqual(org.returncode, 0, org.stderr)
        self.assertIn("consistente", org.stdout)

    def test_outside_git_uses_cwd_as_root(self) -> None:
        plain = self.root / "avulsa"
        (plain / "docs" / "architecture" / "ADR").mkdir(parents=True)
        r = run("new", "Solto", cwd=plain, env=self.env_)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((plain / "docs" / "architecture" / "ADR" / "1-solto.md").exists())

    def test_nested_repository_uses_innermost_root(self) -> None:
        inner = self.repo / "vendor" / "lib"
        (inner / "docs" / "architecture" / "ADR").mkdir(parents=True)
        subprocess.run(["git", "init", "-q", str(inner)], check=True)
        r = run("new", "Interno", cwd=inner, env=self.env_)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((inner / "docs" / "architecture" / "ADR" / "1-interno.md").exists())

    def test_global_config_relative_path_is_relative_to_root(self) -> None:
        cfg = self.root / "cfg"
        (cfg / "adr-std").mkdir(parents=True)
        (cfg / "adr-std" / "config").write_text("path = global-adrs\n", encoding="utf-8")
        (self.repo / "global-adrs").mkdir()
        r = run("new", "G", cwd=self.sub, env={**self.env_, "XDG_CONFIG_HOME": str(cfg)})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.repo / "global-adrs" / "1-g.md").exists())


class MissingFolderTest(CliTestCase):
    """RF-06 a RF-08: pasta inexistente nunca é criada em silêncio."""

    def setUp(self) -> None:
        super().setUp()
        self.repo = self.git_repo()
        self.env_ = self.env()
        self.default = self.repo / "docs" / "architecture" / "ADR"

    def test_new_fails_without_creating_anything(self) -> None:
        r = run("new", "Primeiro", cwd=self.repo, env=self.env_)
        self.assertEqual(r.returncode, 1)
        self.assertIn("pasta de ADRs não encontrada", r.stderr)
        self.assertIn(str(self.default), r.stderr)
        self.assertIn("--create", r.stderr)
        self.assertFalse((self.repo / "docs").exists())

    def test_new_create_makes_folder_and_numbers_from_one(self) -> None:
        r = run("new", "Primeiro", "--create", cwd=self.repo, env=self.env_)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.default / "1-primeiro.md").exists())

    def test_existing_empty_folder_numbers_from_one(self) -> None:
        self.default.mkdir(parents=True)
        r = run("new", "Primeiro", cwd=self.repo, env=self.env_)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.default / "1-primeiro.md").exists())

    def test_other_commands_fail_with_same_message_without_create_hint(self) -> None:
        for args in (("list",), ("link", "ADR-1", "restringe", "ADR-2"), ("organize", "--dry-run")):
            with self.subTest(args=args):
                r = run(*args, cwd=self.repo, env=self.env_)
                self.assertEqual(r.returncode, 1)
                self.assertIn("pasta de ADRs não encontrada", r.stderr)
                self.assertNotIn("--create", r.stderr)


class OutsideRootTest(CliTestCase):
    """SEG-01: `.adr-std` versionado não pode apontar para fora da raiz."""

    def setUp(self) -> None:
        super().setUp()
        self.repo = self.git_repo()
        self.env_ = self.env()

    def test_adr_std_outside_root_is_refused_and_nothing_written(self) -> None:
        alvo = self.root / "fora"
        alvo.mkdir()
        for value in ("../fora", str(alvo)):
            with self.subTest(value=value):
                (self.repo / ".adr-std").write_text(f"path: {value}\n", encoding="utf-8")
                r = run("new", "X", "--create", cwd=self.repo, env=self.env_)
                self.assertEqual(r.returncode, 2)
                self.assertIn("fora da raiz", r.stderr)
                self.assertEqual(list(alvo.iterdir()), [])

    def test_path_arg_and_global_config_may_point_outside_root(self) -> None:
        alvo = self.root / "livre"
        alvo.mkdir()
        r = run("new", "A", "--path", str(alvo), cwd=self.repo, env=self.env_)
        self.assertEqual(r.returncode, 0, r.stderr)
        cfg = self.root / "cfg"
        (cfg / "adr-std").mkdir(parents=True)
        (cfg / "adr-std" / "config").write_text(f"path = {alvo}\n", encoding="utf-8")
        r = run("new", "B", cwd=self.repo, env={**self.env_, "XDG_CONFIG_HOME": str(cfg)})
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((alvo / "2-b.md").exists())


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
