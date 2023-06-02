// deploy/00_deploy_your_contract.js
const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const nftSwap = await deploy("nftSwap", {
    from: deployer,
    log: true,
  });

  await run(`verify:verify`, {
    address: nftSwap.address,
    constructorArguments: [],
  });
};
module.exports.tags = ["nftSwap"];