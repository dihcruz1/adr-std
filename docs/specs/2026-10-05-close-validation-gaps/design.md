# Design — configuração por plataforma e evidências

## Contrato e decisões

D-01: cumprir o ADR-1 existente: APPDATA no Windows; XDG nos demais sistemas. Alterar o wrapper para XDG contrariaria a decisão; duplicar os caminhos em cada consumidor repetiria o defeito.
D-02: extrair `global_config_home()` em `adr_cli.py`, reutilizada pela CLI e migração. São três consumidores lógicos da configuração (wrapper, CLI, migração); manter o parser e a precedência existentes. No Windows: ADR_STD_APPDATA > APPDATA > perfil/AppData/Roaming; nos demais: XDG_CONFIG_HOME > ~/.config. ADR_STD_APPDATA é mecanismo de teste já configurado.
D-03: testes de plataforma com `sys.platform` simulado e diretórios temporários; integração Pester grava config path e chama new/list/migrate. Manter restrição da raiz da migração.
D-04: evidências antigas continuam históricas; adicionar fechamento datado e ajustar resumo vigente. Marcar aberta qualquer validação obrigatória sem evidência, inclusive release v1.0.0.
D-06 (2026-10-22): a evidência de Windows nativo (NTFS, `.cmd`, PATH) pode vir do job `test-windows` (`windows-latest`) do `release.yml` num PR ou `workflow_dispatch` da branch, que não publica (`publish` só roda em tag). Pester em PowerShell para Linux continua evidência parcial.
D-07 (2026-10-22): `testResults.xml` é saída gerada (`Invoke-Pester -CI`, também no CI): vai para o `.gitignore` e o resumo da execução de 2026-10-05 (56 testes, 0 falhas, 7 ignorados, 0 inconclusivos) fica nesta spec.
D-08 (2026-10-22): próxima versão 3.0.0. `new` deixou de criar a pasta inexistente (comportamento documentado e testado desde a v1.2) e ganhou `--create`; `migrate --path` relativo passou a valer só contra o `cwd`. Mesmo critério da v2.0.0 (quebra de compatibilidade). Tag e publicação não fazem parte desta spec sem autorização.
D-05: não inventar aprovação ou substituir um agente real por mock nos cenários comportamentais. --ask deve limitar perguntas por rodada e --quick não deve perguntar.

## Modelo de domínio

N/A: resolução de caminhos e auditoria de evidências não introduzem entidades, invariantes de negócio novas, agregados ou eventos. Função pequena reaproveita a arquitetura atual; sem camada de repositório/gateway.

## Estratégia de validação

RED: reproduzir APPDATA ignorado em CLI e migração. GREEN: função compartilhada. REFACTOR: remover os dois cálculos duplicados. Regressão: unittest completo, bash completo, gate estático, verificadores de ADR/ROADMAP e Pester se disponível. Windows nativo só pode ser aprovado com execução Windows real; Linux/PowerShell portátil não prova NTFS nem PATH nativo. Releases via gh somente leitura e pacote baixado conferido por checksum.

Gate 2: aprovado por aderência ao ADR-1 e às specs existentes. Gate 3: revisão de coerência feita com `/opsx:update` em 2026-10-22 (antes indisponível); nenhum código alterado antes dele. Contexto novo: a spec 2026-10-22-adr-cli-resolucao-de-pasta já está na `main` (d858ee9); `config_home` agora aparece em `adr_cli.py` (`main`) e `migrate_numbering.py`, e `resolve_folder` recebe `config_home` como parâmetro; `global_config_home()` substitui os dois cálculos sem mudar essa assinatura.

## Ajustes da revisão independente

Integração config path → Python exige Windows nativo para fechamento de RF-03; simulação de plataforma e PowerShell portátil são evidências parciais. Executar alterações de tests/test_cli.ps1 em sequência (2.1 antes de 3.1). Indisponibilidade documentada não conclui RF-04/RF-05 nem os respectivos testes. Investigar skips na fase Discovery do Pester e redirecionar stdin no teste sem terminal, exigindo código 3 em vez de mascarar falha como inconclusiva. Fonte: [fases do Pester 5](https://pester.dev/docs/v5/usage/discovery-and-run).

`global_config_home() -> Path` trata variáveis vazias como ausentes. Perfil Windows: ADR_STD_HOME (isolamento), USERPROFILE, depois Path.home(); fallback exclusivo do Python, sem prometer funcionamento do wrapper com APPDATA ausente. RED deve executar os pontos de entrada CLI/migração com sys.platform=win32 e APPDATA/XDG distintos; testes diretos cobrem os fallbacks. Linux/macOS ignoram APPDATA e ADR_STD_APPDATA.

Riscos: ler perfil real (mitigação SEG-01 e diretórios temporários), concluir com skips (RF-04, matriz de execução), migrar fora da raiz (SEG-02 e teste de recusa). Commit 1 contém somente esta spec e seu apontador; commit 2 contém correção, testes, evidências e consolidação após validação.
