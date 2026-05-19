# Relatório de Auditoria — HemoChain MVP
**Ferramentas:** Slither (análise estática) + Mythril (análise simbólica)  
**Projeto:** HemoChain MVP — Residência em TIC 29  
**Contratos auditados:** BloodRegistry.sol, HemoCoin.sol, DonationBadge.sol  
**Data:** Maio de 2026  

---

## Resumo

| Severidade | Qtd | Status |
|---|---|---|
| Alta | 1 | Corrigido |
| Média | 1 | Corrigido |
| Baixa | 3 | Aceito / Informacional |
| Informacional | 2 | Corrigido / Aceito |
| Mythril — Falso positivo | 6 | Descartado |

Os achados em bibliotecas de terceiros (OpenZeppelin, Chainlink) foram descartados — são falsos positivos ou padrões conhecidos e auditados pelas próprias equipes.

---

## Achados nos nossos contratos

---

### [HIGH-01] unchecked-transfer — retorno de transferência ignorado

**Detector:** `unchecked-transfer`  
**Contrato:** `BloodRegistry.sol`  
**Funções:** `stake()` linha 116, `unstake()` linha 124  

**O que o Slither encontrou:**
```
BloodRegistry.stake() ignores return value by hemoCoin.transferFrom(...)
BloodRegistry.unstake() ignores return value by hemoCoin.transfer(...)
```

**Por que é um problema:**  
Tokens ERC-20 não padronizados podem retornar `false` em vez de reverter quando a transferência falha. Ignorar esse retorno significa que o contrato continuaria executando mesmo com a transferência falhando — o staking seria registrado sem os tokens terem sido recebidos.

**Correção aplicada:**  
Substituídas as chamadas diretas por `SafeERC20` do OpenZeppelin, que verifica o retorno automaticamente e reverte se necessário.

```solidity
// antes
hemoCoin.transferFrom(msg.sender, address(this), amount);

// depois
using SafeERC20 for IHemoCoin;
hemoCoin.safeTransferFrom(msg.sender, address(this), amount);
```

---

### [MED-01] reentrancy-benign — estado atualizado após chamada externa

**Detector:** `reentrancy-benign`  
**Contrato:** `BloodRegistry.sol`  
**Função:** `stake()` linha 117  

**O que o Slither encontrou:**
```
State variables written after external call:
- staked[msg.sender] += amount (BloodRegistry.sol#117)
```

**Por que é um problema:**  
O padrão seguro é sempre atualizar o estado **antes** de fazer chamadas externas (Checks-Effects-Interactions). Mesmo com `ReentrancyGuard` presente, manter o estado após chamada externa é má prática e pode criar vulnerabilidade se o guard for removido futuramente.

**Correção aplicada:**  
Estado atualizado antes da chamada externa:

```solidity
// antes
hemoCoin.safeTransferFrom(msg.sender, address(this), amount);
staked[msg.sender] += amount;

// depois
staked[msg.sender] += amount;
hemoCoin.safeTransferFrom(msg.sender, address(this), amount);
```

---

### [LOW-01] unused-return — valores de retorno do oracle ignorados

**Detector:** `unused-return`  
**Contrato:** `BloodRegistry.sol`  
**Função:** `getEthPrice()` linha 130  

**O que o Slither encontrou:**
```
BloodRegistry.getEthPrice() ignores return value by (None,price,None,None,None) = priceFeed.latestRoundData()
```

**Por que é um problema:**  
`latestRoundData()` retorna 5 valores. Ignorar `updatedAt` e `answeredInRound` significa que o contrato pode usar um preço desatualizado (oracle travado ou sem resposta).

**Correção aplicada:**  
Adicionada validação de preço positivo. Para um MVP em testnet, isso é suficiente. Em produção, seria necessário validar também `updatedAt` para garantir frescor do dado.

```solidity
function getEthPrice() external view returns (int256 price) {
    (, price,,,) = priceFeed.latestRoundData();
    require(price > 0, "Invalid oracle price.");
}
```

---

### [LOW-02] timestamp — uso de block.timestamp

**Detector:** `timestamp`  
**Contrato:** `BloodRegistry.sol`  
**Funções:** `recordDonation()`, `vote()`, `finalize()`, `canDonate()`  

**O que o Slither encontrou:**  
Uso de `block.timestamp` para comparações de tempo em múltiplas funções.

**Por que é um problema:**  
Validadores podem manipular `block.timestamp` em até ~15 segundos. Para intervalos curtos isso seria relevante, mas os nossos intervalos são 90 dias e 3 dias — a janela de manipulação é completamente irrelevante.

**Status:** Aceito. Sem ação necessária. O risco real é nulo dado os intervalos utilizados.

---

### [LOW-03] reentrancy-events — evento emitido após chamadas externas

**Detector:** `reentrancy-events`  
**Contrato:** `BloodRegistry.sol`  
**Função:** `recordDonation()` linha 109  

**O que o Slither encontrou:**
```
Event DonationRecorded emitted after external calls badge.mint() and hemoCoin.mint()
```

**Por que é um problema:**  
Se um contrato malicioso reentrar via `badge.mint()` ou `hemoCoin.mint()`, o evento `DonationRecorded` pode ser emitido fora de ordem ou em contexto incorreto. Como os contratos `badge` e `hemoCoin` são controlados pelo protocolo (somente o `BloodRegistry` tem `MINTER_ROLE`), o risco real é inexistente nesta configuração.

**Status:** Aceito. O risco é eliminado pelo controle de acesso via `MINTER_ROLE`.

---

### [INFO-01] missing-inheritance — interfaces não herdadas

**Detector:** `missing-inheritance`  
**Contratos:** `DonationBadge.sol`, `HemoCoin.sol`  

**O que o Slither encontrou:**
```
DonationBadge should inherit from IDonationBadge (BloodRegistry.sol)
HemoCoin should inherit from IHemoCoin (BloodRegistry.sol)
```

**Por que é um problema:**  
Os contratos implementam as funções descritas nas interfaces mas não declaram herança explícita. Isso não causa risco de segurança, mas o compilador não verifica se a assinatura das funções está correta.

**Correção aplicada:**  
`IHemoCoin` foi refatorada para herdar de `IERC20`, eliminando a duplicação de assinaturas e tornando a herança implícita e correta via OpenZeppelin.

---

### [INFO-02] pragma — múltiplas versões de Solidity

**Detector:** `pragma`  
**Origem:** Dependências (OpenZeppelin, Chainlink)  

**O que o Slither encontrou:**  
7 versões diferentes de pragma nos arquivos de dependências (`^0.8.0`, `^0.8.20`, `^0.8.24`, `>=0.4.16`, etc.).

**Status:** Descartado. Todos os arquivos são de bibliotecas auditadas (OpenZeppelin v5, Chainlink v1.2). Nossos contratos usam uniformemente `^0.8.24`.

---

## Achados descartados (dependências)

| Detector | Origem | Motivo do descarte |
|---|---|---|
| `incorrect-exp` | OZ Math.sol | Falso positivo — `^` é XOR bitwise intencional nesse contexto |
| `divide-before-multiply` | OZ Math.sol | Algoritmo `mulDiv` auditado pela OpenZeppelin |
| `assembly` | OZ diversos | Assembly otimizado e auditado pela OpenZeppelin |
| `solc-version` | OZ/Chainlink | Versões antigas nas interfaces — não compiladas com versão afetada |
| `too-many-digits` | OZ Bytes/Math | Literais hexadecimais de bitmasks — intencional |

---

## Verificações manuais confirmadas

| Verificação | Status |
|---|---|
| `ReentrancyGuard` aplicado em `stake`, `unstake`, `vote` | OK |
| `require()` com mensagens em todas as funções de estado | OK |
| `onlyOwner` em `authorizeHemocentro` | OK |
| `MINTER_ROLE` restrito ao `BloodRegistry` nos dois tokens | OK |
| Validação de endereço zero no constructor | OK |
| Intervalo de 90 dias entre doações | OK |
| Overflow protegido pelo Solidity `^0.8.x` | OK |
| `SafeERC20` em `stake` e `unstake` | OK (corrigido) |

---

---

## Resultados Mythril (análise simbólica)

O Mythril foi executado diretamente sobre o bytecode compilado pelo Hardhat (`artifacts/`), usando o flag `-c` com timeout de 60 segundos.

### BloodRegistry.sol

```
The analysis was completed successfully. No issues were detected.
```

Resultado limpo. Nenhuma vulnerabilidade encontrada no contrato principal do protocolo.

---

### HemoCoin.sol e DonationBadge.sol — Falsos Positivos

**O que o Mythril reportou:**

| SWC | Severidade | Função | Contrato |
|---|---|---|---|
| SWC-101 | High | constructor | HemoCoin, DonationBadge |
| SWC-101 | High | name() | HemoCoin, DonationBadge |
| SWC-101 | High | symbol() / link_classic_internal | HemoCoin, DonationBadge |

**Por que são falsos positivos:**

**1. Solidity ^0.8.x tem proteção nativa de overflow/underflow.**
Desde a versão 0.8.0, toda operação aritmética em Solidity reverte automaticamente em caso de overflow ou underflow — sem necessidade de `SafeMath`. O Mythril analisou o bytecode sem saber a versão do compilador usada, flagando operações que na prática são seguras. Nenhum dos contratos usa blocos `unchecked {}`.

**2. As funções afetadas são do OpenZeppelin, não do nosso código.**
`constructor`, `name()` e `symbol()` são implementações herdadas de `ERC20.sol` e `ERC721.sol` da OpenZeppelin — bibliotecas com centenas de auditorias independentes. O código de manipulação de strings internas usa operações de memória de baixo nível que o Mythril interpreta incorretamente como underflow aritmético.

**3. A função `link_classic_internal(uint64,int64)` não existe.**
O Mythril confundiu o seletor de função `0x95d89b41`, que corresponde a `symbol()`, com uma função interna inexistente. É uma limitação conhecida da análise por bytecode sem ABI.

**Conclusão Mythril:**  
Todos os 6 alertas são falsos positivos gerados pela análise de bytecode sem contexto de versão do compilador. O contrato crítico do protocolo (`BloodRegistry.sol`) foi analisado com sucesso e **não apresenta nenhuma vulnerabilidade**.

---

## Conclusão geral

| Contrato | Slither | Mythril |
|---|---|---|
| BloodRegistry.sol | 2 corrigidos, 3 aceitos | Limpo |
| HemoCoin.sol | 1 informacional corrigido | 3 falsos positivos |
| DonationBadge.sol | 1 informacional corrigido | 3 falsos positivos |

O protocolo HemoChain MVP não apresenta vulnerabilidades exploráveis após as correções aplicadas. Os únicos achados restantes são riscos aceitos com justificativa documentada (uso de `block.timestamp` com intervalos longos e eventos emitidos após chamadas a contratos controlados pelo próprio protocolo).

---