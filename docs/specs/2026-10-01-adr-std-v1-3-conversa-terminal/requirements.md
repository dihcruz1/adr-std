# Requisitos — adr-std v1.3: comandos de conversa no terminal

| Campo | Detalhe |
|---|---|
| **Data** | 2026-10-01 |
| **Status** | Gate 1 |
| **Depende de** | v1.2 ([spec](../2026-10-01-adr-std-v1-2-comandos-terminal/)) e v1.1 (comandos de ação no agente) |
| **Contexto** | [ROADMAP.md](../../../ROADMAP.md), seção "v1.3" |

## 1. Contexto

`create`, `supersede`, `review`, `audit` e `ask` precisam de conversa com modelo de linguagem. No terminal, o
`adr-std` não conversa: **abre um agente já instalado** com um pedido inicial que chama a skill (mesmo texto dos
comandos de ação da v1.1). Quem conduz a conversa continua sendo a skill.

## 2. Decisões fechadas (ROADMAP, v1.3)

| # | Decisão |
|---|---|
| D-01 | Escolha do agente, por prioridade: (1) indicado no comando (nome ou `--agent`); (2) agente padrão (`adr-std config agent <nome>`), com aviso na tela; (3) menu com o último usado pré-selecionado (Enter repete); (4) sem terminal interativo e sem 1 nem 2: erro pedindo `--agent` |
| D-02 | Um termo é agente só se for exatamente um nome da lista **e** vier seguido da descrição; nome parecido gera sugestão ("quis dizer claude-code?"); descrição entre aspas que começa com nome de agente continua descrição |
| D-03 | O menu lista só agentes com a skill instalada que abrem pelo terminal com pedido inicial. Continue e Antigravity (só editor) ficam de fora. `--agent` = "onde instalar" no `install` e "qual agente abrir" nos comandos de conversa |
| D-04 | `config agent`: sem argumento mostra o atual; `<nome>` define; `--unset` desfaz |

### Formas de abrir cada agente (ponto a confirmar do ROADMAP, resolvido)

Verificadas com `--help` dos CLIs instalados nesta máquina (2026-10-01):

| Agente | Comando |
|---|---|
| claude-code | `claude "<pedido>"` |
| codex | `codex "<pedido>"` |
| gemini-cli | `gemini -i "<pedido>"` (`-i` mantém a sessão interativa) |
| opencode | `opencode --prompt "<pedido>"` |

Demais agentes ficam fora do menu até a forma de abrir ser confirmada (basta uma linha em `agent_launch.tsv`).

## 3. Linguagem Ubíqua

| Termo | Significado |
|---|---|
| **Comando de conversa** | `create`, `supersede`, `review`, `audit`, `ask` rodados no terminal |
| **Agente padrão** | Agente gravado por `adr-std config agent`, usado sem perguntar |
| **Último usado** | Agente da última abertura bem-sucedida, pré-selecionado no menu |
| **Pedido inicial** | Texto `Use a skill adr-std, ação "<ação>", com estes argumentos: <args>` entregue ao agente |
| **Agente elegível** | Tem skill instalada (registrada no estado) e linha em `agent_launch.tsv` |

## 4. Requisitos funcionais (EARS)

- **RF-01 (evento):** QUANDO o usuário rodar `adr-std create|supersede|review|audit|ask [agente] [opções] [descrição]`, o sistema DEVE abrir o agente escolhido com o pedido inicial correspondente.
- **RF-02 (ubíquo):** A escolha do agente DEVE seguir a prioridade D-01.
- **RF-03 (estado):** ONDE houver agente padrão e nenhuma indicação no comando, o sistema DEVE abrir o padrão e avisar na tela qual está sendo usado.
- **RF-04 (evento):** QUANDO não houver indicação nem padrão e houver terminal interativo, o sistema DEVE mostrar o menu de agentes elegíveis, com o último usado pré-selecionado; Enter repete a pré-seleção.
- **RF-05 (indesejado):** SE não houver indicação, nem padrão, nem terminal interativo, ENTÃO o sistema DEVE sair com código 3 pedindo `--agent`, sem abrir agente.
- **RF-06 (indesejado):** SE não houver agente elegível, ENTÃO o sistema DEVE sair com código 3 indicando `adr-std install`.
- **RF-07 (ubíquo):** O primeiro termo é agente só nas condições da D-02; nome parecido (sem ser exato) seguido de mais termos DEVE falhar com código 2 e sugestão; nome exato de agente que não abre pelo terminal DEVE falhar com código 2 listando os que abrem.
- **RF-08 (evento):** QUANDO o usuário rodar `adr-std config agent`, o sistema DEVE mostrar o agente padrão (ou dizer que não há); com `<nome>` válido DEVE gravá-lo; com `--unset` DEVE removê-lo; nome inválido ou não elegível DEVE falhar com código 2.
- **RF-09 (ubíquo):** Após abrir o agente, o sistema DEVE registrar o agente como "último usado".
- **RF-10 (opção):** ONDE `--ask N`/`-a N` ou `--quick`/`-k` forem informados em `create` ou `supersede`, o sistema DEVE repassá-los no pedido inicial; `N` não inteiro DEVE falhar com código 2; em outros comandos essas opções DEVEM ser recusadas (código 2).
- **RF-11 (indesejado):** SE o binário do agente não estiver no PATH, ENTÃO o sistema DEVE sair com código 5 dizendo qual binário falta.
- **RF-12 (indesejado):** `ask` sem pergunta DEVE falhar com código 2.
- **RF-13 (ubíquo):** `help` DEVE listar os cinco comandos e `config`; `VERSION` DEVE ser `1.3.0` com `CHANGELOG.md`; `agent_launch.tsv` DEVE ir no instalador e no pacote.
- **RF-14 (ubíquo):** Paridade bash/PowerShell, verificada em `tests/test_cli.sh` e `tests/test_cli.ps1`.

## 5. Requisitos não funcionais e de segurança

- **SEG-01:** O pedido é entregue ao binário como **um único argumento** (sem `eval`, sem `sh -c`, sem concatenar em linha de comando), então a descrição do usuário não vira comando de shell.
- **SEG-02:** O sistema NÃO DEVE solicitar, gravar nem exibir credenciais; abrir o agente herda o login que o próprio agente já tem.
- **SEG-03:** O binário vem só de `agent_launch.tsv` (dado versionado), nunca do texto do usuário.
- **SEG-04:** `config agent` grava só um id presente em `agent_launch.tsv`.
- **RNF-01:** Mensagens em pt-BR; o menu e `config` não dependem de Python.

## 6. Cenários (Gherkin)

```gherkin
Cenário: agente indicado no comando
  Dado a skill instalada em claude-code e codex
  Quando rodo "adr-std create codex usar Postgres"
  Então o binário codex abre com o pedido 'Use a skill adr-std, ação "create", com estes argumentos: usar Postgres'

Cenário: descrição entre aspas que começa com nome de agente
  Quando rodo 'adr-std create "codex deve ser o padrão"'
  Então o termo inteiro é descrição e o agente vem do padrão ou do menu

Cenário: nome parecido
  Quando rodo "adr-std create claude usar Postgres"
  Então erro com "quis dizer claude-code?" e nenhum agente abre

Cenário: sem terminal, sem padrão
  Quando rodo "adr-std audit" sem tty
  Então código 3 pedindo --agent

Cenário: menu com memória
  Dado último usado codex
  Quando rodo "adr-std review" e respondo Enter
  Então abre o codex
```

## 7. Riscos

| # | Risco | Mitigação |
|---|---|---|
| R-01 | Injeção de comando pela descrição | SEG-01 + teste com `$(...)` e `;` |
| R-02 | A forma de abrir um agente mudar | Dado em `agent_launch.tsv`; corrigir é editar uma linha |
| R-03 | Agente real não conversa nos testes | Testes usam binário falso no PATH; abertura real com agente é verificação manual registrada, não automática |
| R-04 | Sugestão falsa-positiva bloquear descrição legítima | Regra D-02 estrita (exato ou parecido ≥ 4 letras e sem espaço); aspas resolvem; mensagem diz como |

## 8. Fora do escopo

Agentes além dos quatro da tabela; abertura em modo não interativo (`-p`); streaming da resposta para o terminal.
