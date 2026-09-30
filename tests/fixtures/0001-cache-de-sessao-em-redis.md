# ADR-0001: Guardar a sessão de conversa em Redis

| Campo | Valor |
|---|---|
| **ID** | ADR-0001 |
| **Status** | Aceito |
| **Data da decisão** | 2026-09-09 |
| **Aprovado em** | 2026-09-10 |
| **Modificado em** | — |
| **Decisores** | Equipe de engenharia do assistente |
| **Autoridade que aprova** | Coordenação do projeto |
| **Stakeholders afetados** | Usuários do chat; equipe de operação |
| **Concerns e aspectos** | O histórico sobrevive a reinício da API? (disponibilidade); aspecto informacional |
| **Elementos afetados** | Gerenciador de sessão da API; infraestrutura Docker |
| **Relações com outras decisões** | Nenhuma |

## Contexto e definição do problema

A sessão de conversa fica em memória do processo e se perde a cada reinício da API.

## Restrições e suposições

- **Restrição:** a infraestrutura já roda em Docker, sem serviço gerenciado de nuvem.
- **Suposição:** o volume de sessões simultâneas fica abaixo de mil.

## Fatores de decisão (drivers)

- Sobreviver a reinício da API.
- Expirar sessões inativas automaticamente.

## Opções consideradas

1. **Redis com TTL**
2. **Banco relacional**

## Decisão

Escolhemos **Redis com TTL**.

## Justificativa

Redis atende os dois drivers com um recurso nativo (expiração por TTL) e já existe no ambiente Docker,
sem custo de novo serviço.

## Prós e contras das opções

### Redis com TTL (escolhida)
- Prós: expiração nativa; baixa latência.
- Contras: mais um contêiner para operar.

### Banco relacional (rejeitada)
- Prós: consultas ricas.
- Contras: expiração exige rotina própria.
- **Motivo da rejeição:** não atende o driver de expiração sem código extra.

## Consequências

- **Positivas:** sessão persiste entre reinícios.
- **Negativas / custo:** dependência operacional do Redis.
- **Neutras / acompanhar:** uso de memória do Redis.
- **Efeito em outras decisões:** nenhum.

## Verificação

Reiniciar a API no meio de uma conversa e confirmar que o histórico continua.

## Limitações deste registro

Nenhuma.

## Histórico de modificações

| Data | Alteração | Autor |
|---|---|---|
| 2026-09-09 | Criação | Equipe de engenharia |

## Referências

- ISO/IEC/IEEE 42010:2022, cláusula 6.10.
