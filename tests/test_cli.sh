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
  bad=$(grep -v '^#' "$f" | grep . | awk -F'\t' 'NF != 5' | wc -l | tr -d ' ')
  assert_eq "$bad" "0" "linhas sem 5 colunas" || return 1
  ids=$(grep -v '^#' "$f" | grep . | cut -f1 | wc -l | tr -d ' ')
  unique=$(grep -v '^#' "$f" | grep . | cut -f1 | sort -u | wc -l | tr -d ' ')
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
  local bad; bad=$(grep -v '^#' "$cf" | grep . | awk -F'\t' 'NF != 2' | wc -l | tr -d ' ')
  assert_eq "$bad" "0" "linhas de commands.tsv sem 2 colunas" || return 1
  for id in claude-code gemini-cli opencode continue; do
    grep -v '^#' "$tf" | grep . | cut -f1 | grep -qxF "$id" || fail "command_targets.tsv sem $id" || return 1
  done
  bad=$(grep -v '^#' "$tf" | grep . | awk -F'\t' 'NF != 4' | wc -l | tr -d ' ')
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
  grep -qE '^agent'$'\t''claude-code'$'\t''' "$(state_file)" || fail "estado sem claude-code" || return 1
  grep -qE '^version'$'\t''' "$(state_file)" || fail "estado sem versão" || return 1

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
  local n; n=$(grep -cE '^agent'$'\t''(gemini-cli|opencode)'$'\t'''"$HOME"'/.agents/skills/adr-std('$'\t''(copy|link))?$' "$(state_file)")
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
  local n; n=$(grep -cE '^agent'$'\t''claude-code'$'\t''' "$(state_file)")
  assert_eq "$n" "1" "linhas do agente no estado"
}

test_uninstall_one() {
  mkdir -p "$HOME/.claude" "$HOME/.codex"
  "$CLI" install claude-code codex >/dev/null || fail "install falhou" || return 1
  "$CLI" uninstall codex >/dev/null || fail "uninstall falhou" || return 1
  assert_no_file "$HOME/.codex/skills/adr-std" || return 1
  assert_file "$HOME/.claude/skills/adr-std/SKILL.md" || return 1
  grep -qE '^agent'$'\t''codex'$'\t''' "$(state_file)" && fail "codex ainda no estado"
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
  grep -qE '^agent'$'\t''' "$(state_file)" && fail "agentes ainda no estado"
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

test_status_mode_per_agent() {
  mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.continue"
  "$CLI" install --link claude-code >/dev/null || fail "install --link falhou" || return 1
  "$CLI" install codex >/dev/null || fail "install copy falhou" || return 1
  local out; out="$("$CLI" status)"
  printf '%s\n' "$out" | grep -E 'claude-code' | grep -qF '[íntegra, link]' || fail "claude-code sem [íntegra, link]: $out" || return 1
  printf '%s\n' "$out" | grep -E 'codex' | grep -qF '[íntegra, copy]' || fail "codex sem [íntegra, copy]: $out" || return 1
  rm -rf "$HOME/.codex/skills/adr-std"
  out="$("$CLI" status)"
  printf '%s\n' "$out" | grep -E 'codex' | grep -qF '[danificada (pasta ausente ou incompleta), copy]' || fail "danificada sem o modo: $out" || return 1
  printf '%s\n' "$out" | head -1 | grep -q '^adr-std: skill instalada na versão' || fail "cabeçalho mudou: $out"
}

test_status_mode_old_state_uses_global() {
  mkdir -p "$HOME/.claude" "$HOME/.config/adr-std"
  "$CLI" install claude-code >/dev/null || fail "install falhou" || return 1
  local f; f="$(state_file)"
  # estado antigo: linha agent de 3 colunas e mode global link
  awk -F'\t' 'BEGIN{OFS="\t"} $1=="agent"{print $1,$2,$3; next} $1=="mode"{print "mode","link"; next} {print}' "$f" > "$f.new" && mv "$f.new" "$f"
  local out; out="$("$CLI" status)"
  printf '%s\n' "$out" | grep -E 'claude-code' | grep -qF '[íntegra, link]' || fail "estado antigo não usou o mode global: $out"
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
  local n; n=$(find "$HOME/.claude/commands" -name 'adr-std-*.md' | wc -l | tr -d ' ')
  assert_eq "$n" "10" "arquivos de comando criados" || return 1
  # shellcheck disable=SC2016 # literal $ARGUMENTS esperado no arquivo, não expansão
  assert_contains "$(cat "$HOME/.claude/commands/adr-std-create.md")" '$ARGUMENTS' || return 1
  assert_contains "$(cat "$HOME/.claude/commands/adr-std-create.md")" 'ação "create"' || return 1
  grep -qE '^command'$'\t''claude-code'$'\t''' "$(state_file)" || fail "estado sem registro de comando"
}

test_install_no_commands() {
  mkdir -p "$HOME/.claude"
  "$CLI" install --no-commands claude-code >/dev/null || fail "install falhou" || return 1
  assert_no_file "$HOME/.claude/commands/adr-std-create.md" || return 1
  grep -qE '^command'$'\t''' "$(state_file)" 2>/dev/null && fail "estado com comando apesar de --no-commands"
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
  grep -qE '^command'$'\t''' "$(state_file)" 2>/dev/null && fail "comandos ainda no estado"
  return 0
}

test_check() {
  local out
  out="$("$CLI" check "$ROOT/tests/fixtures/1-cache-de-sessao-em-redis.md")" || fail "check da fixture deveria passar" || return 1
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
  ( cd site && exec python3 -m http.server "$port" --bind 127.0.0.1 >/dev/null 2>&1 ) &
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

# update (v2.0): gancho de migração depois do instalador. O pacote falso é o próprio repositório
# (start_server copia o working tree), então já traz skill/scripts/migrate_numbering.py.
update_setup() { # prepara skill instalada, servidor falso e projeto com 0001-a.md
  mkdir -p "$HOME/.claude"
  installer --agent claude-code >/dev/null 2>&1 < /dev/null || fail "instalação inicial falhou" || return 1
  start_server 9.9.9 || { fail "servidor de teste não subiu"; return 1; }
  migrate_project || { stop_server; return 1; }
  UTTY="$PWD/no-tty"   # arquivo inexistente: simula ausência de terminal
}

# Roda o update no projeto; define UOUT e UCODE.
run_update() { # args...
  UOUT="$(cd proj && ADR_STD_BASE_URL="$BASE" ADR_STD_TTY="$UTTY" "$HOME/.local/bin/adr-std" update "$@" 2>&1)"; UCODE=$?
}

assert_project_unchanged() {
  assert_file proj/docs/architecture/ADR/0001-a.md || return 1
  assert_no_file proj/docs/architecture/ADR/1-a.md || return 1
  grep -qF '0001-a.md' proj/README.md || fail "README alterado"
}

test_update_migrate_no_tty() {
  update_setup || return 1
  run_update; stop_server
  assert_eq "$UCODE" "0" "código do update" || return 1
  assert_eq "$(cat "$HOME/.local/share/adr-std/VERSION")" "9.9.9" "versão depois do update" || return 1
  assert_contains "$UOUT" "0001-a.md" || return 1
  assert_contains "$UOUT" "1-a.md" || return 1
  assert_contains "$UOUT" "adr-std migrate --apply" || return 1
  printf '%s' "$UOUT" | grep -qF 'Aplicar a migração?' && fail "perguntou sem terminal" && return 1
  assert_project_unchanged
}

test_update_migrate_tty_yes() {
  update_setup || return 1
  printf 's\n' > ans; UTTY="$PWD/ans"
  run_update; stop_server
  assert_eq "$UCODE" "0" "código do update" || return 1
  assert_contains "$UOUT" "Aplicar a migração? [s/N]" || return 1
  assert_file proj/docs/architecture/ADR/1-a.md || return 1
  assert_no_file proj/docs/architecture/ADR/0001-a.md || return 1
  grep -qF 'docs/architecture/ADR/1-a.md' proj/README.md || fail "link do README não corrigido"
}

test_update_migrate_tty_no() {
  update_setup || return 1
  local answer
  for answer in 'n' '' 'talvez'; do
    printf '%s\n' "$answer" > ans; UTTY="$PWD/ans"
    run_update
    assert_eq "$UCODE" "0" "código do update (resposta '$answer')" || { stop_server; return 1; }
    assert_contains "$UOUT" "Aplicar a migração? [s/N]" || { stop_server; return 1; }
    assert_project_unchanged || { stop_server; return 1; }
  done
  : > ans   # EOF sem resposta
  run_update; stop_server
  assert_eq "$UCODE" "0" "código do update (EOF)" || return 1
  assert_project_unchanged
}

test_update_no_migrate() {
  update_setup || return 1
  printf 's\n' > ans; UTTY="$PWD/ans"
  run_update --no-migrate; stop_server
  assert_eq "$UCODE" "0" "código do update" || return 1
  assert_eq "$(cat "$HOME/.local/share/adr-std/VERSION")" "9.9.9" "skill atualizada" || return 1
  printf '%s' "$UOUT" | grep -qE 'plano de migração|migração: nada a fazer|Aplicar a migração' && fail "calculou ou mostrou o plano com --no-migrate" && return 1
  assert_project_unchanged
}

test_update_dry_run_no_migrate() {
  update_setup || return 1
  run_update --dry-run; stop_server
  assert_eq "$UCODE" "0" "código do update" || return 1
  assert_contains "$UOUT" "simulação" || return 1
  printf '%s' "$UOUT" | grep -qE 'plano de migração|migração: nada a fazer' && fail "migrou com --dry-run" && return 1
  assert_project_unchanged
}

test_update_migrate_nothing_to_do() {
  update_setup || return 1
  # projeto com numbering: padded
  printf 'numbering: padded\n' > proj/.adr-std
  run_update
  assert_eq "$UCODE" "0" "código do update (padded)" || { stop_server; return 1; }
  assert_contains "$UOUT" "migração: nada a fazer" || { stop_server; return 1; }
  printf '%s' "$UOUT" | grep -qF 'plano de migração' && { stop_server; fail "mostrou plano em projeto padded"; return 1; }
  assert_project_unchanged || { stop_server; return 1; }
  # diretório sem pasta de ADRs
  mkdir -p empty && ( cd empty && git init -q )
  UOUT="$(cd empty && ADR_STD_BASE_URL="$BASE" ADR_STD_TTY="$UTTY" "$HOME/.local/bin/adr-std" update 2>&1)"; UCODE=$?
  stop_server
  assert_eq "$UCODE" "0" "código do update (sem pasta)" || return 1
  assert_contains "$UOUT" "migração: nada a fazer" || return 1
  printf '%s' "$UOUT" | grep -qF 'plano de migração' && fail "mostrou plano sem pasta de ADRs"
  return 0
}

test_update_migrate_no_python() {
  update_setup || return 1
  # PATH só com as ferramentas do instalador, sem python
  mkdir -p nopybin
  local t p
  for t in bash sh curl unzip sha256sum shasum cp mv rm mkdir cat date dirname basename grep sed awk tr cut sort uname mktemp ln chmod head tail printf env wc readlink tee find xargs; do
    p="$(command -v "$t" 2>/dev/null)" && [ -x "$p" ] && ln -sf "$p" "nopybin/$t"
  done
  UOUT="$(cd proj && PATH="$PWD/../nopybin" ADR_STD_BASE_URL="$BASE" ADR_STD_TTY="$UTTY" "$HOME/.local/bin/adr-std" update 2>&1)"; UCODE=$?
  stop_server
  assert_eq "$UCODE" "0" "código do update sem Python" || { echo "$UOUT"; return 1; }
  assert_eq "$(cat "$HOME/.local/share/adr-std/VERSION")" "9.9.9" "skill continua atualizada" || return 1
  assert_contains "$UOUT" "aviso" || return 1
  assert_contains "$UOUT" "Python" || return 1
  assert_project_unchanged
}

test_update_failed_installer_no_migration() {
  update_setup || return 1
  echo "0000000000000000000000000000000000000000000000000000000000000000  adr-std.zip" > site/releases/latest/download/adr-std.zip.sha256
  printf 's\n' > ans; UTTY="$PWD/ans"
  run_update; stop_server
  assert_eq "$UCODE" "5" "código do instalador preservado" || return 1
  assert_contains "$UOUT" "checksum" || return 1
  printf '%s' "$UOUT" | grep -qE 'plano de migração|migração: nada a fazer|Aplicar a migração' && fail "migrou com o instalador falhando" && return 1
  assert_project_unchanged
}

# update e uninstall com destinos adotados (RF-11, D-10, D-17).
test_update_skips_link_mode_destinations() {
  update_setup || return 1
  "$HOME/.local/bin/adr-std" install claude-code --link >/dev/null 2>&1 < /dev/null
  local before; before="$(readlink "$HOME/.claude/skills/adr-std")"
  [ -n "$before" ] || { stop_server; fail "destino não virou link"; return 1; }
  run_update; stop_server
  assert_eq "$UCODE" "0" "$UOUT" || return 1
  assert_eq "$(readlink "$HOME/.claude/skills/adr-std")" "$before" "link não foi substituído" || return 1
  assert_contains "$UOUT" "já segue o repositório" || return 1
  assert_contains "$UOUT" "adr-std migrate --apply" "a migração roda mesmo assim"
}

test_update_installer_code_4_still_migrates() {
  update_setup || return 1
  # a pasta registrada passa a ser de outra skill: o instalador pula o destino e devolve 4
  rm -rf "$HOME/.claude/skills/adr-std"; mkdir -p "$HOME/.claude/skills/adr-std"
  printf -- '---\nname: outra\n---\n' > "$HOME/.claude/skills/adr-std/SKILL.md"
  run_update; stop_server
  assert_eq "$UCODE" "4" "o update devolve 4 no fim" || return 1
  assert_contains "$UOUT" "outra-skill" "mostra o resumo" || return 1
  assert_contains "$UOUT" "adr-std migrate --apply" "executou a migração" || return 1
  assert_project_unchanged
}

test_uninstall_adopted_link_keeps_target_and_backup() {
  mkdir -p "$HOME/.claude/skills"
  ln -s "$ROOT/skill" "$HOME/.claude/skills/adr-std"
  mkdir -p "$HOME/.claude/skills/adr-std.bak-2026-10-27"; printf 'bak\n' > "$HOME/.claude/skills/adr-std.bak-2026-10-27/x.txt"
  "$CLI" install claude-code >/dev/null 2>&1
  [ -L "$HOME/.claude/skills/adr-std" ] || fail "o link adotado deveria continuar link" || return 1
  "$CLI" uninstall claude-code >/dev/null 2>&1
  [ ! -e "$HOME/.claude/skills/adr-std" ] && [ ! -L "$HOME/.claude/skills/adr-std" ] || fail "o link adotado deveria ter sido removido" || return 1
  assert_file "$ROOT/skill/SKILL.md" || return 1
  assert_eq "$(cat "$HOME/.claude/skills/adr-std.bak-2026-10-27/x.txt")" "bak" "o backup é mantido"
}

test_help_lists_adopt() {
  local out; out="$("$CLI" help)" || fail "help falhou" || return 1
  assert_contains "$out" "--adopt" || return 1
  assert_contains "$out" "código 4"
}

# Achados da revisão independente (4.6).
test_update_agent_not_registered_ignores_global_link_mode() {
  update_setup || return 1
  # estado global em link, mas o cursor nunca foi registrado: não pode ser tratado como destino em modo link
  { grep -v '^mode	' "$(state_file)"; printf 'mode\tlink\n'; } > state.new && mv state.new "$(state_file)"
  mkdir -p "$HOME/.cursor"
  run_update --agent cursor; stop_server
  if printf '%s' "$UOUT" | grep -qF "cursor: " && printf '%s' "$UOUT" | grep -qF "já segue o repositório"; then fail "agente não registrado tratado como link: $UOUT"; return 1; fi
  assert_file "$HOME/.cursor/skills/adr-std/SKILL.md"
}

test_adopt_install_failure_restores_original() {
  load_act_on_dest || return 1
  classify_skill_dir skills/adr-std adr-std; printf 'original\n' > skills/adr-std/extra.txt
  install_to() { return 1; }   # falha depois do backup
  ADOPT=1
  ADR_STD_TODAY=2026-10-27 act_on_dest claude-code foreign-adr-std "$PWD/skills/adr-std" >out.txt 2>&1; local rc=$?
  assert_eq "$rc" "4" || return 1
  assert_eq "$ACT_RESULT" "skipped:falha-na-instalacao" || return 1
  assert_eq "$(cat skills/adr-std/extra.txt)" "original" "o original volta ao lugar" || return 1
  assert_no_file "$PWD/skills/adr-std.bak-2026-10-27" || return 1
  assert_eq "$(state_agents)" "" "nada registrado"
}

test_help_lists_update_no_migrate() {
  local out; out="$("$CLI" help)" || fail "help falhou" || return 1
  assert_contains "$out" "--no-migrate" || return 1
  assert_contains "$out" "plano de migração"
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
  sed -i.bak 's/^name: adr-std$/name: outro-nome/' repo/skill/SKILL.md && rm -f repo/skill/SKILL.md.bak
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
  for c in new list link organize migrate; do
    assert_contains "$out" "  $c " || return 1
  done
  assert_contains "$out" "--apply" || return 1
  assert_contains "$out" "--exclude" || return 1
}

migrate_project() {
  mkdir -p proj/docs/architecture/ADR || return 1
  ( cd proj && git init -q && git config user.email t@t && git config user.name t ) || return 1
  printf '# ADR-0001: A\n' > proj/docs/architecture/ADR/0001-a.md
  printf 'Veja [A](docs/architecture/ADR/0001-a.md).\n' > proj/README.md
  ( cd proj && git add -A && git commit -q -m init ) || return 1
}

test_cli_migrate_plan() {
  migrate_project || return 1
  local out; out="$(cd proj && "$CLI" migrate 2>&1)" || fail "migrate falhou: $out" || return 1
  assert_contains "$out" "0001-a.md" || return 1
  assert_contains "$out" "1-a.md" || return 1
  assert_file proj/docs/architecture/ADR/0001-a.md || return 1
  assert_no_file proj/docs/architecture/ADR/1-a.md || return 1
  grep -qF '0001-a.md' proj/README.md || fail "README alterado sem --apply"
}

test_cli_migrate_apply() {
  migrate_project || return 1
  local out; out="$(cd proj && "$CLI" migrate --apply 2>&1)" || fail "migrate --apply falhou: $out" || return 1
  assert_file proj/docs/architecture/ADR/1-a.md || return 1
  assert_no_file proj/docs/architecture/ADR/0001-a.md || return 1
  grep -qF 'docs/architecture/ADR/1-a.md' proj/README.md || fail "link do README não corrigido" || return 1
  out="$(cd proj && "$CLI" migrate 2>&1)" || fail "segunda execução falhou: $out"
}

test_cli_new_list() {
  local out
  out="$("$CLI" new "Usar fila" --path adrs --create)" || fail "new falhou" || return 1
  assert_contains "$out" "1-usar-fila.md" || return 1
  assert_file adrs/1-usar-fila.md || return 1
  out="$("$CLI" list --path adrs)" || fail "list falhou" || return 1
  assert_contains "$out" "Usar fila" || return 1
  assert_contains "$out" "Proposto"
}

test_cli_link_organize() {
  "$CLI" new "Um" --path adrs --create >/dev/null && "$CLI" new "Dois" --path adrs >/dev/null || return 1
  "$CLI" link ADR-1 restringe ADR-2 --path adrs >/dev/null || fail "link falhou" || return 1
  grep -qF 'é restringido por ADR-1' adrs/2-dois.md || fail "relação recíproca ausente" || return 1
  mv adrs/2-dois.md adrs/5-dois.md
  local out; out="$("$CLI" organize --dry-run --path adrs)" || fail "organize falhou" || return 1
  assert_contains "$out" "5-dois.md -> 2-dois.md" || return 1
  assert_file adrs/5-dois.md
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

test_cli_migrate_no_python() {
  local out code
  out="$(PATH="/nao/existe" /bin/bash "$CLI" migrate 2>&1)"; code=$?
  assert_eq "$code" "6" "código de migrate sem Python" || return 1
  assert_contains "$out" "Python" || return 1
  assert_contains "$out" "checklist"
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
  bad=$(grep -v '^#' "$f" | grep . | awk -F'\t' 'NF != 3' | wc -l | tr -d ' ')
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
  assert_eq "$(awk -F'\t' '$1=="default_agent"{print $2}' "$(state_file)")" "codex" "estado" || return 1
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
  assert_eq "$(awk -F'\t' '$1=="default_agent"{print $2}' "$(state_file)")" "codex" "default_agent preservado" || return 1
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
  printf '# ADR-1: teste\n\n| **ID** | ADR-1 |\n| **Status** | Proposto |\n| **Data da decisão** | 2026-10-02 |\n' > outra-pasta/1-teste.md
  "$CLI" config path outra-pasta >/dev/null || return 1
  out="$("$CLI" list)" || fail "list falhou" || return 1
  assert_contains "$out" "ADR-1" || return 1
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
  assert_eq "$(awk -F'\t' '$1=="last_agent"{print $2}' "$(state_file)")" "codex" "último usado" || return 1
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

# Gancho de teste: com ADR_STD_LIB definida, `source bin/adr-std` só define as funções e não executa `main`.
load_lib() {
  ADR_STD_LIB=1 . "$ROOT/bin/adr-std"
}

test_lib_hook_loads_without_running() {
  local out
  out="$(ADR_STD_LIB=1 bash -c '. "$1"; declare -F classify_dest >/dev/null && declare -F main >/dev/null && echo carregou' _ "$ROOT/bin/adr-std" 2>&1)"
  assert_eq "$out" "carregou" "com ADR_STD_LIB o script só define funções (sem ajuda, sem erro)" || return 1
  out="$(bash "$ROOT/bin/adr-std" version 2>&1)"
  assert_eq "$out" "adr-std $(cat "$ROOT/VERSION")" "sem ADR_STD_LIB a CLI executa normalmente" || return 1
  bash "$ROOT/bin/adr-std" comando-inexistente >/dev/null 2>&1
  assert_eq "$?" "2" "código de saída de comando desconhecido preservado"
}

# resolve_link_chain (D-6, SEG-02): as funções vêm de `source bin/adr-std` com ADR_STD_LIB=1 (load_lib).
load_resolve_link_chain() {
  load_lib
  declare -F resolve_link_chain >/dev/null || fail "resolve_link_chain não definida em bin/adr-std"
}

test_resolve_link_chain_direct() {
  load_resolve_link_chain || return 1
  mkdir -p real && ln -s "$PWD/real" l1
  local out; out="$(resolve_link_chain "$PWD/l1")" || fail "link direto deveria resolver" || return 1
  assert_eq "$out" "$PWD/real"
}

test_resolve_link_chain_nested() {
  load_resolve_link_chain || return 1
  mkdir -p real && ln -s "$PWD/real" l1 && ln -s "$PWD/l1" l2 && ln -s "$PWD/l2" l3
  local out; out="$(resolve_link_chain "$PWD/l2")" || fail "2 níveis deveria resolver" || return 1
  assert_eq "$out" "$PWD/real" "2 níveis" || return 1
  out="$(resolve_link_chain "$PWD/l3")" || fail "3 níveis deveria resolver" || return 1
  assert_eq "$out" "$PWD/real" "3 níveis"
}

test_resolve_link_chain_relative() {
  load_resolve_link_chain || return 1
  mkdir -p real sub && ln -s ../real sub/l1 && ln -s sub/l1 l2
  local out; out="$(resolve_link_chain "$PWD/l2")" || fail "link relativo deveria resolver" || return 1
  assert_eq "$out" "$PWD/real"
}

test_resolve_link_chain_cycle() {
  load_resolve_link_chain || return 1
  ln -s "$PWD/b" a && ln -s "$PWD/a" b
  resolve_link_chain "$PWD/a" >/dev/null 2>&1 && fail "ciclo deveria falhar" && return 1
  ln -s "$PWD/self" self
  resolve_link_chain "$PWD/self" >/dev/null 2>&1 && fail "autolink deveria falhar" && return 1
  return 0
}

test_resolve_link_chain_limit() {
  load_resolve_link_chain || return 1
  mkdir -p real && ln -s "$PWD/real" n1
  local i
  for i in 2 3 4 5 6 7 8 9 10 11; do ln -s "$PWD/n$((i - 1))" "n$i"; done
  local out; out="$(resolve_link_chain "$PWD/n10")" || fail "10 saltos deveria resolver" || return 1
  assert_eq "$out" "$PWD/real" "10 saltos" || return 1
  resolve_link_chain "$PWD/n11" >/dev/null 2>&1 && fail "11 saltos deveria falhar" && return 1
  return 0
}

test_resolve_link_chain_broken() {
  load_resolve_link_chain || return 1
  ln -s "$PWD/ausente" quebrado
  resolve_link_chain "$PWD/quebrado" >/dev/null 2>&1 && fail "link quebrado deveria falhar" && return 1
  resolve_link_chain "$PWD/nao-existe" >/dev/null 2>&1 && fail "caminho inexistente deveria falhar" && return 1
  return 0
}

# skill_name_of (D-11, SEG-03): lê só o frontmatter do SKILL.md, como texto.
load_skill_name_of() {
  load_lib
  declare -F skill_name_of >/dev/null || fail "skill_name_of não definida em bin/adr-std"
}

test_skill_name_of_adr_std() {
  load_skill_name_of || return 1
  mkdir -p s && printf -- '---\nname: adr-std\ndescription: x\n---\ncorpo\n' > s/SKILL.md
  assert_eq "$(skill_name_of "$PWD/s")" "adr-std"
}

test_skill_name_of_other_name() {
  load_skill_name_of || return 1
  mkdir -p s && printf -- '---\nname: outra-coisa\n---\ncorpo\n' > s/SKILL.md
  assert_eq "$(skill_name_of "$PWD/s")" "outra-coisa"
}

test_skill_name_of_no_frontmatter() {
  load_skill_name_of || return 1
  mkdir -p s && printf 'name: adr-std\nsó corpo\n' > s/SKILL.md
  assert_eq "$(skill_name_of "$PWD/s")" "" "sem bloco --- não há name" || return 1
  printf -- '---\ndescription: x\n---\nname: adr-std\n' > s/SKILL.md
  assert_eq "$(skill_name_of "$PWD/s")" "" "name fora do frontmatter é ignorado"
}

test_skill_name_of_bom_and_crlf() {
  load_skill_name_of || return 1
  mkdir -p s
  printf '\xef\xbb\xbf---\nname: adr-std\n---\ncorpo\n' > s/SKILL.md
  assert_eq "$(skill_name_of "$PWD/s")" "adr-std" "BOM no início do SKILL.md" || return 1
  printf -- '---\r\nname: adr-std\r\n---\r\ncorpo\r\n' > s/SKILL.md
  assert_eq "$(skill_name_of "$PWD/s")" "adr-std" "fim de linha CRLF" || return 1
  printf '\xef\xbb\xbf---\r\ndescription: x\r\nname: outro\r\n---\r\n' > s/SKILL.md
  assert_eq "$(skill_name_of "$PWD/s")" "outro" "BOM e CRLF juntos"
}

test_skill_name_of_no_file() {
  load_skill_name_of || return 1
  mkdir -p s
  assert_eq "$(skill_name_of "$PWD/s")" "" "pasta sem SKILL.md" || return 1
  assert_eq "$(skill_name_of "$PWD/inexistente")" "" "pasta inexistente"
}

test_skill_name_of_text_only() {
  load_skill_name_of || return 1
  mkdir -p s
  printf -- '---\nname: $(touch %s/executou) `touch %s/executou2`\n---\n' "$PWD" "$PWD" > s/SKILL.md
  local out; out="$(skill_name_of "$PWD/s")"
  assert_no_file "$PWD/executou" || return 1
  assert_no_file "$PWD/executou2" || return 1
  assert_contains "$out" '$(touch' || return 1
  assert_contains "$out" '`touch'
}

test_skill_name_of_limit_20_lines() {
  load_skill_name_of || return 1
  mkdir -p s
  { printf -- '---\n'; for i in $(seq 1 25); do printf 'campo%s: v\n' "$i"; done; printf 'name: adr-std\n---\n'; } > s/SKILL.md
  assert_eq "$(skill_name_of "$PWD/s")" "" "name além da 20ª linha é ignorado"
}

# classify_dest (RF-01 a RF-04, RF-08, D-7): classificação somente leitura de um destino.
load_classify_dest() {
  load_lib
  declare -F classify_dest >/dev/null || fail "classify_dest não definida em bin/adr-std" || return 1
  MARKER=".installed-by-adr-std"
  SRC="$PWD/src"; DATA_DIR="$PWD/data"; STATE_FILE="$PWD/state"
  mkdir -p "$SRC/skill" "$DATA_DIR/skill"
}

classify_skill_dir() { # pasta nome
  mkdir -p "$1" && printf -- '---\nname: %s\n---\ncorpo\n' "$2" > "$1/SKILL.md"
}

# owned_by_us (D-8): propriedade pela cadeia de links resolvida, não pelo readlink exato.
load_owned_by_us() {
  load_classify_dest || return 1
  declare -F owned_by_us >/dev/null || fail "owned_by_us não definida em bin/adr-std"
}

test_owned_by_us_chained_link() {
  load_owned_by_us || return 1
  ln -s "$SRC/skill" direto && ln -s "$PWD/direto" meio && ln -s "$PWD/meio" encadeado
  printf 'agent\tclaude-code\t%s\nagent\tcodex\t%s\n' "$PWD/direto" "$PWD/encadeado" > "$STATE_FILE"
  owned_by_us "$PWD/direto" || fail "link direto registrado deveria ser nosso" || return 1
  owned_by_us "$PWD/encadeado" || fail "link encadeado registrado deveria ser nosso"
}

# act_on_dest (RF-01 a RF-03, RF-08, D-16): ação por classe; o resultado fica em ACT_RESULT.
load_act_on_dest() {
  load_classify_dest || return 1
  declare -F act_on_dest >/dev/null || fail "act_on_dest não definida em bin/adr-std" || return 1
  CONFIG_DIR="$PWD/cfg"; LINK=0
  printf 'skill\n' > "$SRC/skill/SKILL.md"
}

test_act_on_dest_absent_installs() {
  load_act_on_dest || return 1
  act_on_dest claude-code absent "$PWD/skills/adr-std" >/dev/null; local rc=$?
  assert_eq "$rc" "0" "absent instala" || return 1
  assert_eq "$ACT_RESULT" "installed" || return 1
  assert_file "$PWD/skills/adr-std/$MARKER" || return 1
  assert_eq "$(state_agent_mode claude-code)" "copy" "registra o modo copy"
}

test_act_on_dest_ours_copy_updates() {
  load_act_on_dest || return 1
  act_on_dest claude-code absent "$PWD/skills/adr-std" >/dev/null
  printf 'novo\n' > "$SRC/skill/SKILL.md"
  act_on_dest claude-code ours "$PWD/skills/adr-std" >/dev/null; local rc=$?
  assert_eq "$rc" "0" || return 1
  assert_eq "$ACT_RESULT" "updated" || return 1
  [ ! -L "$PWD/skills/adr-std" ] || fail "cópia deveria continuar cópia" || return 1
  assert_eq "$(cat "$PWD/skills/adr-std/SKILL.md")" "novo" "conteúdo atualizado"
}

test_act_on_dest_ours_link_stays_link() {
  load_act_on_dest || return 1
  mkdir -p skills && ln -s "$SRC/skill" skills/adr-std
  state_add_agent claude-code "$PWD/skills/adr-std" link
  act_on_dest claude-code ours "$PWD/skills/adr-std" >/dev/null; local rc=$?
  assert_eq "$rc" "0" || return 1
  assert_eq "$ACT_RESULT" "updated" || return 1
  [ -L "$PWD/skills/adr-std" ] || fail "link sem --link deveria continuar link (D-16)" || return 1
  assert_eq "$(readlink "$PWD/skills/adr-std")" "$SRC/skill" "aponta para a fonte" || return 1
  assert_eq "$(state_agent_mode claude-code)" "link"
}

test_act_on_dest_explicit_link_converts_copy() {
  load_act_on_dest || return 1
  act_on_dest claude-code absent "$PWD/skills/adr-std" >/dev/null
  LINK=1
  act_on_dest claude-code ours "$PWD/skills/adr-std" >/dev/null
  [ -L "$PWD/skills/adr-std" ] || fail "--link explícito converte cópia em link" || return 1
  assert_eq "$(state_agent_mode claude-code)" "link"
}

test_act_on_dest_repo_link_adopted_in_place() {
  load_act_on_dest || return 1
  ln -s "$SRC/skill" direto && mkdir -p skills && ln -s "$PWD/direto" skills/adr-std
  local before; before="$(readlink "$PWD/skills/adr-std")"
  act_on_dest claude-code repo-link "$PWD/skills/adr-std" >/dev/null; local rc=$?
  assert_eq "$rc" "0" || return 1
  assert_eq "$ACT_RESULT" "adopted-in-place" || return 1
  assert_eq "$(readlink "$PWD/skills/adr-std")" "$before" "link intacto" || return 1
  assert_eq "$(ls skills | grep -c bak)" "0" "sem backup" || return 1
  assert_eq "$(state_agent_mode claude-code)" "link" "registrado como link" || return 1
  assert_eq "$(state_agents | cut -f2)" "$PWD/skills/adr-std" "registrado no estado"
}

test_act_on_dest_foreign_other_untouched() {
  load_act_on_dest || return 1
  classify_skill_dir skills/adr-std outra-skill
  act_on_dest claude-code foreign-other "$PWD/skills/adr-std" >/dev/null; local rc=$?
  assert_eq "$rc" "4" "pulo devolve 4" || return 1
  assert_eq "$ACT_RESULT" "skipped:outra-skill" || return 1
  assert_eq "$(skill_name_of "$PWD/skills/adr-std")" "outra-skill" "intacta" || return 1
  assert_eq "$(state_agents)" "" "não registra"
}

test_act_on_dest_foreign_adr_std_without_terminal() {
  load_act_on_dest || return 1
  classify_skill_dir skills/adr-std adr-std
  ADR_STD_TTY=/nao/existe act_on_dest claude-code foreign-adr-std "$PWD/skills/adr-std" >/dev/null; local rc=$?
  assert_eq "$rc" "4" || return 1
  assert_eq "$ACT_RESULT" "skipped:sem-terminal" || return 1
  assert_eq "$(skill_name_of "$PWD/skills/adr-std")" "adr-std" "intacta" || return 1
  assert_eq "$(state_agents)" "" "não registra"
}

# Adoção interativa de foreign-adr-std (RF-04, RF-05): confirmação [s/N], backup e instalação.
test_adopt_confirmed_copy_makes_backup_and_installs() {
  load_act_on_dest || return 1
  local answer
  for answer in s S; do
    rm -rf skills cfg state; classify_skill_dir skills/adr-std adr-std; printf 'original\n' > skills/adr-std/extra.txt
    printf '%s\n' "$answer" > answer
    ADR_STD_TODAY=2026-10-27 ADR_STD_TTY="$PWD/answer" act_on_dest claude-code foreign-adr-std "$PWD/skills/adr-std" >out.txt 2>&1; local rc=$?
    assert_eq "$rc" "0" "resposta '$answer' confirma" || return 1
    assert_eq "$ACT_RESULT" "adopted-with-backup" || return 1
    assert_eq "$(cat skills/adr-std.bak-2026-10-27/extra.txt)" "original" "backup com o conteúdo original" || return 1
    assert_file "$PWD/skills/adr-std/$MARKER" || return 1
    assert_eq "$(state_agent_mode claude-code)" "copy" "registrado como copy" || return 1
    assert_contains "$(cat out.txt)" "adr-std.bak-2026-10-27" || return 1
    assert_contains "$(cat out.txt)" "[s/N]" || return 1
  done
}

test_adopt_refused_leaves_no_trace() {
  load_act_on_dest || return 1
  local answer
  for answer in "" n N xyz "sim"; do
    rm -rf skills cfg state; classify_skill_dir skills/adr-std adr-std; printf 'original\n' > skills/adr-std/extra.txt
    printf '%s\n' "$answer" > answer
    ADR_STD_TODAY=2026-10-27 ADR_STD_TTY="$PWD/answer" act_on_dest claude-code foreign-adr-std "$PWD/skills/adr-std" >/dev/null 2>&1; local rc=$?
    assert_eq "$rc" "4" "resposta '$answer' recusa" || return 1
    assert_eq "$ACT_RESULT" "skipped:recusado" || return 1
    assert_eq "$(cat skills/adr-std/extra.txt)" "original" "pasta intacta" || return 1
    assert_no_file "$PWD/skills/adr-std.bak-2026-10-27" || return 1
    assert_no_file "$PWD/skills/adr-std/$MARKER" || return 1
    assert_eq "$(state_agents)" "" "nada registrado" || return 1
  done
}

test_adopt_foreign_link_backs_up_link_not_target() {
  load_act_on_dest || return 1
  classify_skill_dir fora adr-std; printf 'alvo\n' > fora/extra.txt
  mkdir -p skills && ln -s "$PWD/fora" skills/adr-std
  printf 's\n' > answer
  ADR_STD_TODAY=2026-10-27 ADR_STD_TTY="$PWD/answer" act_on_dest claude-code foreign-adr-std "$PWD/skills/adr-std" >out.txt 2>&1; local rc=$?
  assert_eq "$rc" "0" || return 1
  assert_eq "$ACT_RESULT" "adopted-with-backup" || return 1
  [ -L "$PWD/skills/adr-std.bak-2026-10-27" ] || fail "o backup deveria ser o próprio link" || return 1
  assert_eq "$(readlink "$PWD/skills/adr-std.bak-2026-10-27")" "$PWD/fora" "link do backup intacto" || return 1
  assert_eq "$(cat fora/extra.txt)" "alvo" "alvo não tocado" || return 1
  [ ! -L "$PWD/skills/adr-std" ] || fail "o destino novo deveria ser cópia" || return 1
  assert_file "$PWD/skills/adr-std/$MARKER"
}

test_adopt_confirmed_with_link_mode() {
  load_act_on_dest || return 1
  classify_skill_dir skills/adr-std adr-std
  LINK=1; printf 's\n' > answer
  ADR_STD_TODAY=2026-10-27 ADR_STD_TTY="$PWD/answer" act_on_dest claude-code foreign-adr-std "$PWD/skills/adr-std" >/dev/null 2>&1; local rc=$?
  assert_eq "$rc" "0" || return 1
  assert_eq "$(readlink "$PWD/skills/adr-std")" "$SRC/skill" "link para a fonte" || return 1
  assert_eq "$(state_agent_mode claude-code)" "link"
}

test_adopt_backup_failure_does_not_install() {
  [ "$(id -u)" -ne 0 ] || { echo "    (pulado: root ignora permissões)"; return 0; }
  load_act_on_dest || return 1
  classify_skill_dir skills/adr-std adr-std; printf 'original\n' > skills/adr-std/extra.txt
  printf 's\n' > answer
  chmod a-w skills
  ADR_STD_TODAY=2026-10-27 ADR_STD_TTY="$PWD/answer" act_on_dest claude-code foreign-adr-std "$PWD/skills/adr-std" >/dev/null 2>&1; local rc=$?
  chmod u+w skills
  assert_eq "$rc" "4" || return 1
  assert_eq "$ACT_RESULT" "skipped:backup-falhou" || return 1
  assert_eq "$(cat skills/adr-std/extra.txt)" "original" "pasta intacta, sem instalar por cima" || return 1
  assert_no_file "$PWD/skills/adr-std/$MARKER" || return 1
  assert_eq "$(state_agents)" "" "nada registrado"
}

# --adopt e modo sem terminal (RF-06, RF-07, RF-08, SEG-01).
test_adopt_flag_parsed() {
  load_lib
  ADOPT=0; parse_args claude-code --adopt
  assert_eq "$ADOPT" "1" "--adopt liga ADOPT" || return 1
  ADOPT=0; parse_args claude-code
  assert_eq "$ADOPT" "0" "sem --adopt, ADOPT fica 0"
}

test_adopt_flag_adopts_without_asking() {
  load_act_on_dest || return 1
  classify_skill_dir skills/adr-std adr-std; printf 'original\n' > skills/adr-std/extra.txt
  ADOPT=1
  ADR_STD_TODAY=2026-10-27 ADR_STD_TTY=/nao/existe act_on_dest claude-code foreign-adr-std "$PWD/skills/adr-std" >out.txt 2>&1; local rc=$?
  assert_eq "$rc" "0" || return 1
  assert_eq "$ACT_RESULT" "adopted-with-backup" || return 1
  assert_eq "$(cat skills/adr-std.bak-2026-10-27/extra.txt)" "original" "backup com o conteúdo original" || return 1
  assert_file "$PWD/skills/adr-std/$MARKER" || return 1
  assert_eq "$(state_agent_mode claude-code)" "copy" || return 1
  if grep -qF "[s/N]" out.txt; then fail "--adopt não deveria perguntar"; return 1; fi
}

test_adopt_flag_ignores_terminal_answer() {
  load_act_on_dest || return 1
  classify_skill_dir skills/adr-std adr-std
  printf 'n\n' > answer
  ADOPT=1
  ADR_STD_TODAY=2026-10-27 ADR_STD_TTY="$PWD/answer" act_on_dest claude-code foreign-adr-std "$PWD/skills/adr-std" >/dev/null 2>&1
  assert_eq "$ACT_RESULT" "adopted-with-backup" "--adopt vale mesmo com terminal"
}

test_adopt_flag_never_touches_foreign_other() {
  load_act_on_dest || return 1
  classify_skill_dir skills/adr-std outra-skill
  ADOPT=1
  act_on_dest claude-code foreign-other "$PWD/skills/adr-std" >/dev/null 2>&1; local rc=$?
  assert_eq "$rc" "4" || return 1
  assert_eq "$ACT_RESULT" "skipped:outra-skill" || return 1
  assert_eq "$(skill_name_of "$PWD/skills/adr-std")" "outra-skill" "intacta" || return 1
  assert_eq "$(ls skills | grep -c bak)" "0" "sem backup" || return 1
  assert_eq "$(state_agents)" "" "não registra"
}

test_adopt_flag_backup_failure_does_not_install() {
  [ "$(id -u)" -ne 0 ] || { echo "    (pulado: root ignora permissões)"; return 0; }
  load_act_on_dest || return 1
  classify_skill_dir skills/adr-std adr-std; printf 'original\n' > skills/adr-std/extra.txt
  ADOPT=1; chmod a-w skills
  ADR_STD_TODAY=2026-10-27 act_on_dest claude-code foreign-adr-std "$PWD/skills/adr-std" >/dev/null 2>&1; local rc=$?
  chmod u+w skills
  assert_eq "$rc" "4" || return 1
  assert_eq "$ACT_RESULT" "skipped:backup-falhou" || return 1
  assert_eq "$(cat skills/adr-std/extra.txt)" "original" "pasta intacta" || return 1
  assert_eq "$(state_agents)" "" "nada registrado"
}

test_install_without_terminal_skips_with_adopt_hint() {
  mkdir -p "$HOME/.claude/skills/adr-std"
  printf -- '---\nname: adr-std\n---\n' > "$HOME/.claude/skills/adr-std/SKILL.md"
  local out code
  out="$(ADR_STD_TTY=/nao/existe "$CLI" install claude-code 2>&1)"; code=$?
  assert_eq "$code" "4" || return 1
  assert_contains "$out" "sem-terminal" || return 1
  assert_contains "$out" "--adopt" "dica de --adopt" || return 1
  assert_no_file "$HOME/.claude/skills/adr-std/.installed-by-adr-std" || return 1
  assert_eq "$(ls "$HOME/.claude/skills" | grep -c bak)" "0" "sem backup"
}

test_install_with_adopt_flag_end_to_end() {
  mkdir -p "$HOME/.claude/skills/adr-std" "$HOME/.codex/skills/outra"
  printf -- '---\nname: adr-std\n---\n' > "$HOME/.claude/skills/adr-std/SKILL.md"
  printf 'x\n' > "$HOME/.claude/skills/adr-std/extra.txt"
  local out code
  out="$(ADR_STD_TTY=/nao/existe ADR_STD_TODAY=2026-10-27 "$CLI" install claude-code --adopt 2>&1)"; code=$?
  assert_eq "$code" "0" "$out" || return 1
  assert_file "$HOME/.claude/skills/adr-std/.installed-by-adr-std" || return 1
  assert_eq "$(cat "$HOME/.claude/skills/adr-std.bak-2026-10-27/extra.txt")" "x" "backup" || return 1
  assert_contains "$out" "Pronto." || return 1
  grep -qE "^agent"$'\t'"claude-code"$'\t' "$(state_file)" || fail "estado sem claude-code"
}

# --dry-run por destino (RF-10): classe e ação, sem alterar arquivos nem estado e sem ler o terminal.
snapshot_home() { # árvore, conteúdo e links do HOME de teste
  ( cd "$HOME" && find . | sort && find . -type f -exec cksum {} + | sort && find . -type l -exec readlink {} + | sort )
}

dry_run_setup() { # monta as cinco classes em cinco agentes
  "$CLI" install claude-code >/dev/null 2>&1                                  # ours
  mkdir -p "$HOME/.codex/skills" && ln -s "$ROOT/skill" "$HOME/.codex/skills/adr-std"   # repo-link
  mkdir -p "$HOME/.cursor/skills/adr-std" && printf -- '---\nname: adr-std\n---\n' > "$HOME/.cursor/skills/adr-std/SKILL.md"  # foreign-adr-std
  mkdir -p "$HOME/.roo/skills/adr-std" && printf -- '---\nname: outra\n---\n' > "$HOME/.roo/skills/adr-std/SKILL.md"          # foreign-other
  mkdir -p "$HOME/.codeium/windsurf"                                           # absent
}

test_dry_run_five_classes_changes_nothing() {
  dry_run_setup
  local before after out code
  before="$(snapshot_home)"
  out="$(ADR_STD_TTY=/nao/existe "$CLI" install claude-code codex cursor roo windsurf --dry-run 2>&1)"; code=$?
  after="$(snapshot_home)"
  assert_eq "$code" "0" "$out" || return 1
  assert_eq "$after" "$before" "a simulação não pode alterar arquivos nem estado" || return 1
  assert_contains "$out" "$HOME/.claude/skills/adr-std: ours -> atualizaria" || return 1
  assert_contains "$out" "$HOME/.codex/skills/adr-std: repo-link -> registraria sem alterar" || return 1
  assert_contains "$out" "$HOME/.cursor/skills/adr-std: foreign-adr-std -> pularia" || return 1
  assert_contains "$out" "$HOME/.roo/skills/adr-std: foreign-other -> pularia" || return 1
  assert_contains "$out" "$HOME/.codeium/windsurf/skills/adr-std: absent -> instalaria" || return 1
}

test_dry_run_foreign_adr_std_adopt_and_ask() {
  dry_run_setup
  local out before after
  before="$(snapshot_home)"
  out="$(ADR_STD_TTY=/nao/existe "$CLI" install cursor --dry-run --adopt 2>&1)"
  assert_contains "$out" "foreign-adr-std -> adotaria" "com --adopt" || return 1
  # terminal disponível: perguntaria, sem ler (a FIFO tem escritor e ninguém responde; se lesse, travaria)
  local fifo="$HOME/tty.fifo"; mkfifo "$fifo"; exec 4<>"$fifo"
  out="$(ADR_STD_TTY="$fifo" timeout 10 "$CLI" install cursor --dry-run 2>&1)"; local code=$?
  exec 4>&-
  assert_eq "$code" "0" "não deve travar lendo o terminal" || return 1
  assert_contains "$out" "foreign-adr-std -> perguntaria" "com terminal" || return 1
  rm -f "$fifo"
  after="$(snapshot_home)"
  assert_eq "$after" "$before" "nada alterado"
}

test_dry_run_shared_dest_single_line() {
  mkdir -p "$HOME/.gemini" "$HOME/.config/opencode"
  local out
  out="$("$CLI" install gemini-cli opencode --dry-run 2>&1)"
  assert_eq "$(printf '%s\n' "$out" | grep -c ': absent -> instalaria')" "1" "uma linha por pasta compartilhada"
}

# backup_dest (RF-05, D-12, SEG-01): mv do próprio caminho para <pasta>.bak-<data>, sem sobrescrever.
test_backup_dest_directory() {
  load_lib
  mkdir -p skills/adr-std && printf 'conteudo\n' > skills/adr-std/SKILL.md
  local out
  out="$(ADR_STD_TODAY=2026-10-27 backup_dest "$PWD/skills/adr-std")" || fail "backup_dest falhou" || return 1
  assert_eq "$out" "$PWD/skills/adr-std.bak-2026-10-27" "imprime o caminho do backup" || return 1
  assert_no_file skills/adr-std || return 1
  assert_eq "$(cat skills/adr-std.bak-2026-10-27/SKILL.md)" "conteudo" "conteúdo idêntico ao original"
}

test_backup_dest_link_not_dereferenced() {
  load_lib
  mkdir -p alvo && printf 'x\n' > alvo/SKILL.md
  mkdir -p skills && ln -s "$PWD/alvo" skills/adr-std
  local out
  out="$(ADR_STD_TODAY=2026-10-27 backup_dest "$PWD/skills/adr-std")" || fail "backup_dest falhou" || return 1
  [ ! -e skills/adr-std ] && [ ! -L skills/adr-std ] || fail "o destino original deveria ter saído" || return 1
  [ -L "$out" ] || fail "o backup de um link deveria continuar link" || return 1
  assert_eq "$(readlink "$out")" "$PWD/alvo" "link movido aponta para o mesmo alvo" || return 1
  assert_eq "$(cat alvo/SKILL.md)" "x" "alvo intacto"
}

test_backup_dest_suffix_when_exists() {
  load_lib
  mkdir -p skills/adr-std && printf 'novo\n' > skills/adr-std/SKILL.md
  mkdir -p skills/adr-std.bak-2026-10-27 && printf 'antigo1\n' > skills/adr-std.bak-2026-10-27/SKILL.md
  local out
  out="$(ADR_STD_TODAY=2026-10-27 backup_dest "$PWD/skills/adr-std")" || fail "backup_dest falhou" || return 1
  assert_eq "$out" "$PWD/skills/adr-std.bak-2026-10-27-2" "primeiro sufixo" || return 1
  assert_eq "$(cat skills/adr-std.bak-2026-10-27/SKILL.md)" "antigo1" "backup anterior intacto" || return 1
  mkdir -p skills/adr-std && printf 'novo2\n' > skills/adr-std/SKILL.md
  out="$(ADR_STD_TODAY=2026-10-27 backup_dest "$PWD/skills/adr-std")" || fail "backup_dest falhou (2)" || return 1
  assert_eq "$out" "$PWD/skills/adr-std.bak-2026-10-27-3" "segundo sufixo" || return 1
  assert_eq "$(cat skills/adr-std.bak-2026-10-27-2/SKILL.md)" "novo" "segundo backup intacto"
}

test_backup_dest_mv_failure() {
  load_lib
  [ "$(id -u)" != "0" ] || return 0   # root ignora permissões; o caso não se aplica
  mkdir -p skills/adr-std && printf 'orig\n' > skills/adr-std/SKILL.md
  chmod a-w skills
  local rc=0 out
  out="$(ADR_STD_TODAY=2026-10-27 backup_dest "$PWD/skills/adr-std" 2>&1)" || rc=$?
  chmod u+w skills
  [ "$rc" -ne 0 ] || fail "falha de mv deveria retornar erro" || return 1
  assert_eq "$(cat skills/adr-std/SKILL.md)" "orig" "origem intacta" || return 1
  assert_eq "$(ls skills | grep -c bak)" "0" "nada pela metade"
}

test_owned_by_us_regressions() {
  load_owned_by_us || return 1
  classify_skill_dir "$PWD/copia" adr-std && : > "$PWD/copia/$MARKER"
  classify_skill_dir "$PWD/semmarca" adr-std
  ln -s "$SRC/skill" naoreg
  classify_skill_dir "$PWD/fora" adr-std && ln -s "$PWD/fora" paraforaA && ln -s "$PWD/paraforaA" paraforaB
  ln -s "$PWD/nada" quebrado
  printf 'agent\ta\t%s\nagent\tb\t%s\nagent\tc\t%s\nagent\td\t%s\n' \
    "$PWD/copia" "$PWD/semmarca" "$PWD/paraforaB" "$PWD/quebrado" > "$STATE_FILE"
  owned_by_us "$PWD/copia" || fail "cópia registrada com marcador deveria ser nossa" || return 1
  ! owned_by_us "$PWD/semmarca" || fail "cópia registrada sem marcador não é nossa" || return 1
  ! owned_by_us "$PWD/naoreg" || fail "link não registrado não é nosso" || return 1
  ! owned_by_us "$PWD/paraforaB" || fail "link registrado para fora da fonte não é nosso" || return 1
  ! owned_by_us "$PWD/quebrado" || fail "link quebrado registrado não é nosso"
}

test_classify_dest_absent() {
  load_classify_dest || return 1
  assert_eq "$(classify_dest "$PWD/destino")" "absent"
}

test_classify_dest_ours() {
  load_classify_dest || return 1
  classify_skill_dir "$PWD/copia" adr-std && : > "$PWD/copia/$MARKER"
  printf 'agent\tclaude-code\t%s\n' "$PWD/copia" > "$STATE_FILE"
  assert_eq "$(classify_dest "$PWD/copia")" "ours" "cópia registrada com marcador" || return 1
  ln -s "$SRC/skill" lnk
  printf 'agent\tclaude-code\t%s\n' "$PWD/lnk" >> "$STATE_FILE"
  assert_eq "$(classify_dest "$PWD/lnk")" "ours" "link para a fonte registrado"
}

test_classify_dest_repo_link() {
  load_classify_dest || return 1
  ln -s "$SRC/skill" direto
  assert_eq "$(classify_dest "$PWD/direto")" "repo-link" "direto" || return 1
  ln -s "$PWD/direto" meio && ln -s "$PWD/meio" encadeado
  assert_eq "$(classify_dest "$PWD/encadeado")" "repo-link" "encadeado" || return 1
  ln -s "$DATA_DIR/skill" dados
  assert_eq "$(classify_dest "$PWD/dados")" "repo-link" "para DATA_DIR/skill"
}

test_classify_dest_repo_link_symlinked_parent() {
  load_classify_dest || return 1
  mkdir -p real/src/skill && ln -s "$PWD/real" via
  SRC="$PWD/via/src"
  ln -s "$PWD/real/src/skill" fisico
  assert_eq "$(classify_dest "$PWD/fisico")" "repo-link" "SRC lógico, link físico" || return 1
  SRC="$PWD/real/src"
  ln -s "$PWD/via/src/skill" logico
  assert_eq "$(classify_dest "$PWD/logico")" "repo-link" "SRC físico, link lógico"
}

test_classify_dest_foreign_adr_std() {
  load_classify_dest || return 1
  classify_skill_dir "$PWD/copia" adr-std
  assert_eq "$(classify_dest "$PWD/copia")" "foreign-adr-std" "cópia sem registro" || return 1
  classify_skill_dir "$PWD/fora" adr-std && ln -s "$PWD/fora" ponte
  assert_eq "$(classify_dest "$PWD/ponte")" "foreign-adr-std" "link para fora da fonte"
}

test_classify_dest_foreign_other() {
  load_classify_dest || return 1
  classify_skill_dir "$PWD/outra" outra-coisa
  assert_eq "$(classify_dest "$PWD/outra")" "foreign-other" "outra skill" || return 1
  mkdir -p vazia
  assert_eq "$(classify_dest "$PWD/vazia")" "foreign-other" "sem SKILL.md" || return 1
  ln -s "$PWD/b" a && ln -s "$PWD/a" b
  assert_eq "$(classify_dest "$PWD/a")" "foreign-other" "ciclo" || return 1
  ln -s "$PWD/ausente" quebrado
  assert_eq "$(classify_dest "$PWD/quebrado")" "foreign-other" "link quebrado"
}

test_classify_dest_read_only() {
  load_classify_dest || return 1
  ln -s "$SRC/skill" direto
  classify_skill_dir "$PWD/copia" adr-std
  classify_skill_dir "$PWD/outra" outra-coisa
  printf 'agent\tclaude-code\t%s\n' "$PWD/copia" > "$STATE_FILE"
  local before after d
  snapshot() { find "$PWD" | sort; find "$PWD" -type f -exec cksum {} + | sort; find "$PWD" -type l -exec readlink {} +; }
  before="$(snapshot)"
  for d in direto copia outra ausente; do classify_dest "$PWD/$d" >/dev/null; done
  after="$(snapshot)"
  assert_eq "$after" "$before" "a árvore não pode mudar"
}

# Estado com modo por agente (D-9, RF-11): 4ª coluna da linha `agent`.
load_state_mode() {
  load_lib
  declare -F state_agent_mode >/dev/null || fail "state_agent_mode não definida em bin/adr-std" || return 1
  CONFIG_DIR="$PWD/cfg"; STATE_FILE="$CONFIG_DIR/state"
}

test_state_agent_mode_fourth_column() {
  load_state_mode || return 1
  state_add_agent claude-code "$PWD/a" link
  state_add_agent codex "$PWD/b" copy
  assert_eq "$(state_agent_mode claude-code)" "link" "modo link gravado" || return 1
  assert_eq "$(state_agent_mode codex)" "copy" "modo copy gravado" || return 1
  grep -qE '^agent'$'\t''claude-code'$'\t'"$PWD/a"$'\t''link$' "$STATE_FILE" || fail "linha sem a 4ª coluna" || return 1
  assert_eq "$(state_agents | cut -f1,2 | tr '\t' ' ' | tr '\n' ';')" "claude-code $PWD/a;codex $PWD/b;" "state_agents mantém só id e pasta" || return 1
  assert_eq "$(state_agents | awk -F'\t' '{print NF}' | sort -u)" "2" "state_agents imprime duas colunas"
}

test_state_agent_mode_old_state_falls_back_to_global() {
  load_state_mode || return 1
  mkdir -p "$CONFIG_DIR"
  printf 'version\t3.0.0\nmode\tlink\nagent\tclaude-code\t%s\n' "$PWD/a" > "$STATE_FILE"
  assert_eq "$(state_agent_mode claude-code)" "link" "3 colunas cai no mode global (link)" || return 1
  printf 'version\t3.0.0\nmode\tcopy\nagent\tclaude-code\t%s\n' "$PWD/a" > "$STATE_FILE"
  assert_eq "$(state_agent_mode claude-code)" "copy" "3 colunas cai no mode global (copy)" || return 1
  printf 'version\t3.0.0\nmode\tlink\nagent\tclaude-code\t%s\tcopy\n' "$PWD/a" > "$STATE_FILE"
  assert_eq "$(state_agent_mode claude-code)" "copy" "a coluna do agente vence o mode global"
}

test_state_agent_mode_empty_without_any() {
  load_state_mode || return 1
  assert_eq "$(state_agent_mode claude-code)" "" "sem arquivo de estado" || return 1
  mkdir -p "$CONFIG_DIR"
  printf 'version\t3.0.0\nagent\tclaude-code\t%s\n' "$PWD/a" > "$STATE_FILE"
  assert_eq "$(state_agent_mode claude-code)" "" "sem coluna e sem mode global" || return 1
  assert_eq "$(state_agent_mode outro)" "" "agente não registrado"
}

test_install_records_mode_per_agent() {
  local bin="$ROOT/bin/adr-std"
  mkdir -p "$HOME/.claude"
  "$bin" install --agent claude-code --no-commands >/dev/null 2>&1 || fail "install copy falhou" || return 1
  grep -qE '^agent'$'\t''claude-code'$'\t''[^'$'\t'']+'$'\t''copy$' "$(state_file)" || fail "install sem --link não gravou copy" || return 1
  rm -rf "$HOME/.claude/skills/adr-std"
  "$bin" uninstall --agent claude-code >/dev/null 2>&1
  "$bin" install --agent claude-code --link --no-commands >/dev/null 2>&1 || fail "install --link falhou" || return 1
  grep -qE '^agent'$'\t''claude-code'$'\t''[^'$'\t'']+'$'\t''link$' "$(state_file)" || fail "install --link não gravou link"
}

# cmd_install sem interrupção por conflito (RF-09, RF-12, D-14): o laço segue, o resumo lista os pulos e o código é 4.
test_install_all_conflict_continues() {
  mkdir -p "$HOME/.claude/skills/adr-std" "$HOME/.codex" "$HOME/.gemini"
  echo "do usuário" > "$HOME/.claude/skills/adr-std/nota.txt"
  local out code
  out="$("$CLI" install --all 2>&1)"; code=$?
  assert_eq "$code" "4" "código de saída com pulo" || return 1
  assert_file "$HOME/.codex/skills/adr-std/SKILL.md" || return 1
  assert_file "$HOME/.agents/skills/adr-std/SKILL.md" || return 1
  assert_file "$HOME/.claude/commands/adr-std-create.md" || fail "comandos /adr-std-* não foram criados" || return 1
  assert_eq "$(cat "$HOME/.claude/skills/adr-std/nota.txt")" "do usuário" || return 1
  assert_no_file "$HOME/.claude/skills/adr-std/SKILL.md" || return 1
  assert_contains "$out" "$HOME/.claude/skills/adr-std" || return 1
  assert_contains "$out" "outra-skill" || return 1
  grep -qE "^agent"$'\t'"codex"$'\t' "$(state_file)" || fail "estado sem codex" || return 1
  if grep -qE "^agent"$'\t'"claude-code"$'\t' "$(state_file)"; then fail "agente pulado foi registrado"; return 1; fi
}

test_install_all_skipped_no_pronto() {
  mkdir -p "$HOME/.claude/skills/adr-std"
  echo "x" > "$HOME/.claude/skills/adr-std/nota.txt"
  local out code
  out="$("$CLI" install claude-code 2>&1)"; code=$?
  assert_eq "$code" "4" || return 1
  if printf '%s' "$out" | grep -qF "Pronto."; then fail "não deveria dizer Pronto quando tudo foi pulado"; return 1; fi
  if grep -qE "^(version|mode|agent)"$'\t' "$(state_file)" 2>/dev/null; then fail "estado de skill gravado sem instalação"; return 1; fi
}

test_install_no_skip_exit_zero() {
  mkdir -p "$HOME/.claude"
  local out code
  out="$("$CLI" install claude-code 2>&1)"; code=$?
  assert_eq "$code" "0" || return 1
  assert_contains "$out" "Pronto." || return 1
  if printf '%s' "$out" | grep -qF "outra-skill"; then fail "resumo de pulo sem pulo"; return 1; fi
}

test_install_shared_dest_single_classification() {
  mkdir -p "$HOME/.gemini" "$HOME/.config/opencode" "$HOME/.agents/skills/adr-std"
  echo "x" > "$HOME/.agents/skills/adr-std/nota.txt"
  local out code
  out="$("$CLI" install gemini-cli opencode --no-commands 2>&1)"; code=$?
  assert_eq "$code" "4" || return 1
  local n; n=$(printf '%s\n' "$out" | grep -cF "outra-skill")
  assert_eq "$n" "1" "um resumo por pasta compartilhada" || return 1
  if grep -qE "^agent"$'\t' "$(state_file)" 2>/dev/null; then fail "agente de pasta pulada foi registrado"; return 1; fi
}

test_install_unknown_agent_still_code_2() {
  local out code
  out="$("$CLI" install --agent agente-inexistente 2>&1)"; code=$?
  assert_eq "$code" "2" || return 1
  assert_contains "$out" "agente desconhecido" || return 1
}

test_install_failure_becomes_skipped() {
  if [ "$(id -u)" -eq 0 ]; then echo "    (pulado: root ignora permissões)"; return 0; fi
  mkdir -p "$HOME/.claude" "$HOME/.codex"
  chmod a-w "$HOME/.claude"
  local out code
  out="$("$CLI" install --agent claude-code,codex --no-commands 2>&1)"; code=$?
  chmod u+w "$HOME/.claude"
  assert_eq "$code" "4" || return 1
  assert_contains "$out" "falha-na-instalacao" || return 1
  assert_no_file "$HOME/.claude/skills/adr-std" || return 1
  assert_file "$HOME/.codex/skills/adr-std/SKILL.md" || return 1
  if grep -qE "^agent"$'\t'"claude-code"$'\t' "$(state_file)"; then fail "falha registrada como instalada"; return 1; fi
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
    local name
    while IFS= read -r name; do tests+=("$name"); done < <(declare -F | awk '{print $3}' | grep '^test_' | sed 's/^test_//')
  fi
  for t in "${tests[@]}"; do run_test "$t"; done
  echo "Resultado: $PASS passaram, $FAIL falharam${FAILED:+ (${FAILED[*]})}"
  [ "$FAIL" -eq 0 ]
}

main "$@"
