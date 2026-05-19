const { ethers } = require("hardhat");

const CHAINLINK_ETH_USD_SEPOLIA = "0x694AA1769357215DE4FAC081bf1f309aDC325306";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deployer:", deployer.address);

  const HemoCoin = await ethers.getContractFactory("HemoCoin");
  const hemoCoin = await HemoCoin.deploy();
  await hemoCoin.waitForDeployment();
  console.log("HemoCoin:", await hemoCoin.getAddress());

  const DonationBadge = await ethers.getContractFactory("DonationBadge");
  const badge = await DonationBadge.deploy();
  await badge.waitForDeployment();
  console.log("DonationBadge:", await badge.getAddress());

  const BloodRegistry = await ethers.getContractFactory("BloodRegistry");
  const registry = await BloodRegistry.deploy(
    await hemoCoin.getAddress(),
    await badge.getAddress(),
    CHAINLINK_ETH_USD_SEPOLIA
  );
  await registry.waitForDeployment();
  console.log("BloodRegistry:", await registry.getAddress());

  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  await hemoCoin.grantRole(MINTER_ROLE, await registry.getAddress());
  await badge.grantRole(MINTER_ROLE, await registry.getAddress());
  console.log("MINTER_ROLE concedido ao BloodRegistry.");
}

main().catch((e) => { console.error(e); process.exit(1); });
