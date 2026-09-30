#!/usr/bin/env bash
# Gera dist/adr-std.zip e dist/adr-std.zip.sha256.
# Uso: ./package.sh [--release] [pasta-de-saída]
#   --release  exige todos os arquivos do pacote (usado na publicação)

set -eu
cd "$(dirname "${BASH_SOURCE[0]}")"

release=0
[ "${1:-}" = "--release" ] && { release=1; shift; }
out="${1:-dist}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"

required=(VERSION agents.tsv install.sh bin/adr-std skill/SKILL.md skill/scripts/check_adr.py
          packaging/instalar-windows.bat packaging/instalar-mac.command packaging/instalar-linux.sh
          packaging/desinstalar-windows.bat packaging/desinstalar-mac.command packaging/desinstalar-linux.sh)
release_only=(README.md LICENSE install.ps1 bin/adr-std.ps1 bin/adr-std.cmd)

missing=()
for f in "${required[@]}"; do [ -e "$f" ] || missing+=("$f"); done
[ ${#missing[@]} -eq 0 ] || { echo "package.sh: arquivos faltando: ${missing[*]}" >&2; exit 1; }
if [ "$release" -eq 1 ]; then
  for f in "${release_only[@]}"; do [ -e "$f" ] || missing+=("$f"); done
  [ ${#missing[@]} -eq 0 ] || { echo "package.sh --release: arquivos faltando: ${missing[*]}" >&2; exit 1; }
fi

if find . -path ./.git -prune -o -type f \( -iname '*42010*.pdf' -o -iname '*42010*.docx' \) -print | grep -q .; then
  echo "package.sh: arquivo da norma encontrado; remova antes de empacotar" >&2; exit 1
fi

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/bin"
for f in VERSION agents.tsv install.sh; do cp "$f" "$stage/"; done
for f in README.md LICENSE install.ps1; do [ -e "$f" ] && cp "$f" "$stage/"; done
cp bin/adr-std "$stage/bin/"
for f in bin/adr-std.ps1 bin/adr-std.cmd; do [ -e "$f" ] && cp "$f" "$stage/bin/"; done
cp -R skill "$stage/skill"
cp packaging/* "$stage/"
find "$stage" -name __pycache__ -prune -exec rm -rf {} +
chmod +x "$stage"/*.sh "$stage"/*.command "$stage/bin/adr-std"

rm -f "$out/adr-std.zip" "$out/adr-std.zip.sha256"
( cd "$stage" && zip -qr "$out/adr-std.zip" . )
( cd "$out" && sha256sum adr-std.zip > adr-std.zip.sha256 )
echo "Gerado: $out/adr-std.zip ($(cat VERSION))"
