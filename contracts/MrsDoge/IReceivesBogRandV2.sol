// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity ^0.6.12;

interface IReceivesBogRandV2 {
    function receiveRandomness(bytes32 hash, uint256 random) external;
}
