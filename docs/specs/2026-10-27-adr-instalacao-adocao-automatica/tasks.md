# Tarefas — instalação com adoção automática de pastas existentes

Data: 2026-10-27. Requisitos: `requirements.md` (Gate 1 aprovado); design: `design.md` (Gate 2 aprovado). Marque `[x]` só com evidência real (comando e resultado) no campo Evidência de cada tarefa.

Convenção: cada tarefa de código segue RED → GREEN → REFACTOR, em `tests/test_cli.sh` (Bash) e `tests/test_cli.ps1` (Pester), com `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `ADR_STD_TTY` e `APPDATA` isolados em diretório temporário. Comandos rodam da raiz do repositório. Sem rede, push, release ou deploy; commit só com autorização expressa do responsável. Antes de cada tarefa: `git status`, preservando mudanças alheias.

Execução proposta: uma tarefa por vez, com subagente, nas etapas 1 a 4 (todas editam `bin/adr-std`, então não são paralelas). As etapas 5 (PowerShell) e 6 (documentação) só dependem do contrato fechado na etapa 4 e podem rodar em paralelo entre si.

## Etapa 0 — Preparação

- [ ] 0.1 Criar a branch `feat/instalacao-adocao-automatica` a partir de `develop`, sem tocar nos arquivos alheios.
  - Validação: `git branch --show-current` e `git status --short`.
- [ ] 0.2 Medir a linha de base: `bash tests/test_cli.sh`, `python3 -m unittest discover tests` e `bash tests/gate.sh static`; registrar contagens.
  - Depende de 0.1. Validação: comandos acima com saída 0 e totais anotados na Evidência.

## Etapa 1 — Resolução de links e classificação (somente leitura)

- [ ] 1.1 `resolve_link_chain <pasta>`: segue `readlink` em laço, máximo de 10 saltos, ciclo e link quebrado retornam falha; imprime o destino final.
  - RED: casos link direto, encadeado de 2 e 3 níveis, ciclo, 11 saltos e link quebrado. GREEN: o laço. REFACTOR: reaproveitar na verificação de `owned_by_us`.
  - Atende D-6, SEG-02. Depende de 0.2. Validação: `bash tests/test_cli.sh` (casos novos).
- [ ] 1.2 `skill_name_of <pasta>`: lê o frontmatter do `SKILL.md` (primeiro bloco `---`, até 20 linhas) e imprime `name`; sem arquivo ou sem `name`, imprime vazio.
  - RED: `name: adr-std`, outro nome, sem frontmatter, sem `SKILL.md`, conteúdo com `$(...)` e crases (tratado como texto). GREEN: `sed`/`head`.
  - Atende D-11, SEG-03. Depende de 0.2. Validação: `bash tests/test_cli.sh`.
- [ ] 1.3 `classify_dest <pasta>` combinando 1.1 e 1.2 e a tabela do design; sem escrita.
  - RED: oito casos da tabela (`absent`, `ours`, `repo-link` direto e encadeado, `foreign-adr-std` cópia e link para fora, `foreign-other` por outra skill, sem `SKILL.md`, ciclo e link quebrado). GREEN: a função. REFACTOR: nenhuma.
  - Atende RF-01 a RF-04, RF-08, D-7. Depende de 1.1 e 1.2. Validação: `bash tests/test_cli.sh`; conferir que a árvore de teste não mudou após a classificação.
- [ ] 1.4 `owned_by_us` passa a usar a cadeia resolvida (D-8).
  - RED: link encadeado já registrado hoje é tratado como não nosso. GREEN: comparar o destino final com `$SRC/skill` e `$DATA_DIR/skill`. Regressão: link direto e cópia com marcador seguem nossos.
  - Depende de 1.1. Validação: `bash tests/test_cli.sh`.

## Etapa 2 — Estado com modo por agente

- [ ] 2.1 `state_add_agent` grava a 4ª coluna (`link` ou `copy`); `state_agent_mode <id>` lê e cai no `mode` global quando a coluna falta.
  - RED: estado novo e estado antigo de 3 colunas. GREEN: ajuste dos helpers; `state_agents` continua imprimindo as colunas 2 e 3.
  - Atende D-9, RF-11. Depende de 0.2. Validação: `bash tests/test_cli.sh`.
- [ ] 2.2 `cmd_status` mostra o modo por agente.
  - RED: saída com `[íntegra, link]` e `[íntegra, copy]`; estado antigo mostra o `mode` global. GREEN: ajuste do `printf`.
  - Atende RF-11. Depende de 2.1. Validação: `bash tests/test_cli.sh`.

## Etapa 3 — Ação por destino e laço sem interrupção

- [ ] 3.1 `backup_dest <pasta>`: move a pasta ou o link para `adr-std.bak-<AAAA-MM-DD>` no mesmo diretório, com sufixo `-2`, `-3` se existir, sem desreferenciar; falha de `mv` retorna erro.
  - RED: pasta, link, backup existente, falha simulada de permissão. GREEN: `mv` com laço de sufixo.
  - Atende RF-05, D-12, SEG-01. Depende de 1.3. Validação: `bash tests/test_cli.sh`; conteúdo do backup idêntico ao original.
- [ ] 3.2 `act_on_dest`: roteia por classe (instalar, atualizar, registrar sem alterar, pular `foreign-other`) e devolve o resultado (`installed`, `updated`, `adopted-in-place`, `skipped:<motivo>`).
  - RED: um caso por classe, incluindo `repo-link` sem tocar o link e sem backup, `foreign-other` intacto, mesmo com `--adopt` ainda não implementado, e `ours` em modo `link` rodado de novo sem `--link`, que deve continuar link (D-16). GREEN: a função, lendo `state_agent_mode`.
  - Atende RF-01 a RF-03, RF-08. Depende de 1.3, 1.4 e 2.1. Validação: `bash tests/test_cli.sh`.
- [ ] 3.3 `cmd_install` sem `return` no conflito: junta os resultados, roda `install_commands` sempre, imprime o resumo e devolve 4 se houver pulo.
  - RED: `--all` com conflito no primeiro agente instala os demais, cria os comandos `/adr-std-*`, lista o pulado e sai com 4; sem pulo sai com 0; dois agentes na pasta compartilhada geram uma classificação; `--agent` desconhecido segue com código 2 e nenhum destino vem de argumento livre (SEG-04); falha de backup (3.1) vira `skipped:backup-falhou` sem instalar por cima.
  - Atende RF-09, RF-12, D-14. Depende de 3.2. Validação: `bash tests/test_cli.sh`.

## Etapa 4 — Adoção e simulação

- [ ] 4.1 Adoção interativa de `foreign-adr-std`: mostra o que será substituído, lê a resposta por `read_tty_line`, só `s`/`S` confirma; confirmada, faz `backup_dest` e instala; recusa vira `skipped:recusado`.
  - RED: resposta `s`, vazia, `n` e lixo; backup criado só na confirmação. GREEN: a ação.
  - Atende RF-04, RF-05. Depende de 3.1 e 3.3. Validação: `bash tests/test_cli.sh` com `ADR_STD_TTY`.
- [ ] 4.2 `--adopt` e modo sem terminal: sem terminal e sem `--adopt`, pula com `skipped:sem-terminal` e dica de `--adopt`; com `--adopt`, adota com backup sem perguntar; `--adopt` nunca vale para `foreign-other`.
  - RED: os três casos mais `--adopt` em outra skill. GREEN: opção em `parse_args` e ramo na ação. REFACTOR: unificar mensagens de pulo.
  - Atende RF-06, RF-07, RF-08. Depende de 4.1. Validação: `bash tests/test_cli.sh`.
- [ ] 4.3 `--dry-run` imprime `<pasta>: <classe> -> <ação>` por destino sem alterar arquivos nem estado.
  - RED: comparar a árvore e o estado antes e depois, nas cinco classes; com `foreign-adr-std` a saída mostra `perguntaria`, `adotaria` ou `pularia` e nenhuma leitura de terminal acontece (`ADR_STD_TTY` apontando para um arquivo que não deve ser lido). GREEN: ramo de simulação em `cmd_install`.
  - Atende RF-10. Depende de 3.3. Validação: `bash tests/test_cli.sh`.
- [ ] 4.4 `update` pula destinos em modo `link` e informa o motivo; com código 4 do instalador, mostra o resumo, executa `maybe_migrate` e devolve 4; `uninstall` remove o link adotado sem tocar o alvo nem o `adr-std.bak-*`.
  - RED: destino `link` não é substituído pela release; instalador simulado devolvendo 4 ainda dispara a migração e o `update` sai com 4, enquanto outro código de erro (ex.: 1) continua interrompendo; `uninstall` mantém o alvo e o backup. GREEN: ajuste em `cmd_update` e `cmd_uninstall`.
  - Atende RF-11, D-10, D-17. Depende de 2.1 e 4.2. Validação: `bash tests/test_cli.sh`.
- [ ] 4.5 Ajuda do comando: `--adopt` em `cmd_help`.
  - RED: `adr-std help` cita `--adopt`. Depende de 4.2. Validação: `bash tests/test_cli.sh`.
- [ ] 4.6 Revisão independente e regressão da etapa Bash: `bash tests/test_cli.sh`, `python3 -m unittest discover tests`, `bash tests/gate.sh static`; comparar contra a linha de base de 0.2.
  - Depende de 4.1 a 4.5. Validação: totais iguais ou maiores e nenhuma falha.

## Etapa 5 — Windows (PowerShell)

- [ ] 5.1 Espelhar `Resolve-LinkChain`, `Get-SkillName` e `Get-DestClass` em `bin/adr-std.ps1` com `ReparsePoint` e `Target`, mesmo limite de 10 saltos e detecção de ciclo.
  - RED: casos Pester equivalentes a 1.1 a 1.3, com junção e link simbólico. GREEN: as funções.
  - Atende RF-13, D-15. Depende de 4.6. Validação: `pwsh -NoProfile -Command "Invoke-Pester tests/test_cli.ps1"`.
- [ ] 5.2 Espelhar estado por agente, `Backup-Dest`, ação por destino, `--adopt`, `--dry-run`, resumo e código 4, `update` pulando `link` e `status`.
  - RED: casos equivalentes a 2.1 a 4.4. GREEN: ajustes em `Install-To`, `Invoke-Install`, `Invoke-Update`, `Invoke-Status`.
  - Atende RF-13. Depende de 5.1. Validação: Pester local; a conclusão do RF-13 só vale com o job Windows do CI verde (`pwsh` portátil não prova NTFS).
- [ ] 5.3 Regressão do Pester: totais contra a linha de base de 0.2, sem testes pulados novos.
  - Depende de 5.2. Validação: Pester local.

## Etapa 6 — Documentação

- [ ] 6.1 README: a seção de instalação descreve a adoção, `--adopt`, o backup e o código 4; a cópia manual deixa de ser apresentada como caminho que o instalador recusa; troubleshooting atualizado (linha `já existe e não foi instalada pelo adr-std`).
  - Atende RF-14. Depende de 4.6. Validação: revisão cruzada contra a ajuda e `git diff --check`.
- [ ] 6.2 `CHANGELOG.md` em `[Não lançado]` (Adicionado: `--adopt`; Alterado: conflito não interrompe o laço, código 4 no fim, `update` pula links) e conferência do `SKILL.md`, alterando-o somente se citar a instalação.
  - Atende RF-14. Depende de 6.1. Validação: `git diff --check`; o `VERSION` e o número da release não mudam.
- [ ] 6.3 `ROADMAP.md` do produto e `docs/architecture/ADR/ROADMAP.md`: avaliar na auditoria se entram como versão; se entrarem, `python3 skill/scripts/check_roadmap.py docs/architecture/ADR` retorna `[OK]`.
  - Depende de 6.2. Validação: o comando acima.

## Etapa 7 — Verificação final

- [ ] 7.1 Cenário real no seu perfil, sem alterar nada: `bin/adr-std install --all --dry-run`; as classes dos quatro links manuais (`~/.agents`, `~/.claude`, `~/.codex`, `~/.continue`) aparecem como `repo-link` e as dos demais agentes encontrados (antigravity, copilot, kiro, amp) como `absent`; Gemini CLI e OpenCode aparecem na mesma pasta compartilhada (uma classificação, RF-12).
  - Atende RF-03, RF-10. Depende de 4.6. Validação: saída colada na Evidência; `git status` e o perfil inalterados.
- [ ] 7.2 Instalação real no seu perfil só com autorização expressa e pontual: `bin/adr-std install --all`; depois `bin/adr-std status` e o conteúdo de `~/.claude/commands/`.
  - Atende RF-03, RF-09. Depende de 7.1. Validação: `status` lista os agentes com o modo e os links preservados.
- [ ] 7.3 Verificar a entrega contra requisitos, design e tarefas; preencher a tabela de rastreabilidade com a evidência de cada item e fechar a auditoria 360° (Gate 3) antes de qualquer commit.
  - Depende de 5.3, 6.3 e 7.1. Validação: todos os RF e SEG com resultado `Atendido` ou limitação registrada.

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

Resultado: sem discrepância aberta entre os três artefatos. Pendente: aprovação do Gate 3 pelo responsável.
