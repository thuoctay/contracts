// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { console2 } from "forge-std/console2.sol";
import { Script } from "forge-std/Script.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { BatchMerkleRegistryUpgradeable } from "@src/BatchMerkleRegistryUpgradeable.sol";

contract DeployBatchMerkleRegistry is Script {
    address public batchMerkleRegistry;

    function deploy() public returns (address) {
        vm.startBroadcast();

        batchMerkleRegistry = Upgrades.deployUUPSProxy(
            "BatchMerkleRegistryUpgradeable.sol",
            abi.encodeCall(BatchMerkleRegistryUpgradeable.initialize, (msg.sender))
        );

        vm.stopBroadcast();

        address implementationAddress = Upgrades.getImplementationAddress(batchMerkleRegistry);

        console2.log("BatchMerkleRegistry deployed at:", batchMerkleRegistry);
        console2.log("Implementation deployed at:", implementationAddress);

        return batchMerkleRegistry;
    }

    function submitSampleRoot() public {
        vm.startBroadcast();

        // Example: Submit a sample Merkle root for testing
        string memory batchId = "BATCH-0001";
        string memory version = "2025-06-23";
        bytes32 sampleRoot = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

        BatchMerkleRegistryUpgradeable(batchMerkleRegistry).submitBatchRoot(batchId, version, sampleRoot);

        vm.stopBroadcast();

        console2.log("Submitted sample root for batch:", batchId, "version:", version);
    }

    function run() public {
        deploy();
        submitSampleRoot();
    }
}
