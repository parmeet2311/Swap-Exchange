// SPDX-License-Identifier: None
pragma solidity 0.8.19;

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

contract DemoContract {
    using BytesHelperLib for bytes;
    using BytesHelperLib for address;

    function doWithdrawl() external{
        address zrc20Matic = 0xd97B1de3619ed2c6BEb3860147E30cA8A7dC9891;
        address zrc20Bnb = 0x13A0c5930C028511Dc02665E7285134B6d11A5f4;
        address _add = 0x421B35e07B9d3Cc08f6780A01E5fEe7B8aeFD13E;
        bytes32 _address = BytesHelperLib.addressToBytes(_add);
        uint256 amount = 100000000000000000;
        offchainWithdraw(zrc20Matic, _address, amount);
        offchainWithdraw(zrc20Bnb, _address, amount);
        
    } 

    function offchainWithdraw(
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
