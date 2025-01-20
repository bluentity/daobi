// scripts/deploy_upgradeable.js
const { ethers, upgrades } = require("hardhat");

async function main() {
  const Daobi = await ethers.getContractFactory("DAObiContract2");
  const daobi = await upgrades.deployProxy(Daobi, { kind: 'uups' });
  await daobi.deployed();
  console.log("Token deployed to:", daobi.address);

  const DaobiVote = await ethers.getContractFactory("DaobiVoteContract");
  const dbvote = await upgrades.deployProxy(DaobiVote, { kind: 'uups' });
  await dbvote.deployed();
  console.log("Voting Contract Deployed to: ", dbvote.address);

  const Daobi3 = await ethers.getContractFactory("DAObiWithVoting");
  const daobi3 = await upgrades.upgradeProxy(daobi.address, Daobi3, { kind: 'uups' });
  await daobi3.deployed();
  console.log("Token deployed to:", daobi3.address);


}

main();