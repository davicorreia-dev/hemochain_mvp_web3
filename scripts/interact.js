require("dotenv").config();
const { ethers } = require("ethers");

const REGISTRY_ABI = [
  "function registerDonor(string calldata name) external",
  "function authorizeHemocentro(address addr) external",
  "function recordDonation(address donor) external",
  "function stake(uint256 amount) external",
  "function unstake(uint256 amount) external",
  "function propose(string calldata description) external returns (uint256)",
  "function vote(uint256 id, bool support) external",
  "function finalize(uint256 id) external",
  "function getEthPrice() external view returns (int256)",
  "function canDonate(address donor) external view returns (bool)",
  "function donors(address) external view returns (string, bool, uint256, uint256)",
  "function staked(address) external view returns (uint256)",
];

const HMC_ABI = [
  "function balanceOf(address) external view returns (uint256)",
  "function approve(address spender, uint256 amount) external returns (bool)",
];

async function main() {
  // Provider
  const provider = new ethers.JsonRpcProvider(
    process.env.SEPOLIA_RPC_URL
  );

  // Wallets
  const owner = new ethers.Wallet(
    process.env.PRIVATE_KEY,
    provider
  );

  const hemocentro = new ethers.Wallet(
    process.env.HEMOCENTRO_KEY,
    provider
  );

  // Contracts
  const registry = new ethers.Contract(
    process.env.REGISTRY_ADDRESS,
    REGISTRY_ABI,
    owner
  );

  const hmc = new ethers.Contract(
    process.env.HMC_ADDRESS,
    HMC_ABI,
    owner
  );

  console.log("=== HemoChain — fluxo completo ===\n");

  console.log("1. Verificando cadastro...");

  const donorData = await registry.donors(owner.address);

  if (!donorData[1]) {
    const tx = await registry.registerDonor("Maria Silva");
    await tx.wait();

    console.log("   Doador registrado.");
  } else {
    console.log("   Doador já registrado.");
  }

  console.log("   Donor:", owner.address);

  console.log("\n2. Autorizar hemocentro");

  const txAuth = await registry.authorizeHemocentro(
    hemocentro.address
  );

  await txAuth.wait();

  console.log("   Hemocentro autorizado:");
  console.log("   ", hemocentro.address);

  console.log("\n3. Registrar doação");

  const txDonation = await registry
    .connect(hemocentro)
    .recordDonation(owner.address);

  const rcDonation = await txDonation.wait();

  console.log("   Tx hash:");
  console.log("   ", rcDonation.hash);

  const balance = await hmc.balanceOf(owner.address);

  console.log("\n4. Saldo HMC");
  console.log(
    "   ",
    ethers.formatEther(balance),
    "HMC"
  );

  console.log("\n5. ETH/USD via Chainlink");

  const price = await registry.getEthPrice();

  console.log(
    "   Preço:",
    (Number(price) / 1e8).toFixed(2),
    "USD"
  );

  console.log("\n6. Stake de 50 HMC");

  const stakeAmount = ethers.parseEther("50");

  // approve
  const txApprove = await hmc.approve(
    process.env.REGISTRY_ADDRESS,
    stakeAmount
  );

  await txApprove.wait();

  // stake
  const txStake = await registry.stake(stakeAmount);

  await txStake.wait();

  const staked = await registry.staked(owner.address);

  console.log(
    "   Total staked:",
    ethers.formatEther(staked),
    "HMC"
  );

  console.log("\n7. Criar proposta DAO");

  const txProposal = await registry.propose(
    "Aumentar recompensa para 150 HMC apos 500 doacoes"
  );

  const rcProposal = await txProposal.wait();

  console.log("   Proposta criada.");
  console.log("   Tx:");
  console.log("   ", rcProposal.hash);

  console.log("\n8. Votar na proposta #1");

  const txVote = await registry.vote(1, true);

  await txVote.wait();

  console.log("   Voto registrado.");

  console.log("\n=== Concluído ===");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});