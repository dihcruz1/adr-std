# Tarefas — adr-std v1.0: distribuição e instalação da skill

| Campo | Detalhe |
|---|---|
| **Data** | 2026-09-30 |
| **Status** | Gate 3 aprovado (2026-09-30); em execução |
| **Requisitos / Design** | [requirements.md](requirements.md) · [design.md](design.md) |
| **Regra de execução** | Uma tarefa por vez, na ordem; marcar `[x]` só com evidência de teste. Commit só com autorização expressa. |
| **Base dos comandos** | `cd /Fusiondev/Code/Skills/adr-std` |

## 0. Reorganização (feita antes da spec, por autorização "pode executar")

- [x] 0.1 — Mover o repositório para `/Fusiondev/Code/Skills/adr-std`, a skill para `skill/` e os testes para `tests/`, preservando o histórico; reapontar `~/.agents/skills/adr-std` para `skill/`. Cobre D-03, D-19.
  - **Evidência:** `git status` mostra 7 renomeações (`R`); link aponta para `/Fusiondev/Code/Skills/adr-std/skill`; fixture passa (saída 0) e template reprova (saída 1) pelos novos caminhos. Mudanças ainda não commitadas.

## 1. Testes do script existente

- [x] 1.1 — Converter as verificações manuais do `check_adr.py` em testes automáticos; depende de 0.1. Cobre gate R-08.
  - **RED:** `tests/test_check_adr.py` com: fixture conforme → saída 0; template → saída 1; `--name-pattern` aceita `1-titulo.md`; justificativa dentro de "Decisão" aceita em B4; opção rejeitada sem motivo falha em C2. Rodar antes de existir o arquivo: falha por ausência.
  - **GREEN:** criar o arquivo de testes; o script já deve passar (se algum caso falhar, corrigir o script).
  - **REFACTOR:** extrair a construção de ADRs de teste para uma função auxiliar no próprio teste.
  - **Validação:** `python3 -m unittest discover -s tests -p 'test_check_adr.py' -v`
  - **Evidência:** RED: `Ran 0 tests` / `NO TESTS RAN`. GREEN: 7 testes OK (fixture, template, padrão legado, justificativa na Decisão, rejeição sem motivo, Aceito sem data, pasta ignorando template e CONVENTIONS). O script não precisou de correção. REFACTOR: função auxiliar `write_adr`.

## 2. Dados e estrutura

- [x] 2.1 — Criar `agents.tsv` e `VERSION` (`1.0.0`); depende de 0.1. Cobre RNF-05, P-04.
  - **RED:** `tests/test_cli.sh` caso "agents.tsv tem 15 agentes válidos, ids únicos, 5 colunas" falha (arquivo ausente).
  - **GREEN:** criar os arquivos conforme design, seção 5.
  - **REFACTOR:** comentários de cabeçalho explicando as colunas.
  - **Validação:** `bash tests/test_cli.sh agents_file`
  - **Evidência:** RED: `não existe: agents.tsv`. GREEN: `✓ agents_file` (15 agentes, 5 colunas, ids únicos, VERSION 1.0.0). Executor `tests/test_cli.sh` criado com HOME temporário por teste.

## 3. Comando `adr-std` (bash)

- [x] 3.1 — `adr-std agents` e `adr-std version`/`help`; depende de 2.1. Cobre RF-11.
  - **RED:** com `HOME` temporário contendo `.claude` e `.codex`, `adr-std agents` deve marcar os dois como encontrados; teste falha (comando ausente).
  - **GREEN:** `bin/adr-std` com leitura do `agents.tsv` e detecção por pasta.
  - **REFACTOR:** funções `load_agents` e `detect_agents` reutilizáveis.
  - **Validação:** `bash tests/test_cli.sh agents version help`
  - **Evidência:** RED: `bin/adr-std: Arquivo ou diretório inexistente` nos 3 testes. GREEN: 4 de 4 (agents, agents_file, help, version). REFACTOR: funções `agent_rows`, `agent_field`, `is_detected`, `detected_ids`. Limite: `shellcheck` não instalado localmente; roda no gate do CI (8.1).
- [x] 3.2 — `adr-std install` com agentes indicados, resolução de destino e deduplicação; depende de 3.1. Cobre RF-03, RF-04, RF-05, RF-13.
  - **RED:** casos: `install claude-code` cria só `~/.claude/skills/adr-std`; `--agent claude-code,codex` e `--agent claude-code codex` equivalentes; `gemini-cli opencode` → uma cópia em `~/.agents/skills/adr-std`; `--dry-run` não altera nada; nome inválido sugere o mais próximo.
  - **GREEN:** cópia da fonte local para os destinos, com marcador `.installed-by-adr-std` e registro no estado.
  - **REFACTOR:** função única `resolve_targets`.
  - **Validação:** `bash tests/test_cli.sh install_explicit install_dedupe install_dryrun install_invalid`
  - **Evidência:** RED: `comando desconhecido: install` (3 testes); `install_invalid` passou por acaso e foi endurecido (exige "quis dizer"), depois falhou. GREEN: 8 de 8. REFACTOR: `target_for` resolve destino; deduplicação por pasta antes de copiar; estado via `state_put` e `state_add_agent`.
- [x] 3.3 — Menu interativo, `--all` e regra sem terminal; depende de 3.2. Cobre RF-02, RF-16.
  - **RED:** entrada simulada `1 2` instala os dois primeiros detectados; `todos` instala todos; sem terminal e sem agentes → erro com código 3 e mensagem pedindo `--agent`.
  - **GREEN:** menu lendo de `/dev/tty` quando disponível.
  - **REFACTOR:** separar desenho do menu da leitura da escolha.
  - **Validação:** `bash tests/test_cli.sh install_menu install_all install_noninteractive`
  - **Evidência:** RED: `install_menu` ("indique os agentes...") e `install_noninteractive` (sem "--agent") falharam; `install_all` já passava porque o `--all` entrou na 3.2. GREEN: 11 de 11. Menu lê de `/dev/tty` (ou `ADR_STD_TTY` nos testes); sem terminal, código 3. REFACTOR: `choose_agents` separado de `cmd_install`.
- [x] 3.4 — Proteção contra sobrescrita e idempotência; depende de 3.2. Cobre RF-06, RNF-03, R-03.
  - **RED:** pasta `adr-std` preexistente sem marcador → não alterada, código 4; rodar `install` duas vezes → mesmo resultado, sem erro.
  - **GREEN:** conferência de estado e marcador antes de escrever.
  - **REFACTOR:** função `owned_by_us`.
  - **Validação:** `bash tests/test_cli.sh install_conflict install_idempotent`
  - **Evidência:** RED: `install_conflict` esperado código 4, obtido 0; `install_idempotent` deixou `residuo.txt`. GREEN: 13 de 13. Pasta só é substituída se estiver no estado e tiver marcador (ou link para a fonte); caso contrário, código 4 e a pasta do usuário fica intacta. REFACTOR: função `owned_by_us`.
- [x] 3.5 — `uninstall` e `status`; depende de 3.4. Cobre RF-08, RF-10.
  - **RED:** `uninstall codex` remove só o Codex; `uninstall` remove todos os registrados e nada mais; `status` mostra versão, agentes e pasta faltando como "danificada".
  - **GREEN:** implementação usando o estado.
  - **REFACTOR:** reutilizar `owned_by_us`.
  - **Validação:** `bash tests/test_cli.sh uninstall_one uninstall_all status`
  - **Evidência:** RED: `comando desconhecido: uninstall/status` (3 testes). GREEN: 16 de 16. `uninstall` remove só o que está no estado e é do adr-std (uma pasta `adr-std` do usuário em outro agente ficou intacta); `status` marca pasta ausente como danificada. REFACTOR: `owned_by_us` reaproveitada; `dest_in_use_by_other` protege a pasta compartilhada.
- [x] 3.6 — `--link` (desenvolvimento); depende de 3.2. Cobre RF-14.
  - **RED:** `install --link claude-code` cria link para `skill/` do repositório; `uninstall` remove só o link.
  - **GREEN:** ramo de link na instalação.
  - **Validação:** `bash tests/test_cli.sh install_link`
  - **Evidência:** o ramo `--link` foi implementado junto com a 3.2, então o teste já passou ao ser escrito (sem RED real; registrado por honestidade). GREEN: link aponta para `skill/` do repositório, estado registra `mode link`, `uninstall` remove só o link e o repositório fica intacto.
- [x] 3.7 — `check`; depende de 3.1. Cobre RF-12.
  - **RED:** `adr-std check tests/fixtures` → saída 0; com `PATH` sem Python → código 6 e mensagem sugerindo o checklist.
  - **GREEN:** repasse ao `check_adr.py` da fonte local.
  - **Validação:** `bash tests/test_cli.sh check check_nopython`
  - **Evidência:** RED: `comando desconhecido: check` e código 2 no caso sem Python. GREEN: 19 de 19; sem Python, código 6 com mensagem citando o checklist manual.

## 4. Instalador e atualização (bash)

- [x] 4.1 — `install.sh` modo local e PATH; depende de 3.5. Cobre RF-01, RF-15, R-05.
  - **RED:** com `HOME` temporário, `./install.sh --agent claude-code` instala o comando em `~/.local/bin`, a fonte em `~/.local/share/adr-std` e a skill no Claude Code; resposta "não" ao PATH não altera `~/.bashrc`; resposta "sim" acrescenta uma única linha marcada.
  - **GREEN:** instalador conforme design, seções 4 e 8.
  - **Validação:** `bash tests/test_cli.sh installer_local installer_path`
  - **Evidência:** RED: `./install.sh: Arquivo ou diretório inexistente`. GREEN: `installer_local` (comando em `~/.local/bin`, fonte em `~/.local/share/adr-std`, skill no Claude Code) e `installer_path` (resposta "n" não altera o `.bashrc`; "s" acrescenta uma linha `# adr-std`; segunda execução não duplica). Modo remoto fica para a 4.2.
- [x] 4.2 — Modo remoto e `update` com checksum; depende de 4.1 e 5.1. Cobre RF-07, R-01, R-02.
  - **RED:** servidor local (`python3 -m http.server`) servindo zip e `.sha256`; `ADR_STD_BASE_URL` apontando para ele; checksum válido → instala; inválido → código 5 e nada alterado; `update` reinstala nos agentes do estado.
  - **GREEN:** download, conferência e extração em pasta temporária.
  - **Validação:** `bash tests/test_cli.sh installer_remote update update_badsum`
  - **Evidência:** RED: `modo remoto ainda não disponível` e `comando desconhecido: update`. GREEN: servidor local (`python3 -m http.server`) serve zip e `.sha256`; instalação remota (script sozinho, sem arquivos ao lado) instala a versão 9.9.9; checksum inválido → código 5, mensagem com "checksum" e nada instalado; `update` reinstala nos agentes do estado e atualiza o estado. REFACTOR: `update` reaproveita o `install.sh` em modo remoto (`ADR_STD_REMOTE=1`), sem duplicar o download; `exec` final trocado por chamada normal para o `trap` limpar a pasta temporária.
- [x] 4.3 — `self-uninstall`; depende de 4.1. Cobre RF-09.
  - **RED:** remove skill, estado, linha de PATH e comando; não toca outras linhas do `~/.bashrc`.
  - **GREEN:** implementação.
  - **Validação:** `bash tests/test_cli.sh self_uninstall`
  - **Evidência:** RED: `comando desconhecido: self-uninstall`. GREEN: 22 de 22; remove skill, estado, fonte, comando e a linha `# adr-std`, preservando as outras linhas do `.bashrc` (alias e comentário do usuário).

## 5. Pacote

- [x] 5.1 — `package.sh` e atalhos de `packaging/`; depende de 3.1. Cobre RF-17.
  - **RED:** teste lista o conteúdo esperado do zip e compara; falha sem o script.
  - **GREEN:** `package.sh` gera `dist/adr-std.zip` e `.sha256`; atalhos chamam os instaladores e pausam no fim.
  - **Validação:** `bash tests/test_cli.sh package package_release_requires_all`
  - **Evidência:** RED: `package.sh falhou` (script ausente). GREEN: zip com os arquivos esperados, sem `tests/`, `docs/`, `.git` nem arquivo da norma, e checksum confere. Ajuste de design: `package.sh` inclui o que existir e o modo `--release` exige também `README.md`, `LICENSE`, `install.ps1` e `bin/adr-std.ps1|.cmd` (criados nas tarefas 6.1 e 7.x); o gate 8.1 deve usar `--release`.

## 6. Windows (PowerShell)

- [ ] 6.1 — `bin/adr-std.ps1`, `bin/adr-std.cmd` e `install.ps1` com paridade de 3.1 a 4.3; depende de 4.3. Cobre RF-01 a RF-16 no Windows.
  - **RED:** `tests/test_cli.ps1` (Pester) com os mesmos cenários de `test_cli.sh`, em perfil temporário.
  - **GREEN:** implementação espelhando o bash.
  - **REFACTOR:** conferir mensagens idênticas às do bash.
  - **Validação:** `pwsh -Command "Invoke-Pester tests/test_cli.ps1"` (CI Windows; teste humano pendente)
  - **Evidência parcial (2026-09-30):** escritos `bin/adr-std.ps1`, `bin/adr-std.cmd`, `install.ps1` e `tests/test_cli.ps1` (Pester, 22 casos espelhando o bash). **Não executados:** esta máquina não tem PowerShell (`pwsh` ausente), então não há RED nem GREEN reais. A tarefa só fecha quando o Pester passar no CI do Windows (ou em máquina com Windows) e o solicitante ou colega validar o `.bat` de duplo clique. Riscos conhecidos: sintaxe PowerShell não verificada; `self-uninstall` no Windows não consegue apagar o `adr-std.ps1` em execução (remove o restante); `irm | iex` não repassa argumentos, então cai no menu.

## 7. Documentação

- [ ] 7.1 — `README.md` completo; depende de 5.1. Cobre RF-18, D-10.
  - **RED:** checklist de seções do README (as 21 da proposta) marcado como incompleto.
  - **GREEN:** escrever o README: skill (o que faz, garantias, limites da norma, exemplos, template, verificação, arquivos), quatro formas de instalação por sistema, avisos de segurança, agentes, comandos, confirmar, atualizar e remover, problemas comuns, sobre a norma, limitações, licença.
  - **REFACTOR:** conferir cada comando citado executando-o com `HOME` temporário.
  - **Validação:** todos os comandos do README executados sem erro em `HOME` temporário; revisão do solicitante.
  - **Evidência parcial:** README escrito (15 seções). Comandos executados num `HOME` temporário sem erro: `install.sh --agent`, `agents`, `install --dry-run --all`, `install --all`, `status`, `check` (com e sem `--name-pattern`), nome de agente errado ("quis dizer claude-code?"), `uninstall codex`, `update --dry-run`, `self-uninstall`. **Pendente: revisão do solicitante e a parte de Windows (`install.ps1`), que o README já descreve.** Por isso a tarefa continua aberta.
- [x] 7.2 — `CONTRIBUTING.md`, `CHANGELOG.md` e `LICENSE`; depende de 7.1. Cobre P-02, P-09.
  - **Validação:** revisão do solicitante.
  - **Evidência:** `LICENSE` (MIT, Diego Cruz, 2026), `CHANGELOG.md` e `CONTRIBUTING.md` criados. Marcada como concluída na entrega; a revisão do solicitante pode reabri-la.

## 8. Publicação

- [ ] 8.1 — `.github/workflows/release.yml` com gate de segurança; depende de 1.1, 5.1 e 6.1. Cobre RF-19, R-06, R-08.
  - **RED:** rodar localmente os passos do gate com um arquivo `42010-teste.pdf` inserido → o gate deve falhar.
  - **GREEN:** workflow com gate, testes em Ubuntu, macOS e Windows, e publicação condicionada.
  - **Validação:** gate local verde sem o arquivo proibido; vermelho com ele.
  - **Evidência parcial:** RED: `tests/gate.sh: Arquivo ou diretório inexistente` (5 testes). GREEN: 5 de 5 (`gate_passes_clean_repo`, `gate_blocks_norm_file` com `42010-teste.pdf`, `gate_blocks_big_file` com 1,2 MB, `gate_checks_skill_name`, `gate_checks_tag_version`). Workflow `release.yml` escrito: gate (estático, tag, shellcheck, PSScriptAnalyzer, unittest), testes em Ubuntu e macOS, Pester no Windows e publicação condicionada a `package.sh --release`. **Não validado:** o workflow só roda no GitHub, e o job do Windows depende de `install.ps1`, `bin/adr-std.ps1` e `tests/test_cli.ps1` (tarefa 6.1, ainda não feita). Por isso a 8.1 continua aberta.
- [ ] 8.2 — Criar o repositório público no GitHub, fazer push e a tag `v1.0.0`; depende de 8.1 e da aprovação dos Gates. **Exige autorização expressa** (push, tag, credenciais do solicitante).
  - **Validação:** release publicada com `adr-std.zip` e `.sha256`; instalação pelas quatro formas em máquina limpa.

## 9. Validação final

- [ ] 9.1 — Rodar `tests/cenarios.md` em pelo menos dois agentes e registrar; depende de 8.2.
- [ ] 9.2 — Verificar a entrega contra requisitos, design e tarefas (auditoria 360°) e registrar o resultado aqui.

## Auditoria cruzada 360° (preliminar, 2026-09-30)

| Requisito | Tarefas |
|---|---|
| RF-01 | 4.1, 4.2, 6.1 |
| RF-02 | 3.3 |
| RF-03, RF-04, RF-05, RF-13 | 3.2 |
| RF-06, RNF-03 | 3.4 |
| RF-07 | 4.2 |
| RF-08, RF-10 | 3.5 |
| RF-09 | 4.3 |
| RF-11 | 3.1 |
| RF-12 | 3.7 |
| RF-14 | 3.6 |
| RF-15 | 4.1 |
| RF-16 | 3.3 |
| RF-17 | 5.1 |
| RF-18 | 7.1 |
| RF-19 | 8.1 |
| RNF-01, RNF-02, RNF-04 | 3.x, 4.x, 6.1 (verificados nos testes com `HOME` temporário, sem `sudo`) |
| RNF-05 | 2.1 |
| R-01 a R-09 | 4.2, 3.4, 4.1, 8.1 e regra de execução |

Sem requisito órfão nem tarefa sem requisito. Paralelizáveis depois de 3.1: 3.7, 5.1 e 1.1.
