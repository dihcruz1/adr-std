#!/usr/bin/env bash
# Atalho de instalação (Linux). Uso: bash instalar-linux.sh
cd "$(dirname "$0")" || exit 1
bash ./install.sh "$@"
status=$?
echo
read -r -p "Pressione Enter para fechar..." _ < /dev/tty 2>/dev/null || true
exit $status
