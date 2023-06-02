async function signTypedData() {
    // connect to wallet
    const from = await ethereum.request({ method: "eth_requestAccounts" });

    const msgParams = JSON.stringify({
        domain: {
            name: "CrossChainOTCDesk",
            version: "1",
            chainId: 7001,
            verifyingContract: "0x5dd2f496F19321F728a709154c3D83D6830edfec",
        },

        message: {
            nonce: 1,
            maker: "0x421B35e07B9d3Cc08f6780A01E5fEe7B8aeFD13E",
            tokenToSell: "0x13A0c5930C028511Dc02665E7285134B6d11A5f4",
            sellAmount: "100000000000000000",
            taker: "0x4a649e62bdA41A688042C55E71b9B69DCD25Bb77",
            tokenToBuy: "0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891",
            buyAmount: "100000000000000000",
        },

        primaryType: "Order",
        types: {
            EIP712Domain: [
                { name: "name", type: "string" },
                { name: "version", type: "string" },
                { name: "chainId", type: "uint256" },
                { name: "verifyingContract", type: "address" },
            ],
            // Refer to primaryType
            Order: [{ name: "nonce", type: "uint256" },
            { name: "maker", type: "address" },
            { name: "tokenToSell", type: "address" },
            { name: "sellAmount", type: "uint256" },
            { name: "taker", type: "address" },
            { name: "tokenToBuy", type: "address" },
            { name: "buyAmount", type: "uint256" },
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
            // display
            document.getElementById("signedTypedData").innerHTML = result.result;
        }
    );
}