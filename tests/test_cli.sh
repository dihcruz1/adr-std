#!/usr/bin/env bash
# Testes do comando adr-std e do instalador (bash).
# Uso: bash tests/test_cli.sh [teste ...]   (sem argumentos: todos)
# Nunca usa o HOME real: cada teste roda num HOME temporário.

set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0
FAILED=()

fail() { echo "    ✗ $*"; return 1; }
assert_eq() { [ "$1" = "$2" ] || fail "esperado '$2', obtido '$1'${3:+ ($3)}"; }
assert_file() { [ -e "$1" ] || fail "não existe: $1"; }
assert_no_file() { [ ! -e "$1" ] || fail "não deveria existir: $1"; }
assert_contains() { printf '%s' "$1" | grep -qF -- "$2" || fail "saída não contém: $2"; }

# ---------------------------------------------------------------------------
# testes

test_agents_file() {
  local f="$ROOT/agents.tsv"
  assert_file "$f" || return 1
  local rows ids unique bad
  rows=$(grep -v '^#' "$f" | grep -c .)
  assert_eq "$rows" "15" "linhas de agentes" || return 1
  bad=$(grep -v '^#' "$f" | grep . | awk -F'\t' 'NF != 5' | wc -l)
  assert_eq "$bad" "0" "linhas sem 5 colunas" || return 1
  ids=$(grep -v '^#' "$f" | grep . | cut -f1 | wc -l)
  unique=$(grep -v '^#' "$f" | grep . | cut -f1 | sort -u | wc -l)
  assert_eq "$unique" "$ids" "ids repetidos" || return 1
  assert_file "$ROOT/VERSION" || return 1
  grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' "$ROOT/VERSION" || fail "VERSION fora do formato X.Y.Z"
}

test_command_tables() {
  local cf="$ROOT/commands.tsv" tf="$ROOT/command_targets.tsv"
  assert_file "$cf" || return 1
  assert_file "$tf" || return 1
  local rows; rows=$(grep -v '^#' "$cf" | grep -c .)
  assert_eq "$rows" "10" "ações em commands.tsv" || return 1
  local bad; bad=$(grep -v '^#' "$cf" | grep . | awk -F'\t' 'NF != 2' | wc -l)
  assert_eq "$bad" "0" "linhas de commands.tsv sem 2 colunas" || return 1
  for id in claude-code gemini-cli opencode continue; do
    grep -v '^#' "$tf" | grep . | cut -f1 | grep -qxF "$id" || fail "command_targets.tsv sem $id" || return 1
  done
  bad=$(grep -v '^#' "$tf" | grep . | awk -F'\t' 'NF != 4' | wc -l)
  assert_eq "$bad" "0" "linhas de command_targets.tsv sem 4 colunas"
}

CLI="$ROOT/bin/adr-std"

test_version() {
  local out; out="$("$CLI" version)" || fail "saída diferente de zero" || return 1
  assert_contains "$out" "$(cat "$ROOT/VERSION")"
}

test_help() {
  local out; out="$("$CLI" help)" || fail "saída diferente de zero" || return 1
  for c in install update uninstall self-uninstall status agents check version; do
    assert_contains "$out" "$c" || return 1
  done
  out="$("$CLI" 2>&1)"; assert_contains "$out" "install" || return 1
  "$CLI" comando-inexistente >/dev/null 2>&1 && fail "comando inválido deveria falhar"
  return 0
}

test_agents() {
  mkdir -p "$HOME/.claude" "$HOME/.codex"
  local out; out="$("$CLI" agents)" || fail "saída diferente de zero" || return 1
  assert_contains "$out" "claude-code" || return 1
  printf '%s\n' "$out" | grep -E '^ *claude-code' | grep -q 'encontrado' || fail "claude-code não marcado" || return 1
  printf '%s\n' "$out" | grep -E '^ *codex' | grep -q 'encontrado' || fail "codex não marcado" || return 1
  printf '%s\n' "$out" | grep -E '^ *cursor' | grep -q 'encontrado' && fail "cursor marcado sem existir"
  return 0
}

state_file() { echo "$HOME/.config/adr-std/state"; }
config_file() { echo "$HOME/.config/adr-std/config"; }

test_install_explicit() {
  mkdir -p "$HOME/.claude" "$HOME/.codex"
  "$CLI" install claude-code >/dev/null || fail "install falhou" || return 1
  assert_file "$HOME/.claude/skills/adr-std/SKILL.md" || return 1
  assert_file "$HOME/.claude/skills/adr-std/references/guia-42010.md" || return 1
  assert_file "$HOME/.claude/skills/adr-std/.installed-by-adr-std" || return 1
  assert_no_file "$HOME/.codex/skills/adr-std" || return 1
  grep -qP '^agent\tclaude-code\t' "$(state_file)" || fail "estado sem claude-code" || return 1
  grep -qP '^version\t' "$(state_file)" || fail "estado sem versão" || return 1

  rm -rf "$HOME/.claude/skills" "$HOME/.config"
  "$CLI" install --agent claude-code,codex >/dev/null || fail "--agent com vírgula falhou" || return 1
  assert_file "$HOME/.codex/skills/adr-std/SKILL.md" || return 1
  assert_file "$HOME/.claude/skills/adr-std/SKILL.md" || return 1

  rm -rf "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.config"
  "$CLI" install --agent claude-code codex >/dev/null || fail "--agent com espaço falhou" || return 1
  assert_file "$HOME/.codex/skills/adr-std/SKILL.md" || return 1
  assert_file "$HOME/.claude/skills/adr-std/SKILL.md"
}

test_install_dedupe() {
  mkdir -p "$HOME/.gemini" "$HOME/.config/opencode"
  "$CLI" install gemini-cli opencode >/dev/null || fail "install falhou" || return 1
  assert_file "$HOME/.agents/skills/adr-std/SKILL.md" || return 1
  assert_no_file "$HOME/.gemini/skills/adr-std" || return 1
  assert_no_file "$HOME/.config/opencode/skills/adr-std" || return 1
  local n; n=$(grep -cP '^agent\t(gemini-cli|opencode)\t'"$HOME"'/.agents/skills/adr-std$' "$(state_file)")
  assert_eq "$n" "2" "agentes registrados na pasta compartilhada"
}

test_install_dryrun() {
  mkdir -p "$HOME/.claude"
  local out; out="$("$CLI" install --dry-run claude-code)" || fail "dry-run falhou" || return 1
  assert_contains "$out" ".claude/skills/adr-std" || return 1
  assert_no_file "$HOME/.claude/skills/adr-std" || return 1
  assert_no_file "$(state_file)"
}

test_install_invalid() {
  local out; out="$("$CLI" install claude 2>&1)" && fail "agente inválido deveria falhar" && return 1
  assert_contains "$out" "quis dizer" || return 1
  assert_contains "$out" "claude-code"
}

test_install_menu() {
  mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.gemini"
  printf '1 2\n' > input
  local out; out="$(ADR_STD_TTY="$PWD/input" "$CLI" install)" || fail "install com menu falhou" || return 1
  assert_contains "$out" "claude-code" || return 1
  assert_file "$HOME/.claude/skills/adr-std/SKILL.md" || return 1
  assert_file "$HOME/.codex/skills/adr-std/SKILL.md" || return 1
  assert_no_file "$HOME/.agents/skills/adr-std" || return 1
  rm -rf "$HOME/.claude/skills" "$HOME/.codex/skills" "$HOME/.config"
  printf 'todos\n' > input
  ADR_STD_TTY="$PWD/input" "$CLI" install >/dev/null || fail "menu 'todos' falhou" || return 1
  assert_file "$HOME/.agents/skills/adr-std/SKILL.md"
}

test_install_all() {
  mkdir -p "$HOME/.claude" "$HOME/.gemini"
  "$CLI" install --all >/dev/null || fail "--all falhou" || return 1
  assert_file "$HOME/.claude/skills/adr-std/SKILL.md" || return 1
  assert_file "$HOME/.agents/skills/adr-std/SKILL.md" || return 1
  assert_no_file "$HOME/.codex/skills/adr-std"
}

test_install_noninteractive() {
  mkdir -p "$HOME/.claude"
  local out code
  out="$(ADR_STD_TTY=/nao/existe "$CLI" install 2>&1)"; code=$?
  assert_eq "$code" "3" "código de saída" || return 1
  assert_contains "$out" "--agent" || return 1
  assert_no_file "$HOME/.claude/skills/adr-std"
}

test_install_conflict() {
  mkdir -p "$HOME/.claude/skills/adr-std"
  echo "do usuário" > "$HOME/.claude/skills/adr-std/nota.txt"
  local out code
  out="$("$CLI" install claude-code 2>&1)"; code=$?
  assert_eq "$code" "4" "código de saída" || return 1
  assert_contains "$out" "não foi instalad" || return 1
  assert_eq "$(cat "$HOME/.claude/skills/adr-std/nota.txt")" "do usuário" || return 1
  assert_no_file "$HOME/.claude/skills/adr-std/SKILL.md"
}

test_install_idempotent() {
  mkdir -p "$HOME/.claude"
  "$CLI" install claude-code >/dev/null || fail "primeira instalação falhou" || return 1
  echo "antigo" > "$HOME/.claude/skills/adr-std/residuo.txt"
  "$CLI" install claude-code >/dev/null || fail "segunda instalação falhou" || return 1
  assert_file "$HOME/.claude/skills/adr-std/SKILL.md" || return 1
  assert_no_file "$HOME/.claude/skills/adr-std/residuo.txt" || return 1
  local n; n=$(grep -cP '^agent\tclaude-code\t' "$(state_file)")
  assert_eq "$n" "1" "linhas do agente no estado"
}

test_uninstall_one() {
  mkdir -p "$HOME/.claude" "$HOME/.codex"
  "$CLI" install claude-code codex >/dev/null || fail "install falhou" || return 1
  "$CLI" uninstall codex >/dev/null || fail "uninstall falhou" || return 1
  assert_no_file "$HOME/.codex/skills/adr-std" || return 1
  assert_file "$HOME/.claude/skills/adr-std/SKILL.md" || return 1
  grep -qP '^agent\tcodex\t' "$(state_file)" && fail "codex ainda no estado"
  return 0
}

test_uninstall_all() {
  mkdir -p "$HOME/.claude" "$HOME/.gemini"
  "$CLI" install claude-code gemini-cli >/dev/null || fail "install falhou" || return 1
  mkdir -p "$HOME/.codex/skills/adr-std"; echo x > "$HOME/.codex/skills/adr-std/meu.txt"
  "$CLI" uninstall >/dev/null || fail "uninstall falhou" || return 1
  assert_no_file "$HOME/.claude/skills/adr-std" || return 1
  assert_no_file "$HOME/.agents/skills/adr-std" || return 1
  assert_file "$HOME/.codex/skills/adr-std/meu.txt" || return 1
  grep -qP '^agent\t' "$(state_file)" && fail "agentes ainda no estado"
  return 0
}

test_status() {
  mkdir -p "$HOME/.claude" "$HOME/.codex"
  local out; out="$("$CLI" status)" || fail "status falhou" || return 1
  assert_contains "$out" "não instalada" || return 1
  "$CLI" install claude-code codex >/dev/null
  out="$("$CLI" status)"
  assert_contains "$out" "$(cat "$ROOT/VERSION")" || return 1
  assert_contains "$out" "claude-code" || return 1
  rm -rf "$HOME/.codex/skills/adr-std"
  out="$("$CLI" status)"
  printf '%s\n' "$out" | grep -E 'codex' | grep -q 'danificada' || fail "pasta faltando não marcada como danificada"
}

test_install_link() {
  mkdir -p "$HOME/.claude"
  "$CLI" install --link claude-code >/dev/null || fail "install --link falhou" || return 1
  [ -L "$HOME/.claude/skills/adr-std" ] || fail "não é link" || return 1
  assert_eq "$(readlink "$HOME/.claude/skills/adr-std")" "$ROOT/skill" || return 1
  assert_file "$HOME/.claude/skills/adr-std/SKILL.md" || return 1
  assert_eq "$(state_get_mode)" "link" || return 1
  "$CLI" uninstall claude-code >/dev/null || fail "uninstall falhou" || return 1
  assert_no_file "$HOME/.claude/skills/adr-std" || return 1
  assert_file "$ROOT/skill/SKILL.md"
}

state_get_mode() { awk -F'\t' '$1 == "mode" { print $2 }' "$(state_file)"; }

test_install_commands() {
  mkdir -p "$HOME/.claude"
  "$CLI" install claude-code >/dev/null || fail "install falhou" || return 1
  assert_file "$HOME/.claude/commands/adr-std-create.md" || return 1
  assert_file "$HOME/.claude/commands/adr-std-list.md" || return 1
  local n; n=$(find "$HOME/.claude/commands" -name 'adr-std-*.md' | wc -l)
  assert_eq "$n" "10" "arquivos de comando criados" || return 1
  # shellcheck disable=SC2016 # literal $ARGUMENTS esperado no arquivo, não expansão
  assert_contains "$(cat "$HOME/.claude/commands/adr-std-create.md")" '$ARGUMENTS' || return 1
  assert_contains "$(cat "$HOME/.claude/commands/adr-std-create.md")" 'ação "create"' || return 1
  grep -qP '^command\tclaude-code\t' "$(state_file)" || fail "estado sem registro de comando"
}

test_install_no_commands() {
  mkdir -p "$HOME/.claude"
  "$CLI" install --no-commands claude-code >/dev/null || fail "install falhou" || return 1
  assert_no_file "$HOME/.claude/commands/adr-std-create.md" || return 1
  grep -qP '^command\t' "$(state_file)" 2>/dev/null && fail "estado com comando apesar de --no-commands"
  return 0
}

test_install_commands_preserve_foreign() {
  mkdir -p "$HOME/.claude/commands"
  echo "comando do usuário" > "$HOME/.claude/commands/adr-std-create.md"
  local out; out="$("$CLI" install claude-code 2>&1)" || fail "install falhou" || return 1
  assert_eq "$(cat "$HOME/.claude/commands/adr-std-create.md")" "comando do usuário" || return 1
  assert_contains "$out" "adr-std-create" || return 1
  assert_file "$HOME/.claude/commands/adr-std-list.md"
}

test_install_commands_all_agents() {
  mkdir -p "$HOME/.gemini" "$HOME/.continue"
  "$CLI" install gemini-cli continue >/dev/null || fail "install falhou" || return 1
  assert_file "$HOME/.gemini/commands/adr-std-create.toml" || return 1
  assert_contains "$(cat "$HOME/.gemini/commands/adr-std-create.toml")" '{{args}}' || return 1
  assert_file "$HOME/.continue/prompts/adr-std-create.prompt" || return 1
  assert_contains "$(cat "$HOME/.continue/prompts/adr-std-create.prompt")" '{{{ input }}}'
}

test_uninstall_removes_commands() {
  mkdir -p "$HOME/.claude"
  "$CLI" install claude-code >/dev/null || fail "install falhou" || return 1
  echo "outro" > "$HOME/.claude/commands/alheio.md"
  "$CLI" uninstall claude-code >/dev/null || fail "uninstall falhou" || return 1
  assert_no_file "$HOME/.claude/commands/adr-std-create.md" || return 1
  assert_file "$HOME/.claude/commands/alheio.md" || return 1
  grep -qP '^command\t' "$(state_file)" 2>/dev/null && fail "comandos ainda no estado"
  return 0
}

test_check() {
  local out
  out="$("$CLI" check "$ROOT/tests/fixtures/0001-cache-de-sessao-em-redis.md")" || fail "check da fixture deveria passar" || return 1
  assert_contains "$out" "[OK" || return 1
  "$CLI" check "$ROOT/skill/references/template-madr.md" >/dev/null 2>&1 && fail "check do template deveria falhar"
  return 0
}

test_check_nopython() {
  local out code
  out="$(PATH="/nao/existe" /bin/bash "$CLI" check "$ROOT/tests/fixtures" 2>&1)"; code=$?
  assert_eq "$code" "6" "código de saída" || return 1
  assert_contains "$out" "Python" || return 1
  assert_contains "$out" "checklist"
}

installer() { ( cd "$ROOT" && bash ./install.sh "$@" ); }

test_installer_local() {
  mkdir -p "$HOME/.claude"
  printf 'n\n' > answer
  local out; out="$(ADR_STD_TTY="$PWD/answer" installer --agent claude-code 2>&1)" || { echo "$out"; fail "install.sh falhou"; return 1; }
  assert_file "$HOME/.local/bin/adr-std" || return 1
  [ -x "$HOME/.local/bin/adr-std" ] || fail "comando sem permissão de execução" || return 1
  assert_file "$HOME/.local/share/adr-std/skill/SKILL.md" || return 1
  assert_file "$HOME/.local/share/adr-std/agents.tsv" || return 1
  assert_file "$HOME/.claude/skills/adr-std/SKILL.md" || return 1
  local v; v="$(PATH="$HOME/.local/bin:$PATH" adr-std version)"
  assert_contains "$v" "$(cat "$ROOT/VERSION")"
}

test_installer_path() {
  mkdir -p "$HOME/.claude"
  : > "$HOME/.bashrc"
  printf 'n\n' > no; printf 's\n' > yes
  SHELL=/bin/bash ADR_STD_TTY="$PWD/no" installer --agent claude-code >/dev/null 2>&1 || fail "install.sh (não) falhou" || return 1
  grep -q 'adr-std' "$HOME/.bashrc" && fail "alterou o .bashrc sem permissão" && return 1
  SHELL=/bin/bash ADR_STD_TTY="$PWD/yes" installer --agent claude-code >/dev/null 2>&1 || fail "install.sh (sim) falhou" || return 1
  local n; n=$(grep -c '# adr-std' "$HOME/.bashrc")
  assert_eq "$n" "1" "linhas acrescentadas ao .bashrc" || return 1
  SHELL=/bin/bash ADR_STD_TTY="$PWD/yes" installer --agent claude-code >/dev/null 2>&1
  n=$(grep -c '# adr-std' "$HOME/.bashrc")
  assert_eq "$n" "1" "linha duplicada na segunda execução"
}

test_self_uninstall() {
  mkdir -p "$HOME/.claude"
  printf '# minha linha\nalias ll="ls -l"\n' > "$HOME/.bashrc"
  printf 's\n' > yes
  SHELL=/bin/bash ADR_STD_TTY="$PWD/yes" installer --agent claude-code >/dev/null 2>&1 || fail "install.sh falhou" || return 1
  grep -q '# adr-std' "$HOME/.bashrc" || fail "PATH não foi acrescentado" || return 1
  "$HOME/.local/bin/adr-std" self-uninstall >/dev/null || fail "self-uninstall falhou" || return 1
  assert_no_file "$HOME/.claude/skills/adr-std" || return 1
  assert_no_file "$HOME/.local/bin/adr-std" || return 1
  assert_no_file "$HOME/.local/share/adr-std" || return 1
  assert_no_file "$HOME/.config/adr-std" || return 1
  grep -q '# adr-std' "$HOME/.bashrc" && fail "linha do PATH não foi removida" && return 1
  grep -qF 'alias ll="ls -l"' "$HOME/.bashrc" || fail "apagou linha do usuário" || return 1
  grep -qF '# minha linha' "$HOME/.bashrc" || fail "apagou comentário do usuário"
}

test_package() {
  local out="$PWD/out"
  ( cd "$ROOT" && bash ./package.sh "$out" ) >/dev/null 2>&1 || fail "package.sh falhou" || return 1
  assert_file "$out/adr-std.zip" || return 1
  assert_file "$out/adr-std.zip.sha256" || return 1
  local list; list="$(unzip -Z1 "$out/adr-std.zip")"
  for f in VERSION agents.tsv install.sh bin/adr-std \
           instalar-windows.bat instalar-mac.command instalar-linux.sh \
           desinstalar-windows.bat desinstalar-mac.command desinstalar-linux.sh \
           skill/SKILL.md skill/scripts/check_adr.py; do
    printf '%s\n' "$list" | grep -qxF "$f" || fail "zip sem $f" || return 1
  done
  printf '%s\n' "$list" | grep -Eq '^(tests|docs|\.git|\.github)/' && fail "zip contém arquivos de desenvolvimento" && return 1
  printf '%s\n' "$list" | grep -Eiq '42010.*\.(pdf|docx)' && fail "zip contém arquivo da norma" && return 1
  ( cd "$out" && sha256sum -c adr-std.zip.sha256 >/dev/null ) || fail "checksum não confere" || return 1
  return 0
}

test_package_release_requires_all() {
  # O modo --release exige todos os arquivos do design; enquanto faltar algum, deve falhar e dizer qual.
  local out="$PWD/out" msg
  if [ -f "$ROOT/install.ps1" ] && [ -f "$ROOT/README.md" ] && [ -f "$ROOT/LICENSE" ] && [ -f "$ROOT/bin/adr-std.ps1" ] && [ -f "$ROOT/bin/adr-std.cmd" ]; then
    ( cd "$ROOT" && bash ./package.sh --release "$out" ) >/dev/null 2>&1 || fail "--release deveria passar com todos os arquivos"
    return
  fi
  msg="$( cd "$ROOT" && bash ./package.sh --release "$out" 2>&1 )" && fail "--release deveria falhar com arquivos faltando" && return 1
  assert_contains "$msg" "faltando"
}

# Servidor local com uma "release" de teste. Uso: start_server <versão>; define BASE e SERVER_PID.
start_server() {
  local ver="$1"
  mkdir -p site/releases/latest/download
  local src="$PWD/src"; mkdir -p "$src"
  cp -R "$ROOT/." "$src/" 2>/dev/null; rm -rf "$src/.git" "$src/dist"
  echo "$ver" > "$src/VERSION"
  ( cd "$src" && bash ./package.sh "$PWD/../site/releases/latest/download" >/dev/null 2>&1 ) || return 1
  local port=$((20000 + RANDOM % 20000))
  ( cd site && python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1 ) &
  SERVER_PID=$!
  BASE="http://127.0.0.1:$port"
  local _i; for _i in 1 2 3 4 5 6 7 8 9 10; do curl -fs "$BASE/" >/dev/null 2>&1 && return 0; sleep 0.3; done
  return 1
}

stop_server() { [ -n "${SERVER_PID:-}" ] && kill "$SERVER_PID" 2>/dev/null; wait "$SERVER_PID" 2>/dev/null; return 0; }

test_installer_remote() {
  mkdir -p "$HOME/.claude"
  start_server 9.9.9 || { fail "servidor de teste não subiu"; return 1; }
  printf 'n\n' > answer
  local out
  # simula "curl | bash": o script chega pela entrada padrão, sem arquivos ao lado
  mkdir -p alone && cp "$ROOT/install.sh" alone/install.sh
  out="$(cd alone && ADR_STD_BASE_URL="$BASE" ADR_STD_TTY="$PWD/../answer" bash ./install.sh --agent claude-code 2>&1)" || { stop_server; echo "$out"; fail "instalação remota falhou"; return 1; }
  stop_server
  assert_file "$HOME/.claude/skills/adr-std/SKILL.md" || return 1
  assert_eq "$(cat "$HOME/.local/share/adr-std/VERSION")" "9.9.9" "versão baixada"
}

test_update_badsum() {
  mkdir -p "$HOME/.claude"
  start_server 9.9.9 || { fail "servidor de teste não subiu"; return 1; }
  echo "0000000000000000000000000000000000000000000000000000000000000000  adr-std.zip" > site/releases/latest/download/adr-std.zip.sha256
  mkdir -p alone && cp "$ROOT/install.sh" alone/install.sh
  local out code
  out="$(cd alone && ADR_STD_BASE_URL="$BASE" bash ./install.sh --agent claude-code 2>&1)"; code=$?
  stop_server
  assert_eq "$code" "5" "código de saída" || return 1
  assert_contains "$out" "checksum" || return 1
  assert_no_file "$HOME/.claude/skills/adr-std" || return 1
  assert_no_file "$HOME/.local/bin/adr-std"
}

test_update() {
  mkdir -p "$HOME/.claude" "$HOME/.codex"
  installer --agent claude-code codex >/dev/null 2>&1 < /dev/null || fail "instalação inicial falhou" || return 1
  local old; old="$(cat "$HOME/.local/share/adr-std/VERSION")"
  start_server 9.9.9 || { fail "servidor de teste não subiu"; return 1; }
  local out
  out="$(ADR_STD_BASE_URL="$BASE" "$HOME/.local/bin/adr-std" update 2>&1)" || { stop_server; echo "$out"; fail "update falhou"; return 1; }
  stop_server
  assert_eq "$(cat "$HOME/.local/share/adr-std/VERSION")" "9.9.9" "versão depois do update" || return 1
  assert_file "$HOME/.claude/skills/adr-std/SKILL.md" || return 1
  assert_file "$HOME/.codex/skills/adr-std/SKILL.md" || return 1
  assert_contains "$(cat "$HOME/.config/adr-std/state")" "9.9.9" || return 1
  [ "$old" != "9.9.9" ] || fail "versão inicial já era 9.9.9"
}

gate_copy() { # copia o repositório (sem .git) para ./repo
  mkdir -p repo && cp -R "$ROOT/." repo/ && rm -rf repo/.git repo/dist
}

test_gate_passes_clean_repo() {
  gate_copy
  ( cd repo && bash tests/gate.sh static ) >/dev/null 2>&1 || { ( cd repo && bash tests/gate.sh static ); fail "gate deveria passar no repositório limpo"; }
}

test_gate_blocks_norm_file() {
  gate_copy
  echo x > "repo/42010-teste.pdf"
  local out; out="$( cd repo && bash tests/gate.sh static 2>&1 )" && fail "gate deveria falhar com arquivo da norma" && return 1
  assert_contains "$out" "42010"
}

test_gate_blocks_big_file() {
  gate_copy
  head -c 1200000 /dev/zero > repo/grande.bin
  local out; out="$( cd repo && bash tests/gate.sh static 2>&1 )" && fail "gate deveria falhar com arquivo acima de 1 MB" && return 1
  assert_contains "$out" "grande.bin"
}

test_gate_checks_skill_name() {
  gate_copy
  sed -i 's/^name: adr-std$/name: outro-nome/' repo/skill/SKILL.md
  local out; out="$( cd repo && bash tests/gate.sh static 2>&1 )" && fail "gate deveria falhar com name diferente" && return 1
  assert_contains "$out" "name"
}

test_gate_checks_tag_version() {
  gate_copy
  ( cd repo && bash tests/gate.sh tag "v$(cat "$ROOT/VERSION")" ) >/dev/null 2>&1 || fail "tag igual a VERSION deveria passar" || return 1
  ( cd repo && bash tests/gate.sh tag v9.9.9 ) >/dev/null 2>&1 && fail "tag diferente de VERSION deveria falhar"
  return 0
}

# ---------------------------------------------------------------------------
# v1.2: comandos mecânicos no terminal

test_help_lists_new_commands() {
  local out; out="$("$CLI" help)" || return 1
  for c in new list link organize; do
    assert_contains "$out" "  $c " || return 1
  done
}

test_cli_new_list() {
  local out
  out="$("$CLI" new "Usar fila" --path adrs)" || fail "new falhou" || return 1
  assert_contains "$out" "0001-usar-fila.md" || return 1
  assert_file adrs/0001-usar-fila.md || return 1
  out="$("$CLI" list --path adrs)" || fail "list falhou" || return 1
  assert_contains "$out" "Usar fila" || return 1
  assert_contains "$out" "Proposto"
}

test_cli_link_organize() {
  "$CLI" new "Um" --path adrs >/dev/null && "$CLI" new "Dois" --path adrs >/dev/null || return 1
  "$CLI" link ADR-0001 restringe ADR-0002 --path adrs >/dev/null || fail "link falhou" || return 1
  grep -qF 'é restringido por ADR-0001' adrs/0002-dois.md || fail "relação recíproca ausente" || return 1
  mv adrs/0002-dois.md adrs/0005-dois.md
  local out; out="$("$CLI" organize --dry-run --path adrs)" || fail "organize falhou" || return 1
  assert_contains "$out" "0005-dois.md -> 0002-dois.md" || return 1
  assert_file adrs/0005-dois.md
}

test_cli_no_python() {
  local cmd out code
  for cmd in new list link organize; do
    out="$(PATH="/nao/existe" /bin/bash "$CLI" "$cmd" x 2>&1)"; code=$?
    assert_eq "$code" "6" "código de $cmd sem Python" || return 1
    assert_contains "$out" "Python" || return 1
    assert_contains "$out" "checklist" || return 1
  done
}

test_installer_copies_command_tables() {
  mkdir -p "$HOME/.claude"
  installer --agent claude-code >/dev/null 2>&1 < /dev/null || fail "instalação falhou" || return 1
  assert_file "$HOME/.local/share/adr-std/commands.tsv" || return 1
  assert_file "$HOME/.local/share/adr-std/command_targets.tsv" || return 1
}

test_package_has_command_tables() {
  local out="$PWD/out"
  ( cd "$ROOT" && bash ./package.sh "$out" ) >/dev/null 2>&1 || fail "package.sh falhou" || return 1
  local list; list="$(unzip -Z1 "$out/adr-std.zip")"
  for f in commands.tsv command_targets.tsv skill/scripts/adr_cli.py; do
    printf '%s\n' "$list" | grep -qxF "$f" || fail "zip sem $f" || return 1
  done
}

# ---------------------------------------------------------------------------
# v1.3: comandos de conversa no terminal

# Cria binários falsos de agente num diretório do PATH; cada um grava os argumentos recebidos
# (um por linha, com o nome do agente) em $PWD/fake.log.
fake_agents() {
  mkdir -p fakebin emptybin
  local b
  for b in claude codex gemini opencode; do
    # shellcheck disable=SC2016 # o script falso deve receber "$@" literal, sem expandir aqui
    printf '#!/bin/sh\necho "%s" >> "%s/fake.log"\nfor a in "$@"; do printf "ARG:%%s\\n" "$a" >> "%s/fake.log"; done\n' \
      "$b" "$PWD" "$PWD" > "fakebin/$b"
    chmod +x "fakebin/$b"
  done
}

# Roda o adr-std com os agentes falsos na frente do PATH.
cv() { PATH="$PWD/fakebin:$PATH" "$CLI" "$@"; }

REQ_PREFIX='Use a skill adr-std, ação'

test_launch_table() {
  local f="$ROOT/agent_launch.tsv"
  assert_file "$f" || return 1
  local rows bad id
  rows=$(grep -v '^#' "$f" | grep -c .)
  assert_eq "$rows" "4" "agentes que abrem pelo terminal" || return 1
  bad=$(grep -v '^#' "$f" | grep . | awk -F'\t' 'NF != 3' | wc -l)
  assert_eq "$bad" "0" "linhas sem 3 colunas" || return 1
  while IFS= read -r id; do
    grep -v '^#' "$ROOT/agents.tsv" | cut -f1 | grep -qxF "$id" || fail "agente fora do agents.tsv: $id" || return 1
  done < <(grep -v '^#' "$f" | grep . | cut -f1)
}

test_config_agent() {
  local out code
  out="$("$CLI" config agent)" || return 1
  assert_contains "$out" "nenhum agente padrão" || return 1
  "$CLI" config agent codex >/dev/null || fail "definir falhou" || return 1
  out="$("$CLI" config agent)"; assert_contains "$out" "codex" || return 1
  assert_eq "$(grep -P '^default_agent\t' "$(state_file)" | cut -f2)" "codex" "estado" || return 1
  "$CLI" config agent --unset >/dev/null || return 1
  out="$("$CLI" config agent)"; assert_contains "$out" "nenhum agente padrão" || return 1
  out="$("$CLI" config agent cursor 2>&1)"; code=$?
  assert_eq "$code" "2" "agente que não abre pelo terminal" || return 1
  out="$("$CLI" config agent claud 2>&1)"; code=$?
  assert_eq "$code" "2" "nome inválido" || return 1
  out="$("$CLI" config 2>&1)"; code=$?
  assert_eq "$code" "2" "config sem subcomando" || return 1
  out="$("$CLI" config caminho 2>&1)"; code=$?
  assert_eq "$code" "2" "subcomando inválido de config" || return 1
  assert_contains "$out" "agent" || return 1
  assert_contains "$out" "path"
}

test_config_path() {
  local out code
  out="$("$CLI" config path)" || return 1
  assert_contains "$out" "nenhuma pasta de ADRs" || return 1
  "$CLI" config path docs/decisoes >/dev/null || fail "definir falhou" || return 1
  out="$("$CLI" config path)"; assert_contains "$out" "docs/decisoes" || return 1
  assert_eq "$(grep -cE '^path[[:space:]]*[:=]' "$(config_file)")" "1" "uma única linha path" || return 1
  # gravar de novo não duplica a linha path
  "$CLI" config path docs/decisoes >/dev/null || return 1
  assert_eq "$(grep -cE '^path[[:space:]]*[:=]' "$(config_file)")" "1" "ainda uma única linha path" || return 1
  # config path (arquivo config) e config agent (arquivo state) não interferem um no outro
  "$CLI" config agent codex >/dev/null || return 1
  "$CLI" config path docs/decisoes >/dev/null || return 1
  assert_eq "$(grep -P '^default_agent\t' "$(state_file)" | cut -f2)" "codex" "default_agent preservado" || return 1
  assert_eq "$("$CLI" config path)" "pasta de ADRs: docs/decisoes" "path preservado após config agent" || return 1
  # remover
  "$CLI" config path --unset >/dev/null || return 1
  out="$("$CLI" config path)"; assert_contains "$out" "nenhuma pasta de ADRs" || return 1
  "$CLI" config path --unset >/dev/null || fail "--unset repetido não deve falhar" || return 1
  # opção desconhecida
  out="$("$CLI" config path -x 2>&1)"; code=$?
  assert_eq "$code" "2" "opção desconhecida" || return 1
  # ida-e-volta: o path gravado pelo CLI é lido por list (resolve_folder)
  command -v python3 >/dev/null || return 0  # sem Python, só a parte mecânica acima
  mkdir -p outra-pasta
  printf '# ADR-0001: teste\n\n| **ID** | ADR-0001 |\n| **Status** | Proposto |\n| **Data da decisão** | 2026-10-02 |\n' > outra-pasta/0001-teste.md
  "$CLI" config path outra-pasta >/dev/null || return 1
  out="$("$CLI" list)" || fail "list falhou" || return 1
  assert_contains "$out" "ADR-0001" || return 1
  assert_contains "$out" "teste"
}

test_converse_explicit_agent() {
  fake_agents
  mkdir -p "$HOME/.claude" "$HOME/.codex"
  "$CLI" install claude-code codex >/dev/null || return 1
  cv create codex usar Postgres >/dev/null || fail "create falhou" || return 1
  assert_eq "$(cat fake.log)" "codex
ARG:$REQ_PREFIX \"create\", com estes argumentos: usar Postgres" "chamada do codex" || return 1
  rm fake.log
  cv ask --agent claude-code "o que é um stakeholder?" >/dev/null || fail "ask --agent falhou" || return 1
  assert_eq "$(cat fake.log)" "claude
ARG:$REQ_PREFIX \"ask\", com estes argumentos: o que é um stakeholder?" "chamada do claude" || return 1
  rm fake.log
  cv audit --agent=codex >/dev/null || return 1
  grep -qF 'ação "audit"' fake.log
}

test_converse_gemini_and_opencode_flags() {
  fake_agents
  cv review --agent gemini-cli docs >/dev/null || fail "gemini falhou" || return 1
  assert_eq "$(cat fake.log)" "gemini
ARG:-i
ARG:$REQ_PREFIX \"review\", com estes argumentos: docs" "gemini usa -i" || return 1
  rm fake.log
  cv review --agent opencode docs >/dev/null || return 1
  assert_eq "$(cat fake.log)" "opencode
ARG:--prompt
ARG:$REQ_PREFIX \"review\", com estes argumentos: docs" "opencode usa --prompt"
}

test_converse_description_with_agent_name() {
  fake_agents
  mkdir -p "$HOME/.claude"
  "$CLI" install claude-code >/dev/null || return 1
  "$CLI" config agent claude-code >/dev/null || return 1
  cv create "codex deve ser o padrão" >/dev/null || fail "create falhou" || return 1
  assert_eq "$(head -1 fake.log)" "claude" "o termo entre aspas é descrição" || return 1
  grep -qF "argumentos: codex deve ser o padrão" fake.log
}

test_converse_similar_agent() {
  fake_agents
  local out code
  out="$(cv create claude usar Postgres 2>&1)"; code=$?
  assert_eq "$code" "2" "código" || return 1
  assert_contains "$out" "quis dizer claude-code" || return 1
  assert_no_file fake.log || return 1
  out="$(cv create cursor usar Postgres 2>&1)"; code=$?
  assert_eq "$code" "2" "agente que não abre pelo terminal" || return 1
  assert_contains "$out" "claude-code" || return 1
  assert_no_file fake.log
}

test_converse_default_agent() {
  fake_agents
  "$CLI" config agent codex >/dev/null || return 1
  local out; out="$(cv audit </dev/null)" || fail "audit falhou" || return 1
  assert_contains "$out" "agente padrão codex" || return 1
  assert_eq "$(head -1 fake.log)" "codex" "abriu o padrão" || return 1
  rm fake.log
  cv audit --agent claude-code >/dev/null || return 1
  assert_eq "$(head -1 fake.log)" "claude" "o indicado vence o padrão"
}

test_converse_menu_last_used() {
  fake_agents
  mkdir -p "$HOME/.claude" "$HOME/.codex"
  "$CLI" install claude-code codex >/dev/null || return 1
  printf '2\n' > answer
  local out; out="$(ADR_STD_TTY="$PWD/answer" cv audit)" || fail "menu falhou" || return 1
  assert_contains "$out" "1) claude-code" || return 1
  assert_contains "$out" "2) codex" || return 1
  assert_eq "$(head -1 fake.log)" "codex" "escolha 2" || return 1
  assert_eq "$(grep -P '^last_agent\t' "$(state_file)" | cut -f2)" "codex" "último usado" || return 1
  rm fake.log
  printf '\n' > answer
  out="$(ADR_STD_TTY="$PWD/answer" cv audit)" || return 1
  assert_contains "$out" "[2]" || return 1
  assert_eq "$(head -1 fake.log)" "codex" "Enter repete o último usado" || return 1
  printf '9\n' > answer
  ADR_STD_TTY="$PWD/answer" cv audit >/dev/null 2>&1 && fail "escolha inválida deveria falhar"
  return 0
}

test_converse_no_tty() {
  fake_agents
  mkdir -p "$HOME/.claude"
  "$CLI" install claude-code >/dev/null || return 1
  local out code
  out="$(ADR_STD_TTY="/nao/existe" cv audit 2>&1)"; code=$?
  assert_eq "$code" "3" "código" || return 1
  assert_contains "$out" "--agent" || return 1
  assert_no_file fake.log
}

test_converse_no_eligible() {
  fake_agents
  printf '1\n' > answer
  local out code
  out="$(ADR_STD_TTY="$PWD/answer" cv audit 2>&1)"; code=$?
  assert_eq "$code" "3" "código" || return 1
  assert_contains "$out" "adr-std install" || return 1
  assert_no_file fake.log
}

test_converse_injection() {
  fake_agents
  # shellcheck disable=SC2016 # texto de injeção literal: não deve ser expandido pelo teste
  cv create --agent codex 'x; touch PWNED $(touch PWNED2) `touch PWNED3`' >/dev/null || return 1
  assert_no_file PWNED || return 1
  assert_no_file PWNED2 || return 1
  assert_no_file PWNED3 || return 1
  # shellcheck disable=SC2016 # idem
  grep -qF 'argumentos: x; touch PWNED $(touch PWNED2) `touch PWNED3`' fake.log
}

test_converse_ask_quick() {
  fake_agents
  cv create codex --ask 5 usar x >/dev/null || return 1
  grep -qF 'argumentos: --ask 5 usar x' fake.log || fail "--ask não repassado" || return 1
  rm fake.log
  cv supersede codex -k ADR-0001 >/dev/null || return 1
  grep -qF 'argumentos: --quick ADR-0001' fake.log || fail "--quick não repassado" || return 1
  local code
  cv create codex --ask abc x >/dev/null 2>&1; code=$?
  assert_eq "$code" "2" "--ask não inteiro" || return 1
  cv audit --agent codex --quick >/dev/null 2>&1; code=$?
  assert_eq "$code" "2" "--quick fora de create/supersede" || return 1
  cv ask --agent codex >/dev/null 2>&1; code=$?
  assert_eq "$code" "2" "ask sem pergunta"
}

test_converse_missing_binary() {
  fake_agents
  local out code
  out="$(PATH="$PWD/emptybin:/usr/bin:/bin" "$CLI" create --agent codex x 2>&1)"; code=$?
  assert_eq "$code" "5" "código" || return 1
  assert_contains "$out" "codex" || return 1
  assert_no_file fake.log
}

test_help_lists_converse() {
  local out; out="$("$CLI" help)" || return 1
  for c in create supersede review audit ask config; do
    assert_contains "$out" "  $c " || return 1
  done
}

test_installer_copies_launch_table() {
  mkdir -p "$HOME/.claude"
  installer --agent claude-code >/dev/null 2>&1 < /dev/null || fail "instalação falhou" || return 1
  assert_file "$HOME/.local/share/adr-std/agent_launch.tsv" || return 1
  local out="$PWD/out"
  ( cd "$ROOT" && bash ./package.sh "$out" ) >/dev/null 2>&1 || fail "package.sh falhou" || return 1
  unzip -Z1 "$out/adr-std.zip" | grep -qxF agent_launch.tsv || fail "zip sem agent_launch.tsv"
}

# ---------------------------------------------------------------------------
# executor

run_test() {
  local name="$1" fn="test_$1"
  if ! declare -F "$fn" >/dev/null; then
    echo "  ? $name (teste inexistente)"; FAIL=$((FAIL + 1)); FAILED+=("$name"); return
  fi
  local tmp; tmp="$(mktemp -d)"
  if ( export HOME="$tmp/home"; mkdir -p "$HOME"; cd "$tmp"; unset XDG_DATA_HOME XDG_CONFIG_HOME; "$fn" ); then
    echo "  ✓ $name"; PASS=$((PASS + 1))
  else
    echo "  ✗ $name"; FAIL=$((FAIL + 1)); FAILED+=("$name")
  fi
  rm -rf "$tmp"
}

main() {
  local tests=("$@")
  if [ ${#tests[@]} -eq 0 ]; then
    mapfile -t tests < <(declare -F | awk '{print $3}' | grep '^test_' | sed 's/^test_//')
  fi
  for t in "${tests[@]}"; do run_test "$t"; done
  echo "Resultado: $PASS passaram, $FAIL falharam${FAILED:+ (${FAILED[*]})}"
  [ "$FAIL" -eq 0 ]
}

main "$@"
