// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

/**
 * @title   library to verify signatures of different types of OTC Orders
 */
library NFTOrder {
    struct NftToNftOrderStruct {
        uint256 nonce;
        uint256 orderID;
        address maker;
        address[] nftToSell;
        uint256[] sellTokenIds;
        address[] nftToBuy;
        uint256[] buyTokenIds;
        bytes signature;
    }

    struct NftToErc20OrderStruct {
        uint256 nonce;
        uint256 orderID;
        address maker;
        address[] nftToSell;
        uint256[] sellTokenIds;
        address[] tokenToBuy;
        uint256[] buyTokenAmount;
        bytes signature;
    }

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
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        return ecrecover(hash, v, r, s);
    }

    /**
     * @notice  function to verify the signature of the nft order
     * @param   nonce  unique nonce of the order
     * @param   maker  address of the creator of the order
     * @param   nftToSell  array of addresses nft to sell
     * @param   sellTokenIds  array of token ids to sell
     * @param   nftToBuy  array of addresses nft to buy
     * @param   buyTokenIds  array of token ids to buy
     * @param   signature  signature of the order signed by the maker
     * @param   DOMAIN_SEPARATOR   EIP-712 typehash for the contract's domain
     * @param   ORDER_MESSAGE_TYPE  EIP-712 typehash for the message type
     * @return  address  address of the signer
     */
    function verifyNftToNftOrder(
        uint256 nonce,
        address maker,
        address[] calldata nftToSell,
        uint256[] calldata sellTokenIds,
        address[] calldata nftToBuy,
        uint256[] calldata buyTokenIds,
        bytes calldata signature,
        bytes32 DOMAIN_SEPARATOR,
        string memory ORDER_MESSAGE_TYPE
    ) internal pure returns (address) {
        require(signature.length == 65, "wrong signature passed");
        NftToNftOrderStruct memory nftToNftOrder;
        nftToNftOrder.nonce = nonce;
        nftToNftOrder.maker = maker;
        nftToNftOrder.nftToSell = nftToSell;
        nftToNftOrder.sellTokenIds = sellTokenIds;
        nftToNftOrder.nftToBuy = nftToBuy;
        nftToNftOrder.buyTokenIds = buyTokenIds;
        nftToNftOrder.signature = signature;
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        keccak256(abi.encodePacked(ORDER_MESSAGE_TYPE)),
                        nftToNftOrder.nonce,
                        nftToNftOrder.maker,
                        keccak256(abi.encodePacked(nftToNftOrder.nftToSell)),
                        keccak256(abi.encodePacked(nftToNftOrder.sellTokenIds)),
                        keccak256(abi.encodePacked(nftToNftOrder.nftToBuy)),
                        keccak256(abi.encodePacked(nftToNftOrder.buyTokenIds))
                    )
                )
            )
        );
        return recoverSigner(hash, nftToNftOrder.signature);
    }

    /**
     * @notice  function to verify the signature of the nft order
     * @param   nonce  unique nonce of the order
     * @param   maker  address of the creator of the order
     * @param   nftToSell  array of addresses nft to sell
     * @param   sellTokenIds  array of token ids to sell
     * @param   tokenToBuy  array of addresses nft to buy
     * @param   buyTokenAmount  array of token ids to buy
     * @param   signature  signature of the order signed by the maker
     * @param   DOMAIN_SEPARATOR   EIP-712 typehash for the contract's domain
     * @param   ORDER_MESSAGE_TYPE  EIP-712 typehash for the message type
     * @return  address  address of the signer
     */
    function verifyNftToErc20Order(
        uint256 nonce,
        address maker,
        address[] calldata nftToSell,
        uint256[] calldata sellTokenIds,
        address[] calldata tokenToBuy,
        uint256[] calldata buyTokenAmount,
        bytes calldata signature,
        bytes32 DOMAIN_SEPARATOR,
        string memory ORDER_MESSAGE_TYPE
    ) internal pure returns (address) {
        require(signature.length == 65, "wrong signature passed");
        NftToErc20OrderStruct memory nftToErc20Order;
        nftToErc20Order.nonce = nonce;
        nftToErc20Order.maker = maker;
        nftToErc20Order.nftToSell = nftToSell;
        nftToErc20Order.sellTokenIds = sellTokenIds;
        nftToErc20Order.tokenToBuy = tokenToBuy;
        nftToErc20Order.buyTokenAmount = buyTokenAmount;
        nftToErc20Order.signature = signature;
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        keccak256(abi.encodePacked(ORDER_MESSAGE_TYPE)),
                        nftToErc20Order.nonce,
                        nftToErc20Order.maker,
                        keccak256(abi.encodePacked(nftToErc20Order.nftToSell)),
                        keccak256(
                            abi.encodePacked(nftToErc20Order.sellTokenIds)
                        ),
                        keccak256(abi.encodePacked(nftToErc20Order.tokenToBuy)),
                        keccak256(
                            abi.encodePacked(nftToErc20Order.buyTokenAmount)
                        )
                    )
                )
            )
        );
        return recoverSigner(hash, nftToErc20Order.signature);
    }
}
