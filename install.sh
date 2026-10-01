#!/usr/bin/env bash
# Instalador do adr-std (Linux e macOS).
#
# Instala o comando "adr-std" no seu usuário e depois executa "adr-std install".
# Não usa sudo e só escreve dentro da sua pasta pessoal.
#
# Uso:
#   ./install.sh [opções do adr-std install]      # ex.: ./install.sh --agent claude-code codex
#   curl -fsSL <url>/install.sh | bash -s -- --agent claude-code

set -u

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/adr-std"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/adr-std"
STATE_FILE="$CONFIG_DIR/state"
BIN_DIR="$HOME/.local/bin"
PATH_MARK="# adr-std"

err() { echo "adr-std: $*" >&2; }

here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"

# --- origem dos arquivos ------------------------------------------------------
# Modo local: arquivos ao lado do instalador (git clone ou zip).
# Modo remoto: baixa a release do GitHub, confere o checksum e usa o pacote baixado.
# ADR_STD_REMOTE=1 força o modo remoto (usado pelo "adr-std update").

BASE_URL="${ADR_STD_BASE_URL:-https://github.com/dihcruz1/adr-std}"

fetch() { # url destino
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then wget -q "$1" -O "$2"
  else err "preciso de curl ou wget para baixar o pacote"; return 1
  fi
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else err "preciso de sha256sum ou shasum para conferir o pacote"; return 1
  fi
}

unzip_to() { # zip pasta
  if command -v unzip >/dev/null 2>&1; then unzip -q "$1" -d "$2"
  elif command -v python3 >/dev/null 2>&1; then python3 -m zipfile -e "$1" "$2"
  else err "preciso de unzip ou python3 para extrair o pacote"; return 1
  fi
}

download_release() { # versão(opcional) → define SRC
  local ver="$1" url tmp expected actual
  if [ -n "$ver" ]; then url="$BASE_URL/releases/download/$ver"; else url="$BASE_URL/releases/latest/download"; fi
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  echo "Baixando ${ver:-a última versão} de $BASE_URL ..."
  fetch "$url/adr-std.zip" "$tmp/adr-std.zip" || { err "não consegui baixar o pacote"; exit 5; }
  fetch "$url/adr-std.zip.sha256" "$tmp/adr-std.zip.sha256" || { err "não consegui baixar o arquivo de checksum"; exit 5; }
  expected="$(cut -d' ' -f1 "$tmp/adr-std.zip.sha256")"
  actual="$(sha256_of "$tmp/adr-std.zip")" || exit 5
  if [ "$expected" != "$actual" ]; then
    err "o checksum do pacote não confere; nada foi instalado."
    exit 5
  fi
  unzip_to "$tmp/adr-std.zip" "$tmp/pkg" || exit 5
  SRC="$tmp/pkg"
}

# --version é do instalador (versão da release); os demais argumentos vão para "adr-std install".
REQ_VERSION=""
ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --version) REQ_VERSION="${2:-}"; shift; [ $# -gt 0 ] && shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

if [ "${ADR_STD_REMOTE:-0}" != "1" ] && [ -z "$REQ_VERSION" ] && [ -f "$here/skill/SKILL.md" ] && [ -f "$here/bin/adr-std" ]; then
  SRC="$here"
else
  download_release "$REQ_VERSION"
  [ -f "$SRC/skill/SKILL.md" ] || { err "pacote inválido: skill/SKILL.md não encontrado"; exit 5; }
fi

# --- cópia da fonte e do comando ----------------------------------------------

mkdir -p "$DATA_DIR" "$BIN_DIR" "$CONFIG_DIR"
rm -rf "${DATA_DIR:?}/skill" "${DATA_DIR:?}/bin"
cp -R "$SRC/skill" "$DATA_DIR/skill"
cp -R "$SRC/bin" "$DATA_DIR/bin"
cp "$SRC/agents.tsv" "$SRC/VERSION" "$SRC/install.sh" "$DATA_DIR/"
[ -f "$SRC/README.md" ] && cp "$SRC/README.md" "$DATA_DIR/README.md"
chmod +x "$DATA_DIR/bin/adr-std"
cp "$DATA_DIR/bin/adr-std" "$BIN_DIR/adr-std"
chmod +x "$BIN_DIR/adr-std"
echo "  ✔ comando adr-std $(cat "$DATA_DIR/VERSION") → $BIN_DIR/adr-std"

# --- PATH ---------------------------------------------------------------------

profile_for_shell() {
  case "$(basename "${SHELL:-bash}")" in
    zsh)  echo "$HOME/.zshrc" ;;
    fish) echo "$HOME/.config/fish/config.fish" ;;
    *)    echo "$HOME/.bashrc" ;;
  esac
}

ask() { # pergunta → 0 se "s"
  local tty="${ADR_STD_TTY:-/dev/tty}" reply=""
  if { exec 4<"$tty"; } 2>/dev/null; then
    printf '%s [s/N]: ' "$1"
    IFS= read -r reply <&4 || reply=""
    exec 4<&-
    echo
  fi
  case "$reply" in s|S|sim|Sim|y|Y) return 0 ;; *) return 1 ;; esac
}

state_put_line() { # arquivo-de-estado: registra path_line
  { [ -f "$STATE_FILE" ] && awk -F'\t' '$1 != "path_line"' "$STATE_FILE"; printf 'path_line\t%s\n' "$1"; } > "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    profile="$(profile_for_shell)"
    if [ -f "$profile" ] && grep -qF "$PATH_MARK" "$profile"; then
      : # já configurado
    else
      echo "A pasta $BIN_DIR não está no PATH; sem isso o comando adr-std não será encontrado."
      if ask "Posso acrescentar uma linha ao $profile?"; then
        mkdir -p "$(dirname "$profile")"
        if [ "$(basename "$profile")" = "config.fish" ]; then
          printf 'fish_add_path %s  %s\n' "$BIN_DIR" "$PATH_MARK" >> "$profile"
        else
          # shellcheck disable=SC2016 # $PATH deve ficar literal: expande quando o perfil for lido, não agora
          printf 'export PATH="%s:$PATH"  %s\n' "$BIN_DIR" "$PATH_MARK" >> "$profile"
        fi
        state_put_line "$profile"
        echo "  ✔ linha acrescentada ao $profile (abra um novo terminal para valer)"
      else
        echo "  Sem problema. Para usar depois, acrescente ao seu shell:"
        echo "    export PATH=\"$BIN_DIR:\$PATH\""
      fi
    fi ;;
esac

# --- instala a skill nos agentes ----------------------------------------------

"$BIN_DIR/adr-std" install "$@"
exit $?
