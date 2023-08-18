// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IBpt {
    function approve(address spender, uint256 amount) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function getPoolId() external view returns (bytes32);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}
