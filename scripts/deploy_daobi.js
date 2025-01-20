const hre = require("hardhat");
const { ethers, upgrades, run } = require("hardhat");

async function main() {
  const Contract = await ethers.getContractFactory("DAObiContract2");
  
  const contract = await upgrades.deployProxy(Contract, 

    { 
      kind: 'uups',
      initializer: 'initialize'
    }
  );

  await contract.waitForDeployment();  // This is the new syntax for ethers v6
  console.log("Contract deployed to:", await contract.getAddress());  // This is the new syntax for ethers v6

  // Optionally verify implementation contract on Etherscan
  const implementationAddress = await upgrades.erc1967.getImplementationAddress(
    await contract.getAddress()
  );
  console.log("Implementation contract deployed to:", implementationAddress);

  // Wait for some blocks
  console.log("Waiting 30 seconds before verification...");
  await new Promise(resolve => setTimeout(resolve, 30000)); // 30 seconds

  // Verify implementation
  try {
    console.log("Verifying proxy contract...");
    await hre.run("verify:verify", {
      address: implementationAddress,
      constructorArguments: []
    });
    console.log("Implementation verified");
  } catch (error) {
    if (error.message.includes("Already Verified")) {
      console.log("Contract is already verified!");
    } else {
      console.log("Implementation verification failed:", error.message);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });