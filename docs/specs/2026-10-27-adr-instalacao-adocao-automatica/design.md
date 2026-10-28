# Design — instalação com adoção automática de pastas existentes

Data: 2026-10-27. Fonte: `requirements.md` (Gate 1 aprovado em 2026-10-27) e leitura de `bin/adr-std`, `bin/adr-std.ps1`, `install.sh`, `install.ps1`, `agents.tsv`. Status: Gate 2 aprovado em 2026-10-27; ajustado pela auditoria 360° (achados 1, 3, 5 e 6).

## Escopo e princípios

Mudança confinada ao instalador (`bin/adr-std`, `bin/adr-std.ps1`) e ao estado. Sem DDD tático: é um script de instalação, sem domínio rico. KISS e YAGNI: uma função de classificação somente leitura e uma de ação; nenhuma abstração nova (Rule of Three não atingida). `install.sh` e `install.ps1` não mudam: delegam a `adr-std install` e herdam o novo comportamento. Python (`skill/scripts/`) não muda.

## Visão geral

```
cmd_install
  para cada destino único (dedupe por pasta, RF-12)
     |
     +-- classify_dest <pasta>          (leitura apenas; testável isolada)
     |       absent | ours | repo-link | foreign-adr-std | foreign-other
     |
     +-- act_on_dest <classe> <pasta>   (única que escreve)
             absent          -> instalar                    (RF-01)
             ours            -> reinstalar (atualiza), mantendo o
                                modo do estado: link continua link  (RF-02)
             repo-link       -> registrar sem alterar       (RF-03)
             foreign-adr-std -> confirmar [s/N] | --adopt | pular
                                backup .bak-<data> + instalar (RF-04..07)
             foreign-other   -> pular com aviso             (RF-08)
  registra no estado só destinos instalados ou adotados
  install_commands roda sempre (RF-09)
  resumo final; código 4 se houve pulo, senão 0
```

## Decisões de design

| ID | Decisão | Motivo |
|---|---|---|
| D-6 | Resolver a cadeia de links com laço manual de `readlink` (profundidade máxima 10), sem `readlink -f` | `-f` não é portátil (macOS antigo); o laço dá limite e detecção de ciclo (SEG-02) |
| D-7 | "Link para o repositório" = o destino final da cadeia é igual a `$SRC/skill` ou a `$DATA_DIR/skill` (as duas raízes que `owned_by_us` já aceita) | Reaproveita a regra atual de propriedade e cobre quem instalou pelo `curl` |
| D-8 | `owned_by_us` passa a usar a cadeia resolvida (não só `readlink` exato) | Sem isso, um link encadeado adotado voltaria a ser "de terceiros" na segunda execução |
| D-9 | Estado: a linha `agent` ganha uma 4ª coluna com o modo (`agent<TAB>id<TAB>pasta<TAB>link\|copy`); a linha global `mode` continua gravada | Leitores atuais usam só as colunas 2 e 3, então o formato antigo segue válido; linha sem 4ª coluna cai no `mode` global |
| D-10 | `update` pula destinos com modo `link` e informa que eles já seguem o repositório | Atualizar pela release trocaria o link de quem desenvolve por cópia, contra RF-03 e a decisão de preservar o link |
| D-11 | Reconhecer `adr-std` de terceiros pelo `name: adr-std` no frontmatter do `SKILL.md` do destino (primeiro bloco `---`, até 20 linhas, leitura como texto) | KISS; SEG-03 |
| D-12 | Backup por `mv` da pasta ou do link (sem desreferenciar), nome `adr-std.bak-<AAAA-MM-DD>`, com sufixo `-2`, `-3` se existir | RF-05 e SEG-01 |
| D-13 | Sem terminal e sem `--adopt`: pular o destino foreign-adr-std; `--adopt` não afeta foreign-other | RF-06, RF-07 e RF-08 |
| D-14 | O código de saída 4 reaproveita o valor atual de "pasta não nossa"; o resumo final diz quais destinos foram pulados e por quê | Mantém o contrato público, só muda quando ele é devolvido (no fim, não no primeiro conflito) |
| D-15 | Windows: junção e link simbólico são tratados como link pelo atributo `ReparsePoint` e pela propriedade `Target`; a mesma cadeia e o mesmo limite | RF-13 |
| D-16 | `ours` em modo `link` (lido de `state_agent_mode`) é recriado como link para a fonte, mesmo sem `--link`; `ours` em modo `copy` segue como cópia. `--link` explícito converte `copy` em `link` (comportamento atual) | Sem isso, a segunda execução converteria o link adotado em cópia e desfaria o RF-03 |
| D-17 | `update` trata o código 4 do instalador como aviso: imprime o resumo, executa `maybe_migrate` e devolve 4 no fim; os demais códigos de erro continuam interrompendo | Hoje `[ "$rc" -eq 0 ] \|\| return "$rc"` pularia a migração de ADRs com um simples pulo |
| D-18 | Um link para o `skill/` de outro clone não é a fonte; cai em `foreign-adr-std` (confirmação e backup) | Coerente com o RF-04; só é registrado como comportamento aceito |

## Contratos

### `classify_dest <pasta>` (leitura apenas, imprime uma classe)

| Condição (nesta ordem) | Classe |
|---|---|
| Não existe (nem como link quebrado) | `absent` |
| Registrada no estado e (marcador, ou cadeia chega a `$SRC/skill`/`$DATA_DIR/skill`) | `ours` |
| Link cuja cadeia chega a `$SRC/skill` ou `$DATA_DIR/skill` | `repo-link` |
| Cadeia com ciclo ou mais de 10 saltos, ou link quebrado | `foreign-other` |
| `SKILL.md` com `name: adr-std` | `foreign-adr-std` |
| Qualquer outro caso (sem `SKILL.md`, `name` diferente) | `foreign-other` |

`ours` e `repo-link` diferem só pelo registro no estado: `repo-link` ainda não registrado vira `ours` depois da adoção.

### `adr-std install` (mudança de contrato)

- Nova opção `--adopt`; `--dry-run` passa a imprimir `<pasta>: <classe> -> <ação>` por destino, sem nunca perguntar: `foreign-adr-std` aparece como `perguntaria` (com terminal), `adotaria` (com `--adopt`) ou `pularia` (sem terminal e sem `--adopt`).
- Cada destino resulta em `installed`, `updated`, `adopted-in-place`, `adopted-with-backup` ou `skipped:<motivo>`.
- Motivos de pulo: `sem-terminal` (com a dica `--adopt`), `recusado`, `outra-skill`, `backup-falhou` (nada é instalado por cima), `falha-na-instalacao` (a cópia ou o link falhou; o laço segue nos demais destinos).
- Resumo final: uma linha por destino pulado; código 4 se houver pelo menos um pulo, senão 0. Nunca há `return` no meio do laço por causa de conflito.
- `install_commands` roda mesmo com pulo de skill (RF-09).

### Estado (D-9)

```
version<TAB>3.0.0
mode<TAB>copy|link                 (último install; compatibilidade)
agent<TAB>claude-code<TAB>~/.claude/skills/adr-std<TAB>link
command<TAB>claude-code<TAB>~/.claude/commands/adr-std-create.md
```

`cmd_status` mostra o modo por agente (`[íntegra, link]`) e cai no `mode` global quando a coluna falta.

### `update`

Filtra os agentes em modo `link` antes de chamar o instalador remoto e informa o motivo (D-10). Se o instalador devolver 4, mostra o resumo, executa `maybe_migrate` e devolve 4 (D-17).

### `uninstall`

Segue como está: remove só o que `owned_by_us` aprova. Para destino adotado em `link`, remove o link (não o alvo); `adr-std.bak-*` nunca é removido (RF-11).

## Segurança

| Requisito | Como o design atende |
|---|---|
| SEG-01 | Nada é removido sem backup ou adoção no lugar; `rm` só em destino `ours`; o backup é `mv` |
| SEG-02 | Laço de `readlink` com máximo de 10 saltos e detecção de ciclo por repetição; excedeu, `foreign-other` |
| SEG-03 | `SKILL.md` lido com `head`/`sed` como texto; nunca `source` nem execução |
| SEG-04 | Os destinos vêm de `agents.tsv` sob `$HOME`; nenhum caminho vem de argumento livre |
| SEG-05 | Testes com `HOME`, `XDG_*`, `ADR_STD_TTY` e `APPDATA` temporários; sem rede, push ou release |

Riscos adicionais: (1) `--adopt` combinado com `--all` adota várias pastas de uma vez, mitigado pelo backup por destino e pelo resumo; (2) o `mv` do backup falhar por permissão: o destino é pulado com motivo `backup-falhou` e não se instala por cima; (3) o `update` ignorar links pode surpreender: a mensagem informa o motivo.

## Estratégia de testes

TDD por camada (RED, GREEN, REFACTOR), nos arquivos existentes `tests/test_cli.sh` (Bash) e `tests/test_cli.ps1` (Pester), em perfis temporários.

| Teste (Bash; Pester espelha em D-15) | Requisito |
|---|---|
| `classify_dest`: ausente, nosso, link direto, link encadeado, cópia `adr-std`, outra skill, ciclo, link quebrado | RF-01..04, RF-08, SEG-02 |
| Link encadeado para o repositório: adotado, link intacto, sem backup, registrado | RF-03 |
| Cópia manual com `ADR_STD_TTY` respondendo `s`: backup criado, instalação nova | RF-04, RF-05 |
| Mesma cópia com resposta vazia e com `n`: intacta, código 4 | RF-04 |
| Sem terminal e sem `--adopt`: intacta, mensagem com `--adopt`, código 4 | RF-06 |
| `--adopt`: adota com backup; `--adopt` em outra skill: intacta | RF-07, RF-08 |
| Backup já existente: sufixo, nada sobrescrito | RF-05 |
| Segunda execução de `install` sobre link adotado, sem `--link`: continua link | RF-02, D-16 |
| `--dry-run` com adoção: não pergunta (`perguntaria`/`adotaria`/`pularia`) | RF-10 |
| `update` com pulo: migração roda, código 4 no fim | RF-11, D-17 |
| Link para o `skill/` de outro clone: tratado como `foreign-adr-std` | D-18 |
| `--all` com conflito no primeiro agente: demais instalados, comandos criados, código 4 e resumo | RF-09 |
| `--dry-run`: classificação impressa, nada alterado, estado igual | RF-10 |
| Estado com 4ª coluna: `status`, `uninstall`, `update` (pula `link`); estado antigo sem coluna ainda funciona | RF-11 |
| Dois agentes na mesma pasta compartilhada: uma classificação e uma adoção | RF-12 |
| Regressão: instalação em perfil limpo, `update`, `uninstall`, `agents` inalterados | Matriz de não-regressão |
| Windows: junção para o repositório adotada no lugar; cópia com backup | RF-13 |

Gate estático: `bash tests/gate.sh static`, mais `python3 -m unittest` (143 testes, sem mudança esperada) e CI com o job Windows verde antes de fechar RF-13.

## Documentação

README (seção de instalação e a cópia manual), `CHANGELOG.md` em `[Não lançado]`, ajuda do comando (`--adopt`). `SKILL.md` só muda se citar a instalação. Sem ADR novo: a decisão fica nesta spec, e a emenda ao ADR-1 não se aplica (o ADR-1 trata do caminho dos ADRs, não da instalação). Reavaliar na auditoria 360° se o ROADMAP deve ganhar uma versão.
