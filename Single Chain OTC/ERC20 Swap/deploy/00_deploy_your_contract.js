// deploy/00_deploy_your_contract.js
const { ethers } = require("hardhat");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const OTCDesk = await deploy("Swap", {
    from: deployer,
    log: true,
  });

  await run(`verify:verify`, {
    address: OTCDesk.address,
    constructorArguments: [],
  });

};
module.exports.tags = ["OTCDesk"];