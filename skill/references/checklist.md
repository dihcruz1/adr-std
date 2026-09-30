# Checklist de conformidade de um ADR (ISO/IEC/IEEE 42010:2022, 6.10)

Use antes de propor um ADR como `Aceito` e ao revisar ADRs existentes. Cada item diz a origem:
**N-DEVE** (requisito da norma), **N-DEVERIA** (recomendação da norma; ausência exige motivo
registrado), **S** (regra da skill) ou **P** (regra do projeto, quando existir).

Os itens marcados com `[auto]` são verificados por `scripts/check_adr.py`. Os demais exigem leitura.

## A. Identificação e forma

- [ ] `[auto]` A1 (S/P) Nome do arquivo segue a convenção (`NNNN-kebab-case.md` por padrão).
- [ ] `[auto]` A2 (N-DEVERIA, I1) ID do cabeçalho existe e coincide com o número do arquivo.
- [ ] `[auto]` A3 (S) Status é um dos valores: Proposto, Aceito, Rejeitado, Substituído por ADR-NNNN, Obsoleto.
- [ ] `[auto]` A4 (N-DEVERIA, I10) "Data da decisão" em AAAA-MM-DD.
- [ ] `[auto]` A5 (N-DEVERIA, I10) "Aprovado em" preenchido (data ou `pendente`); se Status = Aceito, é uma data.
- [ ] `[auto]` A6 (N-DEVERIA, I10) "Modificado em" preenchido (data ou `—`).
- [ ] `[auto]` A7 (S) Nenhuma linha `> Guia:` nem marcador `<...>` restante.
- [ ] A8 (S) Uma única decisão no ADR.

## B. Decisão e justificativa (núcleo da 6.10)

- [ ] `[auto]` B1 (N-DEVE, 6.10.1) Seção "Decisão" existe e não está vazia.
- [ ] B2 (N-DEVERIA, I2) A decisão está enunciada com clareza, sem ambiguidade.
- [ ] B3 (S) A decisão é essencial por ao menos um critério da seção 7.2 do guia.
- [ ] `[auto]` B4 (N-DEVE, 6.10.2) Seção "Justificativa" existe e não está vazia.
- [ ] B5 (S) A justificativa está amarrada aos fatores de decisão.
- [ ] B6 (N-DEVERIA, 6.10.2) Se a decisão escolhe viewpoint, ADF ou ADL, a escolha está justificada.

## C. Alternativas

- [ ] `[auto]` C1 (N-DEVERIA, 6.10.1) Há ao menos duas opções consideradas, ou explicação de por que só havia uma.
- [ ] `[auto]` C2 (N-DEVERIA, 6.10.1) Cada opção rejeitada tem "Motivo da rejeição".
- [ ] C3 (N-DEVERIA, 6.10.2) Os prós e contras são evidência real de que as opções foram avaliadas.

## D. Responsáveis, contexto e ligações

- [ ] `[auto]` D1 (N-DEVERIA, I3) "Decisores" preenchido.
- [ ] D2 (N-DEVERIA, I3) "Autoridade que aprova" preenchida.
- [ ] `[auto]` D3 (N-DEVERIA, I4) "Restrições e suposições" preenchida.
- [ ] `[auto]` D4 (N-DEVERIA, I5) "Concerns e aspectos" preenchido.
- [ ] D5 (S) "Stakeholders afetados" preenchido.
- [ ] `[auto]` D6 (N-DEVERIA, I6) "Elementos afetados" preenchido.
- [ ] D7 (N-DEVERIA, I8) Cada relação com outro ADR traz o tipo (restringe, refina, conflita com, substitui...).
- [ ] D8 (S) Relações recíprocas coerentes (se A substitui B, B está "Substituído por A").

## E. Consequências, verificação e limites

- [ ] `[auto]` E1 (N-DEVERIA, I9) Seção "Consequências" preenchida.
- [ ] E2 (N-DEVERIA, I9) Efeito em outras decisões considerado.
- [ ] `[auto]` E3 (S) Seção "Verificação" preenchida.
- [ ] `[auto]` E4 (N-DEVERIA, 6.10.2) Seção "Limitações deste registro" preenchida (ou "Nenhuma").
- [ ] `[auto]` E5 (N-DEVERIA, I11) Seção "Referências" existe.
- [ ] E6 (S) A norma é citada pela cláusula, sem texto copiado.

## F. Linguagem e alegações

- [ ] F1 (S) O ADR não afirma conformidade da AD, certificação nem endosso da ISO.
- [ ] F2 (S) O Status descreve a decisão, não o andamento da implementação.
- [ ] F3 (P) Idioma e formato bibliográfico seguem o projeto.

## Resultado

- Algum item **N-DEVE** falhou: o ADR não atende à 6.10. Não pode ser proposto como Aceito.
- Algum item **N-DEVERIA** falhou sem motivo registrado: corrigir ou registrar o motivo em
  "Limitações deste registro".
- Itens **S** e **P** que falharam: corrigir, salvo decisão explícita do usuário.
