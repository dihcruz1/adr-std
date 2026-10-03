# Roadmap do adr-std

Visão curta das versões. O detalhe de cada versão fica na sua spec em `docs/specs/`; este arquivo só resume e aponta
(o contrato SDD não permite duplicar specs fora desse diretório).

| Versão | Conteúdo | Status | Spec |
|---|---|---|---|
| **1.0** | Skill (guia da 42010, template, checklist, `check_adr.py`); instalação em vários agentes; comando `adr-std` (`install`, `update`, `uninstall`, `self-uninstall`, `status`, `agents`, `check`); pacote zip; README | Em execução; tag `v1.0.0` publicada (push autorizado em 2026-10-01); falta Windows real (`--link`, `adr-std.cmd`, PATH), a release no GitHub e a validação nos agentes (9.1; E2E bloqueado por autenticação interativa) | [2026-09-30-adr-std-v1-0](docs/specs/2026-09-30-adr-std-v1-0/) |
| **1.1** | Comandos por ação dentro do agente: `/adr-std-create`, `-supersede`, `-review`, `-organize`, `-link`, `-audit`, `-check`, `-ask`, `-new`, `-list`; conversa guiada com `--ask N` e `--quick` | Concluída (bash e PowerShell; limite de perguntas é bloqueio documentado, não mecanicamente verificável) | [2026-09-30-adr-std-v1-1-comandos-no-agente](docs/specs/2026-09-30-adr-std-v1-1-comandos-no-agente/) |
| **1.2** | Comandos mecânicos no terminal, em Python: `adr-std new`, `list`, `link`, `organize --dry-run` (e o `check` que já existe), com os mesmos nomes dos comandos do agente | Concluída (bash e PowerShell; `organize` real fica fora do escopo, só `--dry-run`) | [2026-10-01-adr-std-v1-2-comandos-terminal](docs/specs/2026-10-01-adr-std-v1-2-comandos-terminal/) |
| **1.3** | Comandos de conversa no terminal (`adr-std create`, `supersede`, `review`, `audit`, `ask`) que abrem um agente escolhido; agente padrão (`adr-std config agent`) e menu com memória | Concluída (bash e PowerShell; agentes: claude-code, codex, gemini-cli, opencode; abertura com agente real é verificação manual, ver `tests/cenarios.md`) | [2026-10-01-adr-std-v1-3-conversa-terminal](docs/specs/2026-10-01-adr-std-v1-3-conversa-terminal/) |
| **1.4** | `adr-std config path` grava a pasta de ADRs na config global pela CLI (nível 4 do ADR-1); fecha a etapa 2 do ADR-1 | Concluída (bash e PowerShell; a leitura da config global já existia desde a v1.2) | [2026-10-02-adr-std-v1-4-config-path](docs/specs/2026-10-02-adr-std-v1-4-config-path/) |
| **2.0** | Numeração dos ADRs sem zeros à esquerda (`<N>-<slug>.md`, `ADR-<N>`, ADR-4); `adr-std migrate` e migração mostrada pelo `update` (plano por omissão, aplicação com confirmação); `check_roadmap.py` com `--name-pattern` | Concluída (bash; PowerShell escrito em paridade, Pester a validar no CI do Windows) | [2026-10-03-adr-numeracao-sem-zeros](docs/specs/2026-10-03-adr-numeracao-sem-zeros/) |

A spec de uma versão só é aberta quando a versão começa, para não escrever requisitos que ainda podem mudar.

## Decisões já tomadas para as versões futuras

### v1.1 — comandos dentro do agente
- Formato `/adr-std-<ação>`, um comando por ação, mais o `/adr-std <texto livre>` genérico. A lógica fica toda na skill; cada
  comando é um arquivo pequeno que só chama a skill com a ação definida.
- `create` e `supersede` conduzem uma conversa: perguntas e sugestões no meio e no fim. `--ask N` (`-a N`) define quantas
  perguntas por rodada (padrão 3, de 1 a 10). `--quick` (`-k`) não faz nenhuma pergunta.
- `/adr-std-new <título>` cria o arquivo vazio (próximo número, `Proposto`, campos `pendente`), sem perguntas; `/adr-std-list [pasta]`
  lista os ADRs. Ambos existem no agente já na v1.1; no terminal só na v1.2.
- Codex: usa `$adr-std <ação>`, sem comandos separados. Antigravity: sem comandos (os *workflows* dele serão desativados
  em 2026-11-01). Detalhes na spec da v1.1.

### v1.2 — terminal, parte mecânica
- Os mesmos nomes de comando no terminal e no agente. O que não precisa de modelo de linguagem roda direto no terminal.
- Em Python, reaproveitando o código do `check_adr.py`. Sem Python, o comando avisa e indica o checklist manual.
- `adr-std new` cria o arquivo do ADR vazio (próximo número, status `Proposto`, campos `pendente`), sem perguntas.
  `adr-std list` mostra os ADRs de uma pasta com ID, título, status e data.

### v1.3 — terminal, parte de conversa
- Os comandos que precisam de conversa abrem um agente. Escolha do agente, por ordem de prioridade:
  1. o agente indicado no comando (`adr-std create claude-code "..."` ou `--agent claude-code`);
  2. o agente padrão definido com `adr-std config agent <nome>` (`--unset` desfaz; sem argumento mostra o atual), com
     aviso na tela dizendo qual está sendo usado;
  3. um menu com os agentes que servem, com o último usado pré-selecionado (Enter repete);
  4. sem terminal interativo e sem 1 ou 2: erro pedindo `--agent`.
- Um termo só é tratado como agente se for exatamente um nome da lista e vier seguido da descrição; nome parecido gera
  sugestão ("quis dizer claude-code?"). Descrição entre aspas que começa com o nome de um agente continua sendo descrição.
- O menu só lista agentes com a skill instalada que abrem pelo terminal com um pedido inicial (Continue e Antigravity, que
  são só de editor, ficam de fora). `--agent` significa "onde instalar" no `install` e "qual agente abrir" nos comandos
  de conversa.

## Pontos a confirmar antes de cada versão

- **v1.1:** pasta global de prompts do Continue; como cada agente repassa os argumentos do comando; como medir nos
  testes que o agente respeita o limite de perguntas. (Decidido: `new` e `list` existem no agente já na v1.1.)
- **v1.3 (resolvido em 2026-10-01):** forma de abrir confirmada com `--help` de `claude`, `codex`, `gemini` (`-i`) e `opencode` (`--prompt`); entram no menu só esses quatro. Os demais agentes seguem de fora até a forma ser confirmada (uma linha em `agent_launch.tsv`).
