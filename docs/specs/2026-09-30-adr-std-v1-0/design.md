# Design — adr-std v1.0: distribuição e instalação da skill

| Campo | Detalhe |
|---|---|
| **Data** | 2026-09-30 |
| **Status** | Gate 2 aprovado (2026-09-30) |
| **Requisitos** | [requirements.md](requirements.md) |

## 1. Princípios

- **KISS:** um instalador por família de sistema (`install.sh`, `install.ps1`); toda a lógica de gestão no
  comando `adr-std` (`bin/adr-std`, `bin/adr-std.ps1`).
- **YAGNI:** v1.0 entrega só instalação e gestão (RF-01 a RF-19). Nada das v1.1 a v1.3 é antecipado,
  exceto a separação `skill/` e o arquivo `agents.tsv`, que as versões seguintes reaproveitam.
- **Rule of Three:** bash e PowerShell repetem a mesma lógica por necessidade de plataforma; não se cria
  gerador de código. Os dois leem o mesmo `agents.tsv` e são validados pelos mesmos cenários.
- **Dado, não código:** agentes e pastas em `agents.tsv` (RNF-05).

## 2. Estrutura do repositório

```
adr-std/                              # github.com/dihcruz1/adr-std
├── README.md                         # documento completo (RF-18); também vai no zip
├── CONTRIBUTING.md                   # desenvolvimento, testes e publicação
├── CHANGELOG.md
├── LICENSE                           # MIT (P-02)
├── VERSION                           # ex.: 1.0.0
├── agents.tsv                        # agentes suportados (seção 5)
├── install.sh                        # instalador Linux e macOS
├── install.ps1                       # instalador Windows
├── bin/
│   ├── adr-std                       # comando (bash)
│   ├── adr-std.ps1                   # comando (PowerShell)
│   └── adr-std.cmd                   # atalho Windows → adr-std.ps1
├── packaging/                        # atalhos de duplo clique que entram no zip
│   ├── instalar-windows.bat · desinstalar-windows.bat
│   ├── instalar-mac.command · desinstalar-mac.command
│   └── instalar-linux.sh · desinstalar-linux.sh
├── package.sh                        # gera dist/adr-std.zip e .sha256
├── .github/workflows/release.yml     # gate de segurança + publicação (RF-19)
├── docs/specs/                       # specs deste projeto
├── skill/                            # SOMENTE isto vai para os agentes, com o nome "adr-std"
│   ├── SKILL.md
│   ├── references/ (guia-42010.md, template-madr.md, checklist.md)
│   └── scripts/check_adr.py
└── tests/
    ├── cenarios.md                   # validação da skill nos agentes
    ├── fixtures/                     # ADRs de exemplo
    ├── test_check_adr.py             # testes do script (unittest)
    ├── test_cli.sh                   # testes do comando bash (HOME temporário)
    └── test_cli.ps1                  # testes do comando PowerShell (Pester)
```

## 3. Onde as coisas ficam no computador do usuário

| Item | Linux e macOS | Windows |
|---|---|---|
| Comando | `~/.local/bin/adr-std` | `%LOCALAPPDATA%\adr-std\bin\adr-std.cmd` (+ `adr-std.ps1`) |
| Fonte local (cópia da release) | `~/.local/share/adr-std/` (`skill/`, `agents.tsv`, `VERSION`, `bin/`) | `%LOCALAPPDATA%\adr-std\` |
| Estado | `~/.config/adr-std/state` | `%APPDATA%\adr-std\state` |
| Skill instalada | `<pasta do agente>/adr-std/` | `<pasta do agente>\adr-std\` |

Todas as pastas ficam no perfil do usuário (RNF-01, R-04). Os caminhos respeitam `XDG_DATA_HOME` e
`XDG_CONFIG_HOME` quando definidos.

## 4. Fluxos de instalação

```
zip (duplo clique) ──> packaging/instalar-* ──> install.sh / install.ps1 (modo local: usa ./skill)
curl | bash ─────────> install.sh (modo remoto: baixa release, confere sha256)
irm | iex ───────────> install.ps1 (modo remoto)
git clone ───────────> ./install.sh (modo local)
                          │
                          ├─ copia bin/, skill/, agents.tsv, VERSION para a fonte local
                          ├─ coloca o comando no PATH (pergunta antes de editar — RF-15)
                          └─ executa: adr-std install [argumentos repassados]
manual ──────────────> usuário copia skill/ para <pasta do agente>/adr-std (sem comando)
```

**Modo do instalador:** se existir `skill/SKILL.md` ao lado do script, modo local; senão, modo remoto.

**Modo remoto:** baixa `https://github.com/dihcruz1/adr-std/releases/latest/download/adr-std.zip` e o
`.sha256` (ou `releases/download/vX.Y.Z/...` com `--version`), confere o hash (`sha256sum`, `shasum -a 256`
ou `Get-FileHash`), extrai numa pasta temporária e segue como modo local. Hash divergente aborta sem
alterar nada (R-02).

**`curl | bash` sem terminal interativo:** o menu lê de `/dev/tty`; sem `/dev/tty` e sem agentes
indicados, aplica RF-16.

## 5. Agentes (`agents.tsv`)

Colunas separadas por tabulação; linhas com `#` são comentários. Caminhos relativos a `~`
(`%USERPROFILE%` no Windows).

| id | nome | detecta (pasta existe) | pasta de skills | lê compartilhada |
|---|---|---|---|---|
| claude-code | Claude Code | `.claude` | `.claude/skills` | não |
| codex | Codex | `.codex` | `.codex/skills` | não |
| gemini-cli | Gemini CLI | `.gemini` | `.gemini/skills` | sim |
| opencode | OpenCode | `.config/opencode` | `.config/opencode/skills` | sim |
| antigravity | Antigravity | `.gemini/antigravity` | `.gemini/antigravity/skills` | não |
| continue | Continue | `.continue` | `.continue/skills` | não |
| cursor | Cursor | `.cursor` | `.cursor/skills` | não |
| github-copilot | GitHub Copilot | `.copilot` | `.copilot/skills` | não |
| windsurf | Windsurf | `.codeium/windsurf` | `.codeium/windsurf/skills` | não |
| roo | Roo Code | `.roo` | `.roo/skills` | não |
| kiro-cli | Kiro CLI | `.kiro` | `.kiro/skills` | não |
| goose | Goose | `.config/goose` | `.config/goose/skills` | não |
| junie | Junie | `.junie` | `.junie/skills` | não |
| amp | Amp | `.config/agents` | `.config/agents/skills` | não |
| universal | Cline, Zed, Warp e outros | `.agents` | `.agents/skills` | — |

Pasta compartilhada: `~/.agents/skills`. Fontes: documentação oficial (Gemini CLI, OpenCode, Codex,
Antigravity) e tabela do `vercel-labs/skills` (demais, a confirmar por agente).

**Resolução de destino (RF-04, RF-05):** para cada agente escolhido, se "lê compartilhada" = sim, o destino
é `~/.agents/skills`; senão, a pasta própria. O conjunto de destinos é deduplicado antes de copiar.

## 6. Estado

Arquivo texto, uma entrada por linha (`chave<TAB>valor`), legível e fácil de ler em bash e PowerShell:

```
version	1.0.0
mode	copy
agent	claude-code	/home/u/.claude/skills/adr-std
agent	codex	/home/u/.codex/skills/adr-std
path_line	/home/u/.bashrc	# adr-std
```

Cada pasta instalada recebe também `adr-std/.installed-by-adr-std` (versão e data). O comando só remove ou
sobrescreve uma pasta se ela estiver no estado **e** tiver esse marcador (RF-06, RF-08, R-03). No modo
`--link`, o marcador é o próprio link apontando para a fonte.

## 7. Contrato do comando `adr-std` (v1.0)

| Comando | Opções | Saída |
|---|---|---|
| `install [agentes...]` | `--agent a b` \| `--agent a,b`, `--all`, `--link`, `--dry-run`, `--version vX.Y.Z` | 0 ok; 3 nenhum agente; 4 conflito (RF-06) |
| `update` | `--agent ...` (inclui agentes), `--version vX.Y.Z`, `--dry-run` | 0 ok; 5 rede ou checksum |
| `uninstall [agentes...]` | `--agent ...`, `--dry-run` | 0 ok |
| `self-uninstall` | `--dry-run` | 0 ok |
| `status` | — | 0; mostra versão, agentes, integridade, versão nova |
| `agents` | — | 0; lista suportados e detectados |
| `check <alvo>` | repassa opções ao `check_adr.py` | código do script; 6 sem Python |
| `version`, `help` | — | 0 |

- **Agentes no comando:** um termo só é tratado como agente se for exatamente um `id` do `agents.tsv`;
  termo parecido gera sugestão ("quis dizer claude-code?") (R-07).
- **Menu (RF-02):** lista os agentes detectados, aceita números separados por espaço ou `todos`.
- **Erros:** mensagens em pt-BR com a ação sugerida; código diferente de zero.

## 8. PATH (RF-15, R-05)

Linux e macOS: se `~/.local/bin` não estiver no PATH, detecta o shell (`$SHELL`: bash → `~/.bashrc`,
zsh → `~/.zshrc`, fish → `~/.config/fish/config.fish`), pergunta, acrescenta uma linha marcada com
`# adr-std` se ainda não existir e registra no estado. Windows: acrescenta a pasta ao PATH do usuário
(`[Environment]::SetEnvironmentVariable(..., 'User')`) após perguntar. `self-uninstall` desfaz.

## 9. Pacote e publicação

- `package.sh` monta `dist/adr-std.zip` com: `README.md`, `LICENSE`, `VERSION`, `agents.tsv`,
  `install.sh`, `install.ps1`, `bin/`, `packaging/*` na raiz do zip e `skill/`; gera `adr-std.zip.sha256`.
- `release.yml` (tag `v*`):
  1. **Gate de segurança:** `shellcheck` nos scripts bash; `PSScriptAnalyzer` nos `.ps1`; `python -m
     unittest` (fixture passa, template reprova); validação do `SKILL.md` (frontmatter, `name` igual a
     `adr-std`); tag igual a `VERSION`; bloqueio de arquivos da norma e de arquivos acima de 1 MB (R-06).
  2. **Testes do comando:** `tests/test_cli.sh` (Ubuntu e macOS) e `tests/test_cli.ps1` (Windows).
  3. **Publicação:** só com 1 e 2 verdes; anexa o zip e o `.sha256` à release.

## 10. Estratégia de testes

| Nível | Ferramenta | O que cobre |
|---|---|---|
| Unidade (script) | `unittest` (Python) | `check_adr.py`: fixture conforme, template, padrões de nome, justificativa na Decisão |
| Comando (bash) | `tests/test_cli.sh`, com `HOME` temporário e pastas de agentes falsas | RF-02 a RF-16, idempotência, sem duplicata, conflito, dry-run, remoção seletiva, PATH |
| Comando (PowerShell) | Pester, com perfil temporário | Mesmos cenários do bash |
| Instalador | Execução do `install.sh` em modo local com `HOME` temporário; modo remoto com servidor local (`python -m http.server`) e checksum válido e inválido | RF-01, RF-07, R-02 |
| Pacote | Conteúdo do zip conferido por lista | RF-17 |
| Skill nos agentes | `tests/cenarios.md` (manual) | Ativação, perguntas, proibições |

Os testes nunca usam o `HOME` real. A URL de download é configurável por variável
(`ADR_STD_BASE_URL`) só para os testes.

## 11. Limites conhecidos

- Windows e macOS só são validados no CI até haver testador humano (pendência 2.3).
- Caminhos dos agentes marcados "a confirmar" podem mudar; corrigir é editar uma linha do `agents.tsv`.

## 12. Modelo de domínio (DDD)

**N/A justificado.** A v1.0 é instalador e CLI de E/S (copiar a skill, ler `agents.tsv`, gravar o estado
de instalação): não há invariante de domínio que peça entidade rica ou Value Object. `agents.tsv` é dado,
não código (RNF-05), e o contrato do comando (seção 7) já isola o comportamento. Aplicar DDD tático
violaria KISS/YAGNI (AGENTS.md: DDD só com invariante de domínio). O vocabulário do domínio está no `GLOSSARY.md`.
