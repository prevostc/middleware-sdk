// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {IVault} from "@symbiotic/interfaces/vault/IVault.sol";
import {IBaseDelegator} from "@symbiotic/interfaces/delegator/IBaseDelegator.sol";
import {IRegistry} from "@symbiotic/interfaces/common/IRegistry.sol";
import {IEntity} from "@symbiotic/interfaces/common/IEntity.sol";
import {IVetoSlasher} from "@symbiotic/interfaces/slasher/IVetoSlasher.sol";
import {Subnetwork} from "@symbiotic/contracts/libraries/Subnetwork.sol";
import {ISlasher} from "@symbiotic/interfaces/slasher/ISlasher.sol";
import {IVetoSlasher} from "@symbiotic/interfaces/slasher/IVetoSlasher.sol";

import {Time} from "@openzeppelin/contracts/utils/types/Time.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {MiddlewareStorage} from "./MiddlewareStorage.sol";
import {ArrayWithTimes} from "./libraries/ArrayWithTimes.sol";

abstract contract VaultManager is MiddlewareStorage {
    using ArrayWithTimes for ArrayWithTimes.AddressArray;
    using Subnetwork for address;

    error NotVault();
    error VaultNotRegistered();
    error VaultAlreadyRegistred();
    error VaultEpochTooShort();

    error TooOldEpoch();
    error InvalidEpoch();

    error InvalidSubnetworksCnt();

    error UnknownSlasherType();

    ArrayWithTimes.AddressArray internal sharedVaults;
    mapping(address => ArrayWithTimes.AddressArray) internal operatorVaults;

    function activeVaults(address operator, uint48 timestamp) public view returns (address[] memory) {
        address[] memory activeSharedVaults = sharedVaults.getActive(timestamp);
        address[] memory activeOperatorVaults = operatorVaults[operator].getActive(timestamp);

        uint256 activeSharedVaultsLen = activeSharedVaults.length;
        address[] memory vaults = new address[](activeSharedVaultsLen + activeOperatorVaults.length);
        for (uint256 i; i < activeSharedVaultsLen; ++i) {
            vaults[i] = activeSharedVaults[i];
        }
        for (uint256 i; i < activeOperatorVaults.length; ++i) {
            vaults[activeSharedVaultsLen + i] = activeOperatorVaults[i];
        }

        return vaults;
    }

    function registerSharedVault(address vault) external onlyOwner {
        _validateVault(vault);
        sharedVaults.register(vault);
    }

    function registerOperatorVault(address vault, address operator) external onlyOwner {
        _validateVault(vault);
        operatorVaults[operator].register(vault);
    }

    function pauseSharedVault(address vault) external onlyOwner {
        sharedVaults.pause(vault);
    }

    function unpauseSharedVault(address vault) external onlyOwner {
        sharedVaults.unpause(vault, SLASHING_WINDOW);
    }

    function pauseOperatorVault(address operator, address vault) external onlyOwner {
        operatorVaults[operator].pause(vault);
    }

    function unpauseOperatorVault(address operator, address vault) external onlyOwner {
        operatorVaults[operator].unpause(vault, SLASHING_WINDOW);
    }

    function unregisterSharedVault(address vault) external onlyOwner {
        sharedVaults.unregister(vault, SLASHING_WINDOW);
    }

    function unregisterOperatorVault(address operator, address vault) external onlyOwner {
        operatorVaults[operator].unregister(vault, SLASHING_WINDOW);
    }

    function getOperatorStake(address operator, uint48 timestamp) public view returns (uint256 stake) {
        address[] memory vaults = activeVaults(operator, timestamp);

        for (uint256 i; i < vaults.length; ++i) {
            address vault = vaults[i];
            for (uint96 subnet = 0; subnet < subnetworks; ++subnet) {
                bytes32 subnetwork = NETWORK.subnetwork(subnet);
                stake += IBaseDelegator(IVault(vault).delegator()).stakeAt(subnetwork, operator, timestamp, "");
            }
        }

        return stake;
    }

    function calcTotalStake(uint48 timestamp, address[] memory operators) external view returns (uint256 totalStake) {
        if (timestamp < Time.timestamp() - SLASHING_WINDOW) {
            revert TooOldEpoch();
        }

        if (timestamp > Time.timestamp()) {
            revert InvalidEpoch();
        }

        for (uint256 i; i < operators.length; ++i) {
            uint256 operatorStake = getOperatorStake(operators[i], timestamp);
            totalStake += operatorStake;
        }

        return totalStake;
    }

    function slashVault(uint48 timestamp, address vault, bytes32 subnetwork, address operator, uint256 amount)
        internal
    {
        address slasher = IVault(vault).slasher();
        uint256 slasherType = IEntity(slasher).TYPE();
        if (slasherType == INSTANT_SLASHER_TYPE) {
            ISlasher(slasher).slash(subnetwork, operator, amount, timestamp, new bytes(0));
        } else if (slasherType == VETO_SLASHER_TYPE) {
            IVetoSlasher(slasher).requestSlash(subnetwork, operator, amount, timestamp, new bytes(0));
        } else {
            revert UnknownSlasherType();
        }
    }

    function _validateVault(address vault) private view {
        if (!IRegistry(VAULT_REGISTRY).isEntity(vault)) {
            revert NotVault();
        }

        uint48 vaultEpoch = IVault(vault).epochDuration();

        address slasher = IVault(vault).slasher();
        if (slasher != address(0) && IEntity(slasher).TYPE() == VETO_SLASHER_TYPE) {
            vaultEpoch -= IVetoSlasher(slasher).vetoDuration();
        }

        if (vaultEpoch < SLASHING_WINDOW) {
            revert VaultEpochTooShort();
        }
    }
}
