// SPDX-License-Identifier: None
pragma solidity 0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "./CrossChainOrder.sol";
import "./BytesHelperLib.sol";

/*//////////////////////////////////////////////////////////////
                            INTERFACE
//////////////////////////////////////////////////////////////*/

interface IZRC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    function deposit(address to, uint256 amount) external returns (bool);

    function withdraw(bytes memory to, uint256 amount) external returns (bool);

    function withdrawGasFee() external view returns (address, uint256);
}

/*//////////////////////////////////////////////////////////////
                            MAIN CONTRACT
//////////////////////////////////////////////////////////////*/

/**
 * @title A contract for non custodial OTC Swap between two parties
 * @custom:developmment contract currently supports Full and Private OTC Orders
 * @dev under events orderType can be equal to 0 or 1 where 0 is full and 1 is private
 */
contract CrossChainSwap is ERC165, ReentrancyGuard, Pausable, AccessControl {
    using CrossChainOrder for *;
    using BytesHelperLib for bytes;
    using BytesHelperLib for address;
    using ERC165Checker for address;

    //EIP712 Initialization
    bytes32 internal DOMAIN_SEPARATOR;
    string internal FULL_ORDER_MESSAGE_TYPE;
    string internal PRIVATE_ORDER_MESSAGE_TYPE;

    uint16 internal constant MAX_DEADLINE = 200;

    //AccessControl Variables
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    //ERC165 Initialization
    bytes4 constant INTERFACE_ID_ERC165 = 0x01ffc9a7;
    bytes4 constant INTERFACE_ID_ERC721 = 0x80ac58cd;
    bytes4 constant INTERFACE_ID_ERC1155 = 0xd9b67a26;
    bytes4 constant INTERFACE_ID_ERC20 = 0x36372b07;

    mapping(address => bool) internal tokenBlacklist;
    mapping(address => mapping(uint256 => bool)) internal fullOrderNonces;
    mapping(address => mapping(uint256 => bool)) internal privateOrderNonces;

    uint16 internal platformFees;
    address internal platformFeesRecipient;
    mapping(address => uint256) internal platformFeesPerToken;

    enum OrderType {
        FULL_ORDER,
        PRIVATE_ORDER
    }
    OrderType internal orderType;

    struct CCOrder {
        uint256 orderID;
        uint256 nonce;
        address maker;
        address tokenToSell;
        uint256 sellAmount;
        address taker;
        address tokenToBuy;
        uint256 buyAmount;
        bool doWithdrawalTaker;
        OrderType CCOrderType;
    }

    constructor() {
        string
            memory EIP712_DOMAIN_TYPE = "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)";
        FULL_ORDER_MESSAGE_TYPE = "Order(uint256 nonce,address maker,address tokenToSell,uint256 sellAmount,address tokenToBuy,uint256 buyAmount)";
        PRIVATE_ORDER_MESSAGE_TYPE = "Order(uint256 nonce,address maker,address tokenToSell,uint256 sellAmount,address taker,address tokenToBuy,uint256 buyAmount)";
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(abi.encodePacked(EIP712_DOMAIN_TYPE)),
                keccak256(abi.encodePacked("CrossChainOTCDesk")),
                keccak256(abi.encodePacked("1")),
                getChainId(),
                address(this)
            )
        );
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(DEFAULT_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(MAINTAINER_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(PAUSER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event buyOrder(
        uint256 indexed orderID,
        address indexed taker,
        address indexed tokenToBuy,
        uint256 buyAmount,
        OrderType orderType
    );

    event sellOrder(
        uint256 indexed orderID,
        address indexed maker,
        address indexed tokenToSell,
        uint256 sellAmount,
        OrderType orderType
    );

    event successfulSwap(
        uint256 indexed orderID,
        address indexed maker,
        address tokenToSell,
        uint256 sellAmount,
        address indexed taker,
        address tokenToBuy,
        uint256 buyAmount,
        OrderType orderType
    );

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
    error WrongGasContract();
    error transferFailed();
    error wrongOrderTypePassed();

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
                            HELPER FUNCTIONS
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

    function addressToBytes(
        address someAddress
    ) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(someAddress)));
    }

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
            interfaceID == INTERFACE_ID_ERC20;
    }

    /**
     * @notice checks if contract address passed supports ERC721
     * @param _address address of the contract to check for support
     * @return bool
     */
    function isInvalidInterface(address _address) internal view returns (bool) {
        return
            ERC165Checker.supportsInterface(_address, INTERFACE_ID_ERC1155) ||
            ERC165Checker.supportsInterface(_address, INTERFACE_ID_ERC721);
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
            IZRC20(_tokens[i]).transfer(platformFeesRecipient, feeToWithdraw);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                SWAP
    //////////////////////////////////////////////////////////////*/

    function swapFullOrder(
        uint256 nonce,
        uint256 orderID,
        address maker,
        address tokenToSell,
        uint256 sellAmount,
        address taker,
        address tokenToBuy,
        uint256 buyAmount,
        bool doWithdrawalTaker,
        bytes memory signature
    ) internal whenNotPaused nonReentrant {
        if (taker == maker) revert invalidAddress(taker);
        if (isBlacklisted(tokenToBuy) == true)
            revert blacklistedToken(tokenToBuy);
        if (isBlacklisted(tokenToSell) == true)
            revert blacklistedToken(tokenToSell);
        if (isInvalidInterface(tokenToBuy) == true)
            revert invalidInterface(tokenToBuy);
        if (isInvalidInterface(tokenToSell) == true)
            revert invalidInterface(tokenToSell);
        if (isInvalidAddress(maker) == true) revert invalidAddress(maker);
        if (isInvalidAddress(tokenToBuy) == true)
            revert invalidAddress(tokenToBuy);
        if (isInvalidAddress(tokenToSell) == true)
            revert invalidAddress(tokenToSell);
        if (tokenToBuy == tokenToSell)
            revert sameAddressesPassed(tokenToBuy, tokenToSell);
        if (fullOrderNonces[maker][nonce] == true) revert nonceUsed();

        if (
            CrossChainOrder.verifyFullOrder(
                nonce,
                maker,
                tokenToSell,
                sellAmount,
                tokenToBuy,
                buyAmount,
                signature,
                DOMAIN_SEPARATOR,
                FULL_ORDER_MESSAGE_TYPE
            ) != maker
        ) revert incorrectSignature(signature);

        fullOrderNonces[maker][nonce] = true;
        orderType = OrderType.FULL_ORDER;

        doSwap(
            maker,
            tokenToSell,
            sellAmount,
            taker,
            tokenToBuy,
            buyAmount,
            doWithdrawalTaker
        );

        emit successfulSwap(
            orderID,
            maker,
            tokenToSell,
            sellAmount,
            taker,
            tokenToBuy,
            buyAmount,
            orderType
        );
        emit buyOrder(orderID, taker, tokenToBuy, buyAmount, orderType);
        emit sellOrder(orderID, maker, tokenToSell, sellAmount, orderType);
    }

    function swapPrivateOrder(
        uint256 nonce,
        uint256 orderID,
        address maker,
        address tokenToSell,
        uint256 sellAmount,
        address taker,
        address tokenToBuy,
        uint256 buyAmount,
        bool doWithdrawalTaker,
        bytes memory signature
    ) internal whenNotPaused nonReentrant {
        if (taker == maker) revert invalidAddress(taker);
        if (isBlacklisted(tokenToBuy) == true)
            revert blacklistedToken(tokenToBuy);
        if (isBlacklisted(tokenToSell) == true)
            revert blacklistedToken(tokenToSell);
        if (isInvalidInterface(tokenToBuy) == true)
            revert invalidInterface(tokenToBuy);
        if (isInvalidInterface(tokenToSell) == true)
            revert invalidInterface(tokenToSell);
        if (isInvalidAddress(maker) == true) revert invalidAddress(maker);
        if (isInvalidAddress(taker) == true) revert invalidAddress(taker);
        if (isInvalidAddress(tokenToBuy) == true)
            revert invalidAddress(tokenToBuy);
        if (isInvalidAddress(tokenToSell) == true)
            revert invalidAddress(tokenToSell);
        if (tokenToBuy == tokenToSell)
            revert sameAddressesPassed(tokenToBuy, tokenToSell);
        if (privateOrderNonces[maker][nonce] == true) revert nonceUsed();
        if (
            CrossChainOrder.verifyPrivateOrder(
                nonce,
                maker,
                tokenToSell,
                sellAmount,
                taker,
                tokenToBuy,
                buyAmount,
                signature,
                DOMAIN_SEPARATOR,
                PRIVATE_ORDER_MESSAGE_TYPE
            ) != maker
        ) revert incorrectSignature(signature);

        privateOrderNonces[maker][nonce] = true;
        orderType = OrderType.PRIVATE_ORDER;

        doSwap(
            maker,
            tokenToSell,
            sellAmount,
            taker,
            tokenToBuy,
            buyAmount,
            doWithdrawalTaker
        );

        emit successfulSwap(
            orderID,
            maker,
            tokenToSell,
            sellAmount,
            taker,
            tokenToBuy,
            buyAmount,
            orderType
        );
        emit buyOrder(orderID, taker, tokenToBuy, buyAmount, orderType);
        emit sellOrder(orderID, maker, tokenToSell, sellAmount, orderType);
    }

    function doSwap(
        address maker,
        address tokenToSell,
        uint256 sellAmount,
        address taker,
        address tokenToBuy,
        uint256 buyAmount,
        bool doWithdrawalTaker
    ) internal whenNotPaused nonReentrant {
        uint256 makerFees = calculatePlatformFee(sellAmount);
        uint256 takerFees = calculatePlatformFee(buyAmount);
        platformFeesPerToken[tokenToSell] += makerFees;
        platformFeesPerToken[tokenToBuy] += takerFees;

        IZRC20(tokenToSell).transferFrom(maker, address(this), sellAmount);

        if (doWithdrawalTaker == true) {
            bytes32 _taker = taker.addressToBytes();
            withdrawToConnectedChain(
                tokenToSell,
                _taker,
                sellAmount - makerFees
            );
        } else {
            IZRC20(tokenToSell).transfer(taker, sellAmount - makerFees);
        }
        IZRC20(tokenToBuy).transfer(maker, buyAmount - takerFees);
    }

    /*//////////////////////////////////////////////////////////////
                            ZETA FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function encodeData(
        CCOrder calldata order,
        bytes calldata signature
    ) external pure returns (bytes memory) {
        return abi.encode(order, signature);
    }

    function decodeData(
        bytes calldata message
    ) internal pure returns (CCOrder memory, bytes memory) {
        return abi.decode(message, (CCOrder, bytes));
    }

    function onCrossChainCall(
        address zrc20,
        uint256 amount,
        bytes calldata message
    ) external {
        CCOrder memory order;
        bytes memory _signature;
        (order, _signature) = decodeData(message);

        if (order.CCOrderType == OrderType.FULL_ORDER) {
            swapFullOrder(
                order.orderID,
                order.nonce,
                order.maker,
                order.tokenToSell,
                order.sellAmount,
                order.taker,
                order.tokenToBuy,
                order.buyAmount,
                order.doWithdrawalTaker,
                _signature
            );
        } else if (order.CCOrderType == OrderType.PRIVATE_ORDER) {
            swapPrivateOrder(
                order.orderID,
                order.nonce,
                order.maker,
                order.tokenToSell,
                order.sellAmount,
                order.taker,
                order.tokenToBuy,
                order.buyAmount,
                order.doWithdrawalTaker,
                _signature
            );
        } else revert wrongOrderTypePassed();
    }

    function withdrawToConnectedChain(
        address token,
        bytes32 _add,
        uint256 amount
    ) internal {
        (address gasZRC20, uint256 gasFee) = IZRC20(token).withdrawGasFee();
        if (gasZRC20 != token) revert();
        if (gasFee >= amount) revert();
        IZRC20(token).approve(token, gasFee);
        IZRC20(token).withdraw(abi.encodePacked(_add), amount - gasFee);
    }
}
