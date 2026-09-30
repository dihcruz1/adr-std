# Requisitos — adr-std v1.0: distribuição e instalação da skill

| Campo | Detalhe |
|---|---|
| **Data** | 2026-09-30 |
| **Status** | Gate 1 aprovado (2026-09-30), incluindo as propostas P-01 a P-09 |
| **Solicitante** | Diego Cruz |
| **Escopo** | Versão 1.0 da skill `adr-std`: repositório, instaladores, comando `adr-std` (gestão), README e publicação |

## 1. Contexto

A skill `adr-std` (guia da ISO/IEC/IEEE 42010:2022, template, checklist e `check_adr.py`) existe e está
instalada só na máquina do solicitante. O objetivo é distribuí-la a colegas de trabalho, instalável em
qualquer computador e em vários agentes de código, com atualização e remoção simples.

## 2. Decisões registradas

### 2.1 Fechadas pelo solicitante

| # | Decisão |
|---|---|
| D-01 | Skill própria, global, que segue a ISO/IEC/IEEE 42010:2022 e funciona em qualquer agente que leia `SKILL.md` |
| D-02 | Nome `adr-std` (sem "ISO" no nome, para não usar a marca) |
| D-03 | Pasta principal do projeto: `/Fusiondev/Code/Skills/adr-std` (repositório git) |
| D-04 | Guia detalhado, cobrindo a norma inteira, com palavras próprias; a cópia da norma não entra no repositório |
| D-05 | Instruções em pt-BR; `description` do `SKILL.md` com termos em pt-BR e inglês |
| D-06 | Script de verificação incluído; regras também em texto (`checklist.md`) |
| D-07 | Numeração padrão de ADRs `NNNN-kebab-case.md`; a convenção do projeto do usuário prevalece |
| D-08 | Distribuir a colegas; repositório no GitHub na conta `dihcruz1` |
| D-09 | Quatro formas de instalação: zip com duplo clique, uma linha (`curl`/`irm`), `git clone` e manual |
| D-10 | `README.md` completo (instalação e tudo sobre a skill) na raiz e dentro do zip; instalação manual descrita |
| D-11 | Comando `adr-std` instalado no computador, com escolha de agentes (`--agent claude-code codex` ou nome direto) |
| D-12 | Suportar vários agentes além de Claude Code, Codex e Gemini (OpenCode, Antigravity, Continue e outros) |
| D-13 | Comandos no agente no formato `/adr-std-<ação>`: `create`, `supersede`, `review`, `organize`, `link`, `audit`, `check`, `ask`, `new`, `list`, e `/adr-std` genérico |
| D-14 | `create` e `supersede` em conversa guiada, com perguntas e sugestões no meio e no fim; `--ask N` define perguntas por rodada; `--quick` não faz perguntas |
| D-15 | Mesmos comandos no terminal e no agente, incluindo `new` e `list` |
| D-16 | Comandos mecânicos (`new`, `list`, `check`, `link`, `organize --dry-run`) em Python, com aviso quando não houver Python |
| D-17 | Comandos de conversa no terminal abrem um agente: indicado no comando (nome direto ou `--agent`), por padrão configurado (`adr-std config agent`) ou escolhido num menu que lembra a última escolha |
| D-18 | Entrega em versões: v1.0 (instalação e gestão), v1.1 (comandos `/adr-std-*` no agente), v1.2 (comandos mecânicos no terminal), v1.3 (repasse para agentes pelo terminal, menu com memória e `config agent`) |
| D-19 | Subpasta `skill/` contém o que é instalado nos agentes; o restante do repositório é distribuição |

### 2.2 Propostas do agente adotadas por "pode executar" (confirmar no Gate 1)

| # | Proposta |
|---|---|
| P-01 | Repositório **público** `github.com/dihcruz1/adr-std` (necessário para `curl` e zip sem login) |
| P-02 | Licença MIT |
| P-03 | A instalação baixa a **última release**; `--version vX.Y.Z` fixa uma versão |
| P-04 | Lista inicial de 15 agentes (seção 5 do `design.md`); lista em arquivo de dados `agents.tsv` |
| P-05 | Uma pasta por agente, sem duplicata; `~/.agents/skills` para agentes que a leem |
| P-06 | Cópia para colegas; `--link` para desenvolvimento |
| P-07 | Instalador pergunta antes de alterar o PATH |
| P-08 | Nomes curtos das opções da v1.1: `-a N` (`--ask N`) e `-k` (`--quick`) |
| P-09 | `CONTRIBUTING.md` separado do README |

### 2.3 Pendências que não bloqueiam a v1.0 no Linux

- Quem testa em Windows e macOS (R-12).
- Confirmação de que a publicação em conta pessoal não conflita com regra da Unifesp.

## 3. Linguagem Ubíqua

| Termo | Significado |
|---|---|
| **Skill** | Conteúdo de `skill/` (`SKILL.md`, `references/`, `scripts/`), instalado com o nome `adr-std` |
| **Agente** | Ferramenta de IA de código que lê skills (Claude Code, Codex, Gemini CLI...) |
| **Pasta de skills do agente** | Diretório global onde o agente procura skills |
| **Instalador** | `install.sh` ou `install.ps1`: coloca o comando `adr-std` no computador e chama `adr-std install` |
| **Comando `adr-std`** | Programa no PATH que instala, atualiza, remove e consulta a skill |
| **Estado** | Arquivo que registra versão, agentes e pastas instaladas |
| **Release** | Versão publicada no GitHub com `adr-std.zip` e `adr-std.zip.sha256` |

## 4. Requisitos funcionais (EARS)

- **RF-01 (evento):** QUANDO o usuário executar o instalador por qualquer das três formas automáticas, o sistema DEVE instalar o comando `adr-std` e iniciar `adr-std install`.
- **RF-02 (evento):** QUANDO o usuário executar `adr-std install` sem agentes, o sistema DEVE listar os agentes encontrados no computador e deixar o usuário escolher um ou mais.
- **RF-03 (evento):** QUANDO o usuário indicar agentes (`--agent a b`, `--agent a,b` ou nomes diretos), o sistema DEVE instalar só nesses, sem menu.
- **RF-04 (ubíquo):** O sistema DEVE instalar a skill com o nome de pasta `adr-std` na pasta de skills de cada agente escolhido.
- **RF-05 (indesejado):** SE um agente ler mais de uma pasta de skills já usada pela instalação, ENTÃO o sistema NÃO DEVE instalar duas vezes para esse agente.
- **RF-06 (indesejado):** SE já existir na pasta de destino um `adr-std` que o sistema não instalou, ENTÃO o sistema NÃO DEVE sobrescrevê-lo e DEVE avisar.
- **RF-07 (evento):** QUANDO o usuário executar `adr-std update`, o sistema DEVE obter a última release (ou a versão de `--version`), conferir o checksum e reinstalar nos agentes registrados, atualizando também o comando.
- **RF-08 (evento):** QUANDO o usuário executar `adr-std uninstall`, o sistema DEVE remover a skill só das pastas registradas no estado (todas, ou as de `--agent`).
- **RF-09 (evento):** QUANDO o usuário executar `adr-std self-uninstall`, o sistema DEVE remover a skill, o estado, a linha de PATH que ele acrescentou e o próprio comando.
- **RF-10 (evento):** QUANDO o usuário executar `adr-std status`, o sistema DEVE mostrar versão instalada, agentes, integridade das pastas e se há versão mais nova.
- **RF-11 (evento):** QUANDO o usuário executar `adr-std agents`, o sistema DEVE listar os agentes suportados, a pasta de cada um e quais existem no computador.
- **RF-12 (evento):** QUANDO o usuário executar `adr-std check <alvo>`, o sistema DEVE executar `check_adr.py`; SE Python 3 não existir, ENTÃO DEVE avisar e sugerir o checklist manual.
- **RF-13 (opção):** ONDE `--dry-run` for informado, o sistema DEVE mostrar as ações sem alterar arquivos.
- **RF-14 (opção):** ONDE `--link` for informado, o sistema DEVE criar links para a pasta `skill/` do repositório em vez de copiar.
- **RF-15 (indesejado):** SE a pasta do comando não estiver no PATH, ENTÃO o sistema DEVE perguntar antes de alterar o arquivo de inicialização do shell (ou o PATH do usuário no Windows) e, sem permissão, mostrar a instrução.
- **RF-16 (indesejado):** SE o terminal não for interativo e nenhum agente for indicado, ENTÃO o sistema DEVE falhar com mensagem pedindo `--agent` ou `--all`.
- **RF-17 (ubíquo):** O pacote zip DEVE conter `README.md`, atalhos de instalar e desinstalar para Windows, macOS e Linux, os instaladores, `VERSION` e `skill/`.
- **RF-18 (ubíquo):** O `README.md` DEVE descrever a skill (o que faz, o que garante, limites da norma, exemplos, template, verificação), as quatro formas de instalação, os comandos, atualizar, remover, problemas comuns, sobre a norma, licença.
- **RF-19 (evento):** QUANDO uma tag `vX.Y.Z` for criada, o pipeline DEVE gerar e publicar `adr-std.zip` e `adr-std.zip.sha256` somente se o gate de segurança passar.

## 5. Critérios de aceite (Gherkin)

```gherkin
Cenário: instalação escolhendo agentes no menu
  Dado um computador com Claude Code e Codex
  Quando o usuário executa "adr-std install" e escolhe "1 2"
  Então a skill existe em ~/.claude/skills/adr-std e ~/.codex/skills/adr-std
  E o estado registra os dois agentes

Cenário: instalação indicando agente
  Quando o usuário executa "adr-std install claude-code"
  Então nenhum menu é mostrado e só ~/.claude/skills/adr-std é criado

Cenário: sem duplicata
  Dado Gemini CLI e OpenCode escolhidos
  Quando a instalação termina
  Então a skill existe uma única vez, em ~/.agents/skills/adr-std

Cenário: não sobrescreve o que não instalou
  Dado uma pasta ~/.claude/skills/adr-std que o estado não registra
  Quando o usuário executa "adr-std install claude-code"
  Então a pasta não é alterada e um aviso é mostrado

Cenário: atualização com checksum inválido
  Dado uma release cujo checksum não confere
  Quando o usuário executa "adr-std update"
  Então nada é alterado e o erro é mostrado

Cenário: remoção só do que foi instalado
  Quando o usuário executa "adr-std uninstall"
  Então só as pastas do estado são removidas

Cenário: simulação
  Quando o usuário executa "adr-std install --all --dry-run"
  Então nenhum arquivo é criado ou alterado
```

## 6. Requisitos não funcionais

- **RNF-01:** Instalação sem privilégios de administrador em todos os sistemas.
- **RNF-02:** Instalação sem dependências além de `curl` ou Git (Linux e macOS) e PowerShell (Windows). Python só para `check`.
- **RNF-03:** Operações idempotentes: repetir `install` ou `update` não gera erro nem duplicata.
- **RNF-04:** Mensagens em pt-BR; comandos, opções e arquivos em inglês.
- **RNF-05:** A lista de agentes é dado (`agents.tsv`), não código.

## 7. Segurança (DevSecOps)

| # | Risco | Tratamento |
|---|---|---|
| R-01 | Execução de script remoto sem leitura (`curl \| bash`) | Script curto e legível; baixa só de `github.com/dihcruz1/adr-std`; README mostra como ler antes |
| R-02 | Pacote adulterado | Checksum SHA-256 conferido antes de instalar (RF-07) |
| R-03 | Sobrescrever ou apagar arquivos do usuário | Só altera pastas registradas no estado; não sobrescreve o que não instalou (RF-06, RF-08) |
| R-04 | Escalada de privilégio | Nunca pede `sudo` nem administrador (RNF-01) |
| R-05 | Alteração silenciosa do shell | Pergunta antes de alterar PATH; remove no `self-uninstall` (RF-15, RF-09) |
| R-06 | Vazamento da norma licenciada | Gate do pipeline bloqueia arquivos da norma (nomes `42010*` com extensão `.pdf`/`.docx`, arquivos acima de 1 MB) |
| R-07 | Injeção via argumentos | Nomes de agente validados contra `agents.tsv`; caminhos entre aspas |
| R-08 | Publicação sem verificação | Release só com gate verde (RF-19) |
| R-09 | Credenciais | O projeto não manuseia credenciais; publicação usa o token do próprio GitHub Actions |

## 8. Fora do escopo da v1.0

Comandos `/adr-std-*` nos agentes (v1.1); `new`, `list`, `link`, `organize` no terminal (v1.2); repasse
para agentes pelo terminal, menu com memória e `config agent` (v1.3); instaladores `.exe`, `.msi`,
`.pkg` ou `.deb`.
