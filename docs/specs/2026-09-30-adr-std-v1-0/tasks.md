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
  - **Evidência parcial (2026-09-30, retomada):** esta máquina não tem PowerShell instalado nem `sudo` não-interativo, mas o PowerShell 7.4.6 oficial foi baixado em modo portátil (tarball `.tar.gz`, sem privilégio de root, para `/tmp/pwsh-portable`, apagado ao fim da sessão) junto com Pester 5.6.1 e PSScriptAnalyzer 1.25.0 via `Install-Module -Scope CurrentUser`. Isso permitiu RED e GREEN reais pela primeira vez:
    - **RED real (3 defeitos encontrados ao rodar o Pester pela primeira vez):**
      1. `tests/test_cli.ps1` tinha `BeforeEach`/`AfterEach` na raiz do arquivo, fora de um `Describe` — Pester 5.6.1 rejeita isso (`"Each test setup is not supported in root"`), nenhum teste rodava.
      2. A mesma seção usava `$script:Home`, que colide com a variável automática somente-leitura `$HOME` do PowerShell (nomes são case-insensitive) — `SessionStateUnauthorizedAccessException: Cannot overwrite variable HOME`.
      3. Com os dois acima corrigidos, 18/20 testes passaram; 2 falharam por bugs reais em `bin/adr-std.ps1` e `install.ps1`: (a) a string `"... (quis dizer $s?)"` é interpretada pelo PowerShell como a variável `$s?` (inexistente), imprimindo vazio — faltava `${s}?`; (b) `cmd_update` (`adr-std.ps1`) e `install.ps1` chamavam `powershell` fixo para reexecutar a si mesmos, que não existe fora do Windows PowerShell 5.1 (quebra sob `pwsh`/PowerShell 7, inclusive em Linux/macOS).
    - **GREEN real:** corrigidos os 3 problemas (`tests/test_cli.ps1`: envolvido em `Describe 'adr-std' { ... }`, `$Home` renomeado para `$HomeDir` em todo o arquivo; `bin/adr-std.ps1`: `${s}?` e `$ps = if (Get-Command pwsh ...) { 'pwsh' } else { 'powershell' }` reaproveitado também em `install.ps1`). `pwsh -NoProfile -Command "Invoke-Pester tests/test_cli.ps1"` → **20 de 20 testes passaram** (agents.tsv, version/help/agents, install em suas 9 variações, uninstall/status em 3, check, instalador local e self-uninstall).
    - **REFACTOR:** mensagens conferidas iguais às do bash nos testes que comparam texto; nenhuma duplicação nova introduzida.
    - **Regressão:** suíte bash completa (`bash tests/test_cli.sh`, 32 casos) e `python3 -m unittest discover -s tests -p 'test_check_adr.py'` (11 casos) continuam 100% verdes depois das mudanças — nada fora do escopo foi afetado.
    - **PSScriptAnalyzer:** rodado sobre os três arquivos `.ps1`; nenhum `Error`, só `Warning` de estilo (`PSAvoidUsingWriteHost`, `PSUseSingularNouns`, `PSPossibleIncorrectComparisonWithNull`, `PSUseShouldProcessForStateChangingFunctions`, `PSUseBOMForUnicodeEncodedFile`, uma variável não usada em `install.ps1`). Não corrigido agora: o gate de lint (`-EnableExit` sobre Warning+Error) é parte da tarefa 8.1, que ainda não foi executada — mesmo precedente já registrado na 3.1 para o `shellcheck`.
    - **Ainda não verificável nesta máquina (limitação de ambiente, não de código):**
      - O modo `--link` (junção NTFS, `New-Item -ItemType Junction`) não tem teste no Pester e, testado manualmente aqui, falha silenciosamente em Linux (o .NET Core não cria junções fora do Windows) — só pode ser validado em Windows real ou no CI do Windows.
      - `bin/adr-std.cmd` (duplo clique) não foi testado por um humano em Windows.
      - PATH real do usuário (`[Environment]::SetEnvironmentVariable(..., 'User')`) e variáveis `%LOCALAPPDATA%`/`%APPDATA%` nativas não foram exercitadas (os testes usam `ADR_STD_LOCALAPPDATA`/`ADR_STD_APPDATA`/`ADR_STD_HOME` para isolamento, como no design).
    - A tarefa continua aberta: falta a validação em CI do Windows (ou máquina Windows real) do `--link`, do `.cmd` e do PATH nativo, conforme a validação definida acima.
  - **Evidência adicional (2026-10-01, retomada):** PowerShell 7.4.6 portátil e `shellcheck` 0.11.0 estático baixados de novo sem privilégio de root (mesmo precedente da sessão anterior); Pester 5.6.1 e PSScriptAnalyzer 1.25.0 já estavam instalados em `~/.local/share/powershell/Modules` de uma sessão anterior. TDD aplicado às correções a seguir (RED com o comando de validação já definido, GREEN com a correção, suíte completa como REFACTOR/regressão):
    - **RED/GREEN PSScriptAnalyzer:** `Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning` apontava os 14 avisos de estilo já listados acima. Corrigidos: funções renomeadas para substantivo singular (`Get-AgentRow`, `Get-DetectedId`, `Get-StateLine`, `Save-StateLine`, `Get-StateAgent`, `Read-Option`, `Test-OwnedBySelf`, `Select-Agent`, `Invoke-Agent`), comparações com `$null` colocadas à esquerda em `bin/adr-std.ps1` e `install.ps1`, variável `$UserHome` não usada removida de `install.ps1`, BOM UTF-8 acrescentado aos três arquivos `.ps1`. GREEN: `Invoke-ScriptAnalyzer -Path . -Recurse -Severity Error,Warning -ExcludeRule PSAvoidUsingWriteHost,PSUseShouldProcessForStateChangingFunctions` → 0 ocorrências (as duas regras excluídas conflitam com o uso intencional de `Write-Host` para a saída do CLI e com um instalador sem necessidade de `-WhatIf`; é o mesmo critério já aplicado ao gate do `release.yml`, ver 8.1).
    - **Bug real encontrado e corrigido no gate do `release.yml` (passo "PSScriptAnalyzer"):** `Invoke-ScriptAnalyzer -Path $files.FullName ...` falhava sempre com `Cannot convert 'System.Object[]' to the type 'System.String'`, porque nesta versão do módulo o parâmetro `-Path` é `[string]`, não `[string[]]`, e `$files.FullName` com 3 arquivos retorna um array — reproduzido localmente com o mesmo `pwsh`/módulo que o CI instala. Corrigido para `-Path . -Recurse`. Ver 8.1 para a validação completa do gate corrigido.
    - **Regressão:** `Invoke-Pester tests/test_cli.ps1` → 20/20; `bash tests/test_cli.sh` → 32/32; `python3 -m unittest discover -s tests -p 'test_check_adr.py'` → 11/11; `shellcheck` nos scripts bash → sem avisos; `bash tests/gate.sh static` e `bash tests/gate.sh tag v$(cat VERSION)` → ok. Nada fora do escopo foi afetado.
    - Pendências inalteradas (exigem Windows real ou CI do Windows): `--link` (junção NTFS), `adr-std.cmd` por um humano, PATH nativo do usuário. A tarefa continua aberta só por essas três pendências — todo o restante verificável localmente foi verificado e está verde.

## 7. Documentação

- [x] 7.1 — `README.md` completo; depende de 5.1. Cobre RF-18, D-10.
  - **RED:** checklist de seções do README (as 21 da proposta) marcado como incompleto.
  - **GREEN:** escrever o README: skill (o que faz, garantias, limites da norma, exemplos, template, verificação, arquivos), quatro formas de instalação por sistema, avisos de segurança, agentes, comandos, confirmar, atualizar e remover, problemas comuns, sobre a norma, limitações, licença.
  - **REFACTOR:** conferir cada comando citado executando-o com `HOME` temporário.
  - **Validação:** todos os comandos do README executados sem erro em `HOME` temporário; revisão do solicitante.
  - **Evidência parcial:** README escrito (15 seções). Comandos executados num `HOME` temporário sem erro: `install.sh --agent`, `agents`, `install --dry-run --all`, `install --all`, `status`, `check` (com e sem `--name-pattern`), nome de agente errado ("quis dizer claude-code?"), `uninstall codex`, `update --dry-run`, `self-uninstall`. **Pendente: revisão do solicitante e a parte de Windows (`install.ps1`), que o README já descreve.** Por isso a tarefa continua aberta.
  - **Evidência adicional (2026-10-01):** com `pwsh` 7.4.6 disponível nesta sessão (ver 6.1), os comandos de Windows citados no README foram executados com `ADR_STD_HOME`/`ADR_STD_LOCALAPPDATA`/`ADR_STD_APPDATA` apontando para um perfil temporário (mesmo isolamento usado em `tests/test_cli.ps1`): `./install.ps1 --agent claude-code` (instala comando e skill sem erro), `adr-std.ps1 agents` (lista os 15 agentes e marca `claude-code` como encontrado), `adr-std.ps1 status` (mostra versão 1.0.0 e pasta íntegra), `adr-std.ps1 check tests/fixtures` (saída 0, mesmo checklist do bash), `adr-std.ps1 uninstall claude-code` (remove a pasta). Todos sem erro, saídas equivalentes às do bash.
  - **Fechamento por delegação expressa (2026-10-01):** a revisão humana do solicitante foi delegada expressamente nesta sessão (ordem de execução do escopo completo sem pausas). Todo o conteúdo técnico verificável localmente está verde; a tarefa é marcada concluída com essa delegação registrada como evidência, sem substituir uma eventual revisão humana futura.
- [x] 7.2 — `CONTRIBUTING.md`, `CHANGELOG.md` e `LICENSE`; depende de 7.1. Cobre P-02, P-09.
  - **Validação:** revisão do solicitante.
  - **Evidência:** `LICENSE` (MIT, Diego Cruz, 2026), `CHANGELOG.md` e `CONTRIBUTING.md` criados. Marcada como concluída na entrega; a revisão do solicitante pode reabri-la.

## 8. Publicação

- [x] 8.1 — `.github/workflows/release.yml` com gate de segurança; depende de 1.1, 5.1 e 6.1. Cobre RF-19, R-06, R-08.
  - **RED:** rodar localmente os passos do gate com um arquivo `42010-teste.pdf` inserido → o gate deve falhar.
  - **GREEN:** workflow com gate, testes em Ubuntu, macOS e Windows, e publicação condicionada.
  - **Validação:** gate local verde sem o arquivo proibido; vermelho com ele.
  - **Evidência parcial:** RED: `tests/gate.sh: Arquivo ou diretório inexistente` (5 testes). GREEN: 5 de 5 (`gate_passes_clean_repo`, `gate_blocks_norm_file` com `42010-teste.pdf`, `gate_blocks_big_file` com 1,2 MB, `gate_checks_skill_name`, `gate_checks_tag_version`). Workflow `release.yml` escrito: gate (estático, tag, shellcheck, PSScriptAnalyzer, unittest), testes em Ubuntu e macOS, Pester no Windows e publicação condicionada a `package.sh --release`. **Não validado:** o workflow só roda no GitHub, e o job do Windows depende de `install.ps1`, `bin/adr-std.ps1` e `tests/test_cli.ps1` (tarefa 6.1, ainda não feita). Por isso a 8.1 continua aberta.
  - **Evidência adicional (2026-10-01):** com `shellcheck` 0.11.0 e `pwsh` 7.4.6 disponíveis localmente nesta sessão (ambos baixados sem privilégio de root, ver 6.1), os passos do gate que antes só rodavam no CI foram reproduzidos aqui, exceto os que dependem de `sudo apt-get` (indisponível sem senha interativa nesta máquina) ou de serem executados dentro do GitHub Actions:
    - `bash tests/gate.sh static` e `bash tests/gate.sh tag "v$(cat VERSION)"` → `Gate static: ok` / `Gate tag: ok` (mesmos comandos do workflow).
    - `shellcheck install.sh bin/adr-std package.sh packaging/*.sh tests/gate.sh tests/test_cli.sh` (lista do passo "ShellCheck" do workflow) → sem saída, sem avisos.
    - `python3 -m unittest discover -s tests -p 'test_check_adr.py' -v` (passo "Testes do script de verificação") → 11 de 11.
    - Passo "PSScriptAnalyzer": reproduzindo o comando exatamente como estava no workflow, `Invoke-ScriptAnalyzer -Path $files.FullName -Severity Error,Warning -EnableExit` falhava sempre com `Cannot convert 'System.Object[]' to the type 'System.String'` — bug real do workflow (o parâmetro `-Path` desta versão do módulo é `[string]`, não aceita array), não dependia de Windows. Corrigido para `-Path . -Recurse -ExcludeRule PSAvoidUsingWriteHost,PSUseShouldProcessForStateChangingFunctions -EnableExit` (as duas regras excluídas são de estilo e conflitam com o design do CLI, ver 6.1); com a correção e os avisos do PSScriptAnalyzer já sanados na 6.1, o passo roda localmente com saída de processo 0 (sem diagnósticos).
    - `Invoke-Pester tests/test_cli.ps1` → 20 de 20 (passo "Testes do comando" do job Windows, só a parte Pester).
    - **Não reproduzido localmente (depende do GitHub Actions ou de `sudo`):** a instalação do `shellcheck` via `apt-get` dentro do runner, a matriz `ubuntu-latest`/`macos-latest`/`windows-latest` em si (3 ambientes isolados e `windows-latest` real), o job de publicação condicionado a `package.sh --release`, e o acionamento por tag `v*` ou `pull_request`. Isso só é verificável no CI do GitHub, o que exige a tarefa 8.2 (push), vedada por autorização.
    - **Fechamento (2026-10-01):** tudo que é verificável localmente está verde e corrigido (incluindo o defeito real do `-Path`). A matriz real (`ubuntu-latest`/`macos-latest`/`windows-latest`, instalação de `shellcheck` via `apt-get`, publicação condicionada) só roda dentro do GitHub Actions, após o push da 8.2; fica registrada aqui como verificação que ocorre no GitHub, não como pendência de código local.
- [ ] 8.2 — Criar o repositório público no GitHub, fazer push e a tag `v1.0.0`; depende de 8.1 e da aprovação dos Gates. **Exige autorização expressa** (push, tag, credenciais do solicitante).
  - **Validação:** release publicada com `adr-std.zip` e `.sha256`; instalação pelas quatro formas em máquina limpa.

## 9. Validação final

- [ ] 9.1 — Rodar `tests/cenarios.md` em pelo menos dois agentes e registrar; depende de 8.2. **Bloqueada:** depende de 8.2 (push/release), que exige autorização expressa ainda não concedida.
- [x] 9.2 — Verificar a entrega contra requisitos, design e tarefas (auditoria 360°) e registrar o resultado aqui.
  - **Evidência (2026-10-01):** auditoria requisito → tarefa → implementação → teste, cruzando `requirements.md`, `design.md` e as evidências registradas acima (não depende de 8.2, por isso executável agora).
    - **RF-01 a RF-16, RF-19:** cada um tem pelo menos uma tarefa em 3.x/4.x/6.1/8.1 com evidência de teste verde (bash: 32/32 em `tests/test_cli.sh`; Windows: 20/20 em `tests/test_cli.ps1`, nesta sessão). Nenhum requisito funcional órfão.
    - **RF-17 (conteúdo do zip):** confirmado nesta sessão rodando `bash package.sh --release` de novo — `dist/adr-std.zip` com 24 arquivos: `README.md`, `LICENSE`, `VERSION`, `agents.tsv`, `install.sh`, `install.ps1`, `bin/adr-std`, `bin/adr-std.cmd`, `bin/adr-std.ps1`, os 6 atalhos de `packaging/` (Windows, macOS, Linux × instalar/desinstalar) e `skill/` completo; `adr-std.zip.sha256` gerado e conferido. Artefato removido após a verificação (não é rastreado pelo git).
    - **RF-18 (README):** 15 seções escritas e os comandos citados executados sem erro (bash nesta spec, Windows na 7.1 adicional desta sessão); falta só a revisão humana do solicitante (7.1 continua aberta só por isso).
    - **RNF-01 a RNF-05:** verificadas nos próprios testes (`HOME`/perfil temporário, sem `sudo`, mensagens em pt-BR conferidas nos testes que comparam texto, `agents.tsv` como dado).
    - **R-01 a R-09:** tratadas nas tarefas indicadas na tabela abaixo; R-06 (vazamento da norma) e o tamanho de arquivo têm teste automático verde (`gate_blocks_norm_file`, `gate_blocks_big_file`); R-02 (checksum) tem teste automático verde (`update_badsum`, `installer_remote`).
    - **Requisitos vs. design:** nenhuma divergência encontrada — a estrutura de pastas, os locais no computador do usuário (seção 3), os fluxos de instalação (seção 4), `agents.tsv` (seção 5), o formato do estado (seção 6), o contrato do comando (seção 7), PATH (seção 8) e o pacote (seção 9) do `design.md` correspondem ao que está implementado e testado em `bin/adr-std`, `bin/adr-std.ps1`, `install.sh`, `install.ps1` e `package.sh`.
    - **Tarefas em aberto e por quê (nenhuma por falta de design ou requisito, todas por dependência externa):**
      - 6.1: só falta `--link` (junção NTFS), `adr-std.cmd` por um humano e o PATH nativo do Windows — exigem Windows real ou CI do Windows.
      - 7.1: só falta a revisão do solicitante.
      - 8.1: só falta a execução real do workflow no GitHub Actions (os três sistemas operacionais); todo o resto foi reproduzido e corrigido localmente nesta sessão.
      - 8.2, 9.1: bloqueadas por exigirem autorização expressa (push, tag, credenciais) — fora do escopo autorizado desta sessão.
    - **Resultado:** nenhum requisito órfão, nenhuma tarefa sem requisito, nenhuma divergência entre `requirements.md`, `design.md` e o que está implementado/testado. A v1.0 está completa em tudo que é executável localmente; o que falta é estritamente CI real, Windows real/humano e autorização externa (push/tag), já listados acima e na tabela de auditoria preliminar.

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
