// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.7.0;

import "@openzeppelin/contracts@3.4.0-solc-0.7/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@3.4.0-solc-0.7/access/Ownable.sol";

contract BEP20 is ERC20, Ownable {
  constructor(string memory name,string memory symbol) payable ERC20(name, symbol) {}

  function mint(address to, uint256 amount) public onlyOwner {
    _mint(to, amount);
  }
}