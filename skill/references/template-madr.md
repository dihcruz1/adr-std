# ADR-NNNN: <título curto da decisão>

> Guia: template MADR estendido para cobrir a ISO/IEC/IEEE 42010:2022, cláusula 6.10.
> Copie para `NNNN-<titulo-em-kebab-case>.md`. Remova todas as linhas `> Guia:` e os marcadores
> `<...>` antes de concluir. Os códigos I1 a I11 remetem à seção 7.3 do `guia-42010.md`.

| Campo | Valor |
|---|---|
| **ID** | ADR-NNNN |
| **Status** | Proposto · Aceito · Rejeitado · Substituído por ADR-NNNN · Obsoleto |
| **Data da decisão** | AAAA-MM-DD |
| **Aprovado em** | AAAA-MM-DD · pendente |
| **Modificado em** | AAAA-MM-DD · — |
| **Decisores** | <quem tomou a decisão> |
| **Autoridade que aprova** | <quem aprova; pode ser igual aos decisores> |
| **Stakeholders afetados** | <papéis, pessoas ou organizações afetados> |
| **Concerns e aspectos** | <concerns (de preferência como perguntas) e aspectos a que a decisão se refere> |
| **Elementos afetados** | <componentes, views, módulos, serviços, dados ou documentos afetados> |
| **Relações com outras decisões** | <tipo + ADR, por exemplo: refina ADR-0002; conflita com ADR-0007; substitui ADR-0003> |

> Guia: tipos de relação (42010:2022, 6.10.1): restringe, influencia, habilita, dispara, força,
> engloba, refina, conflita com, expõe, é compatível com. Use também "substitui".

## Contexto e definição do problema

> Guia: o que força a decisão, em uma ou duas frases neutras. Pode ser uma pergunta
> ("Como devemos...?"). Se a decisão nasce de um problema conhecido de uma view, diga qual.

<...>

## Restrições e suposições

> Guia (I4): restrições (técnicas, legais, de prazo, de custo) e suposições que influenciam a decisão.

- **Restrição:** <...>
- **Suposição:** <...>

## Fatores de decisão (drivers)

> Guia: critérios que pesam na escolha: requisitos, atributos de qualidade, políticas.

- <driver 1>
- <driver 2>

## Opções consideradas

> Guia (6.10.1 e 6.10.2): liste as alternativas reais, inclusive as rejeitadas. Se só havia uma
> opção, explique por quê.

1. **<Opção A>**
2. **<Opção B>**

## Decisão

> Guia (I2, 6.10.1): enunciado claro e único da decisão.

Escolhemos **<opção>**.

## Justificativa

> Guia (I7, 6.10.2): por que esta opção, amarrada aos drivers. Cubra, quando couber: base da decisão,
> impacto em atributos de qualidade, trade-offs, princípios de arquitetura. Se a decisão escolhe um
> viewpoint, framework (ADF) ou linguagem (ADL), justifique a escolha.

<...>

## Prós e contras das opções

> Guia (6.10.2): evidência de que as alternativas foram consideradas. Para cada opção rejeitada,
> diga o motivo da rejeição.

### <Opção A> (escolhida)
- Prós: <...>
- Contras: <...>

### <Opção B> (rejeitada)
- Prós: <...>
- Contras: <...>
- **Motivo da rejeição:** <...>

## Consequências

> Guia (I9): efeitos da decisão, inclusive sobre outras decisões.

- **Positivas:** <...>
- **Negativas / custo:** <...>
- **Neutras / acompanhar:** <...>
- **Efeito em outras decisões:** <...>

## Verificação

> Guia: como saber se a decisão foi acertada (métricas, testes, critérios observáveis).

<...>

## Limitações deste registro

> Guia (6.10.2): o que ficou de fora e por quê (falta de tempo, de dado, coberto por outro documento).
> Escreva "Nenhuma" se não houver.

<...>

## Histórico de modificações

> Guia (I10): uma linha por alteração relevante depois da aprovação.

| Data | Alteração | Autor |
|---|---|---|
| AAAA-MM-DD | Criação | <...> |

## Referências

> Guia (I11): fontes citadas, no formato bibliográfico do projeto (por exemplo, ABNT NBR 6023).
> Cite a norma pela cláusula; nunca copie o texto dela.

- <...>
