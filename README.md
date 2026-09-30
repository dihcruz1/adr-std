# adr-std

Skill para agentes de código que **cria, revisa e organiza ADRs** (registros de decisão de arquitetura) segundo a
**ISO/IEC/IEEE 42010:2022**, cláusula 6.10. Funciona em qualquer agente que leia o formato aberto `SKILL.md`
(Claude Code, Codex, Gemini CLI, OpenCode e outros) e traz um comando de terminal, o `adr-std`, para instalar,
atualizar e remover a skill.

> **Independente.** Esta skill não tem endosso da ISO, do IEC nem do IEEE, e **não contém o texto da norma**:
> o guia é um resumo com palavras próprias que cita as cláusulas. Quem quiser ler a norma precisa obtê-la por
> conta própria.

## Sumário

1. [O que a skill faz](#1-o-que-a-skill-faz)
2. [O que ela garante (e o que não garante)](#2-o-que-ela-garante-e-o-que-não-garante)
3. [Como pedir ao agente](#3-como-pedir-ao-agente)
4. [O template do ADR](#4-o-template-do-adr)
5. [Verificação automática](#5-verificação-automática)
6. [Instalação](#6-instalação)
7. [Escolher os agentes](#7-escolher-os-agentes)
8. [Comandos do terminal](#8-comandos-do-terminal)
9. [Confirmar que funcionou](#9-confirmar-que-funcionou)
10. [Atualizar e remover](#10-atualizar-e-remover)
11. [Problemas comuns](#11-problemas-comuns)
12. [Sobre a norma](#12-sobre-a-norma)
13. [Limitações e próximas versões](#13-limitações-e-próximas-versões)
14. [Arquivos da skill](#14-arquivos-da-skill)
15. [Licença e contribuição](#15-licença-e-contribuição)

---

## 1. O que a skill faz

Depois de instalada, o agente passa a saber conduzir quatro tarefas quando você as pede em linguagem natural:

| Tarefa | Exemplo de pedido |
|---|---|
| **Criar** um ADR | "Crie um ADR para a decisão de usar PostgreSQL em vez de MongoDB." |
| **Revisar ou reorganizar** ADRs | "Revise os ADRs de `docs/architecture/ADR` e padronize a numeração." |
| **Auditar** a descrição de arquitetura | "Nosso projeto está conforme a ISO 42010?" |
| **Tirar dúvidas** sobre a norma | "O que a 42010 exige no registro de decisões?" |

Ao **criar** um ADR, o agente conduz uma conversa: entende a decisão, confere se ela é essencial e única, pergunta o que
falta (decisores, data, alternativas, motivo de cada rejeição), sugere pontos que você não citou, monta o rascunho e
roda a verificação. O status inicial é sempre `Proposto`; só o decisor aprova.

## 2. O que ela garante (e o que não garante)

O agente segue estas regras, todas escritas em `skill/references/guia-42010.md`:

- **Uma decisão por ADR.** Duas decisões viram dois ADRs relacionados.
- **Alternativas rejeitadas registradas, com o motivo.** A norma recomenda esse registro.
- **Decisores, autoridade que aprova e três datas** (decisão, aprovação, modificação).
- **Relações entre ADRs com tipo** (restringe, refina, conflita com, substitui...).
- **Não inventa** decisores, datas, alternativas nem justificativas: pergunta ou marca `pendente`.
- **Não apaga** ADR aceito ou rejeitado; substitui por um novo e liga os dois.
- **Não marca `Aceito` sozinho** e **não faz commit** nem renomeia arquivos sem a sua autorização.
- **Diz de onde vem cada exigência:** norma (com a cláusula), projeto ou skill.

**O que a skill não garante:** conformidade do seu projeto com a 42010. ADRs cobrem a cláusula 6.10 (decisões e
justificativa) e parte da 6.1 (identificação). A conformidade da **descrição de arquitetura** exige a cláusula 6
inteira (stakeholders, concerns, viewpoints, views, correspondências). Por isso o agente pode dizer que um ADR
"atende às exigências da 6.10", mas nunca que o projeto "está conforme a 42010", nem alegar certificação ou endosso.

## 3. Como pedir ao agente

Peça em linguagem natural; a skill é ativada pelo assunto do pedido. Exemplos:

```
Crie um ADR para trocar o Redis por Memcached no cache de sessão. O motivo é o custo.
Revise os ADRs da pasta docs/architecture/ADR contra a norma e me diga o que falta.
Este ADR substitui o ADR-0003: crie o novo e marque o antigo como substituído.
Registre que o ADR-0004 refina o ADR-0002.
Audite a descrição de arquitetura do projeto contra a cláusula 6 da 42010.
O que a norma diz sobre justificar uma decisão?
```

Para chamar a skill pelo nome, quando o agente permitir: `/adr-std` no Claude Code e `$adr-std` no Codex. Na versão
atual não existem comandos separados por ação; veja a [seção 13](#13-limitações-e-próximas-versões).

## 4. O template do ADR

Arquivo: `skill/references/template-madr.md`. Nome do arquivo do ADR: `NNNN-titulo-em-kebab-case.md` (4 dígitos). Se o
seu projeto tiver outra convenção, ela prevalece.

| Campo ou seção | O que registra |
|---|---|
| **ID, Status** | Identificação única; `Proposto`, `Aceito`, `Rejeitado`, `Substituído por ADR-NNNN` ou `Obsoleto` |
| **Data da decisão, Aprovado em, Modificado em** | Quando foi tomada, aprovada e alterada |
| **Decisores, Autoridade que aprova** | Quem decidiu e quem aprova |
| **Stakeholders afetados, Concerns e aspectos, Elementos afetados** | Quem e o que a decisão toca |
| **Relações com outras decisões** | Tipo da relação e o ADR relacionado |
| **Contexto, Restrições e suposições, Fatores de decisão** | O que força a decisão |
| **Opções consideradas, Decisão, Justificativa, Prós e contras** | Alternativas (com motivo de rejeição), escolha e por quê |
| **Consequências, Verificação, Limitações deste registro** | Efeitos, como saber se acertou, o que ficou de fora |
| **Histórico de modificações, Referências** | Alterações depois da aprovação e fontes |

`Status` descreve a decisão, não o andamento da implementação: o andamento vai para um documento de acompanhamento.

## 5. Verificação automática

O comando `adr-std check` confere os itens mecânicos do checklist (formato do nome, status, datas, seções obrigatórias,
opções rejeitadas com motivo, instruções do template esquecidas). Precisa de Python 3.

```bash
adr-std check docs/architecture/ADR                         # uma pasta inteira
adr-std check docs/architecture/ADR/0001-cache-de-sessao.md  # um arquivo
adr-std check docs/architecture/ADR --name-pattern '^(\d+)-.+\.md$'   # numeração diferente da padrão (ex.: 1-titulo.md)
```

Códigos de saída: `0` passou; `1` falhou um requisito da norma; `2` falharam só recomendações ou regras da skill. O
resto do checklist (`skill/references/checklist.md`) exige leitura: o script não julga, por exemplo, se a justificativa
é boa. Sem Python, o `adr-std check` avisa e indica o checklist manual.

## 6. Instalação

Escolha **uma** das quatro formas. As três primeiras instalam também o comando `adr-std`.

### 6.1 Pacote zip (duplo clique)

Para quem não usa terminal nem Git.

1. Baixe `adr-std.zip` da [última versão](https://github.com/dihcruz1/adr-std/releases/latest/download/adr-std.zip).
2. Extraia a pasta.
3. Abra o instalador do seu sistema:

| Sistema | O que fazer |
|---|---|
| **Windows** | Duplo clique em `instalar-windows.bat` |
| **macOS** | Botão direito em `instalar-mac.command` → **Abrir** |
| **Linux** | No terminal, dentro da pasta: `bash instalar-linux.sh` |

Uma janela lista os agentes encontrados e pergunta em quais instalar. Para remover, use `desinstalar-*` da mesma pasta.

**Avisos de segurança esperados**, porque o instalador não tem assinatura digital:

- **Windows:** tela "O Windows protegeu o computador" → **Mais informações** → **Executar assim mesmo**.
- **macOS:** "não pode ser aberto porque é de um desenvolvedor não identificado" → use botão direito → **Abrir**.
- Confira o arquivo baixado, se quiser: o `adr-std.zip.sha256` da mesma página traz o valor correto
  (`sha256sum adr-std.zip` no Linux; `shasum -a 256 adr-std.zip` no macOS; `Get-FileHash adr-std.zip` no Windows).

### 6.2 Uma linha no terminal

```bash
# Linux e macOS
curl -fsSL https://raw.githubusercontent.com/dihcruz1/adr-std/main/install.sh | bash
curl -fsSL https://raw.githubusercontent.com/dihcruz1/adr-std/main/install.sh | bash -s -- --agent claude-code codex
```

```powershell
# Windows (PowerShell)
irm https://raw.githubusercontent.com/dihcruz1/adr-std/main/install.ps1 | iex
```

O instalador baixa a **última versão publicada**, confere o checksum e só então instala. Para fixar uma versão, use
`--version v1.0.0` (Linux e macOS).

> **Cuidado:** esta forma executa um script da internet sem que você o leia antes. Se preferir ler primeiro:
> `curl -fsSL <endereço acima> -o install.sh`, abra o arquivo e depois rode `bash install.sh`. O script é curto, baixa
> apenas de `github.com/dihcruz1/adr-std`, não usa `sudo` e só escreve dentro da sua pasta pessoal.

### 6.3 Git

```bash
git clone https://github.com/dihcruz1/adr-std.git
cd adr-std
./install.sh                          # Windows: .\install.ps1
./install.sh --agent claude-code      # já escolhendo o agente
```

Para atualizar: `git pull` e `adr-std update`.

### 6.4 Manual (sem instalador)

Para quem não quer ou não pode rodar scripts. **Esta forma não instala o comando `adr-std`.**

1. Baixe e extraia o zip.
2. Ache a pasta de skills do seu agente na [tabela da seção 7](#7-escolher-os-agentes).
3. Crie essa pasta, se não existir.
4. Copie a pasta **`skill`** inteira para dentro dela e **renomeie para `adr-std`** (não copie só o `SKILL.md`: a skill
   usa os arquivos de `references/` e `scripts/`).
5. Confira o resultado: `<pasta de skills do agente>/adr-std/SKILL.md`. Se aparecer `adr-std/adr-std/SKILL.md`, há uma
   pasta a mais, e o agente não encontra a skill.
6. Abra uma nova sessão do agente e [teste](#9-confirmar-que-funcionou).

Exemplos: Claude Code → `~/.claude/skills/adr-std/`; Codex → `~/.codex/skills/adr-std/`; Gemini CLI, OpenCode, Cline,
Zed e Warp → `~/.agents/skills/adr-std/`. No Windows, o mesmo caminho a partir de `%USERPROFILE%`.
**Atualizar:** apague a pasta `adr-std` e copie a nova. **Remover:** apague a pasta `adr-std`.

### 6.5 Requisitos

| Forma | Precisa de |
|---|---|
| Zip | Nada além do sistema (no Linux, `bash`) |
| Uma linha | `curl` (ou `wget`), `bash` (Linux e macOS) ou PowerShell (Windows) |
| Git | `git` |
| Manual | Nada |
| `adr-std check` | Python 3 (só para esse comando) |

Nenhuma forma pede senha de administrador nem `sudo`.

### 6.6 O comando no PATH

O instalador coloca o `adr-std` em `~/.local/bin`. Se essa pasta não estiver no PATH, ele **pergunta** antes de
acrescentar uma linha ao seu `~/.bashrc`, `~/.zshrc` ou `config.fish` (no Windows, ao PATH do usuário). Se você
responder que não, ele mostra a linha para você acrescentar depois. A linha é marcada com `# adr-std`, e a
desinstalação remove só ela.

## 7. Escolher os agentes

O instalador procura, na sua pasta pessoal, a pasta de configuração de cada agente. Você escolhe em quais instalar:

```bash
adr-std install                          # mostra um menu com os agentes encontrados
adr-std install claude-code codex        # já escolhe os agentes
adr-std install --agent claude-code,codex   # forma equivalente
adr-std install --all                    # todos os encontrados
```

| Agente | Nome no comando | Pasta de skills |
|---|---|---|
| Claude Code | `claude-code` | `~/.claude/skills` |
| Codex | `codex` | `~/.codex/skills` |
| Gemini CLI | `gemini-cli` | `~/.agents/skills` (compartilhada) |
| OpenCode | `opencode` | `~/.agents/skills` (compartilhada) |
| Antigravity | `antigravity` | `~/.gemini/antigravity/skills` |
| Continue | `continue` | `~/.continue/skills` |
| Cursor | `cursor` | `~/.cursor/skills` |
| GitHub Copilot | `github-copilot` | `~/.copilot/skills` |
| Windsurf | `windsurf` | `~/.codeium/windsurf/skills` |
| Roo Code | `roo` | `~/.roo/skills` |
| Kiro CLI | `kiro-cli` | `~/.kiro/skills` |
| Goose | `goose` | `~/.config/goose/skills` |
| Junie | `junie` | `~/.junie/skills` |
| Amp | `amp` | `~/.config/agents/skills` |
| Cline, Zed, Warp e outros | `universal` | `~/.agents/skills` |

- **Pasta compartilhada:** Gemini CLI e OpenCode leem `~/.agents/skills`, e a skill vai para lá, uma vez só. Instalar
  também na pasta própria deles a faria aparecer duas vezes.
- **Confiabilidade dos caminhos:** os de Gemini CLI, OpenCode, Codex e Antigravity foram conferidos na documentação
  oficial; os demais vêm de uma tabela de terceiros e podem estar desatualizados. Corrigir é editar uma linha do
  arquivo `agents.tsv`.
- **Agente não encontrado:** se você indicar um agente que não foi detectado, o comando instala mesmo assim e avisa.
- **Nome errado:** `adr-std install claude` responde "quis dizer claude-code?".

## 8. Comandos do terminal

| Comando | O que faz |
|---|---|
| `adr-std install [agentes...]` | Instala a skill. Sem agentes, mostra um menu |
| `adr-std install --all` | Instala em todos os agentes encontrados |
| `adr-std install --link` | Cria links para a pasta `skill/` do repositório, em vez de copiar (para quem desenvolve a skill) |
| `adr-std install --dry-run` | Mostra o que faria, sem alterar nada |
| `adr-std update` | Baixa a última versão, confere o checksum e reinstala nos agentes já registrados |
| `adr-std update --version v1.0.0` | Instala uma versão específica |
| `adr-std update --agent gemini-cli` | Atualiza e inclui mais um agente |
| `adr-std uninstall [agentes...]` | Remove a skill de alguns agentes (sem agentes: de todos) |
| `adr-std self-uninstall` | Remove tudo: a skill, o estado, a linha do PATH e o próprio comando |
| `adr-std status` | Versão instalada, agentes, se as pastas estão íntegras |
| `adr-std agents` | Agentes suportados e os encontrados no computador |
| `adr-std check <arquivo-ou-pasta>` | Verifica ADRs (precisa de Python 3) |
| `adr-std version` · `adr-std help` | Versão e ajuda |

Regras de segurança do comando:

- **Nunca sobrescreve** uma pasta `adr-std` que ele não instalou: avisa (código de saída 4) e não altera nada.
- **Só remove** o que ele mesmo instalou e registrou. Uma pasta `adr-std` sua, em outro agente, fica intacta.
- **Repetir** `install` ou `update` não gera erro nem cópias duplicadas.
- **Sem terminal interativo** (script, automação) e sem `--agent` ou `--all`, ele falha e pede a indicação dos agentes.
- **Atualização com checksum inválido:** nada é alterado (código 5).

## 9. Confirmar que funcionou

1. Rode `adr-std status`: deve listar a versão e os agentes, todos "íntegra".
2. Abra uma **sessão nova** do agente (sessões já abertas não carregam a skill).
3. Peça: *"Crie um ADR para a decisão de usar PostgreSQL."* O agente deve carregar a `adr-std` e fazer perguntas
   (decisores, data, alternativas) antes de escrever.

Ajuda dos agentes: no Claude Code, `/skills` lista as skills carregadas; no Codex, `/skills`; no Gemini CLI,
`/skills list`.

## 10. Atualizar e remover

```bash
adr-std update                # atualiza
adr-std status                # confere
adr-std uninstall codex       # remove de um agente
adr-std uninstall             # remove de todos os agentes
adr-std self-uninstall        # remove tudo, inclusive o comando
```

Quem instalou pelo zip pode também baixar o zip novo e rodar o instalador de novo. Quem instalou pela forma manual
apaga a pasta `adr-std` do agente e copia a nova.

## 11. Problemas comuns

| Sintoma | Causa provável | O que fazer |
|---|---|---|
| `adr-std: comando não encontrado` | `~/.local/bin` fora do PATH | Abra um novo terminal; se persistir, acrescente `export PATH="$HOME/.local/bin:$PATH"` ao seu shell |
| O agente não usa a skill | Sessão aberta antes da instalação, ou pasta errada | Abra uma sessão nova; confira com `adr-std status` e a tabela da seção 7 |
| `já existe e não foi instalada pelo adr-std` | Há uma pasta `adr-std` sua no destino | Renomeie ou remova a pasta e instale de novo |
| `o checksum do pacote não confere` | Download corrompido ou pacote alterado | Não instale; tente de novo e, se repetir, avise o mantenedor |
| `o comando check precisa de Python 3` | Python ausente | Instale o Python 3 ou use `skill/references/checklist.md` à mão |
| `sem terminal para o menu` | Execução sem terminal (script, `curl \| bash` sem tty) | Indique `--agent` ou `--all` |
| A skill aparece duas vezes | Instalada na pasta própria de um agente que também lê `~/.agents/skills` | Rode `adr-std uninstall` e instale de novo pelo comando |
| Windows bloqueia o instalador | Script sem assinatura digital | Veja "Avisos de segurança" na seção 6.1 |

## 12. Sobre a norma

- **Norma:** ISO/IEC/IEEE 42010:2022 — *Software, systems and enterprise — Architecture description*, 2ª edição
  (novembro de 2022). Na verificação de 2026-09-29 era a edição vigente; o registro da ISO a marca como "a revisar".
- **Guia da skill:** `skill/references/guia-42010.md` resume toda a norma (cláusulas 1 a 8 e Anexos A a F), com o peso de
  cada exigência (DEVE, DEVERIA, PODE), a matriz de rastreabilidade com o template e as proibições do agente. Foi escrito
  com palavras próprias, não é tradução, e cita cada cláusula para conferência.
- **Onde obter a norma:** nas lojas da ISO, do IEC e do IEEE, ou pela sua instituição. Este repositório não a distribui.
- **Tradução ABNT:** não verificada; se existir, prefira citá-la no seu trabalho.

## 13. Limitações e próximas versões

**Versão 1.0 (esta):** skill, instalação em vários agentes e o comando `adr-std` (`install`, `update`, `uninstall`,
`self-uninstall`, `status`, `agents`, `check`).

**Planejado** (detalhes e decisões em [`ROADMAP.md`](ROADMAP.md)):

| Versão | Conteúdo |
|---|---|
| 1.1 | Comandos por ação dentro do agente: `/adr-std-create` (com `--ask N` e `--quick`), `/adr-std-supersede`, `/adr-std-review`, `/adr-std-organize`, `/adr-std-link`, `/adr-std-audit`, `/adr-std-check`, `/adr-std-ask` |
| 1.2 | Comandos mecânicos no terminal: `adr-std new`, `list`, `link`, `organize --dry-run` |
| 1.3 | Comandos de conversa no terminal (`adr-std create ...`) abrindo o agente escolhido, com menu que lembra a última escolha e `adr-std config agent` |

**Limitações conhecidas:**

- Os scripts de Windows e macOS ainda não foram validados por pessoas nesses sistemas; os testes automáticos rodam no
  Linux.
- Os caminhos de vários agentes não foram conferidos na documentação de cada um (seção 7).
- A skill orienta o agente, mas o cumprimento das regras depende do modelo. Revise o que o agente escrever.
- Um conjunto de ADRs não comprova a conformidade do projeto com a 42010 (seção 2).

## 14. Arquivos da skill

| Arquivo | Uso |
|---|---|
| `skill/SKILL.md` | Ponto de entrada para o agente: tarefas, regras e proibições |
| `skill/references/guia-42010.md` | Resumo detalhado da norma e regras de criação, revisão e auditoria |
| `skill/references/template-madr.md` | Template do ADR, com os campos da cláusula 6.10 |
| `skill/references/checklist.md` | Checklist de conformidade, com a origem de cada item |
| `skill/scripts/check_adr.py` | Verificação automática dos itens mecânicos |

## 15. Licença e contribuição

Licença MIT (arquivo `LICENSE`). A licença cobre esta skill e seus instaladores; não cobre a norma ISO/IEC/IEEE
42010, que tem direitos próprios. Para contribuir, leia `CONTRIBUTING.md`. Dúvidas e problemas: abra uma *issue* em
<https://github.com/dihcruz1/adr-std/issues>.
