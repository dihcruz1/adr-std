# Requisitos — correção da configuração e fechamento das validações

Data: 2026-10-05. Fonte: ADR-1, specs v1.0/v1.1/v1.3/v1.4/v2.0 e solicitação de resolver pendências. Gate 1: aprovado pela inspeção descrita abaixo; escopo limitado aos problemas identificados.

## Causa-raiz

`adr_cli.main` e `migrate_numbering.main` calculam a configuração por XDG em todos os sistemas. O wrapper PowerShell grava em APPDATA, conforme ADR-1. Testes isolados não exercitavam a gravação pelo wrapper seguida de leitura pelos dois consumidores. Checkboxes também confundem implementação com validação externa.

## Requisitos verificáveis

- RF-01: QUANDO executado no Windows, o Python DEVE ler a configuração global em APPDATA, respeitando ADR_STD_APPDATA nos testes; sem APPDATA, usar o caminho convencional sob o perfil do usuário. Linux/macOS DEVEM preservar XDG_CONFIG_HOME e ~/.config.
- RF-02: CLI e migração DEVEM compartilhar a resolução global e preservar --path > .adr-std > global > padrão.
- RF-03: QUANDO config path grava uma pasta, new/list e migrate DEVEM encontrá-la sem --path; a migração DEVE continuar recusando pasta fora da raiz.
- RF-04: A validação Windows DEVE identificar separadamente junção NTFS, execução .cmd, PATH nativo e conversa; testes não executados não são aprovação.
- RF-05: Os cenários da skill DEVEM registrar execução real em dois agentes, incluindo C1–C11 de tests/cenarios.md, --ask 0/1/11, --quick com/sem descrição e T1–T3 da conversa; cada combinação executada terá resultado próprio. Bloqueio de autenticação será registrado sem satisfazer o aceite.
- RF-06: O estado de releases e CI DEVE ser confirmado por evidência externa; os registros atuais DEVEM refletir a evidência mais recente sem apagar o histórico.
- RF-07 (incluído em 2026-10-22): O arquivo `testResults.xml` (saída NUnit do Pester com `-CI`) DEVE deixar de ser artefato solto na raiz: seu resumo vira evidência datada nesta spec e o arquivo passa a ser ignorado pelo git.
- RF-08 (incluído em 2026-10-22): A próxima versão DEVE ter número coerente com o SemVer e com o critério da v2.0.0: remover comportamento documentado é quebra de compatibilidade. `VERSION` e `CHANGELOG.md` DEVEM refletir o número escolhido (3.0.0, decisão do responsável); tag, push e publicação seguem dependendo de autorização pontual.

## Não regressão

| Caso | Resultado exigido |
|---|---|
| Windows com APPDATA e XDG diferentes | APPDATA prevalece |
| Windows com isolamento ADR_STD_APPDATA | perfil real não é lido |
| Linux/macOS com APPDATA presente | XDG continua prevalecendo |
| Sem variáveis configuradas | caminho convencional da plataforma |
| Flag ou .adr-std presente | precedência existente preservada |
| Migração fora da raiz | recusa preservada |
| Gravação PowerShell → leitura Python | pasta configurada utilizada |
| `path` relativo da config global (spec 2026-10-22) | continua relativo à raiz do repositório |

## Segurança e limites

SEG-01: perfis temporários para testes, sem leitura/cópia de credenciais; autenticação apenas por mecanismos configurados. SEG-02: preservar proteção de raiz da migração. SEG-03: sem push, release, deploy ou alteração do PATH real do usuário sem autorização específica. SEG-04: nenhuma alteração alheia incorporada; merge exclusivo humano.

Publicação v1.0.0 ausente não pode ser substituída por afirmação de que a tag basta. Uma nova publicação e execução de CI com código novo dependem de autorização pontual. E2E de navegador N/A: produto CLI sem interface web.

## Baseline externa (consulta 2026-10-05)

Release v1.0.0 ausente; runs de tag 36883965101 e 37130307963 falharam. Release v2.0.1 publicada no SHA da701d9f0d05a700507e56cfefc34d7ac389c973; [run 37296457938](https://github.com/dihcruz1/adr-std/actions/runs/37296457938) verde, mas Pester: 41 aprovados, 14 ignorados, 1 inconclusivo. Sete skips de update calculam HasPython antes de BeforeAll; sete skips são cenários de conversa no Windows. O inconclusivo mascara retorno inesperado no teste sem terminal. Corrigir essa cobertura faz parte de RF-04; nenhum resultado anterior aprova testes novos.
