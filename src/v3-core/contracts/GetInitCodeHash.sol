// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import {PancakeV3Pool} from "./PancakeV3Pool.sol";

contract GetPoolInitCodeHashSmC {
    function GetPoolInitCodeHash() external pure returns(bytes32) {
        bytes32 POOL_INIT_CODE_HASH = keccak256(abi.encodePacked(type(PancakeV3Pool).creationCode));
        return POOL_INIT_CODE_HASH;
    }
}