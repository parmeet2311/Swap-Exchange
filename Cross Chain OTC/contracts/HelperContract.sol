// SPDX-License-Identifier: None
pragma solidity 0.8.19;


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

contract HelperContract {
    function checkBalanceOf(address _token, address _add) public view returns (uint256){
        return IZRC20(_token).balanceOf(_add);
    }

    function checkAllowance(
        address _token,
        address owner,
        address spender
    ) external view returns (uint256) {
        return IZRC20(_token).allowance(owner, spender);
    }
}