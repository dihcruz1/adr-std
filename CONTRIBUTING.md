# Contribuindo com o adr-std

## Estrutura

```
adr-std/
├── README.md, CHANGELOG.md, LICENSE, VERSION   # documentação e versão
├── agents.tsv                                  # agentes suportados (dado, não código)
├── install.sh · install.ps1                    # instaladores (Linux/macOS · Windows)
├── bin/                                        # o comando adr-std (bash e PowerShell)
├── packaging/                                  # atalhos de duplo clique que entram no zip
├── package.sh                                  # gera dist/adr-std.zip e .sha256
├── skill/                                      # SÓ isto vai para os agentes, com o nome "adr-std"
├── tests/                                      # testes e cenários de validação
└── docs/specs/                                 # specs (requisitos, design, tarefas)
```

Regra: tudo o que o agente lê fica em `skill/`. O que é de distribuição ou desenvolvimento fica fora dela.

## Como trabalhamos

- **Specs primeiro.** Mudanças complexas seguem `docs/specs/<AAAA-MM-DD>-<nome>/` com `requirements.md`,
  `design.md` e `tasks.md`, aprovados em três etapas. Em `tasks.md`, o ID da tarefa vai em texto puro (ex.: `1.1`).
- **TDD.** Escreva o teste que falha, faça passar, refatore. Marque a tarefa como concluída só com evidência de teste.
- **Idioma.** Documentação e mensagens em pt-BR; código, arquivos, testes e comandos em inglês.
- **Commits** só com autorização de quem mantém o repositório.

## Rodar os testes

```bash
python3 -m unittest discover -s tests -p 'test_*.py' -v   # scripts Python (check_adr, check_roadmap, adr_cli)
bash tests/test_cli.sh                                             # comando e instalador (bash)
bash tests/test_cli.sh install_menu update                         # só alguns testes
```

Os testes nunca usam o seu `HOME`: cada um roda num diretório temporário. Os testes de download sobem um servidor local
(`python3 -m http.server`) e usam a variável `ADR_STD_BASE_URL`.

## Desenvolver a skill

- Instale com links para editar e ver o efeito na hora: `./install.sh --link --agent claude-code`. Antes, o instalador
  copia a fonte; use `adr-std install --link` para apontar para a pasta `skill/` do repositório.
- Depois de mudar a skill, rode `python3 skill/scripts/check_adr.py tests/fixtures/1-cache-de-sessao-em-redis.md`
  (deve sair `0`) e os cenários de `tests/cenarios.md` em pelo menos dois agentes.
- O guia (`skill/references/guia-42010.md`) é resumo com palavras próprias. **Não cole trechos da norma.** Cite a cláusula.

## Adicionar ou corrigir um agente

Edite uma linha de `agents.tsv` (colunas separadas por tabulação: id, nome, pasta que indica o agente, pasta de skills,
lê a pasta compartilhada). Rode `bash tests/test_cli.sh agents_file` e confira o caminho na documentação do agente.

## Gerar uma versão

1. Atualize `VERSION` e o `CHANGELOG.md`.
2. `./package.sh --release` (exige todos os arquivos do pacote) gera `dist/adr-std.zip` e `dist/adr-std.zip.sha256`.
3. A publicação é feita pelo workflow ao criar a tag `vX.Y.Z`, e só se o gate de segurança passar (ver
   `.github/workflows/release.yml`).

## Segurança

- Não peça nem armazene credenciais. Os instaladores não usam `sudo` e só escrevem no perfil do usuário.
- O repositório não pode conter a norma ISO/IEC/IEEE 42010 (PDF, DOCX ou texto integral); o gate bloqueia esses arquivos.
