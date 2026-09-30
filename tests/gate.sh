#!/usr/bin/env bash
# Gate de segurança da publicação (RF-19, R-06, R-08).
# Uso: bash tests/gate.sh static          # verificações estáticas do repositório
#      bash tests/gate.sh tag vX.Y.Z      # a tag deve ser igual a VERSION
# Sai com código diferente de zero se qualquer verificação falhar.

set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.."

fail=0
bad() { echo "GATE FALHOU: $*" >&2; fail=1; }

gate_static() {
  # 1. SKILL.md: frontmatter com name igual a adr-std e description preenchida
  local skill="skill/SKILL.md"
  [ -f "$skill" ] || { bad "skill/SKILL.md não encontrado"; return; }
  local fm name desc
  fm="$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1 { print }' "$skill")"
  name="$(printf '%s\n' "$fm" | sed -n 's/^name:[[:space:]]*//p' | head -1)"
  desc="$(printf '%s\n' "$fm" | sed -n 's/^description:[[:space:]]*//p' | head -1)"
  [ "$name" = "adr-std" ] || bad "o campo name do SKILL.md deve ser 'adr-std' (encontrado: '${name:-vazio}')"
  [ -n "$desc" ] || bad "o campo description do SKILL.md está vazio"

  # 2. VERSION no formato X.Y.Z
  grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$' VERSION 2>/dev/null || bad "VERSION fora do formato X.Y.Z"

  # 3. Arquivos da norma não podem entrar no repositório (R-06)
  local f
  while IFS= read -r f; do
    bad "arquivo da norma ISO/IEC/IEEE 42010 encontrado: $f"
  done < <(find . -path ./.git -prune -o -type f \( -iname '*42010*.pdf' -o -iname '*42010*.docx' -o -iname '*42010*.epub' -o -iname 'ISO-IEC-IEEE-42010*' \) -print)

  # 4. Nenhum arquivo acima de 1 MB (a norma completa em texto passaria disso)
  while IFS= read -r f; do
    bad "arquivo acima de 1 MB: $f"
  done < <(find . -path ./.git -prune -o -type f -size +1048576c -print)
}

gate_tag() {
  local tag="${1:-}" want
  [ -n "$tag" ] || { bad "informe a tag (ex.: v1.0.0)"; return; }
  want="v$(cat VERSION 2>/dev/null)"
  [ "$tag" = "$want" ] || bad "a tag $tag não corresponde a VERSION ($want)"
}

case "${1:-}" in
  static) gate_static ;;
  tag)    gate_tag "${2:-}" ;;
  *)      echo "uso: bash tests/gate.sh static | tag vX.Y.Z" >&2; exit 2 ;;
esac

[ "$fail" -eq 0 ] && echo "Gate ${1}: ok"
exit "$fail"
