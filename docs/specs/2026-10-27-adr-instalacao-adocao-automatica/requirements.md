# Requisitos — instalação com adoção automática de pastas existentes

Data: 2026-10-27. Fonte: exploração com o responsável (`/opsx:explore`) e leitura de `bin/adr-std`, `install.sh`, `install.ps1` e `agents.tsv`. Status: Gate 1 aprovado em 2026-10-27; ajustado pela auditoria 360° (achados 1, 2, 4, 5 e 6).

## Premissas

- Não há referência de feature em `docs/features/` (pasta vazia); a ausência fica registrada aqui e a fonte são as decisões do responsável.
- O escopo continua sendo a instalação **global** no perfil do usuário. Instalação por projeto ou por pasta qualquer está fora de escopo (decisão do responsável em 2026-10-27).

## Causa-raiz

Em `bin/adr-std` (`install_to`, `owned_by_us`, `cmd_install`):

1. Uma pasta `adr-std` só é "nossa" se estiver registrada no estado (`~/.config/adr-std/state`) e tiver o marcador ou um link exato para `$SRC/skill`. Quem instalou à mão (cópia ensinada no README, link para o repositório ou link encadeado) nunca é reconhecido.
2. Pasta não reconhecida gera erro com código 4, e o `install_to ... || return $?` em `cmd_install` interrompe o laço inteiro. Com `--all`, o primeiro conflito (na ordem, `claude-code`) impede a instalação em todos os agentes seguintes e dos comandos `/adr-std-*`.
3. Sem registro no estado, `adr-std update` responde "nenhum agente registrado" para essas pastas.

Efeito observado na máquina do responsável: nenhum estado, quatro destinos como links manuais (`~/.agents/skills/adr-std` direto para o repositório; `~/.claude`, `~/.codex` e `~/.continue` encadeados por ele) e `adr-std status` dizendo "skill não instalada".

## Decisões aceitas

| ID | Decisão |
|---|---|
| D-1 | Cada destino é classificado em: ausente, nosso, link para o repositório, `adr-std` de terceiros, outra coisa. |
| D-2 | Link (direto ou encadeado) cujo destino final é a pasta `skill/` do repositório de origem é adotado no lugar: nenhum arquivo é alterado e não há pergunta nem backup. |
| D-3 | `adr-std` de terceiros (cópia, ou link para fora do repositório de origem) é adotado com confirmação `[s/N]`; a pasta antiga vai para `adr-std.bak-<AAAA-MM-DD>` ao lado, sem apagar. Sem terminal, só com `--adopt`. |
| D-4 | Pasta ou skill que não é `adr-std` nunca é tocada; o instalador avisa e segue. |
| D-5 | Um conflito não interrompe o laço; o instalador resume no fim e sinaliza no código de saída o que foi pulado. |

## Requisitos verificáveis (EARS)

- **RF-01:** QUANDO o destino não existir, `adr-std install` DEVE instalar a skill (comportamento atual preservado).
- **RF-02:** QUANDO o destino for nosso (registrado e com marcador ou link para a fonte), `adr-std install` DEVE atualizá-lo (comportamento atual preservado). SE o modo registrado do destino for `link` (inclusive o adotado no lugar pelo RF-03), a nova execução DEVE mantê-lo como link para a fonte, nunca convertê-lo em cópia, mesmo sem `--link`.
- **RF-03:** QUANDO o destino for um link, direto ou encadeado, cujo destino final resolva para a pasta `skill/` do repositório de origem, o sistema DEVE registrá-lo no estado sem alterar o link, sem perguntar e sem criar backup.
- **RF-04:** QUANDO o destino for uma pasta ou link reconhecido como `adr-std` (o `SKILL.md` declara `name: adr-std`) que não se enquadre no RF-03, o sistema DEVE mostrar o que será substituído e, em terminal interativo, pedir confirmação `[s/N]`. A resposta padrão (vazia ou diferente de `s`/`S`) DEVE recusar a adoção.
- **RF-05:** QUANDO a adoção do RF-04 for confirmada, o sistema DEVE mover a pasta antiga para `adr-std.bak-<AAAA-MM-DD>` no mesmo diretório e só então instalar. SE esse nome de backup já existir, DEVE acrescentar um sufixo numérico em vez de sobrescrever.
- **RF-06:** QUANDO não houver terminal interativo e `--adopt` não tiver sido informado, o sistema DEVE pular o destino do RF-04, sem alterá-lo, e indicar `--adopt` na mensagem.
- **RF-07:** QUANDO `--adopt` for informado, o sistema DEVE adotar os destinos do RF-04 com backup (RF-05), sem perguntar. `--adopt` DEVE valer só para `adr-std` reconhecido (RF-04), nunca para o RF-08.
- **RF-08:** QUANDO o destino existir e não for `adr-std` reconhecido (outra skill, pasta sem `SKILL.md`, `name` diferente), o sistema DEVE mantê-lo intacto, avisar e seguir, mesmo com `--adopt`.
- **RF-09:** QUANDO um destino for pulado por qualquer motivo (RF-06 e RF-08, recusa no RF-04, falha ao criar o backup do RF-05, caso em que nada é instalado por cima, ou falha da própria instalação do destino), o sistema DEVE continuar nos demais destinos e comandos, listar no fim o que foi pulado e por quê, e terminar com código 4. Sem nenhum pulo, o código DEVE ser 0.
- **RF-10:** QUANDO `--dry-run` for informado, o sistema DEVE listar a classificação e a ação planejada de cada destino sem alterar nenhum arquivo nem o estado. A simulação NÃO DEVE pedir confirmação: para destinos do RF-04 em terminal, DEVE mostrar a ação como `perguntaria` e, sem terminal e sem `--adopt`, como `pularia`.
- **RF-11:** O estado DEVE registrar o modo (`link` ou `copy`) por agente, e `adr-std status`, `uninstall` e `update` DEVEM tratar corretamente destinos adotados. `uninstall` DEVE remover só o que o instalador instalou ou adotou no lugar sem backup; o `adr-std.bak-*` DEVE ser mantido. `update` NÃO DEVE substituir destinos em modo `link` (eles já seguem o repositório) e DEVE informar o motivo; QUANDO o instalador devolver o código 4 por pulo, `update` DEVE mostrar o resumo, executar a migração de ADRs normalmente e terminar com 4.
- **RF-12:** QUANDO dois agentes compartilharem a mesma pasta de destino (por exemplo `~/.agents/skills`), a classificação e a adoção DEVEM ocorrer uma única vez por pasta.
- **RF-13 (Windows):** O mesmo comportamento DEVE valer em `install.ps1` e `bin/adr-std.ps1`, tratando junções e links simbólicos do NTFS como links.
- **RF-14 (documentação):** README, `SKILL.md` (se citar a instalação) e CHANGELOG DEVEM descrever a adoção, `--adopt` e o código 4 por pulo, e o README DEVE deixar de apresentar a cópia manual como caminho que o instalador recusa.

### Segurança

- **SEG-01:** O sistema NUNCA DEVE apagar conteúdo de terceiros: toda substituição passa por backup (RF-05) ou por adoção no lugar sem alteração (RF-03).
- **SEG-02:** A resolução de links (RF-03) DEVE limitar a cadeia (profundidade máxima) e tratar ciclos como "outra coisa" (RF-08), sem seguir indefinidamente.
- **SEG-03:** O reconhecimento por `name: adr-std` DEVE ler apenas o frontmatter do `SKILL.md` do destino, como dado, sem executar nada dele.
- **SEG-04:** A adoção DEVE operar só dentro das pastas de skills listadas em `agents.tsv` sob o perfil do usuário; sem `sudo` nem escrita fora do perfil.
- **SEG-05:** Testes em perfis temporários (`HOME`, `XDG_*`, `APPDATA` isolados), sem credenciais, push, release ou deploy.

Comportamento aceito: um link para o `skill/` de outro clone do repositório não é o repositório de origem; é tratado como `adr-std` de terceiros (RF-04), com confirmação e backup.

Riscos e mitigações: (1) adoção por engano de uma pasta do usuário que só se parece com `adr-std`: confirmação padrão "não" e backup obrigatório; (2) estado misto `link`/`copy` quebrar `update`: modo por agente (RF-11); (3) link encadeado circular ou muito longo: SEG-02; (4) backup acumulando em `~/.<agente>/skills`: documentar a remoção manual, sem apagar automaticamente.

## Matriz de não-regressão

| Cenário | Esperado após a mudança |
|---|---|
| Destino ausente | Instala, igual a hoje |
| Destino nosso, cópia | Atualiza, igual a hoje |
| Destino nosso, `--link` | Recria o link, igual a hoje |
| `uninstall` de destino instalado | Remove só o que é nosso; pasta de terceiros intacta |
| `update` (release remota) | Reinstala nos agentes registrados, igual a hoje; passa a cobrir os adotados |
| `--agent` inválido | Código 2 com sugestão, igual a hoje |
| Nenhum agente encontrado | Código 3, igual a hoje |
| Segunda execução de `install` sobre link adotado | O link continua link (RF-02); nunca vira cópia |
| `update` com algum destino pulado | Migração de ADRs roda; código 4 no fim |
| Conflito com pasta de outra skill | Antes: erro 4 e laço interrompido; depois: erro 4 no fim, demais destinos instalados |
| Instalação dos comandos `/adr-std-*` | Passa a ocorrer mesmo com conflito de skill em algum agente |

## Cenários (Gherkin)

```gherkin
Cenário: link encadeado para o repositório é adotado no lugar
  Dado que ~/.claude/skills/adr-std aponta para ~/.agents/skills/adr-std
  E que ~/.agents/skills/adr-std aponta para a pasta skill/ do repositório de origem
  Quando o usuário roda "adr-std install --agent claude-code"
  Então o link permanece como estava
  E o agente claude-code fica registrado no estado
  E nenhum backup é criado

Cenário: cópia manual é adotada com confirmação e backup
  Dado que ~/.codex/skills/adr-std é uma cópia com SKILL.md "name: adr-std"
  Quando o usuário roda "adr-std install --agent codex" em terminal e responde "s"
  Então a pasta antiga vira ~/.codex/skills/adr-std.bak-2026-10-27
  E a skill atual é instalada em ~/.codex/skills/adr-std

Cenário: sem terminal e sem --adopt
  Dado que ~/.codex/skills/adr-std é uma cópia com SKILL.md "name: adr-std"
  Quando o instalador roda sem terminal e sem --adopt
  Então a pasta permanece intacta
  E a mensagem indica --adopt
  E o código de saída é 4

Cenário: outra skill no mesmo nome de pasta
  Dado que ~/.kiro/skills/adr-std tem SKILL.md com "name: outra-coisa"
  Quando o usuário roda "adr-std install --all --adopt"
  Então a pasta permanece intacta, com aviso
  E os demais agentes são instalados
  E o código de saída é 4

Cenário: um conflito não impede os outros destinos
  Dado que ~/.claude/skills/adr-std é de terceiros e o usuário recusa a adoção
  Quando o usuário roda "adr-std install --all"
  Então os demais agentes encontrados são instalados
  E os comandos /adr-std-* são criados
  E o resumo final lista o claude-code como pulado

Cenário: simulação
  Quando o usuário roda "adr-std install --all --dry-run"
  Então a saída mostra a classificação e a ação de cada destino
  E nenhum arquivo nem o estado são alterados
```

## Fora de escopo

- Instalação por projeto ou em pasta arbitrária.
- Mudança no `update` além de cobrir destinos adotados (sem novo canal de atualização).
- Remoção automática de `adr-std.bak-*`.
- Número da versão e publicação da release: decisão do responsável, com autorização pontual.
