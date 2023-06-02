// SPDX-License-Identifier: None
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "./Order.sol";

/**
 * @title A contract for non custodial OTC Swap between two parties
 * @custom:developmment contract currently supports Full and Private OTC Orders
 * @dev under events orderType can be equal to 0 or 1 where 0 is full and 1 is private
 */
contract Swap is ERC165, ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;
    using ERC165Checker for address;
    using Address for address;
    using Order for *;

    //EIP712 Initialization
    bytes32 internal DOMAIN_SEPARATOR;
    string internal FULL_ORDER_MESSAGE_TYPE;
    string internal PRIVATE_ORDER_MESSAGE_TYPE;

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

    constructor() {
        string
            memory EIP712_DOMAIN_TYPE = "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)";
        FULL_ORDER_MESSAGE_TYPE = "Order(uint256 nonce,address maker,address tokenToSell,uint256 sellAmount,address tokenToBuy,uint256 buyAmount)";
        PRIVATE_ORDER_MESSAGE_TYPE = "Order(uint256 nonce,address maker,address tokenToSell,uint256 sellAmount,address taker,address tokenToBuy,uint256 buyAmount)";

        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(abi.encodePacked(EIP712_DOMAIN_TYPE)),
                keccak256(abi.encodePacked("OTCDesk")),
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

    event buyOrder(
        string indexed orderID,
        string orderId,
        address indexed taker,
        address indexed tokenToBuy,
        uint256 buyAmount,
        OrderType orderType
    );

    event sellOrder(
        string indexed orderID,
        string orderId,
        address indexed maker,
        address indexed tokenToSell,
        uint256 sellAmount,
        OrderType orderType
    );

    event successfulSwap(
        string indexed orderID,
        string orderId,
        address indexed maker,
        address tokenToSell,
        uint256 sellAmount,
        address indexed taker,
        address tokenToBuy,
        uint256 buyAmount,
        OrderType orderType
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
                                CHECKS
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

    /**
     * @notice  checks if the address passed in invalid
     * @param   _address  address to be checked for zero address and this contract address
     * @return  bool  true if the address is invalid and false if it is not
     */
    function isInvalidAddress(address _address) internal view returns (bool) {
        return _address == address(this) || _address == address(0);
    }

    /**
     * @notice  check if the percentage passed is a valid percent in BIPS fomat
     * @param   percentage  the percentage amount
     * @return  bool  true if the percentage is valid otherwise false
     */
    function isValidPecentage(uint16 percentage) internal pure returns (bool) {
        return percentage >= 0 && percentage <= 1000;
    }

    /**
     * @notice  checks if the token passed is blacklisted by the maintainer
     * @param   _token  token address to be checked
     * @return  bool  true if the token is blacklisted otherwise false
     */
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

    /*//////////////////////////////////////////////////////////////
                                SWAP
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice performs an Atomic Swap between the maker and the taker after verification of order
     * @param nonce The number only used once for the wallet signing the order
     * @param orderID the order id of the otc deal
     * @param maker Address of order creator
     * @param tokenToSell Address of the token the maker wants to sell
     * @param sellAmount Amount of tokens the maker wants to sell
     * @param tokenToBuy Address of the token the maker wants to buy
     * @param buyAmount Amount of tokens the maker wants to buy
     * @param signature Signature that the maker signed while making the order
     */
    function swapFullOrder(
        uint256 nonce,
        string calldata orderID,
        address maker,
        address tokenToSell,
        uint256 sellAmount,
        address tokenToBuy,
        uint256 buyAmount,
        bytes calldata signature
    ) external whenNotPaused nonReentrant {
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
            Order.verifyFullOrder(
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

        uint256 makerFees = calculatePlatformFee(sellAmount);
        uint256 takerFees = calculatePlatformFee(buyAmount);
        platformFeesPerToken[tokenToSell] += makerFees;
        platformFeesPerToken[tokenToBuy] += takerFees;
        orderType = OrderType.FULL_ORDER;

        IERC20(tokenToSell).safeTransferFrom(maker, address(this), sellAmount);
        IERC20(tokenToBuy).safeTransferFrom(
            msg.sender,
            address(this),
            buyAmount
        );
        IERC20(tokenToSell).safeTransfer(msg.sender, (sellAmount - makerFees));
        IERC20(tokenToBuy).safeTransfer(maker, (buyAmount - takerFees));

        emit successfulSwap(
            orderID,
            orderID,
            maker,
            tokenToSell,
            sellAmount,
            msg.sender,
            tokenToBuy,
            buyAmount,
            orderType
        );
        emit buyOrder(
            orderID,
            orderID,
            msg.sender,
            tokenToBuy,
            buyAmount,
            orderType
        );
        emit sellOrder(
            orderID,
            orderID,
            maker,
            tokenToSell,
            sellAmount,
            orderType
        );
    }

    /**
     * @notice performs an Atomic Swap between the maker and the taker after verification of order
     * @param nonce The number only used once for the wallet signing the order
     * @param orderID the order id of the otc deal
     * @param maker Address of order creator
     * @param tokenToSell Address of the token the maker wants to sell
     * @param sellAmount Amount of tokens the maker wants to sell
     * @param tokenToBuy Address of the token the maker wants to buy
     * @param buyAmount Amount of tokens the maker wants to buy
     * @param signature Signature that the maker signed while making the order
     */
    function swapPrivateOrder(
        uint256 nonce,
        string calldata orderID,
        address maker,
        address tokenToSell,
        uint256 sellAmount,
        address taker,
        address tokenToBuy,
        uint256 buyAmount,
        bytes calldata signature
    ) external whenNotPaused nonReentrant {
        if(taker != msg.sender) revert invalidAddress(taker);
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
            Order.verifyPrivateOrder(
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

        uint256 makerFees = calculatePlatformFee(sellAmount);
        uint256 takerFees = calculatePlatformFee(buyAmount);
        platformFeesPerToken[tokenToSell] += makerFees;
        platformFeesPerToken[tokenToBuy] += takerFees;
        orderType = OrderType.PRIVATE_ORDER;

        IERC20(tokenToSell).safeTransferFrom(maker, address(this), sellAmount);
        IERC20(tokenToBuy).safeTransferFrom(
            msg.sender,
            address(this),
            buyAmount
        );
        IERC20(tokenToSell).safeTransfer(msg.sender, (sellAmount - makerFees));
        IERC20(tokenToBuy).safeTransfer(maker, (buyAmount - takerFees));

        emit successfulSwap(
            orderID,
            orderID,
            maker,
            tokenToSell,
            sellAmount,
            taker,
            tokenToBuy,
            buyAmount,
            orderType
        );
        emit buyOrder(
            orderID,
            orderID,
            taker,
            tokenToBuy,
            buyAmount,
            orderType
        );
        emit sellOrder(
            orderID,
            orderID,
            maker,
            tokenToSell,
            sellAmount,
            orderType
        );
    }
}
