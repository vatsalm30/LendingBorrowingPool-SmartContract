// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "./Interface/IPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Pool is IPool, ReentrancyGuard {
    function deposit(address _asset, uint256 _amount) external nonReentrant
    {
        emit Deposit(msg.sender, _asset, _amount, block.timestamp);
    }
    function withdraw(address _asset, uint256 _amount) external nonReentrant
    {
        emit Withdraw(msg.sender, _asset, _amount, block.timestamp);
    }
    function borrow(address _asset, uint256 _amount) external nonReentrant
    {
        emit Borrow(msg.sender, _asset, _amount, 0, block.timestamp);
    }
    function repay(address _asset, uint256 _amount) external nonReentrant
    {
        emit Repay(msg.sender, _asset, _amount, block.timestamp);
    }
    function liquidate(address _user, address _collateralAsset, address _borrowedAsset) external nonReentrant
    {
        // This implementation is extremly flawed because it doesn't properly check the users balance.
        emit Liquidate(_user, _collateralAsset, IERC20(_collateralAsset).balanceOf(_user), block.timestamp);
    }
}