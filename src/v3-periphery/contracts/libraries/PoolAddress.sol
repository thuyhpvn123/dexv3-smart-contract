// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

/// @title Provides functions for deriving a pool address from the factory, tokens, and the fee
library PoolAddress {
    // bytes32 internal constant POOL_INIT_CODE_HASH = 0x6ce8eb472fa82df5469c6ab6d485f17c3ad13c8cd7af59b3d4a8026c5ce0f7e2;
    // bytes32 internal constant POOL_INIT_CODE_HASH = 0xc1e46e693cee838177146ee6fad69e71116bc6dce65e302e454defe9a18c9a5c;
    // bytes32 internal constant POOL_INIT_CODE_HASH = 0x4daac5ebdd8eb7708c68e0f40b6b10d8196d802d65b399bee1423f66bb831f1a;
    // bytes32 internal constant POOL_INIT_CODE_HASH = 0x0838fb160c8314a8a48509d4c5b7d032560c924298fc8f808034b4637eb42bc0;
        bytes32 internal constant POOL_INIT_CODE_HASH = 0xf5c8cd209dba528041d79d4ba7073926156cd25911491a8fd976619bfd753a60;

    /// @notice The identifying key of the pool
    struct PoolKey {
        address token0;
        address token1;
        uint24 fee;
    }

    /// @notice Returns PoolKey: the ordered tokens with the matched fee levels
    /// @param tokenA The first token of a pool, unsorted
    /// @param tokenB The second token of a pool, unsorted
    /// @param fee The fee level of the pool
    /// @return Poolkey The pool details with ordered token0 and token1 assignments
    function getPoolKey(
        address tokenA,
        address tokenB,
        uint24 fee
    ) internal pure returns (PoolKey memory) {
        if (tokenA > tokenB) (tokenA, tokenB) = (tokenB, tokenA);
        return PoolKey({token0: tokenA, token1: tokenB, fee: fee});
    }

    /// @notice Deterministically computes the pool address given the factory and PoolKey
    /// @param deployer The PancakeSwap V3 deployer contract address
    /// @param key The PoolKey
    /// @return pool The contract address of the V3 pool
    function computeAddress(address deployer, PoolKey memory key) internal pure returns (address pool) {
        require(key.token0 < key.token1);
        pool = address(
            uint256(
                keccak256(
                    abi.encodePacked(
                        hex'ff',
                        deployer,
                        keccak256(abi.encode(key.token0, key.token1, key.fee)),
                        POOL_INIT_CODE_HASH
                    )
                )
            )
        );
    }
}
