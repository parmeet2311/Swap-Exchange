const { ethers } = require('ethers');
require("dotenv").config();

async function approveToken() {
  const providerUrl = 'https://rpc.ankr.com/zetachain_evm_testnet';
  const provider = new ethers.providers.JsonRpcProvider(providerUrl);

  const privateKey = process.env.PRIVATE_KEY1; 
  const signer = new ethers.Wallet(privateKey, provider);

  const tokenAddress = '0x13A0c5930C028511Dc02665E7285134B6d11A5f4'; 
  const tokenContract = new ethers.Contract(tokenAddress, ['function approve(address spender, uint256 amount) public returns (bool)'], signer);
  const spenderAddress = '0x5dd2f496F19321F728a709154c3D83D6830edfec'; 
  const amount = ethers.utils.parseEther('0.2'); 
  const tx = await tokenContract.approve(spenderAddress, amount);
  console.log(`Transaction hash: ${tx.hash}`);
  await tx.wait();
  console.log(`Transaction confirmed`);
}

approveToken();