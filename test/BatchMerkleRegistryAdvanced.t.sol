// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Test } from "forge-std/Test.sol";
import { IBatchMerkleRegistry } from "@src/interfaces/IBatchMerkleRegistry.sol";
import { BatchMerkleRegistryUpgradeable } from "@src/BatchMerkleRegistryUpgradeable.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Merkle } from "./Merkle.sol";

contract BatchMerkleRegistryAdvancedTest is Test {
    BatchMerkleRegistryUpgradeable public registry;
    address public owner;

    function setUp() public {
        owner = makeAddr("owner");

        vm.startPrank(owner);
        address proxy = Upgrades.deployUUPSProxy(
            "BatchMerkleRegistryUpgradeable.sol", abi.encodeCall(BatchMerkleRegistryUpgradeable.initialize, (owner))
        );
        registry = BatchMerkleRegistryUpgradeable(proxy);
        vm.stopPrank();
    }

    function test_RealMerkleTreeVerification() public {
        string[] memory batchData = new string[](4);
        batchData[0] = "Medicine_A_Lot_001_Exp_2024";
        batchData[1] = "Medicine_B_Lot_002_Exp_2025";
        batchData[2] = "Medicine_C_Lot_003_Exp_2024";
        batchData[3] = "Medicine_D_Lot_004_Exp_2026";

        bytes32[] memory leaves = new bytes32[](4);
        for (uint256 i = 0; i < batchData.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(batchData[i]));
        }

        bytes32 merkleRoot = Merkle.computeMerkleRoot(leaves);

        vm.startPrank(owner);
        registry.submitBatchRoot("PHARMA_BATCH_001", "2025-06-23", merkleRoot);
        vm.stopPrank();

        for (uint256 i = 0; i < leaves.length; i++) {
            bytes32[] memory proof = Merkle.generateMerkleProof(leaves, i);
            bool isValid = registry.verifyLeaf("PHARMA_BATCH_001", "2025-06-23", leaves[i], proof);
            assertTrue(isValid, string.concat("Leaf ", vm.toString(i), " verification failed"));
        }
    }

    function test_MerkleTreeWithOddNumberOfLeaves() public {
        string[] memory batchData = new string[](3);
        batchData[0] = "Product_X_Lot_001";
        batchData[1] = "Product_Y_Lot_002";
        batchData[2] = "Product_Z_Lot_003";

        bytes32[] memory leaves = new bytes32[](3);
        for (uint256 i = 0; i < batchData.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(batchData[i]));
        }

        bytes32 merkleRoot = Merkle.computeMerkleRoot(leaves);

        vm.startPrank(owner);
        registry.submitBatchRoot("BATCH_ODD", "2025-06-23", merkleRoot);
        vm.stopPrank();

        for (uint256 i = 0; i < leaves.length; i++) {
            bytes32[] memory proof = Merkle.generateMerkleProof(leaves, i);
            bool isValid = registry.verifyLeaf("BATCH_ODD", "2025-06-23", leaves[i], proof);
            assertTrue(isValid, string.concat("Odd leaf ", vm.toString(i), " verification failed"));
        }
    }

    function test_MerkleTreeWithSingleLeaf() public {
        string memory batchData = "Single_Product_Lot_001";
        bytes32 leaf = keccak256(abi.encodePacked(batchData));

        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;

        bytes32 merkleRoot = Merkle.computeMerkleRoot(leaves);

        vm.startPrank(owner);
        registry.submitBatchRoot("BATCH_SINGLE", "2025-06-23", merkleRoot);
        vm.stopPrank();

        bytes32[] memory proof = Merkle.generateMerkleProof(leaves, 0);
        bool isValid = registry.verifyLeaf("BATCH_SINGLE", "2025-06-23", leaf, proof);
        assertTrue(isValid, "Single leaf verification failed");
    }

    function test_InvalidLeafRejection() public {
        string[] memory batchData = new string[](2);
        batchData[0] = "Valid_Product_1";
        batchData[1] = "Valid_Product_2";

        bytes32[] memory leaves = new bytes32[](2);
        for (uint256 i = 0; i < batchData.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(batchData[i]));
        }

        bytes32 merkleRoot = Merkle.computeMerkleRoot(leaves);

        vm.startPrank(owner);
        registry.submitBatchRoot("BATCH_VALID", "2025-06-23", merkleRoot);
        vm.stopPrank();

        bytes32 invalidLeaf = keccak256(abi.encodePacked("Invalid_Product"));
        bytes32[] memory proof = Merkle.generateMerkleProof(leaves, 0);

        bool isValid = registry.verifyLeaf("BATCH_VALID", "2025-06-23", invalidLeaf, proof);
        assertFalse(isValid, "Invalid leaf should be rejected");
    }

    function test_BatchVersioning() public {
        string[] memory initialData = new string[](2);
        initialData[0] = "Product_A_v1";
        initialData[1] = "Product_B_v1";

        bytes32[] memory initialLeaves = new bytes32[](2);
        for (uint256 i = 0; i < initialData.length; i++) {
            initialLeaves[i] = keccak256(abi.encodePacked(initialData[i]));
        }

        bytes32 initialRoot = Merkle.computeMerkleRoot(initialLeaves);

        vm.startPrank(owner);
        registry.submitBatchRoot("BATCH_VERSIONED", "2025-06-23", initialRoot);
        vm.stopPrank();

        string[] memory updatedData = new string[](3);
        updatedData[0] = "Product_A_v2";
        updatedData[1] = "Product_B_v2";
        updatedData[2] = "Product_C_v2";

        bytes32[] memory updatedLeaves = new bytes32[](3);
        for (uint256 i = 0; i < updatedData.length; i++) {
            updatedLeaves[i] = keccak256(abi.encodePacked(updatedData[i]));
        }

        bytes32 updatedRoot = Merkle.computeMerkleRoot(updatedLeaves);

        vm.startPrank(owner);
        registry.submitBatchRoot("BATCH_VERSIONED", "2025-06-24", updatedRoot);
        vm.stopPrank();

        for (uint256 i = 0; i < initialLeaves.length; i++) {
            bytes32[] memory proof = Merkle.generateMerkleProof(initialLeaves, i);
            bool isValidV1 = registry.verifyLeaf("BATCH_VERSIONED", "2025-06-23", initialLeaves[i], proof);
            assertTrue(isValidV1, string.concat("2025-06-23 leaf ", vm.toString(i), " verification failed"));
        }

        for (uint256 i = 0; i < updatedLeaves.length; i++) {
            bytes32[] memory proof = Merkle.generateMerkleProof(updatedLeaves, i);
            bool isValidV2 = registry.verifyLeaf("BATCH_VERSIONED", "2025-06-24", updatedLeaves[i], proof);
            assertTrue(isValidV2, string.concat("2025-06-24 leaf ", vm.toString(i), " verification failed"));
        }

        bytes32[] memory v1Proof = Merkle.generateMerkleProof(initialLeaves, 0);
        bool isValidCrossVersion = registry.verifyLeaf("BATCH_VERSIONED", "2025-06-24", initialLeaves[0], v1Proof);
        assertFalse(isValidCrossVersion, "2025-06-23 leaf should not work with 2025-06-24 root");
    }

    function test_SubmitMultipleBatchRoots() public {
        IBatchMerkleRegistry.BatchSubmission[] memory submissions = new IBatchMerkleRegistry.BatchSubmission[](3);

        bytes32 root1 = keccak256(abi.encodePacked("root1"));
        submissions[0] =
            IBatchMerkleRegistry.BatchSubmission({ batchId: "BATCH_A", version: "2025-06-23", root: root1 });

        bytes32 root2 = keccak256(abi.encodePacked("root2"));
        submissions[1] =
            IBatchMerkleRegistry.BatchSubmission({ batchId: "BATCH_B", version: "2025-06-23", root: root2 });

        bytes32 root3 = keccak256(abi.encodePacked("root3"));
        submissions[2] =
            IBatchMerkleRegistry.BatchSubmission({ batchId: "BATCH_A", version: "2025-06-24", root: root3 });

        vm.expectEmit(true, true, true, true);
        emit IBatchMerkleRegistry.MerkleRootSubmitted("BATCH_A", "2025-06-23", root1);
        vm.expectEmit(true, true, true, true);
        emit IBatchMerkleRegistry.MerkleRootSubmitted("BATCH_B", "2025-06-23", root2);
        vm.expectEmit(true, true, true, true);
        emit IBatchMerkleRegistry.MerkleRootSubmitted("BATCH_A", "2025-06-24", root3);

        vm.startPrank(owner);
        registry.submitMultipleBatchRoots(submissions);
        vm.stopPrank();

        assertEq(registry.getRoot("BATCH_A", "2025-06-23"), root1, "Root for BATCH_A 2025-06-23 is incorrect");
        assertEq(registry.getRoot("BATCH_B", "2025-06-23"), root2, "Root for BATCH_B v2.0 is incorrect");
        assertEq(registry.getRoot("BATCH_A", "2025-06-24"), root3, "Root for BATCH_A v1.1 is incorrect");
    }

    function test_RevertWhenNotOwner_SubmitMultipleBatchRoots() public {
        IBatchMerkleRegistry.BatchSubmission[] memory submissions = new IBatchMerkleRegistry.BatchSubmission[](1);
        submissions[0] = IBatchMerkleRegistry.BatchSubmission({
            batchId: "BATCH_C",
            version: "3.0",
            root: keccak256(abi.encodePacked("root4"))
        });

        address notOwner = makeAddr("notOwner");
        vm.startPrank(notOwner);
        bytes4 expectedError = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(expectedError, notOwner));
        registry.submitMultipleBatchRoots(submissions);
        vm.stopPrank();
    }
}
