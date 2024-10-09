// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {BaseMiddleware} from "./BaseMiddleware.sol";
import {PauseableEnumerableSet} from "./libraries/PauseableEnumerableSet.sol";

abstract contract KeyManager is BaseMiddleware {
    using PauseableEnumerableSet for PauseableEnumerableSet.Inner;

    error DuplicateKey();

    bytes32 private constant ZERO_BYTES32 = bytes32(0);

    mapping(address => bytes32) public keys; // Mapping from operator addresses to their current keys
    mapping(address => bytes32) public prevKeys; // Mapping from operator addresses to their previous keys
    mapping(bytes32 => PauseableEnumerableSet.Inner) internal keyData; // Mapping from keys to their associated data

    /* 
     * Returns the operator address associated with a given key.
     * @param key The key for which to find the associated operator.
     * @return The address of the operator linked to the specified key.
     */
    function operatorByKey(bytes32 key) public view returns (address) {
        return keyData[key].getAddress();
    }

    /* 
     * Returns the current key for a given operator. 
     * If the key has changed in the current epoch, returns the previous key.
     * @param operator The address of the operator.
     * @return The key associated with the specified operator.
     */
    function operatorKey(address operator) public view returns (bytes32) {
        if (keyData[keys[operator]].enabledEpoch == getCurrentEpoch()) {
            return prevKeys[operator];
        }

        return keys[operator];
    }

    /* 
     * Checks if a given key was active at a specified epoch.
     * @param epoch The epoch to check for key activity.
     * @param key The key to check.
     * @return A boolean indicating whether the key was active at the specified epoch.
     */
    function keyWasActiveAt(uint48 epoch, bytes32 key) public view returns (bool) {
        return keyData[key].wasActiveAt(epoch);
    }

    /* 
     * Updates the key associated with an operator. 
     * If the new key already exists, a DuplicateKey error is thrown.
     * @param operator The address of the operator whose key is to be updated.
     * @param key The new key to associate with the operator.
     */
    function updateKey(address operator, bytes32 key) external onlyOwner {
        uint48 epoch = getCurrentEpoch();

        if (keyData[key].getAddress() != address(0)) {
            revert DuplicateKey();
        }

        if (keys[operator] != ZERO_BYTES32 && keyData[keys[operator]].enabledEpoch != epoch) {
            prevKeys[operator] = keys[operator];
        }

        keys[operator] = key;

        if (key != ZERO_BYTES32) {
            keyData[key].set(epoch, operator);
        }
    }
}
