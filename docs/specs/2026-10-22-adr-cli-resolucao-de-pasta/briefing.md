# Briefing: `adr-std new` grava no lugar errado quando executado fora da raiz do repositório

Origem: defeito observado em uso real (projeto `led-bomb-monitor`, 2026-10-22). Este arquivo é só o ponto de partida para
o agente local: ele não substitui a spec. Siga o fluxo de defeito do `AGENTS.md` (explorar → `requirements.md` com causa-raiz
e matriz de não-regressão → Gate 1 → `design.md` → Gate 2 → `tasks.md` → TDD).

## Cuidados antes de começar

- A árvore de trabalho já tem mudanças alheias (`AGENTS.md` modificado; `docs/specs/2026-10-05-close-validation-gaps/`,
  `openspec/` e `testResults.xml` não rastreados). Não as altere nem as inclua em commits; `git add` só com caminhos explícitos.
- Esta correção não está coberta por nenhuma spec existente. Crie uma pasta de spec própria (esta, por exemplo, mantendo este
  `briefing.md` ao lado dos três arquivos da spec).
- A skill instalada em `~/.claude/skills/adr-std` é um link para `skill/` deste repositório; qualquer mudança em
  `skill/scripts/adr_cli.py` já vale para os projetos que usam a skill.

## Sintoma

Executar `adr_cli.py new` com o diretório atual diferente da raiz do repositório cria a pasta dos ADRs **dentro do diretório
atual**, numera a partir de 1 e não avisa nada. O mesmo vale para `list`, `link` e `organize`, que operam na pasta errada.

Caso real: o comando foi rodado de dentro de `docs/architecture/ADR/` e criou
`docs/architecture/ADR/docs/architecture/ADR/1-reproducao-de-video-mp4-h-264-no-lcd.md`, com ID `ADR-1`, embora a pasta correta
já tivesse 10 ADRs.

## Reprodução (confirmada em 2026-10-22, repositório temporário)

```bash
mkdir proj && cd proj && git init -q && mkdir -p docs/architecture/ADR
python3 <skill>/scripts/adr_cli.py new "Primeiro"        # cria docs/architecture/ADR/1-primeiro.md (correto)
printf 'path: meus-adrs\n' > .adr-std                     # configuração na RAIZ, como o SKILL.md e o ADR-1 mandam
cd docs/architecture/ADR
python3 <skill>/scripts/adr_cli.py new "Segundo"         # cria docs/architecture/ADR/docs/architecture/ADR/1-segundo.md
```

Resultado observado:

- `.adr-std` da raiz foi **ignorado** a partir da subpasta (o "Segundo" não foi para `meus-adrs`).
- Sem `.adr-std`, o "Terceiro" foi para `docs/architecture/ADR/docs/architecture/ADR/2-terceiro.md`.
- `adr_cli.py list` na subpasta listou só os dois ADRs da pasta errada (`ADR-1 Segundo`, `ADR-2 Terceiro`) e saiu com código 0.

## Causa-raiz (em `skill/scripts/adr_cli.py`)

1. **Padrão relativo ao diretório atual.** `DEFAULT_FOLDER = Path("docs/architecture/ADR")` (linha 46) é usado sem ancorar na
   raiz do repositório; o `Path` relativo é resolvido contra o `cwd`.
2. **`.adr-std` só é procurado no diretório atual.** `resolve_folder` lê `cwd / ".adr-std"` (linha 65), mas o `SKILL.md` (linha
   27) e o ADR-1 desta skill dizem "arquivo `.adr-std` **na raiz do repositório**". O código não implementa o que a decisão
   promete. O valor do campo `path` também é devolvido relativo, e `main` passa `Path.cwd()` (linha 335).
3. **Criação silenciosa da pasta.** `cmd_new` faz `folder.mkdir(parents=True, exist_ok=True)` (linha ~195) sem checar se a
   pasta já existia; `next_number` sobre pasta vazia devolve 1. O erro de caminho vira um ADR "válido" e com número errado.

Os testes atuais fixam o comportamento defeituoso como se fosse correto: `ResolveFolderTest.test_default` espera
`Path("docs/architecture/ADR")` relativo e `test_cli_uses_dot_adr_std_in_cwd` só cobre o caso em que o `cwd` é a raiz
(`tests/test_adr_cli.py`, linhas ~203 a 222).

## Comportamento esperado (a confirmar com o responsável na spec)

- A pasta dos ADRs é resolvida a partir da **raiz do repositório**, não do diretório atual, em todos os comandos que usam
  `args.folder` (`new`, `list`, `link`, `organize`).
- `.adr-std` é lido na raiz do repositório (como documentam `SKILL.md`, README e ADR-1).
- `--path` continua com a maior precedência; a decisão sobre caminho relativo (relativo ao `cwd`, como em qualquer CLI, ou à
  raiz) precisa ser explícita.
- Quando a pasta dos ADRs **não existir**, `new` não cria a árvore em silêncio nem numera a partir de 1 sem avisar.

## Decisões que cabem ao responsável (apresente opções e recomendação na spec; não decida sozinho)

1. **Como achar a raiz.** Opções: (a) `git rev-parse --show-toplevel`; (b) subir os diretórios procurando `.adr-std` e, depois,
   `.git`; (c) combinação, com fallback para o `cwd` fora de um repositório. O ADR-1 rejeitou "descoberta automática por
   heurística" para a *pasta dos ADRs*; escolha a raiz de forma determinística e documentada para não reabrir essa decisão.
   Registre se a mudança exige emenda ou novo ADR.
2. **Pasta inexistente.** Opções: erro com mensagem em pt-BR e saída diferente de zero; criar só com confirmação ou flag
   (`--create`); criar com aviso explícito. Cuide do primeiro uso legítimo (projeto sem nenhum ADR ainda).
3. **Compatibilidade.** Quem hoje roda da raiz não pode ser afetado; avalie se a mudança é correção (patch) ou alteração de
   contrato (registrar no `CHANGELOG.md`, `[Não lançado]`).

## Matriz de não-regressão (mínimo)

| Cenário | Esperado após a correção |
|---|---|
| `cwd` = raiz, sem `.adr-std` | `docs/architecture/ADR` da raiz (igual a hoje) |
| `cwd` = raiz, `.adr-std` com `path` | pasta do `path` (igual a hoje) |
| `cwd` = subpasta, sem `.adr-std` | `docs/architecture/ADR` **da raiz** (hoje: erro) |
| `cwd` = subpasta, `.adr-std` na raiz | pasta do `path` da raiz (hoje: ignora o arquivo) |
| `--path` absoluto, de qualquer `cwd` | exatamente essa pasta (igual a hoje) |
| `--path` relativo | comportamento definido na spec e testado |
| config global (`~/.config/adr-std/config`) | mantém a precedência `--path` > `.adr-std` > global > padrão |
| fora de repositório git | fallback definido na spec (não pode quebrar o uso em pasta avulsa) |
| pasta dos ADRs inexistente | conforme decisão 2; nunca numerar a partir de 1 em silêncio |
| `list`, `link`, `organize --dry-run` de subpasta | operam na pasta correta |
| `check_adr.py`, `check_roadmap.py`, `migrate` | sem mudança de comportamento (confirmar que não usam `resolve_folder`) |

## Testes

- RED primeiro: reproduza o defeito em teste de integração (repositório temporário com `git init`, rodando o script com
  `cwd` em subpasta), cobrindo a matriz acima. Use os helpers `run(...)` e `CliTestCase` de `tests/test_adr_cli.py`.
- Atualize `test_default` e `test_cli_uses_dot_adr_std_in_cwd`, que hoje fixam o comportamento defeituoso, e justifique no
  registro do ticket.
- Paridade Windows: verifique `bin/adr-std.ps1`, `tests/test_cli.ps1` e o job de CI do Windows; a mesma regra de raiz precisa
  valer lá. Não conclua sem evidência de que o Pester continua verde (a v2.0.0 já foi bloqueada por falha desse job).
- Validação do conjunto: `bash tests/gate.sh static` e a suíte `pytest` do repositório.

## Documentação a alinhar

- `skill/SKILL.md` (resolução do caminho, linhas ~24 a 31): hoje diz "raiz do repositório"; confira que o texto descreve o
  comportamento final e oriente o agente a rodar a CLI da raiz ou a usar `--path` absoluto.
- `README.md` (trecho do `.adr-std`/`--path`, linhas ~277 a 280) e `docs/architecture/ADR/1-caminho-padrao-dos-adrs-e-personalizacao.md`
  (Verificação e Limitações) se a decisão 1 mudar algo.
- `CHANGELOG.md`, seção `[Não lançado]`.

## Fora do escopo

- Mudar a numeração (ADR-4 desta skill), o formato do ADR ou o `migrate`.
- Qualquer mudança no projeto `led-bomb-monitor`; o defeito foi só contornado lá rodando o comando da raiz.

## Fonte da observação

Projeto `led-bomb-monitor`, sessão de 2026-10-22: o arquivo errado foi criado em
`docs/architecture/ADR/docs/architecture/ADR/` e removido manualmente; nenhum ADR existente foi afetado.
