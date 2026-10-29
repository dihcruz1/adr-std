# Achados de Revisão de Código (Bot Codex / GitHub PRs)

Documento consolidando os apontamentos de bugs e incompatibilidades levantados pelo bot de revisão nos Pull Requests do repositório, para orientar a implementação das correções.

---

## 1. Incompatibilidade com Python 3.8 (`Path.is_relative_to`)

* **Origem:** PR #1 (comentário de revisão ID `4355309616`).
* **Arquivo:** `skill/scripts/adr_cli.py` (linha ~107).
* **Severidade:** Média (P2).

### Contexto e Causa Raiz
Na função `resolve_folder`, a verificação de confinamento do caminho configurado em `.adr-std` utiliza:
```python
if not folder.is_relative_to(root):
    raise FolderConfigError(
        f"o campo path do .adr-std ({local}) aponta para fora da raiz do repositório ({root})"
    )
```
O método `Path.is_relative_to` foi adicionado na biblioteca padrão do Python apenas a partir da versão **3.9**. Em ambientes com Python 3.8 (comum em distribuições Linux corporativas antigas), a execução do comando falha com `AttributeError`. Como o projeto declara suporte genérico a Python 3 no README, a CLI deixa de funcionar nesses ambientes.

### Solução Recomendada
Substituir o uso de `is_relative_to` por `Path.relative_to` capturando `ValueError`:
```python
try:
    folder.relative_to(root)
except ValueError:
    raise FolderConfigError(
        f"o campo path do .adr-std ({local}) aponta para fora da raiz do repositório ({root})"
    )
```
*Observação: Manter a cobertura de testes em `tests/test_adr_cli.py`.*

---

## 2. Corrupção Silenciosa do Modo de Agentes Legados ao Instalar Novo Agente

* **Origem:** PR #5 (comentário de revisão ID `4396638193`).
* **Arquivos:** `bin/adr-std` (linha ~559) e `bin/adr-std.ps1` (função equivalente de instalação).
* **Severidade:** Alta (P2 / Inconsistência de Estado).

### Contexto e Causa Raiz
No arquivo de estado (`~/.config/adr-std/state`), versões anteriores registravam apenas:
```tsv
mode	copy
agent	claude-code	/home/user/.claude/skills/adr-std
```
Na versão que introduziu modos por agente (PR #5), o modo individual fica na 4ª coluna (`agent\t<id>\t<dest>\t<mode>`). Para agentes legados sem a 4ª coluna, a função `state_agent_mode` recorre ao fallback da chave global `mode`.

Quando um usuário com agentes legados instala um novo agente passando `--link`:
1. O novo agente é registrado com a 4ª coluna `link`.
2. No final do fluxo de instalação (`cmd_install`), a chave global é atualizada:
   ```bash
   state_put mode "$([ "$LINK" -eq 1 ] && echo link || echo copy)"
   ```
3. A chave global `mode` é sobrescrita para `link`.
4. Os agentes legados existentes (que eram cópias) passam a ser resolvidos por `state_agent_mode` como `link`.
5. Em execuções subsequentes de `adr-std update`, o comando assume que os agentes legados já seguem o repositório (modo link) e pula a atualização de suas pastas, deixando-os permanentemente desatualizados.
6. O cenário inverso também ocorre: se o global era `link` e um agente é instalado sem `--link`, agentes legados em modo link passam a ser interpretados como cópias.

### Solução Recomendada
Antes de gravar a chave global `mode` no final do `cmd_install`:
1. Identificar todos os registros de agentes no arquivo de estado que ainda não possuem a 4ª coluna.
2. Materializar explicitamente o modo atual em cada um deles com base no retorno de `state_agent_mode "$id"`.
3. Somente após essa migração em linha dos registros existentes, atualizar a chave global `mode` com o modo da instalação corrente.
4. Aplicar a mesma lógica no script Bash (`bin/adr-std`) e no script PowerShell (`bin/adr-std.ps1`), acompanhado de testes de regressão correspondentes.

