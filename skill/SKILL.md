---
name: adr-std
description: Cria, revisa, numera, relaciona e reorganiza ADRs (Architecture Decision Records, registros de decisão de arquitetura) seguindo a ISO/IEC/IEEE 42010:2022 (cláusula 6.10) com template MADR estendido, e audita a conformidade de descrições de arquitetura. Use quando o usuário pedir para criar, escrever, revisar, auditar, corrigir, renumerar ou organizar ADRs ou decisões de arquitetura, ou perguntar o que a norma 42010 exige. Creates, reviews and organizes ADRs following ISO/IEC/IEEE 42010:2022; independent skill, not endorsed by ISO, IEC or IEEE.
---

# adr-std

Skill para registrar decisões de arquitetura em conformidade com a **ISO/IEC/IEEE 42010:2022**.
Funciona em qualquer agente que leia `SKILL.md`. Documentação e respostas em pt-BR.

## Antes de tudo

1. Leia `references/guia-42010.md`, seções **1, 2, 3 e 15**. Elas definem o peso das regras
   (DEVE, DEVERIA, PODE), os limites da norma e o que é proibido afirmar.
2. Procure as regras do projeto: `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` e a convenção de ADRs
   (por exemplo `docs/architecture/ADR/CONVENTIONS.md`). Onde a regra do projeto for mais restritiva,
   ela prevalece. Onde conflitar com a norma, **avise o usuário** e peça decisão.
3. Ao citar uma exigência, diga a origem: **norma** (com a cláusula), **projeto** ou **skill**.

## Convenções do projeto (ADR-0001 e ADR-0003)

### Caminho dos ADRs

Resolva o caminho onde os ADRs são lidos e gravados nesta ordem (pare na primeira que encontrar):

1. Argumento explícito de pasta passado no comando (ex.: `--path <pasta>`).
2. Campo `path` no arquivo `.adr-std` na raiz do repositório.
3. Convenção declarada em `docs/architecture/ADR/CONVENTIONS.md` ou em `AGENTS.md`.
4. Campo `path` em `~/.config/adr-std/config` (Linux/macOS) ou `%APPDATA%\adr-std\config` (Windows).
   O usuário pode gravar esse nível pela CLI com `adr-std config path <pasta>` (mostra sem argumento, `--unset` remove).
5. **Padrão:** `docs/architecture/ADR/`

### ROADMAP.md (atualização automática)

Sempre que criar ou modificar um ADR **ou** uma Spec como parte de qualquer ação da skill:

1. Localize o arquivo `ROADMAP.md` dentro da pasta de ADRs do projeto.
2. Adicione ou atualize **apenas** a linha correspondente ao ADR ou Spec afetado.
3. Use o Status conforme a situação detectada:
   - ADR criado, sem Spec → `Não iniciada`
   - Spec com apenas `requirements.md` → `Só requisitos`
   - Spec com `design.md` criado → `Em andamento`
   - Spec com `tasks.md` e todas as tarefas `[x]` → `Concluída`
4. Não altere linhas de outros ADRs ou Specs que não foram tocados.
5. Ao concluir a ação principal, informe ao usuário: _"ROADMAP atualizado: [linha afetada]."_
6. Se o `ROADMAP.md` não existir na pasta de ADRs, crie-o com a estrutura definida no ADR-0002.

## Comandos de ação (v1.1)

Os comandos `/adr-std-<ação>` (Claude Code, Gemini CLI, OpenCode, Continue) e `$adr-std <ação>`
(Codex) chamam a skill com a ação já definida — o arquivo de comando não tem regra nenhuma, só a
chamada. As regras abaixo valem para a ação, seja ela chamada pelo comando específico ou deduzida
de `/adr-std <texto livre>`.

### `create` e `supersede` (conversa guiada)

1. Resuma o que entendeu do pedido antes de perguntar qualquer coisa.
2. Avise se a decisão parece trivial, se parecem ser duas decisões, ou se já existe ADR relacionado.
3. Conduza perguntas em rodadas de até **N** perguntas (opção `--ask N`, nomes curtos `-a N`):
   padrão **3**; fora da faixa 1 a 10, use o valor mais próximo e avise o motivo.
4. Com `--quick` (`-k`): não faça nenhuma pergunta — monte o ADR só com a descrição recebida,
   marque como `pendente` tudo que faltar (inclusive Decisão e Justificativa, exigidas pela norma);
   ao final, liste as pendências obrigatórias pela norma, as sugestões e o comando para completar
   (`/adr-std-review <arquivo>`). Se `--quick` vier sem nenhuma descrição, avise e **não crie** o
   arquivo.
5. Se `--quick` e `--ask` vierem juntos, siga o `--quick` e avise que ignorou o `--ask`.
6. Ao usuário dizer "gere com o que temos" (ou equivalente), encerre as perguntas e grave o
   rascunho com as pendências marcadas.
7. Sugestões (alternativa não citada, stakeholder esquecido, risco, ADR relacionado, decisão
   derivada, como verificar) aparecem marcadas como sugestão; nenhuma entra no ADR sem o usuário
   aceitar.
8. Nunca invente decisores, datas, alternativas ou justificativas; o que faltar fica `pendente`.
9. Status inicial sempre `Proposto`; só o decisor aprova.
10. `supersede` segue este mesmo fluxo e estas mesmas opções, além de: marcar o ADR antigo como
    `Substituído por ADR-NNNN`, atualizar "Modificado em" do antigo, e nunca apagar o ADR antigo.

### `new` (esqueleto sem perguntas)

Cria um único arquivo a partir de `references/template-madr.md`, com o próximo número pela
convenção do projeto, o ID, o título recebido, status `Proposto`, "Data da decisão" com a data de
hoje e todos os demais campos como `pendente` — **sem perguntas** e sem alterar nenhum outro
arquivo. Se o título vier vazio, avise e não crie o arquivo.

### `list` (listagem sem alterar arquivos)

Lista os ADRs da pasta indicada (ou da pasta de ADRs do projeto, se nenhuma for indicada) com ID,
título, status e data da decisão — sem alterar nenhum arquivo. Se a pasta não existir ou não tiver
ADRs, diga isso e não crie a pasta.

## Tarefas

### Criar um ADR

1. Aplique os critérios de decisão essencial (guia, seção 7.2). Se nenhum se aplicar, avise.
2. Confirme que é **uma** decisão. Duas decisões viram dois ADRs relacionados.
3. Leia os ADRs existentes para achar relações e evitar duplicata.
4. Descubra o próximo número pela convenção do projeto; na falta dela, `NNNN-` com 4 dígitos
   (o maior número existente + 1; nunca reutilize número).
5. Pergunte ao usuário o que faltar: decisores, autoridade que aprova, data, concerns, stakeholders,
   alternativas reais e o motivo de cada rejeição. **Não invente.**
6. Copie `references/template-madr.md` para `NNNN-<titulo-em-kebab-case>.md` e preencha.
7. Status inicial: `Proposto`. Só o decisor aprova; o agente nunca marca `Aceito` por conta própria.
8. Rode a verificação (seção "Verificar") e corrija o que falhar.
9. Mostre o resultado ao usuário com a lista do que ficou `pendente`.

Regras detalhadas: guia, seção 12.

### Revisar ou reorganizar ADRs

1. Rode a verificação em todos os ADRs e leia cada um contra `references/checklist.md`.
2. Não altere o sentido de ADR aceito: mudança de decisão exige novo ADR que o substitua.
3. Renumerar ou renomear arquivos quebra links: liste as referências afetadas, **mostre o plano** e
   só execute com autorização.
4. Mantenha relações recíprocas (se A substitui B, B fica `Substituído por ADR-A`).
5. Tire o andamento de implementação do campo Status (ele descreve a decisão, não a execução).
6. Entregue um relatório: o que mudou, o que falta, e a origem de cada exigência.

Regras detalhadas: guia, seção 13.

### Auditar a descrição de arquitetura completa

Só quando o usuário pedir conformidade da AD, não de um ADR. Siga o guia, seção 14 (cláusula 6
inteira). ADRs sozinhos cobrem a 6.10 e parte da 6.1; **não bastam** para alegar conformidade da AD.

### Responder dúvidas sobre a norma

Use o guia (seções 4 a 11) e cite a cláusula. Se o guia não cobrir, diga que não cobre; não invente.

## Verificar

Se o agente puder executar código:

```bash
python3 <pasta-da-skill>/scripts/check_adr.py <arquivo-ou-pasta-de-ADRs>
# numeração diferente da padrão, por exemplo "1-titulo.md":
python3 <pasta-da-skill>/scripts/check_adr.py <pasta> --name-pattern '^(\d+)-.+\.md$'
```

Saída: `0` passou; `1` falhou requisito da norma (N-DEVE); `2` falharam só recomendações ou regras
da skill. O script cobre os itens `[auto]` do checklist; os demais exigem leitura. Uma falha em B4
pode ser falso negativo quando a justificativa está referenciada em outra seção: confirme lendo.
Se não puder executar código, aplique o checklist inteiro à mão.

## Proibições (resumo; lista completa no guia, seção 15)

- Não afirmar conformidade, certificação ou endosso da ISO; não alegar conformidade da AD só com ADRs.
- Não copiar texto da norma: resuma e cite a cláusula (por exemplo "42010:2022, 6.10.2").
- Não juntar duas decisões num ADR; não apagar ADR aceito ou rejeitado.
- Não inventar decisores, datas, alternativas ou justificativas.
- Não fazer commit, push ou renomeação em massa sem autorização expressa.

## Arquivos

| Arquivo | Uso |
|---|---|
| `references/guia-42010.md` | Resumo detalhado de toda a norma e regras de criação, revisão e auditoria |
| `references/template-madr.md` | Template do ADR, com os campos da 6.10 |
| `references/checklist.md` | Checklist de conformidade, com a origem de cada item |
| `scripts/check_adr.py` | Verificação automática dos itens `[auto]` (Python 3, só biblioteca padrão) |
| `scripts/adr_cli.py` | Comandos mecânicos do terminal (`new`, `list`, `link`, `organize --dry-run`); o agente não precisa dele, mas pode usá-lo |
