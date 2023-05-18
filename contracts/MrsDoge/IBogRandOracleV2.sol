// SPDX-License-Identifier: MIT

pragma experimental ABIEncoderV2;
pragma solidity ^0.6.12;

interface IBogRandOracleV2 {
    // Request randomness with fee in BOG
    function getBOGFee() external view returns (uint256);
    function requestRandomness() external payable returns (bytes32 assignedHash, uint256 requestID);

    // Request randomness with fee in BNB
    function getBNBFee() external view returns (uint256);
    function requestRandomnessBNBFee() external payable returns (bytes32 assignedHash, uint256 requestID);
    
    // Retrieve request details
    enum RequestState { REQUESTED, FILLED, CANCELLED }
    function getRequest(uint256 requestID) external view returns (RequestState state, bytes32 hash, address requester, uint256 gas, uint256 requestedBlock);
    function getRequest(bytes32 hash) external view returns (RequestState state, uint256 requestID, address requester, uint256 gas, uint256 requestedBlock);
    // Get request blocks to use with blockhash as hash seed
    function getRequestBlock(uint256 requestID) external view returns (uint256);
    function getRequestBlock(bytes32 hash) external view returns (uint256);

    // RNG backend functions
    function seed(bytes32 hash) external;
    function getNextRequest() external view returns (uint256 requestID);
    function fulfilRequest(uint256 requestID, uint256 random, bytes32 newHash) external;
    function cancelRequest(uint256 requestID, bytes32 newHash) external;
    function getFullHashReserves() external view returns (uint256);
    function getDepletedHashReserves() external view returns (uint256);
    
    // Events
    event Seeded(bytes32 hash);
    event RandomnessRequested(uint256 requestID, bytes32 hash);
    event RandomnessProvided(uint256 requestID, address requester, uint256 random);
    event RequestCancelled(uint256 requestID);
}