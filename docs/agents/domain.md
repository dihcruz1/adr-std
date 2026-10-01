# Domain Docs

Como as engineering skills devem consumir a documentação de domínio deste repo ao explorar o código.

## Antes de explorar, leia estes

- **`GLOSSARY.md`** na raiz do repo (se existir).
- **`docs/architecture/ADR/`**: leia os ADRs que tocam a área em que vai trabalhar.
  - O caminho padrão dos ADRs neste projeto é `docs/architecture/ADR/` (decisão registrada no **ADR-0001**).
  - Leia também o **`docs/architecture/ADR/ROADMAP.md`** para entender o estado de implementação de cada decisão.

Se algum desses arquivos não existir, **prossiga silenciosamente**. Não sinalize a ausência; não sugira criá-los antecipadamente.

## Estrutura de arquivos (single-context)

```
/
├── GLOSSARY.md
├── docs/
│   ├── architecture/
│   │   └── ADR/
│   │       ├── ROADMAP.md
│   │       ├── 0001-caminho-padrao-dos-adrs-e-personalizacao.md
│   │       ├── 0002-roadmap-rastreabilidade-etapas-specs.md
│   │       └── 0003-atualizacao-automatica-do-roadmap-pelo-agente.md
│   ├── agents/          ← este diretório
│   └── specs/           ← especificações técnicas por versão
└── skill/               ← conteúdo instalado nos agentes
```

## Use o vocabulário do GLOSSARY.md

Quando sua saída nomear um conceito de domínio, use o termo conforme definido em `GLOSSARY.md`.
Não derive para sinônimos que o glossário evita explicitamente.

Se o conceito não estiver no glossário ainda, é um sinal: ou você está inventando linguagem que o projeto não usa (reconsidere) ou há uma lacuna real (anote para `/domain-modeling`).

## Flag de conflito com ADR

Se sua saída contradizer um ADR existente, sinalize explicitamente em vez de substituir silenciosamente:

> _Contradiz ADR-000X (...), mas vale reabrir porque…_

## Atualização automática do ROADMAP

Conforme **ADR-0003**: sempre que criar ou modificar um ADR ou uma Spec, atualize a linha correspondente em `docs/architecture/ADR/ROADMAP.md` silenciosamente, sem pedir confirmação, e informe ao usuário ao final.
