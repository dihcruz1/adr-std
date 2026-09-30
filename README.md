# Skills

Repositório de desenvolvimento de skills globais no formato aberto `SKILL.md`, para uso em qualquer
agente (Claude Code, Codex, Gemini, Antigravity, OpenCode e outros).

| Skill | Status | Descrição |
|---|---|---|
| `adr-std` | Em validação | ADRs segundo a ISO/IEC/IEEE 42010:2022 (cláusula 6.10), com template MADR estendido |

## Estrutura

```
Skills/
├── README.md
└── adr-std/
    ├── SKILL.md                 # ponto de entrada para o agente
    ├── references/
    │   ├── guia-42010.md        # resumo detalhado da norma, com palavras próprias
    │   ├── template-madr.md     # template do ADR
    │   └── checklist.md         # checklist de conformidade
    ├── scripts/
    │   └── check_adr.py         # verificação automática (Python 3, só biblioteca padrão)
    └── tests/
        ├── cenarios.md          # cenários de validação por agente
        └── fixtures/            # ADR de exemplo que deve passar na verificação
```

## Decisões tomadas (adr-std)

| # | Decisão | Escolha |
|---|---|---|
| 1 | Controle de versão | `git init` local, sem remoto |
| 2 | Idioma | Instruções em pt-BR; `description` do `SKILL.md` com termos em pt-BR e inglês |
| 3 | Script de verificação | Incluído (`scripts/check_adr.py`); as regras também estão no `checklist.md` para agentes sem execução de código |
| 4 | Numeração padrão dos ADRs | `NNNN-kebab-case.md` (4 dígitos); a convenção do projeto prevalece; o script aceita `--name-pattern` |

## Pendente

1. **Instalação nos agentes.** Proposta: link simbólico de `~/.agents/skills/adr-std` para esta pasta e,
   para cada agente que não leia `~/.agents/skills` sozinho, um link no diretório dele. Conferir na
   documentação de cada agente antes. Nada foi instalado.
2. **Validação.** Rodar `adr-std/tests/cenarios.md` em cada agente e registrar o resultado.

## Validar o script

```bash
python3 adr-std/scripts/check_adr.py adr-std/tests/fixtures/0001-cache-de-sessao-em-redis.md  # saída 0
python3 adr-std/scripts/check_adr.py adr-std/references/template-madr.md                       # saída 1
```

## Restrições

- Sem texto copiado da norma; o guia é resumo com palavras próprias e cita as cláusulas.
- A cópia licenciada da norma não entra neste repositório.
- A skill é independente e não tem endosso da ISO, do IEC nem do IEEE; por isso o nome não usa "ISO".
- Nada é instalado nos agentes sem autorização expressa.
