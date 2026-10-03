# Glossário — adr-std

Linguagem Ubíqua do projeto. Termos consolidados das specs em `docs/specs/`; em caso de divergência, vale a spec da versão que introduziu o termo.

## Termos

| Termo | Definição |
|---|---|
| **ADR** | Registro de decisão de arquitetura, no formato MADR estendido pela ISO/IEC/IEEE 42010:2022 (cláusula 6.10). |
| **ADR de origem** | ADR que fundamenta uma spec. |
| **Ação** | Uma das dez tarefas da skill (`create`, `supersede`, `review`, `organize`, `link`, `audit`, `check`, `ask`, `new`, `list`). |
| **Agente** | Ferramenta de IA de código que lê skills (Claude Code, Codex, Gemini CLI, OpenCode etc.). |
| **Agente elegível** | Agente com skill instalada (registrada no estado) e linha em `agent_launch.tsv`. |
| **Agente padrão** | Agente gravado por `adr-std config agent`, usado sem perguntar. |
| **Campo `path`** | Linha `path: <pasta>` na config global ou no `.adr-std` que define a pasta de ADRs. |
| **Comando `adr-std`** | Programa no PATH que instala, atualiza, remove e consulta a skill, e roda os comandos do terminal. |
| **Comando de ação** | Arquivo pequeno em um agente que chama a skill `adr-std` com uma ação definida (`/adr-std-<ação>`). |
| **Comando de conversa** | `create`, `supersede`, `review`, `audit` e `ask` rodados no terminal; abrem um agente. |
| **Config global** | `~/.config/adr-std/config` (Linux/macOS) ou `%APPDATA%\adr-std\config` (Windows), compartilhado com o estado da skill. |
| **Esqueleto** | ADR criado por `new`: seções do template com `pendente`. |
| **Estado** | Arquivo que registra versão, agentes e pastas instaladas. |
| **Etapa** | Passo de implementação previsto em um ADR, rastreado em `docs/architecture/ADR/ROADMAP.md` (distinta de **Versão**). |
| **Instalador** | `install.sh` ou `install.ps1`: coloca o comando `adr-std` no computador e chama `adr-std install`. |
| **Pasta de ADRs** | Diretório dos arquivos `NNNN-<slug>.md`; padrão `docs/architecture/ADR/`. |
| **Pedido inicial** | Texto `Use a skill adr-std, ação "<ação>", com estes argumentos: <args>` entregue ao agente. |
| **Pendente** | Campo do ADR que o usuário não informou; nunca é preenchido por invenção. |
| **Precedência de caminho (ADR-0001)** | `--path` > `.adr-std` > config global > `docs/architecture/ADR/`. |
| **Relação recíproca** | Registro do mesmo vínculo nos dois ADRs, com o tipo inverso. |
| **Release** | Versão publicada no GitHub com `adr-std.zip` e `adr-std.zip.sha256`. |
| **Rodada** | Grupo de perguntas feito de uma vez na conversa guiada (`--ask N`). |
| **Simulação** | Execução que só mostra o plano (`--dry-run`), sem gravar. |
| **Skill** | Conteúdo de `skill/` (`SKILL.md`, `references/`, `scripts/`), instalado com o nome `adr-std`. |
| **Spec** | Conjunto `requirements.md`, `design.md` e `tasks.md` em `docs/specs/<AAAA-MM-DD>-<nome>/`. |
| **Sugestão** | Ideia do agente (alternativa, risco, relação) que só entra no ADR se o usuário aceitar. |
| **Versão** | Entrega do produto (v1.0, v1.1...), com status em `ROADMAP.md` da raiz (distinta de **Etapa**). |

## Termos a evitar

- **Status de implementação no ADR:** o campo `Status` do ADR registra só o ciclo da decisão (`Proposto`, `Aceito`...); o andamento da execução fica no ROADMAP.
- **"Etapa" para versão do produto** e vice-versa.
