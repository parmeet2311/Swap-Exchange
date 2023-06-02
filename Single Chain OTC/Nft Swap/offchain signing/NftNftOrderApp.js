async function signTypedData() {
    const from = await ethereum.request({ method: "eth_requestAccounts" });

    const msgParams = JSON.stringify({
        domain: {
            name: "NFTSwap",
            version: "1",
            chainId: 31337,
            verifyingContract: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
        },

        message: {
            nonce: 1,
            maker: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
            nftToSell: ["0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512"],
            sellTokenIds: [1],
            nftToBuy: ["0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0"],
            buyTokenIds: [100]
        },

        primaryType: "Order",
        types: {
            EIP712Domain: [
                { name: "name", type: "string" },
                { name: "version", type: "string" },
                { name: "chainId", type: "uint256" },
                { name: "verifyingContract", type: "address" },
            ],
            Order: [
                { name: "nonce", type: "uint256" },
                { name: "maker", type: "address" },
                { name: "nftToSell", type: "address[]" },
                { name: "sellTokenIds", type: "uint256[]" },
                { name: "nftToBuy", type: "address[]" },
                { name: "buyTokenIds", type: "uint256[]" },
            ],
        },
    });

    web3.currentProvider.sendAsync(
        {
            method: "eth_signTypedData_v4",
            params: [from[0], msgParams],
            from: from[0],
        },
        function (err, result) {
            if (err) return console.dir(err);
            if (result.error) {
                alert(result.error.message);
            }
            if (result.error) return console.error("ERROR", result);
            console.log("TYPED SIGNED:" + JSON.stringify(result.result));
            document.getElementById("signedTypedData").innerHTML = result.result;
        }
    );
}