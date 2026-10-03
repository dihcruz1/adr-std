# Requisitos — adr-std v1.4: `config path`

| Campo | Detalhe |
|---|---|
| **Data** | 2026-10-02 |
| **ADR de origem** | [ADR-1](../../architecture/ADR/1-caminho-padrao-dos-adrs-e-personalizacao.md) (etapa 2: `adr-std config path` na CLI) |
| **Status** | Gate 1 |
| **Depende de** | v1.2 ([spec](../2026-10-01-adr-std-v1-2-comandos-terminal/), leitura da config global já implementada em `resolve_folder`) e v1.3 ([spec](../2026-10-01-adr-std-v1-3-conversa-terminal/), namespace `config` com `config agent`) |

## 1. Contexto

O ADR-1 decidiu a hierarquia de resolução da pasta de ADRs
(`--path > .adr-std > CONVENTIONS/AGENTS > config global > padrão`) e, na seção **Verificação**,
previu `adr-std config path` como a forma de o usuário **ler e gravar** o campo `path` do arquivo
de config global (`~/.config/adr-std/config` no Linux/macOS, `%APPDATA%\adr-std\config` no Windows).

Hoje a parte de **leitura** da config global já existe e é usada por `new`, `list`, `link` e
`organize` (`resolve_folder` em `skill/scripts/adr_cli.py`), e o namespace `config` já existe no CLI,
mas só com o subcomando `agent` (v1.3). Falta o subcomando `path` que **grava** esse campo pela CLI,
sem o usuário precisar editar o arquivo à mão. Enquanto ele não existir, o critério de Verificação do
ADR-1 fica cumprido só pela metade.

Esta versão fecha essa etapa: adiciona `adr-std config path` (bash e PowerShell), reaproveitando o
mesmo arquivo de config, o mesmo campo `path` e a mesma precedência já implementados.

## 2. Decisões fechadas (ADR-1 + simetria com `config agent`)

| # | Decisão |
|---|---|
| D-01 | `config path` opera **só** no arquivo de config **global** (nível 4 da hierarquia). `.adr-std` local (nível 2) continua sendo edição manual do usuário, por ser por-repositório. |
| D-02 | Simetria com `config agent`: sem argumento **mostra** o `path` atual (ou diz que não há); `<pasta>` **grava**; `--unset` **remove** o campo. |
| D-03 | Gravar `path` **não** cria a pasta de ADRs nem valida se ela existe: `config path` só registra a preferência; quem cria a pasta é `new` (como já ocorre hoje). |
| D-04 | O arquivo de config é o mesmo usado por `config agent` e pelo estado da skill; `config path` grava/lê a linha `path`, preservando as demais linhas (ex.: `default_agent`). |
| D-05 | O valor é gravado como veio (sem normalizar para absoluto): `.adr-std` e config global já aceitam caminho relativo ou absoluto; a resolução relativa ao `cwd` é responsabilidade de quem lê (`resolve_folder`), mantida sem mudança. |

## 3. Linguagem Ubíqua

| Termo | Significado |
|---|---|
| **Config global** | Arquivo `~/.config/adr-std/config` (Linux/macOS) ou `%APPDATA%\adr-std\config` (Windows), compartilhado com o estado da skill |
| **Campo `path`** | Linha `path: <pasta>` na config global que define a pasta de ADRs quando não há `--path` nem `.adr-std` |
| **Precedência D-05 (ADR-1)** | `--path` > `.adr-std` (campo `path`) > config global (campo `path`) > `docs/architecture/ADR/` |

## 4. Requisitos funcionais (EARS)

- **RF-01 (evento):** QUANDO o usuário rodar `adr-std config path` sem argumento, o sistema DEVE mostrar
  o `path` gravado na config global, ou informar que nenhum está definido.
- **RF-02 (evento):** QUANDO o usuário rodar `adr-std config path <pasta>`, o sistema DEVE gravar o campo
  `path` na config global com esse valor, preservando as demais linhas do arquivo, e confirmar na tela.
- **RF-03 (evento):** QUANDO o usuário rodar `adr-std config path --unset`, o sistema DEVE remover o campo
  `path` da config global (se existir) e confirmar; sem o campo, DEVE informar que não havia nada a remover.
- **RF-04 (indesejado):** SE o valor passado a `config path` começar com `-` e não for `--unset`, ENTÃO o
  sistema DEVE recusar com código 2 e mensagem de opção desconhecida (mesma regra do `config agent`).
- **RF-05 (ubíquo):** O campo `path` gravado por `config path` DEVE ser lido por `new`, `list`, `link` e
  `organize` no nível 4 da precedência D-05, sem alteração do comportamento já existente de `resolve_folder`.
- **RF-06 (indesejado):** SE o usuário rodar `config` com um subcomando que não seja `agent` nem `path`,
  ENTÃO o sistema DEVE recusar com código 2 e a mensagem de uso DEVE citar `agent` e `path`.
- **RF-07 (ubíquo):** `adr-std help` DEVE listar `config path`; `VERSION` DEVE ser `1.4.0` com entrada
  correspondente no `CHANGELOG.md`.
- **RF-08 (ubíquo):** Paridade bash/PowerShell, verificada em `tests/test_cli.sh` e `tests/test_cli.ps1`.

## 5. Requisitos não funcionais e de segurança

- **SEG-01:** `config path` grava apenas no arquivo de config global já existente; não grava em caminho
  derivado do valor do usuário (o valor é **conteúdo** da linha `path`, nunca parte de um caminho de arquivo
  a escrever) — não há travessia de diretório possível pela escrita.
- **SEG-02:** A escrita preserva as outras linhas da config (não apaga `default_agent` nem outras chaves),
  usando o mesmo mecanismo de reescrita linha-a-linha já usado por `config agent` / estado.
- **SEG-03:** `config path` não executa o valor como comando nem o interpola em shell; é só texto gravado.
- **RNF-01:** Mensagens em pt-BR; `config path` não depende de Python (é do wrapper, como `config agent`).
- **RNF-02:** Idempotência: gravar o mesmo `path` duas vezes não duplica a linha; `--unset` repetido não falha.

## 6. Cenários (Gherkin)

```gherkin
Cenário: mostrar sem valor definido
  Dado uma config global sem campo path
  Quando rodo "adr-std config path"
  Então a saída informa que nenhuma pasta de ADRs está definida

Cenário: gravar e mostrar
  Quando rodo "adr-std config path docs/decisoes"
  E rodo "adr-std config path"
  Então a saída mostra "docs/decisoes"
  E a config global tem uma única linha "path"

Cenário: preserva o agente padrão
  Dado uma config global com default_agent codex
  Quando rodo "adr-std config path docs/decisoes"
  Então a config global ainda tem default_agent codex e agora também path docs/decisoes

Cenário: remover
  Dado uma config global com path docs/decisoes
  Quando rodo "adr-std config path --unset"
  E rodo "adr-std config path"
  Então a saída informa que nenhuma pasta está definida

Cenário: a config global é lida por list
  Dado "adr-std config path outra-pasta" e um ADR válido em outra-pasta/
  Quando rodo "adr-std list" sem --path e sem .adr-std no cwd
  Então list usa outra-pasta/ e encontra o ADR

Cenário: subcomando inválido de config
  Quando rodo "adr-std config caminho"
  Então código 2 e a mensagem de uso cita "agent" e "path"
```

## 7. Riscos

| # | Risco | Mitigação |
|---|---|---|
| R-01 | Escrita do `path` apagar o `default_agent` ou outras linhas | SEG-02 + teste "preserva o agente padrão" |
| R-02 | `config path` divergir entre bash e PowerShell | RF-08 + Pester espelhando os casos do bash |
| R-03 | Confundir config global (nível 4) com `.adr-std` local (nível 2) | D-01: `config path` só mexe na global; `.adr-std` segue manual, documentado no README |
| R-04 | Mensagem de uso de `config` continuar citando só `agent` | RF-06 + teste de subcomando inválido |

## 8. Fora do escopo

- `config` para `.adr-std` local (nível 2 da hierarquia): continua edição manual por repositório (D-01).
- Nível 3 da hierarquia (`CONVENTIONS.md`/`AGENTS.md`): texto livre lido só pelo agente, sem comando.
- Validar ou criar a pasta indicada (D-03): responsabilidade de `new`.
- `organize` real: fora de escopo desde a v1.2, não tocado aqui.
