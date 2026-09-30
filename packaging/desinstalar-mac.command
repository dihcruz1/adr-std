#!/usr/bin/env bash
# Atalho de desinstalação (Linux). Uso: bash desinstalar-linux.sh
cd "$(dirname "$0")" || exit 1
if command -v adr-std >/dev/null 2>&1; then adr-std self-uninstall; else "$HOME/.local/bin/adr-std" self-uninstall; fi
status=$?
echo
read -r -p "Pressione Enter para fechar..." _ < /dev/tty 2>/dev/null || true
exit $status
