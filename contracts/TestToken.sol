// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract TestToken is ERC20, ERC20Permit {
    constructor(string memory name_, string memory symbol_, uint256 maxSupply_) ERC20(name_, symbol_) ERC20Permit(name_) {
        _mint(msg.sender, maxSupply_ * 10 ** decimals());
    }
}