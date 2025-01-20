const hre = require("hardhat");
const { ethers, upgrades, run } = require("hardhat");

async function main() {
    const PROXY_ADDRESS = "0x98C6203340F1A76eCF9b302c009aAa5d9C7f0603";  // Replace with your actual proxy address
    
    console.log("Upgrading contract at proxy:", PROXY_ADDRESS);
    
    const ContractV3 = await ethers.getContractFactory("DAObi");
    console.log("Upgrading contract...");
    
    const upgraded = await upgrades.upgradeProxy(PROXY_ADDRESS, ContractV3);
    
    await upgraded.waitForDeployment();
    const receipt = await upgraded.deploymentTransaction().wait(2); // Wait for 2 block confirmations
    console.log("Upgrade confirmed in block:", receipt.blockNumber);
    
    // Wait longer for verification
    console.log("Waiting 60 seconds before verification...");
    await new Promise(resolve => setTimeout(resolve, 60000)); // Increased to 60 seconds

    // Get the implementation address
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(PROXY_ADDRESS);
    console.log("New implementation deployed to:", implementationAddress);
    
    // Wait for some blocks before verification
    console.log("Waiting 30 seconds before verification...");
    await new Promise(resolve => setTimeout(resolve, 30000));

    // Verify the implementation
    try {
        console.log("Verifying implementation...");
        await hre.run("verify:verify", {
            address: implementationAddress,
            constructorArguments: []
        });
        console.log("Implementation verified successfully");
    } catch (error) {
        if (error.message.includes("Already Verified")) {
            console.log("Contract is already verified!");
        } else {
            console.log("Verification failed:", error);
        }
    }

    console.log("Contract upgraded");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });