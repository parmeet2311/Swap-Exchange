const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");
const { ethers } = require("hardhat");

describe("OTC Desk", function () {
    async function deployTokenFixture() {
        const [owner, maker, taker] = await ethers.getSigners();

        const Swap = await ethers.getContractFactory("Swap");
        const swapcontract = await Swap.deploy();
        await swapcontract.deployed();
        console.log("Swap Contract Address: ", swapcontract.address);

        const token1 = await ethers.getContractFactory("token1");
        const token1contract = await token1.deploy();
        await token1contract.deployed();
        console.log("Token 1 Contract Address: ", token1contract.address);

        const token2 = await ethers.getContractFactory("token2");
        const token2contract = await token2.deploy();
        await token2contract.deployed();
        console.log("Token 2 Contract Address: ", token2contract.address);

        const nonce = 1;
        const Maker = maker.address;
        const tokenToSell = token1contract.address;
        const sellAmount = 1000;
        const tokenToBuy = token2contract.address;
        const buyAmount = 100;
        const sig = "0x5d2bdcd95c1eaafd14cbf3d200f345122be27035136fcdd675a7415a7ea41b6b32cd015ea4b2a72d04e84d35f96bfd367188dca6e330212c2deeb61112e4df4e1b"
        const signature = (ethers.utils.arrayify(sig));

        await swapcontract.connect(owner).grantRole("0x339759585899103d2ace64958e37e18ccb0504652c81d4a1b8aa80fe2126ab95", owner.address);
        await swapcontract.connect(owner).grantRole("0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a", owner.address);


        return { owner, maker, taker, swapcontract, token1contract, token2contract, nonce, Maker, tokenToSell, sellAmount, tokenToBuy, buyAmount, signature };
    }

    it("Contract Paused", async function () {
        const { owner, maker, taker, swapcontract, token1contract, token2contract, nonce, Maker, tokenToSell, sellAmount, tokenToBuy, buyAmount, signature } = await loadFixture(deployTokenFixture);
        await swapcontract.connect(owner).pause();
        await expect(swapcontract.connect(taker).swapFullOrder(nonce, 1, Maker, tokenToSell, sellAmount, tokenToBuy, buyAmount, signature)).to.be.reverted;
        await swapcontract.connect(owner).unpause();
    });

    it("Token Blacklisted", async function () {
        const { owner, maker, taker, swapcontract, token1contract, token2contract, nonce, Maker, tokenToSell, sellAmount, tokenToBuy, buyAmount, signature } = await loadFixture(deployTokenFixture);
        await swapcontract.connect(owner).tokenBlacklisting(tokenToSell, true);
        await expect(swapcontract.connect(taker).swapFullOrder(nonce, 1, Maker, tokenToSell, sellAmount, tokenToBuy, buyAmount, signature)).to.be.reverted;
    });

    it("Platform Fees", async function () {
        const { owner, maker, taker, swapcontract, token1contract, token2contract, nonce, Maker, tokenToSell, sellAmount, tokenToBuy, buyAmount, signature } = await loadFixture(deployTokenFixture);
        console.log("Platform fees: ", Number(await swapcontract.connect(owner).platformFee()), "BIPS");
        await swapcontract.connect(owner).changePlatformFees(10);
        console.log("Platform fees changed to: ", Number(await swapcontract.connect(owner).platformFee()), "BIPS");
        console.log("Platform fees charged if 500 tokens are passed: ", Number(await swapcontract.connect(owner).calculatePlatformFee(500)));

    });

    it("OTC Swap without platform fees", async function () {
        const { owner, maker, taker, swapcontract, token1contract, token2contract, nonce, Maker, tokenToSell, sellAmount, tokenToBuy, buyAmount, signature } = await loadFixture(deployTokenFixture);

        await token1contract.connect(owner).transfer(maker.address, 100000);
        await token1contract.connect(maker).approve(swapcontract.address, 100000);
        console.log();
        console.log("Balances before OTC Swap:");
        console.log("Balance of maker for token1", Number(await token1contract.connect(maker).balanceOf(maker.address)));
        console.log("Balance of maker for token2", Number(await token2contract.connect(maker).balanceOf(maker.address)));


        await token2contract.connect(owner).transfer(taker.address, 100000);
        await token2contract.connect(taker).approve(swapcontract.address, 100000);
        console.log("Balance of taker for token1", Number(await token1contract.connect(taker).balanceOf(taker.address)));
        console.log("Balance of taker for token2", Number(await token2contract.connect(taker).balanceOf(taker.address)));

        await swapcontract.connect(taker).swapFullOrder(nonce, 1, Maker, tokenToSell, sellAmount, tokenToBuy, buyAmount, signature);

        console.log();
        console.log("Balances after OTC Swap:");
        console.log("Balance of maker for token1", Number(await token1contract.connect(maker).balanceOf(maker.address)));
        console.log("Balance of maker for token2", Number(await token2contract.connect(maker).balanceOf(maker.address)));
        console.log("Balance of taker for token1", Number(await token1contract.connect(taker).balanceOf(taker.address)));
        console.log("Balance of taker for token2", Number(await token2contract.connect(taker).balanceOf(taker.address)));

    });

    it("OTC Swap with platform fees", async function () {
        const { owner, maker, taker, swapcontract, token1contract, token2contract, nonce, Maker, tokenToSell, sellAmount, tokenToBuy, buyAmount, signature } = await loadFixture(deployTokenFixture);

        await token1contract.connect(owner).transfer(maker.address, 100000);
        await token1contract.connect(maker).approve(swapcontract.address, 100000);
        console.log();
        console.log("Balances before OTC Swap:");
        console.log("Balance of maker for token1", Number(await token1contract.connect(maker).balanceOf(maker.address)));
        console.log("Balance of maker for token2", Number(await token2contract.connect(maker).balanceOf(maker.address)));
        await token2contract.connect(owner).transfer(taker.address, 100000);
        await token2contract.connect(taker).approve(swapcontract.address, 100000);
        console.log("Balance of taker for token1", Number(await token1contract.connect(taker).balanceOf(taker.address)));
        console.log("Balance of taker for token2", Number(await token2contract.connect(taker).balanceOf(taker.address)));
        console.log("Balance of otc contract for token1", Number(await token1contract.connect(owner).balanceOf(swapcontract.address)));
        console.log("Balance of otc contract for token2", Number(await token2contract.connect(owner).balanceOf(swapcontract.address)));
        console.log("");
        console.log("Platform fees being charged is 10%");
        await swapcontract.connect(owner).changePlatformFees(100);
        console.log(Number(await swapcontract.connect(owner).calculatePlatformFee(sellAmount)));
        console.log(Number(await swapcontract.connect(owner).calculatePlatformFee(buyAmount)));


        await swapcontract.connect(owner).setPlatformFeesRecipient(owner.address);

        await swapcontract.connect(taker).swapFullOrder(nonce, 1, Maker, tokenToSell, sellAmount, tokenToBuy, buyAmount, signature);
        console.log();
        console.log("Balances after OTC Swap:");
        console.log("Balance of maker for token1", Number(await token1contract.connect(maker).balanceOf(maker.address)));
        console.log("Balance of maker for token2", Number(await token2contract.connect(maker).balanceOf(maker.address)));
        console.log("Balance of taker for token1", Number(await token1contract.connect(taker).balanceOf(taker.address)));
        console.log("Balance of taker for token2", Number(await token2contract.connect(taker).balanceOf(taker.address)));

        console.log("Balance of otc desk for token1", Number(await token1contract.connect(owner).balanceOf(swapcontract.address)));
        console.log("Balance of otc desk for token2", Number(await token2contract.connect(owner).balanceOf(swapcontract.address)));

        await swapcontract.connect(owner).withdrawPlatformFees([token1contract.address, token2contract.address], [1000, 1000]);
        console.log("Balance of owner for token1", Number(await token1contract.connect(owner).balanceOf(owner.address)));
        console.log("Balance of owner for token2", Number(await token2contract.connect(owner).balanceOf(owner.address)));

    });

});