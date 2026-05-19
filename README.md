# HemoChain MVP

Protocolo descentralizado para logística de doação de sangue.
Registra doações na blockchain, emite certificados NFT e recompensa doadores com tokens de governança.

**Rede:** Sepolia Testnet · **Solidity:** ^0.8.24 · **Framework:** Hardhat 2.19.4

---

## Contratos deployados

| Contrato | Endereço |
|---|---|
| BloodRegistry | `0x352Ca1f0Eb77D9977Ae3F0B2C32E55bB666d6EF0` |
| HemoCoin (HMC) | `0x28D61c581E16B13F24a7D53d6636b111269C0221` |
| DonationBadge (HMOB) | `0xAa198368DE6eD2BAB5752f857955B50CF1dc6C4c` |

---

## Estrutura do projeto

```
hemochain-mvp/
├── contracts/
│   ├── BloodRegistry.sol     ← hub central do protocolo
│   ├── HemoCoin.sol          ← token ERC-20 de recompensa
│   └── DonationBadge.sol     ← certificado de doação ERC-721
├── scripts/
│   ├── deploy.js             ← publica os contratos na Sepolia
│   └── interact.js           ← executa o fluxo completo
├── hardhat.config.js
├── package.json
└── .env.example
```

---

## Pré-requisitos

Antes de executar o projeto, instale:

- Node.js v20
- MetaMask
- ETH de teste na Sepolia
- Conta RPC (Infura ou Alchemy)

## Compatibilidade do Node.js

Este projeto utiliza o **Hardhat 2.19.4**.

Versões do Node.js **22+** podem causar incompatibilidades internas relacionadas ao pacote `lodash/isEqual`, afetando a compilação do projeto.

### Recomendação

Utilize **Node.js v20**.

---

## Instalação do Node via NVM

```bash
nvm install 20
nvm use 20
---

## Instalação

**1. Clone o repositório:**

```bash
git clone https://github.com/seu-usuario/hemochain-mvp.git
cd hemochain-mvp
```

**2. Instale as dependências:**

```bash
npm install --legacy-peer-deps
```

> A flag `--legacy-peer-deps` é necessária por conflito de versões entre `@chainlink/contracts` e `ethers`.

**3. Configure as variáveis de ambiente:**

```bash
cp .env.example .env
```

Abra o `.env` e preencha:

```env
# RPC da Sepolia — crie em infura.io ou alchemy.com
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/SUA_CHAVE

# Chave privada da conta principal (deployer/owner)
PRIVATE_KEY=sua_chave_privada_aqui

# Chave privada de uma segunda conta (representa o hemocentro)
HEMOCENTRO_KEY=chave_privada_do_hemocentro_aqui

# Chave da API do Etherscan — crie em etherscan.io (opcional, só para verificação)
ETHERSCAN_API_KEY=sua_chave_etherscan_aqui
```

> **Como obter cada variável:**
> - `SEPOLIA_RPC_URL` — crie um projeto no Infura ou Alchemy e copie o endpoint da Sepolia
> - `PRIVATE_KEY` — no MetaMask: ícone da conta → Detalhes da conta → Exportar chave privada
> - `HEMOCENTRO_KEY` — crie uma segunda conta no MetaMask e exporte da mesma forma
> - As duas contas precisam ter ETH de teste. Use o faucet para ambas.

---

## Como executar

### Compilar os contratos

```bash
npx hardhat compile
```

Deve aparecer `Compiled X Solidity files successfully`.

---

### Fazer o deploy na Sepolia

```bash
npm run deploy
```

O terminal vai imprimir os endereços dos três contratos:

```
Deployer: 0x...
HemoCoin: 0x...
DonationBadge: 0x...
BloodRegistry: 0x...
MINTER_ROLE concedido ao BloodRegistry.
```

Copie os endereços e adicione no `.env`:

```env
REGISTRY_ADDRESS=0x...
HMC_ADDRESS=0x...
BADGE_ADDRESS=0x...
```

---

### Executar o fluxo completo

```bash
node scripts/interact.js
```

O script executa automaticamente todas as etapas do protocolo:

```
1. Registra o doador na blockchain
2. Autoriza o hemocentro
3. Registra uma doação → minta 100 HMC + 1 Badge NFT
4. Exibe o saldo HMC do doador
5. Consulta o preço ETH/USD via Chainlink
6. Faz stake de 50 HMC
7. Cria uma proposta na DAO
8. Vota na proposta
```

---

### Rodar os testes

```bash
npx hardhat test
```

```bash
npx hardhat coverage
```

---

### Verificar contratos no Etherscan (opcional)

```bash
npx hardhat verify --network sepolia ENDERECO_DO_CONTRATO "arg1" "arg2"
```

---

## Como o protocolo funciona

```
Doador        →  registerDonor("Maria Silva")
Owner         →  authorizeHemocentro(0x...)
Hemocentro    →  recordDonation(0x_doador)
                 └── BloodRegistry valida 90 dias
                 └── minta 100 HMC para o doador
                 └── minta 1 Badge NFT para o doador
Doador        →  stake(50 HMC)
Doador        →  propose("Aumentar recompensa para 150 HMC")
Doador        →  vote(1, true)
Qualquer um   →  finalize(1)  ← após 3 dias
```

---

## Tipos sanguíneos

O campo `bloodType` em `recordDonation()` aceita valores de `0` a `7`:

| Valor | Tipo | Valor | Tipo |
|---|---|---|---|
| 0 | A+ | 4 | AB+ |
| 1 | A− | 5 | AB− |
| 2 | B+ | 6 | O+ |
| 3 | B− | 7 | O− |

---

## Segurança

- `ReentrancyGuard` em `stake()`, `unstake()` e `vote()`
- `SafeERC20` nas transferências de token
- `MINTER_ROLE` restrito ao `BloodRegistry` — só doações reais geram HMC e NFT
- Intervalo mínimo de 90 dias entre doações (anti-fraude)
- Overflow/underflow protegido nativamente pelo Solidity `^0.8.24`
- Auditado com Slither e Mythril — relatório em `AUDITORIA.md`

---

## Auditoria

Os contratos foram auditados com **Slither** (análise estática) e **Mythril** (análise simbólica). O `BloodRegistry.sol` — contrato principal — saiu limpo no Mythril. Os achados do Slither foram corrigidos antes do deploy. Ver relatório completo em [`AUDITORIA.md`](./AUDITORIA.md).

---

## Tecnologias

| Tecnologia | Versão |
|---|---|
| Solidity | ^0.8.24 |
| Hardhat | 2.19.4 |
| OpenZeppelin Contracts | ^5.0.0 |
| Chainlink Contracts | ^1.2.0 |
| ethers.js | ^6.4.0 |

---

*HemoChain MVP · Residência em TIC 29 — Web3 · Sepolia Testnet*
