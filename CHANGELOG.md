# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/); versões seguem o
[Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

### Adicionado
- Skill `adr-std`: guia da ISO/IEC/IEEE 42010:2022, template MADR estendido, checklist e `check_adr.py`.
- Comando `adr-std` (bash): `install`, `update`, `uninstall`, `self-uninstall`, `status`, `agents`, `check`,
  `version` e `help`.
- Instalador `install.sh` (modo local e remoto, com conferência de checksum) e pacote zip com atalhos de duplo clique.
- Lista de 15 agentes em `agents.tsv`.
- Testes automáticos do script (`tests/test_check_adr.py`) e do comando (`tests/test_cli.sh`).

### Pendente para a 1.0.0
- Instalador e comando para Windows (PowerShell) e sua validação em Windows.
- Workflow de publicação com gate de segurança.
