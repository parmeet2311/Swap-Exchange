// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./NFTOrder.sol";

/**
 * @title A contract for non custodial OTC Swap between two parties for NFTs
 * @custom:developmment
 */
contract nftSwap is ERC165, ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;
    using ERC165Checker for address;
    using Address for address;
    using NFTOrder for *;

    //EIP712 Initialization
    bytes32 internal DOMAIN_SEPARATOR;
    string internal NFT_TO_NFT_ORDER_MESSAGE_TYPE;
    string internal NFT_TO_ERC20_ORDER_MESSAGE_TYPE;

    //AccessControl Variables
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    //ERC165 Initialization
    bytes4 constant INTERFACE_ID_ERC165 = 0x01ffc9a7;
    bytes4 constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 constant INTERFACE_ID_ERC1155 = 0xd9b67a26;
    bytes4 constant INTERFACE_ID_ERC20 = 0x36372b07;

    mapping(address => bool) internal tokenBlacklist;
    mapping(address => mapping(uint256 => bool)) internal nftToNftOrderNonces;
    mapping(address => mapping(uint256 => bool)) internal nftToErc20OrderNonces;
    uint16 internal platformFees;
    uint256 internal nftFeeAmount;

    address internal platformFeesRecipient;
    mapping(address => uint256) internal platformFeesPerToken;
    enum OrderType {
        NFT_TO_NFT_ORDER,
        NFT_TO_ERC20_ORDER
    }

    constructor() {
        string
            memory EIP712_DOMAIN_TYPE = "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)";
        NFT_TO_NFT_ORDER_MESSAGE_TYPE = "Order(uint256 nonce,address maker,address[] nftToSell,uint256[] sellTokenIds,address[] nftToBuy,uint256[] buyTokenIds)";
        NFT_TO_ERC20_ORDER_MESSAGE_TYPE = "Order(uint256 nonce,address maker,address[] nftToSell,uint256[] sellTokenIds,address[] tokenToBuy,uint256[] buyTokenAmount)";

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(abi.encodePacked(EIP712_DOMAIN_TYPE)),
                keccak256(abi.encodePacked("NFTSwap")),
                keccak256(abi.encodePacked("1")),
                getChainId(),
                address(this)
            )
        );

        platformFeesRecipient = msg.sender;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(MAINTAINER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event successfulNftToNftSwap(
        uint256 orderID,
        address indexed maker,
        address[] nftToSell,
        uint256[] sellTokenIds,
        address indexed taker,
        address[] nftToBuy,
        uint256[] buyTokenIds,
        bytes signature,
        OrderType indexed orderType
    );

    event successfulNftToErc20Swap(
        uint256 orderID,
        address indexed maker,
        address[] nftToSell,
        uint256[] sellTokenIds,
        address indexed taker,
        address[] tokenToBuy,
        uint256[] buyTokenAmount,
        bytes signature,
        OrderType indexed orderType
    );

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyPauser() {
        require(hasRole(PAUSER_ROLE, msg.sender), "pauser role required");
        _;
    }

    modifier onlyMaintainer() {
        require(
            hasRole(MAINTAINER_ROLE, msg.sender),
            "maintainer role required"
        );
        _;
    }

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "admin role required");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                CHAIN ID
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev     used only for the EIP DOMAIN
     * @return  uint256  chain id of the network the contract is deployed on
     */
    function getChainId() internal view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error invalidAddress(address _address);
    error invalidPercentage(uint16 percentage);
    error invalidInterface(address _address);
    error blacklistedToken(address _address);
    error arrayLenghtMismatch(address[] arr1, uint16[] arr2);
    error sameAddressesPassed(address _address1, address _address2);
    error nonceUsed();
    error incorrectSignature(bytes signature);

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice function to check if given interfaces are supported by this contract
     * @param interfaceID interface id of the contract to check
     * @return bool returns if the passed interface is supported
     */
    function supportsInterface(
        bytes4 interfaceID
    ) public pure override(AccessControl, ERC165) returns (bool) {
        return
            interfaceID == INTERFACE_ID_ERC165 ||
            interfaceID == INTERFACE_ID_ERC20 ||
            interfaceID == INTERFACE_ID_ERC721;
    }

    /**
     * @notice checks if contract address passed supports ERC721
     * @param _address address of the contract to check for support
     * @return bool
     */
    function isInvalidInterface(address _address) internal view returns (bool) {
        return ERC165Checker.supportsInterface(_address, INTERFACE_ID_ERC1155);
    }

    function isInvalidAddress(address _address) internal view returns (bool) {
        return _address == address(this) || _address == address(0);
    }

    function isValidPecentage(uint16 percentage) internal pure returns (bool) {
        return percentage >= 0 && percentage <= 1000;
    }

    function isBlacklisted(address _token) internal view returns (bool) {
        return tokenBlacklist[_token];
    }

    /*//////////////////////////////////////////////////////////////
                    PAUSABLE AND BLACKLISTING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pauses the contract functions
     * @dev only callable by the Pauser role
     */
    function pause() external onlyPauser {
        _pause();
    }

    /**
     * @notice UnPauses the contract functions
     * @dev only callable by the Pauser role
     */
    function unpause() external onlyPauser {
        _unpause();
    }

    /**
     * @notice use to add a token to add or remove from blacklist
     * @dev this is only callable by the maintainer role
     * @param _token address of the token to add or remove from blacklist
     * @param makeTokenBlacklisted boolean value to make token blacklisted or not
     */
    function tokenBlacklisting(
        address _token,
        bool makeTokenBlacklisted
    ) external onlyMaintainer {
        if (isInvalidAddress(_token) == true) revert invalidAddress(_token);
        tokenBlacklist[_token] = makeTokenBlacklisted;
    }

    /*//////////////////////////////////////////////////////////////
                            PLATFORM FEES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice change the platform fees
     * @dev platforFees variable is in the form of BPS
     * @param _platformFees percentage fees to be charged for otc swaps, 100%==1000
     */
    function changePlatformFees(uint16 _platformFees) external onlyAdmin {
        if (isValidPecentage(_platformFees) == false)
            revert invalidPercentage(_platformFees);
        platformFees = _platformFees;
    }

    /**
     * @notice function to view current platform fees charged by the contract
     * @return uint256 returns the current platform fees in percentage form
     */
    function platformFee() external view returns (uint256) {
        return (platformFees);
    }

    /**
     * @notice simulates platform fees on a given amount of tokens
     * @param amount amount of tokens on which fees has to be calculated
     * @return uint256 fees in unit value of tokens
     */
    function calculatePlatformFee(
        uint256 amount
    ) public view returns (uint256) {
        return (amount * platformFees) / 1000;
    }

    /**
     * @notice whitelisting address for platform fees withdrawal
     * @param _address address of platformFeesRecipient
     */
    function setPlatformFeesRecipient(address _address) external onlyAdmin {
        if (isInvalidAddress(_address) == true) revert invalidAddress(_address);
        platformFeesRecipient = _address;
    }

    /**
     * @notice  function to withdraw platform fees from the contract
     * @dev     percentage should be in BPS format
     * @param   _tokens  array of tokens to withdraw
     * @param   percetageAmounts  array of percentage amounts to withdraw of tokens
     */
    function withdrawPlatformFees(
        address[] calldata _tokens,
        uint16[] calldata percetageAmounts
    ) external onlyAdmin {
        if (isInvalidAddress(platformFeesRecipient) == true)
            revert invalidAddress(platformFeesRecipient);
        if (_tokens.length != percetageAmounts.length)
            revert arrayLenghtMismatch(_tokens, percetageAmounts);
        for (uint16 i = 0; i < _tokens.length; i++) {
            if (isValidPecentage(percetageAmounts[i]) == false)
                revert invalidPercentage(percetageAmounts[i]);
            uint256 feeToWithdraw = (platformFeesPerToken[_tokens[i]] *
                percetageAmounts[i]) / 1000;
            platformFeesPerToken[_tokens[i]] -= feeToWithdraw;
            IERC20(_tokens[i]).safeTransfer(
                platformFeesRecipient,
                feeToWithdraw
            );
        }
    }

    /**
     * @notice Returns balance of nftSwap contract
     */
    function getBalance() external view onlyAdmin returns (uint) {
        return address(this).balance;
    }

    /*//////////////////////////////////////////////////////////////
                                SWAP
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice  function to Swap Nft <-> Nft
     * @dev     fee implimentation left
     * @param   nftToNftOrder  struct with all the swap details
     */
    function swapNftToNftOrder(
        NFTOrder.NftToNftOrderStruct calldata nftToNftOrder
    ) external whenNotPaused nonReentrant {
        if (isInvalidAddress(nftToNftOrder.maker) == true)
            revert invalidAddress(nftToNftOrder.maker);
        if (
            nftToNftOrderNonces[nftToNftOrder.maker][nftToNftOrder.nonce] ==
            true
        ) revert nonceUsed();
        if (
            NFTOrder.verifyNftToNftOrder(
                nftToNftOrder.nonce,
                nftToNftOrder.maker,
                nftToNftOrder.nftToSell,
                nftToNftOrder.sellTokenIds,
                nftToNftOrder.nftToBuy,
                nftToNftOrder.buyTokenIds,
                nftToNftOrder.signature,
                DOMAIN_SEPARATOR,
                NFT_TO_NFT_ORDER_MESSAGE_TYPE
            ) != nftToNftOrder.maker
        ) revert incorrectSignature(nftToNftOrder.signature);

        nftToNftOrderNonces[nftToNftOrder.maker][nftToNftOrder.nonce] = true;
        OrderType orderType = OrderType.NFT_TO_NFT_ORDER;

        uint16 lenghtToTraverse = uint16(nftToNftOrder.nftToSell.length);

        for (uint16 i = 0; i < lenghtToTraverse; i++) {
            if (isBlacklisted(nftToNftOrder.nftToSell[i]) == true)
                revert blacklistedToken(nftToNftOrder.nftToSell[i]);
            if (isBlacklisted(nftToNftOrder.nftToBuy[i]) == true)
                revert blacklistedToken(nftToNftOrder.nftToBuy[i]);
            if (isInvalidInterface(nftToNftOrder.nftToBuy[i]) == true)
                revert invalidInterface(nftToNftOrder.nftToBuy[i]);
            if (isInvalidInterface(nftToNftOrder.nftToSell[i]) == true)
                revert invalidInterface(nftToNftOrder.nftToSell[i]);
            if (isInvalidAddress(nftToNftOrder.nftToBuy[i]) == true)
                revert invalidAddress(nftToNftOrder.nftToBuy[i]);
            if (isInvalidAddress(nftToNftOrder.nftToSell[i]) == true)
                revert invalidAddress(nftToNftOrder.nftToSell[i]);

            ERC721(nftToNftOrder.nftToSell[i]).safeTransferFrom(
                nftToNftOrder.maker,
                msg.sender,
                nftToNftOrder.sellTokenIds[i]
            );
            ERC721(nftToNftOrder.nftToBuy[i]).safeTransferFrom(
                msg.sender,
                nftToNftOrder.maker,
                nftToNftOrder.buyTokenIds[i]
            );
        }

        emit successfulNftToNftSwap(
            nftToNftOrder.orderID,
            nftToNftOrder.maker,
            nftToNftOrder.nftToSell,
            nftToNftOrder.sellTokenIds,
            msg.sender,
            nftToNftOrder.nftToBuy,
            nftToNftOrder.buyTokenIds,
            nftToNftOrder.signature,
            orderType
        );
    }

    /**
     * @notice  function to Swap Nft <-> ERC20
     * @param   nftToErc20Order  struct with all the swap details
     */
    function swapNftToErc20Order(
        NFTOrder.NftToErc20OrderStruct calldata nftToErc20Order
    ) external whenNotPaused nonReentrant {
        if (isInvalidAddress(nftToErc20Order.maker) == true)
            revert invalidAddress(nftToErc20Order.maker);
        if (
            nftToErc20OrderNonces[nftToErc20Order.maker][
                nftToErc20Order.nonce
            ] == true
        ) revert nonceUsed();
        if (
            NFTOrder.verifyNftToErc20Order(
                nftToErc20Order.nonce,
                nftToErc20Order.maker,
                nftToErc20Order.nftToSell,
                nftToErc20Order.sellTokenIds,
                nftToErc20Order.tokenToBuy,
                nftToErc20Order.buyTokenAmount,
                nftToErc20Order.signature,
                DOMAIN_SEPARATOR,
                NFT_TO_ERC20_ORDER_MESSAGE_TYPE
            ) != nftToErc20Order.maker
        ) revert incorrectSignature(nftToErc20Order.signature);

        nftToNftOrderNonces[nftToErc20Order.maker][
            nftToErc20Order.nonce
        ] = true;
        OrderType orderType = OrderType.NFT_TO_ERC20_ORDER;

        uint16 lenghtToTraverse = uint16(nftToErc20Order.nftToSell.length);

        for (uint16 i = 0; i < lenghtToTraverse; i++) {
            if (isBlacklisted(nftToErc20Order.nftToSell[i]) == true)
                revert blacklistedToken(nftToErc20Order.nftToSell[i]);
            if (isBlacklisted(nftToErc20Order.tokenToBuy[i]) == true)
                revert blacklistedToken(nftToErc20Order.tokenToBuy[i]);
            if (isInvalidInterface(nftToErc20Order.tokenToBuy[i]) == true)
                revert invalidInterface(nftToErc20Order.tokenToBuy[i]);
            if (isInvalidInterface(nftToErc20Order.nftToSell[i]) == true)
                revert invalidInterface(nftToErc20Order.nftToSell[i]);
            if (isInvalidAddress(nftToErc20Order.tokenToBuy[i]) == true)
                revert invalidAddress(nftToErc20Order.tokenToBuy[i]);
            if (isInvalidAddress(nftToErc20Order.nftToSell[i]) == true)
                revert invalidAddress(nftToErc20Order.nftToSell[i]);

            uint256 fee = calculatePlatformFee(
                nftToErc20Order.buyTokenAmount[i]
            );

            IERC20(nftToErc20Order.tokenToBuy[i]).safeTransferFrom(
                msg.sender,
                address(this),
                nftToErc20Order.buyTokenAmount[i] + fee
            );

            IERC20(nftToErc20Order.tokenToBuy[i]).safeTransfer(
                nftToErc20Order.maker,
                nftToErc20Order.buyTokenAmount[i] - fee
            );

            ERC721(nftToErc20Order.nftToSell[i]).safeTransferFrom(
                nftToErc20Order.maker,
                msg.sender,
                nftToErc20Order.sellTokenIds[i]
            );

            platformFeesPerToken[nftToErc20Order.tokenToBuy[i]] += fee * 2;
        }

        emit successfulNftToErc20Swap(
            nftToErc20Order.orderID,
            nftToErc20Order.maker,
            nftToErc20Order.nftToSell,
            nftToErc20Order.sellTokenIds,
            msg.sender,
            nftToErc20Order.tokenToBuy,
            nftToErc20Order.buyTokenAmount,
            nftToErc20Order.signature,
            orderType
        );
    }
}
