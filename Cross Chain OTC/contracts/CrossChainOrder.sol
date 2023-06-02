    // SPDX-License-Identifier: None
    pragma solidity 0.8.19;

    /**
     * @title   library to verify signatures of different types of CrossChain OTC Orders
     */
    library CrossChainOrder {
        /**
         * @notice  recovers the signer of the signature
         * @param   hash  order details in an encoded format
         * @param   signature  signature which was signed by the maker
         * @return  address  signer address
         */
        function recoverSigner(
            bytes32 hash,
            bytes memory signature
        ) internal pure returns (address) {
            bytes memory _signature = signature;
            bytes32 r;
            bytes32 s;
            uint8 v;
            assembly {
                r := mload(add(_signature, 32))
                s := mload(add(_signature, 64))
                v := byte(0, mload(add(_signature, 96)))
            }
            return ecrecover(hash, v, r, s);
        }

        /**
         * @notice  This function is called to check and verify the order before fulfillment by the taker using signature made by the maker
         * @param nonce The number only used once for the wallet signing the order
         * @param maker Address of order creator
         * @param tokenToSell Address of the token the maker wants to sell
         * @param sellAmount Amount of tokens the maker wants to sell
         * @param tokenToBuy Address of the token the maker wants to buy
         * @param buyAmount Amount of tokens the maker wants to buy
         * @param signature Signature that the maker signed while making the order
         * @param DOMAIN_SEPARATOR domain seperator used for eip712
         * @param ORDER_MESSAGE_TYPE message types using in eip712
         * @return Address that signed the given signature
         */
        function verifyFullOrder(
            uint256 nonce,
            address maker,
            address tokenToSell,
            uint256 sellAmount,
            address tokenToBuy,
            uint256 buyAmount,
            bytes memory signature,
            bytes32 DOMAIN_SEPARATOR,
            string memory ORDER_MESSAGE_TYPE
        ) internal pure returns (address) {
            require(signature.length == 65, "wrong signature passed");

            bytes32 hash = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            keccak256(abi.encodePacked(ORDER_MESSAGE_TYPE)),
                            nonce,
                            maker,
                            tokenToSell,
                            sellAmount,
                            tokenToBuy,
                            buyAmount
                        )
                    )
                )
            );

            return recoverSigner(hash, signature);
        }

            /**
         * @notice  This function is called to check and verify the order before fulfillment by the taker using signature made by the maker
         * @param nonce The number only used once for the wallet signing the order
         * @param maker Address of order creator
         * @param tokenToSell Address of the token the maker wants to sell
         * @param sellAmount Amount of tokens the maker wants to sell
         * @param taker the taker of the order
         * @param tokenToBuy Address of the token the maker wants to buy
         * @param buyAmount Amount of tokens the maker wants to buy
         * @param signature Signature that the maker signed while making the order
         * @param DOMAIN_SEPARATOR domain seperator used for eip712
         * @param ORDER_MESSAGE_TYPE message types using in eip712
         * @return Address that signed the given signature
         */
        function verifyPrivateOrder(
            uint256 nonce,
            address maker,
            address tokenToSell,
            uint256 sellAmount,
            address taker,
            address tokenToBuy,
            uint256 buyAmount,
            bytes memory signature,
            bytes32 DOMAIN_SEPARATOR,
            string memory ORDER_MESSAGE_TYPE
        ) internal pure returns (address) {
            require(signature.length == 65, "wrong signature passed");

            bytes32 hash = keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            keccak256(abi.encodePacked(ORDER_MESSAGE_TYPE)),
                            nonce,
                            maker,
                            tokenToSell,
                            sellAmount,
                            taker,
                            tokenToBuy,
                            buyAmount
                        )
                    )
                )
            );

            return recoverSigner(hash, signature);
        }
    }
