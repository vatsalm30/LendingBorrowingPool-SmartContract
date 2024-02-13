// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

interface IPool {
    event Deposit(address indexed _user, address indexed _asset, uint256 _amount, uint256 _timestamp);
    event Withdraw(address indexed _user, address indexed _asset, uint256 _amount, uint256 _timestamp);
    event Borrow(address indexed _user, address indexed _asset, uint256 _amount, uint256 _borrowRate, uint256 _timestamp);
    event Repay(address indexed _user, address indexed _asset, uint256 _amount, uint256 _timestamp);
    event Liquidate(address indexed _user, address indexed _collateralAsset, uint256 _liquidatedAmount, uint256 _timestamp);

    function deposit(address _asset, uint256 _amount) external;
    function withdraw(address _asset, uint256 _amount) external;
    function borrow(address _asset, uint256 _amount) external;
    function repay(address _asset, uint256 _amount) external;
    //function liquidate(address _user, address _collateralAsset, address _borrowedAsset) external;
}