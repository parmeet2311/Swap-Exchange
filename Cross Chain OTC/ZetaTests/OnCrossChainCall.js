const { parseEther } = require("@ethersproject/units");
const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
require("dotenv").config();

const privateKey = "0x" + process.env.PRIVATE_KEY2;
const providerPolygon = new ethers.providers.JsonRpcProvider("https://rpc.ankr.com/polygon_mumbai");
const walletPolygon = new ethers.Wallet(privateKey, providerPolygon);
const providerZeta = new ethers.providers.JsonRpcProvider("https://rpc.ankr.com/zetachain_evm_testnet");
const walletZeta = new ethers.Wallet(privateKey, providerZeta);
const abi = require('./CrossChainSwap.json');

const Order = {
  orderID: 1,
  nonce: 1,
  maker: "0x421B35e07B9d3Cc08f6780A01E5fEe7B8aeFD13E",
  tokenToSell: "0x13A0c5930C028511Dc02665E7285134B6d11A5f4",
  sellAmount: BigNumber.from("100000000000000000"),
  taker: walletZeta.address,
  tokenToBuy: "0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891",
  buyAmount: BigNumber.from("100000000000000000"),
  doWithdrawalTaker: true,
  CCOrderType: 1
};

const zetaSwap = "0x5dd2f496F19321F728a709154c3D83D6830edfec";
const signature = "0x6e860c86bcb096ca01ddc06fd8be0ff2787aae6a3ead712bb0e2dec2b7d62ff83c231f8f8009fba3a042955acee6ae62c0bdf0e0d1e192fd20b62c08cfddc66a1c"

const zetaSwapContract = new ethers.Contract(zetaSwap, abi, walletZeta);

const main = async () => {
  const encodedData = await zetaSwapContract.encodeData(Order, signature);

  const data = zetaSwap + encodedData.slice(2);
  console.log(data)

  const tx = await walletPolygon.sendTransaction({
    data,
    to: '0x7c125C1d515b8945841b3d5144a060115C58725F',
    value: parseEther("0.1")
  });

  console.log("tx:", tx.hash);
};

main().catch(error => {
  console.error(error);
  process.exit(1);
});