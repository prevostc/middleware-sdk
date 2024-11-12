// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IVault} from "@symbiotic/interfaces/vault/IVault.sol";
import {IBaseDelegator} from "@symbiotic/interfaces/delegator/IBaseDelegator.sol";
import {Subnetwork} from "@symbiotic/contracts/libraries/Subnetwork.sol";

import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {BaseMiddleware} from "../../middleware/BaseMiddleware.sol";
import {SharedVaults} from "../../middleware/extensions/SharedVaults.sol";
import {SelfRegisterOperators} from "../../middleware/extensions/SelfRegisterOperators.sol";

import {KeyStorage256} from "../../key-storage/KeyStorage256.sol";
import {Ed25519Sig} from "../../middleware/extensions/sigs/Ed25519Sig.sol";

contract SelfRegisterEd25519Middleware is SharedVaults, SelfRegisterOperators, KeyStorage256, Ed25519Sig {
    /*
     * @notice Constructor for initializing the SelfRegisterEd25519Middleware contract.
     * @param network The address of the network.
     * @param operatorRegistry The address of the operator registry.
     * @param vaultRegistry The address of the vault registry.
     * @param operatorNetOptin The address of the operator network opt-in service.
     * @param owner The address of the contract owner.
     * @param slashingWindow The duration of the slashing window
     */
    constructor(
        address network,
        address operatorRegistry,
        address vaultRegistry,
        address operatorNetOptin,
        address owner,
        uint48 slashingWindow
    ) BaseMiddleware(network, operatorRegistry, vaultRegistry, operatorNetOptin, slashingWindow, owner) {}
}
