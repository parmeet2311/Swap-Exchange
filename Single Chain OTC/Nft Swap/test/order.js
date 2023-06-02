const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers } = require("hardhat");

describe("NFT SWAP", function () {
    async function deployTokenFixture() {
        const [owner, maker, taker] = await ethers.getSigners();

        const Swap = await ethers.getContractFactory("nftSwap");
        const swapcontract = await Swap.deploy();
        await swapcontract.deployed();
        console.log("Nft Swap Contract Address: ", swapcontract.address);

        const nft1 = await ethers.getContractFactory("nft1");
        const nft1contract = await nft1.deploy();
        await nft1contract.deployed();
        console.log("NFT 1 Contract Address: ", nft1contract.address);

        const nft2 = await ethers.getContractFactory("nft2");
        const nft2contract = await nft2.deploy();
        await nft2contract.deployed();
        console.log("NFT 2 Contract Address: ", nft2contract.address);

        const token1 = await ethers.getContractFactory("token1");
        const token1contract = await token1.deploy();
        await nft2contract.deployed();
        console.log("Token 1 Contract Address: ", token1contract.address);

        const token2 = await ethers.getContractFactory("token2");
        const token2contract = await token2.deploy();
        await nft2contract.deployed();
        console.log("Token 2 Contract Address: ", token2contract.address);
        console.log("Maker Address: ", maker.address);
        console.log("Taker Address: ", taker.address);
        console.log("");


        const nonce = 1;
        const Maker = maker.address;
        const nftToSell = nft1contract.address;
        const sellTokenIds = 1;
        const tokenToBuy = token1contract.address;
        const nftToBuy = nft2contract.address;
        const buyTokenIds = 100;
        const buyTokenAmount = 100
        const sig1 = "0xe51d2a842c5db68d86d06de85afb52c7d2e11e86277ca93f9b57fb64ac1c5b801132bfe8d4961e9cfa13880c948c942afd231332c8e7606a6dbf63a2cae636a01b";
        const signatureNftErc20 = (ethers.utils.arrayify(sig1));
        const sig2 = "0x7e71eec36fbf6cbf07775b1d46c458d5a15ffd4a9b0e4f8bba838edb41f21ecc0da81a5115ab611685593b4b9da42a6f2d9e4895b0aa1865e8655487c23998551c";
        const signatureNftNft = (ethers.utils.arrayify(sig2));


        await swapcontract.connect(owner).grantRole("0x339759585899103d2ace64958e37e18ccb0504652c81d4a1b8aa80fe2126ab95", owner.address);
        await swapcontract.connect(owner).grantRole("0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a", owner.address);

        return { owner, maker, taker, swapcontract, nft1contract, nft2contract, token1contract, token2contract, nonce, Maker, nftToSell, sellTokenIds, signatureNftErc20, nftToBuy, tokenToBuy, buyTokenIds, buyTokenAmount, signatureNftErc20, signatureNftNft };

    }

    it("Contract Paused", async function () {
        const { owner, maker, taker, swapcontract, nft1contract, token1contract, nonce, Maker, nftToSell, sellTokenIds, tokenToBuy, buyTokenAmount, signatureNftErc20 } = await loadFixture(deployTokenFixture);

        await nft1contract.connect(owner).mint(maker.address, sellTokenIds)
        await nft1contract.connect(maker).approve(swapcontract.address, sellTokenIds);
        await token1contract.connect(owner).transfer(taker.address, 100000)
        await token1contract.connect(taker).approve(swapcontract.address, 100000);
        await swapcontract.connect(owner).pause();

        await expect(swapcontract.connect(taker).swapNftToErc20Order(
            {
                nonce: nonce,
                orderID: "1",
                maker: Maker,
                nftToSell: [nftToSell],
                sellTokenIds: [sellTokenIds],
                tokenToBuy: [tokenToBuy],
                buyTokenAmount: [buyTokenAmount],
                signature: signatureNftErc20
            }
        )).to.be.reverted;
        await swapcontract.connect(owner).unpause();
    });

    it("Token Blacklisted", async function () {
        const { owner, maker, taker, swapcontract, nft1contract, token1contract, nonce, Maker, nftToSell, sellTokenIds, tokenToBuy, buyTokenAmount, signatureNftErc20 } = await loadFixture(deployTokenFixture);

        await nft1contract.connect(owner).mint(maker.address, sellTokenIds)
        await nft1contract.connect(maker).approve(swapcontract.address, sellTokenIds);
        await token1contract.connect(owner).transfer(taker.address, 100000)
        await token1contract.connect(taker).approve(swapcontract.address, 100000);
        await swapcontract.connect(owner).tokenBlacklisting(token1contract.address, true);
        await expect(swapcontract.connect(taker).swapNftToErc20Order(
            {
                nonce: nonce,
                orderID: "1",
                maker: Maker,
                nftToSell: [nftToSell],
                sellTokenIds: [sellTokenIds],
                tokenToBuy: [tokenToBuy],
                buyTokenAmount: [buyTokenAmount],
                signature: signatureNftErc20
            }
        )).to.be.reverted;

    });

    it("OTC Swap NFT<->ERC20 without platform fees", async function () {
        const { owner, maker, taker, swapcontract, nft1contract, token1contract, nonce, Maker, nftToSell, sellTokenIds, tokenToBuy, buyTokenAmount, signatureNftErc20 } = await loadFixture(deployTokenFixture);
        console.log("OTC Swap without platform fees");

        await nft1contract.connect(owner).mint(maker.address, sellTokenIds)
        await nft1contract.connect(maker).approve(swapcontract.address, sellTokenIds);
        await token1contract.connect(owner).transfer(taker.address, 100000)
        await token1contract.connect(taker).approve(swapcontract.address, 100000);

        console.log("Before OTC Swap:");
        console.log("Owner of nft1: ", await nft1contract.ownerOf(sellTokenIds));
        console.log("Balance of token for Maker: ", Number(await token1contract.balanceOf(maker.address)));
        console.log("Balance of token for Taker: ", Number(await token1contract.balanceOf(taker.address)));


        await swapcontract.connect(taker).swapNftToErc20Order(
            {
                nonce: nonce,
                orderID: "1",
                maker: Maker,
                nftToSell: [nftToSell],
                sellTokenIds: [sellTokenIds],
                tokenToBuy: [tokenToBuy],
                buyTokenAmount: [buyTokenAmount],
                signature: signatureNftErc20
            }
        );
        console.log("");
        console.log("Balances after OTC Swap:");
        console.log("Owner of nft1: ", await nft1contract.ownerOf(sellTokenIds));
        console.log("Balance of token for Maker: ", Number(await token1contract.balanceOf(maker.address)));
        console.log("Balance of token for Taker: ", Number(await token1contract.balanceOf(taker.address)));

    });

    it("OTC Swap NFT<->ERC20 with platform fees", async function () {
        const { owner, maker, taker, swapcontract, nft1contract, token1contract, nonce, Maker, nftToSell, sellTokenIds, tokenToBuy, buyTokenAmount, signatureNftErc20 } = await loadFixture(deployTokenFixture);
        console.log("OTC Swap without platform fees");

        await nft1contract.connect(owner).mint(maker.address, sellTokenIds)
        await nft1contract.connect(maker).approve(swapcontract.address, sellTokenIds);
        await token1contract.connect(owner).transfer(taker.address, 100000)
        await token1contract.connect(taker).approve(swapcontract.address, 100000);

        console.log("Before OTC Swap:");
        console.log("Owner of nft1: ", await nft1contract.ownerOf(sellTokenIds));
        console.log("Balance of token for Maker: ", Number(await token1contract.balanceOf(maker.address)));
        console.log("Balance of token for Taker: ", Number(await token1contract.balanceOf(taker.address)));

        await swapcontract.connect(owner).setPlatformFeesRecipient(owner.address);
        await swapcontract.connect(owner).changePlatformFees(100);


        await swapcontract.connect(taker).swapNftToErc20Order(
            {
                nonce: nonce,
                orderID: "1",
                maker: Maker,
                nftToSell: [nftToSell],
                sellTokenIds: [sellTokenIds],
                tokenToBuy: [tokenToBuy],
                buyTokenAmount: [buyTokenAmount],
                signature: signatureNftErc20
            }
        );
        console.log("");
        console.log("Balances after OTC Swap:");
        console.log("Owner of nft1: ", await nft1contract.ownerOf(sellTokenIds));
        console.log("Balance of token for Maker: ", Number(await token1contract.balanceOf(maker.address)));
        console.log("Balance of token for Taker: ", Number(await token1contract.balanceOf(taker.address)));

        await swapcontract.connect(owner).withdrawPlatformFees([token1contract.address], [1000]);
        console.log("Balance of Owner: ", Number(await token1contract.balanceOf(owner.address)));
    });

    it("OTC Swap NFT<->NFT without platform fees", async function () {
        const { owner, maker, taker, swapcontract, nft1contract, nft2contract, nonce, Maker, nftToSell, sellTokenIds, nftToBuy, buyTokenIds, signatureNftNft } = await loadFixture(deployTokenFixture);
        console.log("OTC Swap without platform fees");

        await nft1contract.connect(owner).mint(maker.address, sellTokenIds)
        await nft1contract.connect(maker).approve(swapcontract.address, sellTokenIds);
        await nft2contract.connect(owner).mint(taker.address, buyTokenIds)
        await nft2contract.connect(taker).approve(swapcontract.address, buyTokenIds);

        console.log("Before OTC Swap:");
        console.log("Owner of nft1: ", await nft1contract.ownerOf(sellTokenIds));
        console.log("Owner of nft2: ", await nft2contract.ownerOf(buyTokenIds));

        await swapcontract.connect(taker).swapNftToNftOrder(
            {
                nonce: nonce,
                orderID: "1",
                maker: Maker,
                nftToSell: [nftToSell],
                sellTokenIds: [sellTokenIds],
                nftToBuy: [nftToBuy],
                buyTokenIds: [buyTokenIds],
                signature: signatureNftNft
            }
        );
        console.log("");
        console.log("Balances after OTC Swap:");
        console.log("Owner of nft1: ", await nft1contract.ownerOf(sellTokenIds));
        console.log("Owner of nft2: ", await nft2contract.ownerOf(buyTokenIds));

    });

});