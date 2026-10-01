# Design — Caminho padrão dos ADRs e personalização (ADR-0001)

| Campo | Detalhe |
|---|---|
| **Requisitos** | [requirements.md](requirements.md) |
| **Status** | Gate 2 |

## Contrato

- `skill/SKILL.md`, seção "Convenções do projeto (ADR-0001 e ADR-0003)" → "Caminho dos ADRs":
  lista ordenada de 5 níveis, texto estável (usado como oráculo de teste por correspondência de
  substring, não por hash, para tolerar reformulação futura sem quebrar o teste por acidente de
  formatação).
- `scripts/check_adr.py`: contrato de CLI já existente (`targets: list[str]`, aceita arquivo ou
  pasta) não muda; o requisito é apenas confirmar, por teste, que pastas fora do padrão funcionam.

## Estratégia de testes

- Teste de texto sobre `skill/SKILL.md` (não há script dedicado): verifica presença e ordem dos
  5 marcadores da hierarquia. Vive em `tests/test_check_adr.py` como um teste adicional, por ser o
  único arquivo de testes Python do repositório (reaproveita o executor existente; nenhuma
  abstração nova — ainda não há um terceiro caso de teste "sobre documentação", então não há
  Rule of Three a aplicar para extrair um módulo próprio).
- Teste existente de `check_adr.py` com pasta custom (`outra-pasta/`) confirma RF-03 — já é
  mecanicamente coberto pela forma como os testes atuais chamam o script (nenhum deles usa
  `docs/architecture/ADR/` fixo), então o teste novo só precisa nomear explicitamente esse caso
  para não depender de coincidência.

## Modelo de domínio

N/A — não há entidade, Value Object, Repositório ou Agregado novo. A "hierarquia de resolução de
caminho" é uma regra de leitura de configuração executada pelo agente ao interpretar `SKILL.md`,
não uma estrutura de dados ou I/O que o código Python manipule.

## Decisões de design

- Sem novo script: a verificação mecânica de RF-01/RF-02/RF-04 é um teste de texto, não um
  programa novo — criar um script só para ler uma seção de Markdown violaria KISS/YAGNI (o
  requisito é "a instrução existe e está na ordem certa", não "um usuário final roda isso").
- RF-03 já está satisfeito pela implementação atual de `check_adr.py` (aceita qualquer caminho);
  o teste apenas tria essa garantia para não regredir.
