// scripts/deploy.js
const { ethers } = require("hardhat");

async function main() {

  // Get the contract owner
  const [deployer] = await ethers.getSigners();
  const mintingAddress = process.env.INIT_DAO_WALLET;

  console.log(`Deploying contract from: ${deployer.address}`);
  console.log(`Minting address: ${mintingAddress}`)

  // Hardhat helper to get the ethers contractFactory object
  const CYBROToken = await ethers.getContractFactory('CYBROToken');

  // Deploy the contract
  console.log('Deploying Cybro Token $CYBRO...');

  const cybroToken = await CYBROToken.deploy(mintingAddress);
  await cybroToken.waitForDeployment();

  const contractAddress = await cybroToken.getAddress();
  console.log(`Cybro Token deployed to: ${contractAddress}`)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
