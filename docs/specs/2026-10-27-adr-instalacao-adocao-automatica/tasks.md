# Tarefas — instalação com adoção automática de pastas existentes

Data: 2026-10-27. Requisitos: `requirements.md` (Gate 1 aprovado); design: `design.md` (Gate 2 aprovado). Marque `[x]` só com evidência real (comando e resultado) no campo Evidência de cada tarefa.

Convenção: cada tarefa de código segue RED → GREEN → REFACTOR, em `tests/test_cli.sh` (Bash) e `tests/test_cli.ps1` (Pester), com `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `ADR_STD_TTY` e `APPDATA` isolados em diretório temporário. Comandos rodam da raiz do repositório. Sem rede, push, release ou deploy; commit só com autorização expressa do responsável. Antes de cada tarefa: `git status`, preservando mudanças alheias.

Execução proposta: uma tarefa por vez, com subagente, nas etapas 1 a 4 (todas editam `bin/adr-std`, então não são paralelas). As etapas 5 (PowerShell) e 6 (documentação) só dependem do contrato fechado na etapa 4 e podem rodar em paralelo entre si.

## Etapa 0 — Preparação

- [x] 0.1 Criar a branch `feat/instalacao-adocao-automatica` a partir de `develop`, sem tocar nos arquivos alheios.
  - Validação: `git branch --show-current` e `git status --short`.
  - Evidência: `git branch --show-current` → `feat/instalacao-adocao-automatica`; `git status --short` limpo; commits `9b6215b` e `7d12146` só com a spec.
- [x] 0.2 Medir a linha de base: `bash tests/test_cli.sh`, `python3 -m unittest discover tests` e `bash tests/gate.sh static`; registrar contagens.
  - Depende de 0.1. Validação: comandos acima com saída 0 e totais anotados na Evidência.
  - Evidência (2026-10-27): `bash tests/test_cli.sh` → 72 passaram, 0 falharam; `python3 -m unittest discover tests` → 143 testes OK; `bash tests/gate.sh static` → `Gate static: ok`. `pwsh` ausente neste computador (`command -v pwsh` sem saída): Pester não roda localmente, então a linha de base do Pester vem do job Windows do CI e a etapa 5 só fecha com o CI verde.

## Etapa 1 — Resolução de links e classificação (somente leitura)

- [x] 1.1 `resolve_link_chain <pasta>`: segue `readlink` em laço, máximo de 10 saltos, ciclo e link quebrado retornam falha; imprime o destino final.
  - RED: casos link direto, encadeado de 2 e 3 níveis, ciclo, 11 saltos e link quebrado. GREEN: o laço. REFACTOR: reaproveitar na verificação de `owned_by_us`.
  - Atende D-6, SEG-02. Depende de 0.2. Validação: `bash tests/test_cli.sh` (casos novos).
  - Evidência (2026-10-27): RED: os 6 testes novos (`resolve_link_chain_direct`, `_nested`, `_relative`, `_cycle`, `_limit`, `_broken`) falharam com `resolve_link_chain não definida em bin/adr-std` (0 passaram, 6 falharam). GREEN: função em `bin/adr-std` (laço de `readlink`, máximo de 10 saltos, ciclo por repetição, normaliza `.`/`..`); o caso relativo falhou na 1ª versão (`sub/../real`) e passou após a normalização. `bash tests/test_cli.sh` → 78 passaram, 0 falharam (antes 72); `python3 -m unittest discover tests` → 143 OK; `bash tests/gate.sh static` → ok. Os testes extraem a função do script com `sed` porque `bin/adr-std` termina em `main; exit`. Sem REFACTOR.
- [x] 1.2 `skill_name_of <pasta>`: lê o frontmatter do `SKILL.md` (primeiro bloco `---`, até 20 linhas) e imprime `name`; sem arquivo ou sem `name`, imprime vazio.
  - RED: `name: adr-std`, outro nome, sem frontmatter, sem `SKILL.md`, conteúdo com `$(...)` e crases (tratado como texto). GREEN: `sed`/`head`.
  - Atende D-11, SEG-03. Depende de 0.2. Validação: `bash tests/test_cli.sh`.
  - Evidência (2026-10-27): RED: os 6 testes novos (`skill_name_of_adr_std`, `_other_name`, `_no_frontmatter`, `_no_file`, `_text_only`, `_limit_20_lines`) falharam com `skill_name_of não definida em bin/adr-std` (0 passaram, 6 falharam). GREEN: função com `head -n 20` e `awk` (só texto, sem expansão), 6 passaram; `$(touch ...)` e crases ficaram como texto e nenhum arquivo foi criado; o `skill/SKILL.md` real devolve `adr-std`. Totais: `bash tests/test_cli.sh` 84 passaram, 0 falharam (antes 78); `python3 -m unittest discover tests` 143 OK; `bash tests/gate.sh static` ok. REFACTOR: nada a refatorar.
  - Evidência (2026-10-27, extensão): `SKILL.md` com BOM no início e/ou fim de linha CRLF passou a ser reconhecido. RED: `skill_name_of_bom_and_crlf` falhou; GREEN: `awk` portátil (BOM por `index`/`substr`, sem escape `\x`, para o macOS do CI) → `bash tests/test_cli.sh`: 92 passaram, 0 falharam; `python3 -m unittest`: 143 OK; `bash tests/gate.sh static`: ok.
- [x] 1.3 `classify_dest <pasta>` combinando 1.1 e 1.2 e a tabela do design; sem escrita.
  - RED: oito casos da tabela (`absent`, `ours`, `repo-link` direto e encadeado, `foreign-adr-std` cópia e link para fora, `foreign-other` por outra skill, sem `SKILL.md`, ciclo e link quebrado). GREEN: a função. REFACTOR: nenhuma.
  - Atende RF-01 a RF-04, RF-08, D-7. Depende de 1.1 e 1.2. Validação: `bash tests/test_cli.sh`; conferir que a árvore de teste não mudou após a classificação.
  - Evidência (2026-10-27): RED: 7 testes novos (`classify_dest_absent`, `_ours`, `_repo_link`, `_repo_link_symlinked_parent`, `_foreign_adr_std`, `_foreign_other`, `_read_only`) falharam com `classify_dest não definida em bin/adr-std`. GREEN: `classify_dest` e os auxiliares `points_to_source` e `physical_path` em `bin/adr-std`; os 7 passaram. A comparação com `$SRC/skill` e `$DATA_DIR/skill` usa o caminho físico (`cd -P`/`pwd -P`) nos dois lados, coberta pelo teste com `$SRC` atrás de um diretório pai que é link (SRC lógico com link físico e SRC físico com link lógico); sem mudança de design. O teste de somente leitura compara lista de arquivos, `cksum` e `readlink` antes e depois. `bash tests/test_cli.sh` → 91 passaram, 0 falharam (antes 84); `python3 -m unittest discover tests` → 143 OK; `bash tests/gate.sh static` → ok. `owned_by_us` não foi alterada (é a 1.4).
- [x] 1.4 `owned_by_us` passa a usar a cadeia resolvida (D-8).
  - RED: link encadeado já registrado hoje é tratado como não nosso. GREEN: comparar o destino final com `$SRC/skill` e `$DATA_DIR/skill`. Regressão: link direto e cópia com marcador seguem nossos.
  - Depende de 1.1. Validação: `bash tests/test_cli.sh`.
  - Evidência (2026-10-27): RED: `owned_by_us_chained_link` falhou (link encadeado registrado tratado como não nosso); `owned_by_us_regressions` já passava (cópia com marcador nossa; sem marcador, link não registrado, link registrado para fora da fonte e link quebrado não são). GREEN: o ramo de link de `owned_by_us` passou a chamar `points_to_source`. REFACTOR: `classify_dest` deixou de repetir a regra e chama `owned_by_us`. `bash tests/test_cli.sh`: 94 passaram, 0 falharam (testes de install/uninstall/update inclusos); `python3 -m unittest discover tests`: 143 OK; `bash tests/gate.sh static`: ok.

## Etapa 2 — Estado com modo por agente

- [x] 2.1 `state_add_agent` grava a 4ª coluna (`link` ou `copy`); `state_agent_mode <id>` lê e cai no `mode` global quando a coluna falta.
  - RED: estado novo e estado antigo de 3 colunas. GREEN: ajuste dos helpers; `state_agents` continua imprimindo as colunas 2 e 3.
  - Atende D-9, RF-11. Depende de 0.2. Validação: `bash tests/test_cli.sh`.
  - Evidência (2026-10-27): RED: `state_agent_mode_fourth_column`, `state_agent_mode_old_state_falls_back_to_global`, `state_agent_mode_empty_without_any` e `install_records_mode_per_agent` falharam (`state_agent_mode não definida`; `install sem --link não gravou copy`). GREEN: `state_agent_mode` (4ª coluna, senão `mode` global, senão vazio) e `state_add_agent id pasta modo`; `cmd_install` passa `link` se `LINK=1`, senão `copy`; `state_agents` segue com duas colunas. O `install_dedupe` teve a regex ajustada para aceitar a 4ª coluna opcional (mesma verificação). `bash tests/test_cli.sh`: 98 passaram, 0 falharam; `python3 -m unittest discover tests`: 143 OK; `bash tests/gate.sh static`: ok.
- [x] 2.2 `cmd_status` mostra o modo por agente.
  - RED: saída com `[íntegra, link]` e `[íntegra, copy]`; estado antigo mostra o `mode` global. GREEN: ajuste do `printf`.
  - Atende RF-11. Depende de 2.1. Validação: `bash tests/test_cli.sh`.
  - Evidência (2026-10-27): RED: `status_mode_per_agent` e `status_mode_old_state_uses_global` falharam (saída sem o modo por agente). GREEN: `cmd_status` imprime `[íntegra, link]`, `[íntegra, copy]` e `[danificada (pasta ausente ou incompleta), <modo>]` via `state_agent_mode`; estado antigo de 3 colunas usa o `mode` global; cabeçalho preservado. `bash tests/test_cli.sh`: 101 passaram, 0 falharam; `python3 -m unittest discover tests`: 143 OK; `bash tests/gate.sh static`: ok; `git diff --check`: ok. Nenhum teste existente precisou de ajuste.

## Etapa 3 — Ação por destino e laço sem interrupção

- [x] 3.1 `backup_dest <pasta>`: move a pasta ou o link para `adr-std.bak-<AAAA-MM-DD>` no mesmo diretório, com sufixo `-2`, `-3` se existir, sem desreferenciar; falha de `mv` retorna erro.
  - RED: pasta, link, backup existente, falha simulada de permissão. GREEN: `mv` com laço de sufixo.
  - Atende RF-05, D-12, SEG-01. Depende de 1.3. Validação: `bash tests/test_cli.sh`; conteúdo do backup idêntico ao original.
  - Evidência (2026-10-27): RED: `backup_dest_directory`, `_link_not_dereferenced` e `_suffix_when_exists` falharam (`backup_dest: comando não encontrado`); `_mv_failure` passava por acaso (comando inexistente) e só passou a valer após o GREEN. GREEN: `backup_dest` (`mv --` do próprio caminho, laço de sufixo `-2`, `-3`, data por `ADR_STD_TODAY`). Cobertura: pasta com conteúdo idêntico; link movido continua link para o mesmo alvo, alvo intacto; backup existente gera `-2` e `-3` sem tocar nos anteriores; diretório pai sem escrita (`chmod a-w`) devolve erro e a origem fica intacta, sem `.bak` pela metade (o caso é pulado se `id -u` for 0). `bash tests/test_cli.sh`: 105 passaram, 0 falharam; `python3 -m unittest`: 143 OK; `bash tests/gate.sh static`: ok.
- [x] 3.2 `act_on_dest`: roteia por classe (instalar, atualizar, registrar sem alterar, pular `foreign-other`) e devolve o resultado (`installed`, `updated`, `adopted-in-place`, `skipped:<motivo>`).
  - RED: um caso por classe, incluindo `repo-link` sem tocar o link e sem backup, `foreign-other` intacto, mesmo com `--adopt` ainda não implementado, e `ours` em modo `link` rodado de novo sem `--link`, que deve continuar link (D-16). GREEN: a função, lendo `state_agent_mode`.
  - Atende RF-01 a RF-03, RF-08. Depende de 1.3, 1.4 e 2.1. Validação: `bash tests/test_cli.sh`.
  - Evidência (2026-10-27): RED: os 7 testes novos `act_on_dest_*` falharam com `act_on_dest não definida` (105 anteriores verdes). GREEN: `act_on_dest <id> <classe> <pasta>` com resultado em `ACT_RESULT` (`installed`, `updated`, `adopted-in-place`, `skipped:<motivo>`; código 0, ou 4 se pulou). `absent`→instala; `ours`→reinstala e, em modo `link` no estado, continua link sem `--link` (D-16); `--link` explícito converte cópia em link; `repo-link`→registra como `link` sem tocar o link (`readlink` igual antes/depois, sem `.bak`); `foreign-other`→`skipped:outra-skill`, intacta e sem registro; `foreign-adr-std`→`skipped:sem-terminal` por ora (adoção real na 4.1/4.2), intacta. `install_to` não mudou; não foi ligada ao laço de `cmd_install` (3.3). `bash tests/test_cli.sh`: 112 passaram, 0 falharam (2 execuções completas; uma rodada isolada teve `servidor de teste não subiu` em `update_migrate_no_python`, que passou sozinho e nas reexecuções); `python3 -m unittest discover tests`: 143 OK; `bash tests/gate.sh static`: ok; `git diff --check`: ok.
- [x] 3.3 `cmd_install` sem `return` no conflito: junta os resultados, roda `install_commands` sempre, imprime o resumo e devolve 4 se houver pulo.
  - RED: `--all` com conflito no primeiro agente instala os demais, cria os comandos `/adr-std-*`, lista o pulado e sai com 4; sem pulo sai com 0; dois agentes na pasta compartilhada geram uma classificação; `--agent` desconhecido segue com código 2 e nenhum destino vem de argumento livre (SEG-04); falha de backup (3.1) vira `skipped:backup-falhou` sem instalar por cima.
  - Atende RF-09, RF-12, D-14. Depende de 3.2. Validação: `bash tests/test_cli.sh`.
  - Evidência (2026-10-27): `cmd_install` chama `classify_dest` + `act_on_dest` uma vez por pasta (resultado guardado para os agentes que a compartilham), sem `|| return $?`; `install_commands` roda sempre; resumo "Destinos pulados" com o motivo por pasta e código 4 (0 sem pulos); `Pronto.`, `version` e `mode` só quando algo foi instalado, atualizado ou adotado; agente de pasta pulada não é registrado. `install_to` passou a devolver 1 (com mensagem) quando `mkdir`, `cp`, `mv` ou `ln` falham, antes devolvia sucesso mesmo assim. RED: `install_all_conflict_continues`, `install_shared_dest_single_classification` e `install_failure_becomes_skipped` falharam (os outros três novos já protegiam o comportamento atual). GREEN: `bash tests/test_cli.sh` → 118 passaram, 0 falharam, duas execuções seguidas; `python3 -m unittest discover tests` → 143 OK; `bash tests/gate.sh static` → ok; `git diff --check` ok. Teste instável do servidor local (`update_failed_installer_no_migration`, `servidor de teste não subiu`) falhou numa execução e passou nas duas seguintes. Nenhum teste antigo foi alterado (`install_conflict` segue válido porque o resumo contém "não foi instalada"). Pendência de design resolvida (2026-10-27): o motivo `falha-na-instalacao` entrou na lista de motivos do `design.md` e no RF-09 do `requirements.md`; coberto por teste em `tests/test_cli.sh` e implementado em `bin/adr-std` (resumo e `act_on_dest`).

## Etapa 4 — Adoção e simulação

- [x] 4.1 Adoção interativa de `foreign-adr-std`: mostra o que será substituído, lê a resposta por `read_tty_line`, só `s`/`S` confirma; confirmada, faz `backup_dest` e instala; recusa vira `skipped:recusado`.
  - RED: resposta `s`, vazia, `n` e lixo; backup criado só na confirmação. GREEN: a ação.
  - Atende RF-04, RF-05. Depende de 3.1 e 3.3. Validação: `bash tests/test_cli.sh` com `ADR_STD_TTY`.
  - Evidência (2026-10-27): RED: 5 testes `adopt_*` falharam (`skipped:sem-terminal` no lugar de adoção/recusa; `esperado '0', obtido '4'`). GREEN em `act_on_dest` (ramo `foreign-adr-std`): mostra pasta, tipo (cópia ou link e alvo) e o nome do backup, lê a resposta por `read_tty_line`, só `s`/`S` confirma; confirmada: `backup_dest`, instalação (cópia, ou link com `LINK=1`) e registro com `adopted-with-backup`; recusa (vazia, `n`, `N`, `xyz`, `sim`) → `skipped:recusado` sem backup nem rastro no estado; falha de backup → `skipped:backup-falhou` sem instalar por cima; sem terminal → `skipped:sem-terminal`. REFACTOR: `backup_path_for` extraída de `backup_dest` para exibir o nome antes de mover. Link de terceiros vai para o backup como link (alvo intacto). Totais: `bash tests/test_cli.sh` 123 passaram, 0 falharam (2ª execução completa; a 1ª teve só `update_migrate_no_python` falhando por 'servidor de teste não subiu', que passou isolado); `python3 -m unittest discover tests` 143 OK; `bash tests/gate.sh static` ok; `git diff --check` ok.
- [x] 4.2 `--adopt` e modo sem terminal: sem terminal e sem `--adopt`, pula com `skipped:sem-terminal` e dica de `--adopt`; com `--adopt`, adota com backup sem perguntar; `--adopt` nunca vale para `foreign-other`.
  - RED: os três casos mais `--adopt` em outra skill. GREEN: opção em `parse_args` e ramo na ação. REFACTOR: unificar mensagens de pulo.
  - Atende RF-06, RF-07, RF-08. Depende de 4.1. Validação: `bash tests/test_cli.sh`.
  - Evidência (2026-10-27): RED: 6 testes novos falharam (`adopt_flag_parsed` e `install_with_adopt_flag_end_to_end` com `opção desconhecida: --adopt`; `adopt_flag_adopts_without_asking`, `_ignores_terminal_answer`, `_backup_failure_does_not_install` e `install_without_terminal_skips_with_adopt_hint` sem o comportamento); `adopt_flag_never_touches_foreign_other` já passava (SEG-01/RF-08 protegidos desde a 3.2). GREEN: `ADOPT=0` e `--adopt` em `parse_args`; no ramo `foreign-adr-std` de `act_on_dest`, `ADOPT=1` confirma sem ler o terminal (mesmo caminho de backup e instalação da 4.1; falha de backup segue `skipped:backup-falhou`), sem terminal e sem `--adopt` segue `skipped:sem-terminal` com a dica. REFACTOR: mensagem de pulo `sem-terminal` do resumo reescrita (estava truncada) e dica `--adopt` também na linha do destino. `--adopt` nunca vale para `foreign-other`. `bash tests/test_cli.sh`: 130 passaram, 0 falharam (2 execuções); `python3 -m unittest discover tests`: 143 OK; `bash tests/gate.sh static`: ok; `git diff --check`: ok.
- [x] 4.3 `--dry-run` imprime `<pasta>: <classe> -> <ação>` por destino sem alterar arquivos nem estado.
  - RED: comparar a árvore e o estado antes e depois, nas cinco classes; com `foreign-adr-std` a saída mostra `perguntaria`, `adotaria` ou `pularia` e nenhuma leitura de terminal acontece (`ADR_STD_TTY` apontando para um arquivo que não deve ser lido). GREEN: ramo de simulação em `cmd_install`.
  - Atende RF-10. Depende de 3.3. Validação: `bash tests/test_cli.sh`.
  - Evidência (2026-10-27): RED: `dry_run_five_classes_changes_nothing`, `dry_run_foreign_adr_std_adopt_and_ask` e `dry_run_shared_dest_single_line` falharam (a simulação só imprimia `instalaria`). GREEN: `dry_run_action` e `tty_available` (só abre e fecha o terminal, sem ler) e o ramo `DRY` de `cmd_install` classifica e imprime `<pasta>: <classe> -> <ação>` (`instalaria`, `atualizaria`, `registraria sem alterar`, `adotaria (com backup)`, `perguntaria`, `pularia (...)`). Cobertura: as cinco classes em cinco agentes; árvore, conteúdo, links e estado idênticos antes e depois (`snapshot_home`); com `ADR_STD_TTY` apontando para uma FIFO sem resposta, a simulação não trava (não lê); pasta compartilhada gera uma linha. `bash tests/test_cli.sh`: 133 passaram, 0 falharam.
- [x] 4.4 `update` pula destinos em modo `link` e informa o motivo; com código 4 do instalador, mostra o resumo, executa `maybe_migrate` e devolve 4; `uninstall` remove o link adotado sem tocar o alvo nem o `adr-std.bak-*`.
  - RED: destino `link` não é substituído pela release; instalador simulado devolvendo 4 ainda dispara a migração e o `update` sai com 4, enquanto outro código de erro (ex.: 1) continua interrompendo; `uninstall` mantém o alvo e o backup. GREEN: ajuste em `cmd_update` e `cmd_uninstall`.
  - Atende RF-11, D-10, D-17. Depende de 2.1 e 4.2. Validação: `bash tests/test_cli.sh`.
  - Evidência (2026-10-27): RED: `update_skips_link_mode_destinations` e `update_installer_code_4_still_migrates` falharam; `uninstall_adopted_link_keeps_target_and_backup` já passava (regressão protegida: `rm -rf` de link não toca o alvo e o backup fica). GREEN em `cmd_update`: agentes em modo `link` saem da lista do instalador com a mensagem `já segue o repositório` (D-10; `--link` explícito não filtra); lista vazia não chama o instalador; código 4 do instalador segue para `maybe_migrate` e o `update` devolve 4 (D-17), enquanto outro código (ex.: 5, `update_failed_installer_no_migration`) continua interrompendo. `bash tests/test_cli.sh`: 136 passaram, 0 falharam.
- [x] 4.5 Ajuda do comando: `--adopt` em `cmd_help`.
  - RED: `adr-std help` cita `--adopt`. Depende de 4.2. Validação: `bash tests/test_cli.sh`.
  - Evidência (2026-10-27): `test_help_lists_adopt` (`--adopt` e `código 4`) e linhas novas em `cmd_help` (`--adopt`, `--dry-run` por pasta, código 4). O teste foi escrito junto da ajuda, sem observar o RED isolado. `bash tests/test_cli.sh`: 137 passaram, 0 falharam (2 execuções).
- [x] 4.6 Revisão independente e regressão da etapa Bash: `bash tests/test_cli.sh`, `python3 -m unittest discover tests`, `bash tests/gate.sh static`; comparar contra a linha de base de 0.2.
  - Depende de 4.1 a 4.5. Validação: totais iguais ou maiores e nenhuma falha.

  - Evidência (2026-10-27): revisão independente por subagente (somente leitura): nenhum achado alto; SEG-01 a SEG-04 conferidos. Achados médios corrigidos com RED e GREEN: (1) `update --agent <novo>` tratava agente não registrado como `link` pelo `mode` global (`update_agent_not_registered_ignores_global_link_mode`; o filtro agora só vale para agentes registrados); (2) falha de instalação depois do backup deixava o destino vazio (`adopt_install_failure_restores_original`; o original volta ao lugar, sem `.bak`). Aceitos como limitações: `name:` com aspas ou comentário no frontmatter não é reconhecido (só deixa de adotar, seguro); o `mode` global pode ficar `copy` com todos os destinos em `link` (o `status` mostra o modo por agente); no PowerShell a comparação de link com a fonte é lexical, não física (seguro: gera adoção com backup). Regressão: `bash tests/test_cli.sh` 139 passaram, 0 falharam (linha de base 72; 2 execuções); `python3 -m unittest discover tests` 143 OK; `bash tests/gate.sh static` ok; `git diff --check` ok.
## Etapa 5 — Windows (PowerShell)

- [x] 5.1 Espelhar `Resolve-LinkChain`, `Get-SkillName` e `Get-DestClass` em `bin/adr-std.ps1` com `ReparsePoint` e `Target`, mesmo limite de 10 saltos e detecção de ciclo.
  - RED: casos Pester equivalentes a 1.1 a 1.3, com junção e link simbólico. GREEN: as funções.
  - Atende RF-13, D-15. Depende de 4.6. Validação: `pwsh -NoProfile -Command "Invoke-Pester tests/test_cli.ps1"`.
  - Estado (2026-10-27): `Resolve-LinkChain` (10 saltos, ciclo, quebrado), `Get-SkillName` (BOM, CRLF, 20 linhas, só texto), `Test-PointsToSource`, `Test-OwnedBySelf` e `Get-DestClass` escritos em `bin/adr-std.ps1`; Pester em `tests/test_cli.ps1` (link direto e encadeado, outra skill, `adr-std` alheio). NÃO executado: `pwsh` ausente neste computador (`command -v pwsh` sem saída); só leitura, balanceamento de chaves comparado ao HEAD e revisão independente da sintaxe. Fica aberta até o Pester rodar (CI Windows).
- [x] 5.2 Espelhar estado por agente, `Backup-Dest`, ação por destino, `--adopt`, `--dry-run`, resumo e código 4, `update` pulando `link` e `status`.
  - RED: casos equivalentes a 2.1 a 4.4. GREEN: ajustes em `Install-To`, `Invoke-Install`, `Invoke-Update`, `Invoke-Status`.
  - Atende RF-13. Depende de 5.1. Validação: Pester local; a conclusão do RF-13 só vale com o job Windows do CI verde (`pwsh` portátil não prova NTFS).
  - Estado (2026-10-27): estado por agente (`Get-StateAgentMode`, `Add-StateAgent` com 4ª coluna), `Get-BackupPath`/`Backup-Dest`, `Invoke-ActOnDest`, `Get-DryRunAction`, `--adopt`, laço sem interrupção com resumo e código 4 em `Invoke-Install`, `Install-To` devolvendo booleano, `Invoke-Update` pulando `link` e tratando o código 4, `Invoke-Status` com o modo, ajuda. Pester equivalente a 2.1 a 4.5 em `tests/test_cli.ps1`. NÃO executado (sem `pwsh`); fica aberta até o Pester local ou o job Windows do CI ficarem verdes (RF-13 só vale com o CI Windows verde).
  - Revisão estática independente (2026-10-27), corrigida sem execução: `Invoke-Cli`/`Invoke-UpdateIn` com `[object]$Answer` e resposta vazia como `' '` (variável de ambiente vazia não existe no Windows), stdin redirecionado nos testes, asserção de estado sem rastro de `agent`, asserções reforçadas em `update --agent` e no link direto/encadeado; `Test-ReparsePoint` só para `Junction`/`SymbolicLink` e `name:` comparado com `-ceq`/`-cmatch` (igual ao Bash). Implementados depois (2026-10-28): `Get-PhysicalPath` (equivale ao `pwd -P` do Bash: um link correto atrás de junção ou link de pasta-pai continua `repo-link`; RED no Windows 11: sem a função o caso virou `foreign-adr-std`, o que causaria backup indevido, SEG-01) e 7 testes Pester novos: caminho físico, ciclo, 10 contra 11 links (SEG-02), sufixo `-2`/`-3`, backup de link para outro clone, pasta compartilhada uma vez só (RF-12) e D-16. Pester no Windows 11 real: 76 passaram, 0 falharam, 8 pulados (os mesmos 8 só-Linux). Limite conhecido: nomes curtos 8.3 (`RUNNER~1`) não são expandidos, então um link via nome curto pode cair em `foreign-adr-std` e pedir confirmação (nunca apaga sem backup).
- [x] 5.3 Regressão do Pester: totais contra a linha de base de 0.2, sem testes pulados novos.
  - Depende de 5.2. Validação: Pester local.
  - Evidência (2026-10-28), Windows 11 real (contêiner `win11`, disco NTFS `C:\`, cópia do repositório em `C:\adr-std-test`), PowerShell 7.6.9, Pester 6.2.0, Python 3.12.10 e git 2.56 (o job do CI usa `pwsh` com o Pester mais recente e Python): `Invoke-Pester -Path tests/test_cli.ps1 -CI` → 69 passaram, 0 falharam, 8 pulados. Os 8 pulados são os testes antigos com `-Skip:($env:OS -eq 'Windows_NT')` (só Linux) e o do PATH; nenhum teste novo foi pulado. A primeira rodada achou 6 falhas, todas de teste ou de ambiente e nenhuma de comportamento: asserção minha de link (`Resolve-Path` devolve o caminho da junção), snapshot de pasta (no NTFS a data da pasta muda só por leitura; passou a ignorá-la), `git` ausente na máquina, PATH com entrada vazia, asserção `claude` que também casava as linhas de comando, e o teste de `update` que acrescentava a 5ª coluna `link` em vez de trocar a 4ª (`copy`). Corrigidos e reexecutados (68/1, depois 69/0).
  - Limite: o RF-13 continua só com a confirmação do job Windows do CI (após o push, que depende de autorização). Esta execução é em Windows 11 real, não em `windows-latest`.
  - Exceção à regra "sem rede" da spec, autorizada pelo responsável nesta sessão: instalação de PowerShell 7, Python 3.12, git (winget) e Pester (PSGallery) na VM de testes. Nada disso toca o perfil do responsável. O executor da VM (`runner.ps1`, `jobs/`, `out/`) e a cópia `repo/` ficam em `/Fusiondev/App/windows/shared`, fora deste repositório.

## Etapa 6 — Documentação

- [x] 6.1 README: a seção de instalação descreve a adoção, `--adopt`, o backup e o código 4; a cópia manual deixa de ser apresentada como caminho que o instalador recusa; troubleshooting atualizado (linha `já existe e não foi instalada pelo adr-std`).
  - Atende RF-14. Depende de 4.6. Validação: revisão cruzada contra a ajuda e `git diff --check`.
  - Evidência (2026-10-27): README: parágrafo "Instalar depois pelo instalador" na seção 6.4 (reconhecimento, backup, `--adopt`, outra skill intocada, backup não apagado), linhas `--adopt`, `--dry-run` por pasta e `update` em modo `link` na tabela de comandos, e novas linhas do troubleshooting (`Destinos pulados` com código 4 e `adr-std.bak-<data>`) no lugar de `já existe e não foi instalada pelo adr-std`. Conferido contra `adr-std help`; `git diff --check` ok.
- [x] 6.2 `CHANGELOG.md` em `[Não lançado]` (Adicionado: `--adopt`; Alterado: conflito não interrompe o laço, código 4 no fim, `update` pula links) e conferência do `SKILL.md`, alterando-o somente se citar a instalação.
  - Atende RF-14. Depende de 6.1. Validação: `git diff --check`; o `VERSION` e o número da release não mudam.
  - Evidência (2026-10-27): `CHANGELOG.md` em `[Não lançado]`: Adicionado (`--adopt`, classificação por pasta, `--dry-run` por destino, modo por agente) e Alterado (conflito não interrompe o laço e sai com 4, `update` pula `link` e trata o código 4, falha de gravação vira `falha-na-instalacao`). `SKILL.md` não cita a instalação (`grep -i instal skill/SKILL.md` sem ocorrência), então não foi alterado; `VERSION` intacto. `git diff --check` ok.
- [x] 6.3 `ROADMAP.md` do produto e `docs/architecture/ADR/ROADMAP.md`: avaliar na auditoria se entram como versão; se entrarem, `python3 skill/scripts/check_roadmap.py docs/architecture/ADR` retorna `[OK]`.
  - Depende de 6.2. Validação: o comando acima.
  - Evidência (2026-10-27): decisão da auditoria: não entra como versão no `ROADMAP.md` do produto (a mudança ainda não tem número de release; a spec de uma versão só é aberta quando a versão começa e o número é decisão do responsável) nem no `docs/architecture/ADR/ROADMAP.md` (não há ADR novo). `python3 skill/scripts/check_roadmap.py docs/architecture/ADR` → `[OK] ROADMAP consistente`.

## Etapa 7 — Verificação final

- [x] 7.1 Cenário real no seu perfil, sem alterar nada: `bin/adr-std install --all --dry-run`; as classes dos quatro links manuais (`~/.agents`, `~/.claude`, `~/.codex`, `~/.continue`) aparecem como `repo-link` e as dos demais agentes encontrados (copilot, kiro, amp) como `absent` (o `~/.gemini/antigravity` é link encadeado para `~/.agents` e aparece como `repo-link`); Gemini CLI e OpenCode aparecem na mesma pasta compartilhada (uma classificação, RF-12).
  - Atende RF-03, RF-10. Depende de 4.6. Validação: saída colada na Evidência; `git status` e o perfil inalterados.
  - Evidência (2026-10-27): `bin/adr-std install --all --dry-run` no perfil real, código 0: `~/.claude`, `~/.codex`, `~/.agents` (Gemini CLI e OpenCode, uma linha só, RF-12) e `~/.continue` aparecem como `repo-link -> registraria sem alterar`; `~/.gemini/antigravity` também aparece como `repo-link` (é um link encadeado para `~/.agents`, a spec previa `absent`); copilot, kiro e amp como `absent -> instalaria`. Os 10 comandos `/adr-std-*` de claude, gemini, opencode e continue aparecem só como `(simulação) criaria`. Listagem dos destinos, dos diretórios de comandos e do estado idêntica antes e depois (`cmp`); `git status` só com os arquivos da mudança.
- [x] 7.2 Instalação real no seu perfil só com autorização expressa e pontual: `bin/adr-std install --all`; depois `bin/adr-std status` e o conteúdo de `~/.claude/commands/`.
  - Atende RF-03, RF-09. Depende de 7.1. Validação: `status` lista os agentes com o modo e os links preservados.
  - Evidência (2026-10-27, autorizada pelo responsável nesta sessão): `bin/adr-std install --all` → código 0; claude-code, codex, `~/.agents` (gemini-cli, opencode, universal), antigravity, continue e cursor: `já aponta para o repositório; registrado sem alterar`; github-copilot, kiro-cli e amp instalados em cópia 3.0.0. `bin/adr-std status`: os seis destinos link seguem `[íntegra, link]` e os três novos `[íntegra, copy]`; nenhum `adr-std.bak-*` criado; `~/.claude/commands/` com os 10 `adr-std-*.md`.
- [x] 7.3 Verificar a entrega contra requisitos, design e tarefas; preencher a tabela de rastreabilidade com a evidência de cada item e fechar a auditoria 360° (Gate 3) antes de qualquer commit.
  - Depende de 5.3, 6.3 e 7.1. Validação: todos os RF e SEG com resultado `Atendido` ou limitação registrada.
  - Evidência (2026-10-28): tabela "Verificação final contra os requisitos" abaixo. Suítes: Bash 139/0, `python3 -m unittest discover tests` OK, `gate.sh static` ok, `check_roadmap.py` `[OK]`, Pester no Windows 11 real 76 passaram, 0 falharam, 8 pulados (só-Linux). Todos os RF e SEG `Atendido`, exceto o RF-13, com a limitação registrada (falta o job `windows-latest` do CI).

## Verificação final contra os requisitos — 2026-10-28

| Requisito | Resultado | Evidência |
|---|---|---|
| RF-01 | Atendido | `test_classify_dest_absent`, `test_install_with_adopt_flag_end_to_end`; Pester `instala só nos agentes indicados` |
| RF-02 | Atendido | `test_act_on_dest_ours_copy_updates`, `test_act_on_dest_ours_link_stays_link`; Pester D-16 (segunda instalação mantém o link) |
| RF-03 | Atendido | `test_classify_dest_repo_link`, `..._symlinked_parent`, `test_act_on_dest_repo_link_adopted_in_place`; 7.2 no perfil real: 7 links registrados sem alterar e sem backup; Pester `link para o repositório (direto e encadeado)` |
| RF-04 | Atendido | `test_classify_dest_foreign_adr_std`, `test_adopt_confirmed_copy_makes_backup_and_installs`, `test_adopt_refused_leaves_no_trace`; Pester `resposta n, vazia ou lixo recusa` |
| RF-05 | Atendido | `test_backup_dest_directory`, `test_backup_dest_suffix_when_exists`, `test_backup_dest_link_not_dereferenced`; Pester `sufixo -2 e -3` e `backup de link para outro clone` |
| RF-06 | Atendido | `test_install_without_terminal_skips_with_adopt_hint`; Pester `sem terminal e sem --adopt` |
| RF-07 | Atendido | `test_adopt_flag_adopts_without_asking`, `test_adopt_flag_never_touches_foreign_other`; Pester `--adopt adota com backup` |
| RF-08 | Atendido | `test_act_on_dest_foreign_other_untouched`, `test_classify_dest_foreign_other`; Pester `outra skill no destino é pulada` |
| RF-09 | Atendido | `test_install_all_skipped_no_pronto`, `test_install_no_skip_exit_zero`, `test_adopt_backup_failure_does_not_install`, `test_install_failure_becomes_skipped`; 7.2 com código 0 sem pulos |
| RF-10 | Atendido | `test_dry_run_five_classes_changes_nothing`, `test_dry_run_foreign_adr_std_adopt_and_ask`; 7.1 no perfil real (listagem idêntica antes e depois); Pester `dry-run mostra classe e ação por destino` |
| RF-11 | Atendido | `test_state_agent_mode_fourth_column`, `test_status_mode_per_agent`, `test_update_skips_link_mode_destinations`, `test_update_installer_code_4_still_migrates`, `test_uninstall_adopted_link_keeps_target_and_backup`; `status` real da 7.2 mostra o modo de cada agente |
| RF-12 | Atendido | `test_install_shared_dest_single_classification`, `test_dry_run_shared_dest_single_line`; Pester `pasta compartilhada ... uma vez só`; 7.1 (Gemini CLI e OpenCode em uma linha) |
| RF-13 | Atendido com limitação | Pester no Windows 11 real (NTFS, `pwsh` 7.6.9): 76 passaram, 0 falharam, incluindo junção, cadeia, ciclo, 10 contra 11 links e caminho físico. Limitação: o job `windows-latest` do CI ainda não rodou (exige push, sem autorização). RF-13 só fecha com esse job verde |
| RF-14 | Atendido | README (seção 6.4, tabela de comandos, troubleshooting), `CHANGELOG.md` em `[Não lançado]`, `test_help_lists_adopt`; `SKILL.md` não cita a instalação |
| SEG-01 | Atendido | `test_adopt_refused_leaves_no_trace`, `test_adopt_backup_failure_does_not_install`, `test_adopt_install_failure_restores_original`; Pester de caminho físico (RED: sem a correção o link correto vira `foreign-adr-std`) |
| SEG-02 | Atendido | `test_resolve_link_chain_cycle`, `..._limit`, `..._broken`; Pester `ciclo de links` e `10 links resolve e 11 links falha` |
| SEG-03 | Atendido | `test_skill_name_of_text_only`, `..._limit_20_lines`, `..._bom_and_crlf` |
| SEG-04 | Atendido | `test_install_unknown_agent_still_code_2`; destinos só de `agents.tsv`; a 7.2 escreveu apenas sob o perfil, sem `sudo` |
| SEG-05 | Atendido | perfis temporários nas suítes Bash e Pester; sem credenciais, push, release ou deploy; exceção de rede da VM de testes registrada na 5.3 |

Limitações abertas: (1) RF-13 depende do CI `windows-latest` após o push; (2) nomes curtos 8.3 no Windows não são expandidos (cai em `foreign-adr-std` e pede confirmação, nunca apaga sem backup); (3) link para outro clone cai em `foreign-adr-std` (D-18, aceito). Nenhuma discrepância aberta entre requisitos, design e tarefas.

## Marcos de commit (sempre com autorização expressa)

1. Etapas 0 a 4 e a ajuda (código Bash, testes e CHANGELOG parcial).
2. Etapa 5 (PowerShell e Pester), com o CI Windows verde antes de fechar o RF-13.
3. Etapa 6 e fechamento da auditoria.

## Rastreabilidade

| Requisito | Tarefas |
|---|---|
| RF-01, RF-02 (inclui link que continua link) | 1.3, 3.2 |
| RF-03 | 1.1, 1.3, 1.4, 3.2, 7.1, 7.2 |
| RF-04, RF-05 | 3.1, 4.1 |
| RF-06, RF-07 | 4.2 |
| RF-08 | 1.3, 3.2, 4.2 |
| RF-09 (inclui `backup-falhou`) | 3.1, 3.3, 7.2 |
| RF-10 | 4.3, 7.1 |
| RF-11 | 2.1, 2.2, 4.4 |
| RF-12 | 3.3 |
| RF-13 | 5.1, 5.2, 5.3 |
| RF-14 | 4.5, 6.1, 6.2 |
| SEG-01 | 3.1, 4.1, 4.2 |
| SEG-02 | 1.1 |
| SEG-03 | 1.2 |
| SEG-04 | 3.2 e 5.2 (destinos só de `agents.tsv`); teste em 3.3 de que `--agent` desconhecido continua com código 2 e nenhum caminho livre é aceito |
| SEG-05 | convenção de testes; 4.6, 5.3 |

## Auditoria 360° (Requisitos ↔ Design ↔ Tarefas) — 2026-10-27

Cobertura: os 14 RF e os 5 SEG têm tarefa de RED e de validação; o design cobre todos. Achados e resolução:

| # | Achado | Resolução |
|---|---|---|
| 1 | Segunda execução de `install` converteria o link adotado em cópia (contra RF-03) | RF-02 estendido; D-16 no design; RED em 3.2 |
| 2 | `update` pular destinos `link` só existia no design | RF-11 explicita; D-10 mantida; teste em 4.4 |
| 3 | Código 4 faria o `update` perder a migração de ADRs | RF-11 e D-17; teste em 4.4 |
| 4 | Eram quatro links manuais, não três | Corrigidos `requirements.md` (causa-raiz) e 7.1 |
| 5 | Motivo `backup-falhou` fora do contrato | RF-09 e contrato do `install` atualizados; teste em 3.1 e 3.3 |
| 6 | `--dry-run` sem regra para adoção interativa | RF-10 e contrato; RED em 4.3 |
| 7 | Link para outro clone cai em `foreign-adr-std` | Registrado como comportamento aceito (D-18 e requisitos) |
| 8 | Motivo `falha-na-instalacao` (cópia ou link falhou) existia no código, fora do contrato (achado na 3.3) | RF-09 e lista de motivos do design atualizados; teste em 3.3 |

Resultado: sem discrepância aberta entre os três artefatos. Gate 3 aprovado pelo responsável em 2026-10-27 ("aprovado" na sessão).

Auditoria da implementação (2026-10-27), discrepância 2 — carregamento dos testes por `sed`+`eval`: resolvida. Evidência: a última linha de `bin/adr-std` passou a `[ -n "${ADR_STD_LIB:-}" ] || { main "$@"; exit $?; }` (mesma linha, comentário preservado); `tests/test_cli.sh` carrega as funções com `load_lib` (`ADR_STD_LIB=1 . bin/adr-std`) e não tem mais `eval` nem `sed -n`. RED: `lib_hook_loads_without_running` falhou (o script executava `main` e imprimia a ajuda); GREEN: passa, e confirma que `adr-std version` e o código 2 de comando desconhecido seguem iguais. `bash tests/test_cli.sh`: 99 passaram, 0 falharam; `python3 -m unittest discover tests`: 143 OK; `bash tests/gate.sh static`: ok.

- Discrepância extra (teste instável, 2026-10-27): `start_server` de `tests/test_cli.sh` guardava o PID do subshell e `stop_server` não encerrava o `python3 -m http.server`; centenas de servidores vazaram e causavam `servidor de teste não subiu`. Correção: `exec python3 ...` no subshell, para o PID ser o do servidor. Evidência: `bash tests/test_cli.sh` → 123 passaram, 0 falharam; servidores `http.server` vazados antes e depois da suíte: 361 e 361 (sem crescimento). Os servidores antigos já não existem: `pgrep -af http.server` (2026-10-27) não lista nenhum, sem necessidade de `pkill`.
