# Requisitos — adr-std v1.2: comandos mecânicos no terminal

| Campo | Detalhe |
|---|---|
| **Data** | 2026-10-01 |
| **Status** | Gate 1 |
| **Depende de** | v1.1 concluída ([spec](../2026-09-30-adr-std-v1-1-comandos-no-agente/)) |
| **Contexto** | [ROADMAP.md](../../../ROADMAP.md), seção "v1.2"; ADR-0001 (caminho dos ADRs) |

## 1. Contexto

As ações `new` e `list` já existem dentro do agente (v1.1). A v1.2 leva para o terminal o que **não precisa de modelo de
linguagem**: `adr-std new`, `list`, `link` e `organize --dry-run`, com os mesmos nomes dos comandos do agente. O `check`
já existe. A lógica fica em Python (`skill/scripts/adr_cli.py`), reaproveitando o parsing do `check_adr.py`; os
comandos `bin/adr-std` e `bin/adr-std.ps1` só despacham.

## 2. Decisões já fechadas (ROADMAP)

| # | Decisão |
|---|---|
| D-01 | Mesmos nomes de comando no terminal e no agente |
| D-02 | Python, reaproveitando `check_adr.py` por importação; sem Python o comando avisa e indica o checklist manual |
| D-03 | `new` cria o arquivo vazio (próximo número, `Proposto`, campos `pendente`), sem perguntas |
| D-04 | `organize` só em modo simulação (`--dry-run`) nesta versão; reorganização real fica para versão futura |
| D-05 | Pasta dos ADRs: `--path` > `.adr-std` (`path`) > `~/.config/adr-std/config` (`path`) > `docs/architecture/ADR` (ADR-0001). O nível 3 (convenção em `CONVENTIONS.md`/`AGENTS.md`) é lido só pelo agente (texto livre, sem formato máquina) |

## 3. Linguagem Ubíqua

| Termo | Significado |
|---|---|
| **Pasta de ADRs** | Diretório onde ficam os arquivos `NNNN-<slug>.md` |
| **Esqueleto** | ADR criado por `new`: seções do template com `pendente` |
| **Relação recíproca** | Registro do mesmo vínculo nos dois ADRs, com o tipo inverso |
| **Simulação** | Execução que só mostra o plano (`--dry-run`), sem gravar |

## 4. Requisitos funcionais (EARS)

- **RF-01 (evento):** QUANDO o usuário rodar `adr-std new <título>`, o sistema DEVE criar `NNNN-<slug>.md` na pasta de ADRs, com o
  próximo número (largura mínima 4), status `Proposto`, data de hoje e demais campos `pendente`, sem perguntas.
- **RF-02 (indesejado):** SE o título for vazio, ENTÃO o sistema DEVE recusar com código 2 e não criar arquivo.
- **RF-03 (evento):** QUANDO o usuário rodar `adr-std list`, o sistema DEVE listar ID, status, data da decisão e título de cada ADR da pasta.
- **RF-04 (indesejado):** SE a pasta não existir, ENTÃO `list` DEVE sair com código 1 e mensagem; SE estiver vazia, DEVE informar que não há ADR (código 0).
- **RF-05 (evento):** QUANDO o usuário rodar `adr-std link <ADR-A> <tipo> <ADR-B>`, o sistema DEVE gravar a relação em A e a recíproca em B, no campo "Relações com outras decisões", preservando o que já existia.
- **RF-06 (indesejado):** SE o tipo for desconhecido (código 2) ou um dos ADRs não existir (código 1), ENTÃO o sistema NÃO DEVE alterar nenhum arquivo.
- **RF-07 (evento):** QUANDO o usuário rodar `adr-std organize --dry-run`, o sistema DEVE mostrar o plano de renumeração/renomeação sem alterar nada; sem `--dry-run`, DEVE recusar com código 2.
- **RF-08 (ubíquo):** Os quatro comandos DEVEM resolver a pasta pela precedência D-05 e aceitar `--name-pattern REGEX`.
- **RF-09 (evento):** QUANDO `bin/adr-std` ou `bin/adr-std.ps1` receber `new`, `list`, `link` ou `organize`, DEVE repassar ao `adr_cli.py`; SE não houver Python 3, DEVE sair com código 6 avisando e indicando `skill/references/checklist.md`.
- **RF-10 (ubíquo):** `adr-std help` DEVE listar os quatro comandos novos; `VERSION` DEVE ser `1.2.0` e o `CHANGELOG.md` DEVE registrar a versão.
- **RF-11 (ubíquo):** Os arquivos `commands.tsv` e `command_targets.tsv` (v1.1) DEVEM ser copiados pelo `install.sh`, pelo `install.ps1` e incluídos no `dist/adr-std.zip` (discrepância da v1.1: sem eles, instalar pelo zip ou pelo `install.sh` remoto não cria os comandos de ação).
- **RF-12 (ubíquo):** O comportamento do PowerShell DEVE ter paridade com o bash, verificada em `tests/test_cli.ps1`.

## 5. Requisitos não funcionais e de segurança

- **RNF-01:** Mensagens em pt-BR; nomes de código, arquivo e comando em inglês.
- **RNF-02:** Sem dependências além da biblioteca padrão do Python 3.
- **SEG-01:** O sistema NUNCA DEVE gravar fora da pasta de ADRs: o nome do arquivo vem só do `slugify` (apenas `[a-z0-9-]`), então `../` e `/` no título não escapam.
- **SEG-02:** O sistema NUNCA DEVE sobrescrever um arquivo existente em `new`.
- **SEG-03:** O título entra no arquivo como texto numa única linha (quebras de linha viram espaço); nada é executado nem interpretado como shell.
- **SEG-04:** `link` e `organize` NÃO DEVEM deixar estado parcial: validam tudo antes de gravar.

## 6. Cenários (Gherkin)

```gherkin
Cenário: new numera o próximo ADR
  Dado uma pasta com 0001-a.md e 0003-b.md
  Quando rodo "adr-std new 'Usar fila'"
  Então existe 0004-usar-fila.md com Status Proposto e Decisores pendente

Cenário: título malicioso não escapa da pasta
  Quando rodo "adr-std new '../../x'"
  Então o arquivo criado está dentro da pasta de ADRs

Cenário: link é recíproco e preserva relações
  Dado ADR-0001 com relação "refina ADR-0009"
  Quando rodo "adr-std link ADR-0001 restringe ADR-0002"
  Então 0001 tem "refina ADR-0009; restringe ADR-0002" e 0002 tem "é restringido por ADR-0001"

Cenário: sem Python
  Dado um PATH sem python3
  Quando rodo "adr-std list"
  Então o código é 6 e a mensagem cita o checklist manual
```

## 7. Riscos

| # | Risco | Mitigação |
|---|---|---|
| R-01 | Path traversal por título | SEG-01 + teste |
| R-02 | Sobrescrita de ADR existente | SEG-02 + teste |
| R-03 | Relação gravada só de um lado | SEG-04 + teste |
| R-04 | Pacote sem os `.tsv` da v1.1 | RF-11 + teste de pacote |
| R-05 | Windows real não testado (junção `--link`, `.cmd`, PATH nativo) | Já registrado na v1.0 (6.1); fora do alcance local |

## 8. Fora do escopo

`organize` real (renomeia arquivos), `adr-std config path` (ADR-0001 etapa 2; só leitura de `.adr-std`/config global aqui), nível 3 da hierarquia.
