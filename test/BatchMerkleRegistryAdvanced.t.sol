// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Test } from "forge-std/Test.sol";
import { BatchMerkleRegistryUpgradeable } from "@src/BatchMerkleRegistryUpgradeable.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

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

    // OpenZeppelin-compatible efficientKeccak256
    function efficientKeccak256(bytes32 a, bytes32 b) internal pure returns (bytes32 value) {
        assembly ("memory-safe") {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    // OpenZeppelin-compatible commutativeKeccak256
    function commutativeKeccak256(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a);
    }

    // OpenZeppelin-compatible Merkle root computation
    function computeMerkleRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        if (leaves.length == 0) return bytes32(0);
        if (leaves.length == 1) return leaves[0];
        bytes32[] memory currentLevel = leaves;
        while (currentLevel.length > 1) {
            uint256 n = currentLevel.length;
            uint256 nextLen = (n + 1) / 2;
            bytes32[] memory nextLevel = new bytes32[](nextLen);
            for (uint256 i = 0; i < n; i += 2) {
                if (i + 1 < n) {
                    nextLevel[i / 2] = commutativeKeccak256(currentLevel[i], currentLevel[i + 1]);
                } else {
                    nextLevel[i / 2] = currentLevel[i];
                }
            }
            currentLevel = nextLevel;
        }
        return currentLevel[0];
    }

    // OpenZeppelin-compatible Merkle proof generation
    function generateMerkleProof(bytes32[] memory leaves, uint256 leafIndex) internal pure returns (bytes32[] memory) {
        require(leafIndex < leaves.length, "Leaf index out of bounds");
        if (leaves.length == 1) return new bytes32[](0);
        bytes32[] memory proof = new bytes32[](leaves.length - 1); // max possible size
        uint256 proofPos = 0;
        uint256 idx = leafIndex;
        bytes32[] memory currentLevel = leaves;
        while (currentLevel.length > 1) {
            uint256 n = currentLevel.length;
            uint256 nextLen = (n + 1) / 2;
            bytes32[] memory nextLevel = new bytes32[](nextLen);
            for (uint256 i = 0; i < n; i += 2) {
                if (i + 1 < n) {
                    nextLevel[i / 2] = commutativeKeccak256(currentLevel[i], currentLevel[i + 1]);
                } else {
                    nextLevel[i / 2] = currentLevel[i];
                }
            }
            // Add sibling to proof if exists
            uint256 pairIndex = idx ^ 1;
            if (pairIndex < n) {
                proof[proofPos++] = currentLevel[pairIndex];
            }
            idx /= 2;
            currentLevel = nextLevel;
        }
        // Resize proof array to actual size
        bytes32[] memory trimmed = new bytes32[](proofPos);
        for (uint256 i = 0; i < proofPos; i++) {
            trimmed[i] = proof[i];
        }
        return trimmed;
    }

    function test_RealMerkleTreeVerification() public {
        // Create test data - pharmaceutical batch data
        string[] memory batchData = new string[](4);
        batchData[0] = "Medicine_A_Lot_001_Exp_2024";
        batchData[1] = "Medicine_B_Lot_002_Exp_2025";
        batchData[2] = "Medicine_C_Lot_003_Exp_2024";
        batchData[3] = "Medicine_D_Lot_004_Exp_2026";

        // Convert to leaves
        bytes32[] memory leaves = new bytes32[](4);
        for (uint256 i = 0; i < batchData.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(batchData[i]));
        }

        // Compute Merkle root
        bytes32 merkleRoot = computeMerkleRoot(leaves);

        // Submit root to registry
        vm.startPrank(owner);
        registry.submitBatchRoot("PHARMA_BATCH_001", "2025-06-23", merkleRoot);
        vm.stopPrank();

        // Verify each leaf with its proof
        for (uint256 i = 0; i < leaves.length; i++) {
            bytes32[] memory proof = generateMerkleProof(leaves, i);
            bool isValid = registry.verifyLeaf("PHARMA_BATCH_001", "2025-06-23", leaves[i], proof);
            assertTrue(isValid, string.concat("Leaf ", vm.toString(i), " verification failed"));
        }
    }

    function test_MerkleTreeWithOddNumberOfLeaves() public {
        // Test with odd number of leaves
        string[] memory batchData = new string[](3);
        batchData[0] = "Product_X_Lot_001";
        batchData[1] = "Product_Y_Lot_002";
        batchData[2] = "Product_Z_Lot_003";

        bytes32[] memory leaves = new bytes32[](3);
        for (uint256 i = 0; i < batchData.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(batchData[i]));
        }

        bytes32 merkleRoot = computeMerkleRoot(leaves);

        vm.startPrank(owner);
        registry.submitBatchRoot("BATCH_ODD", "2025-06-23", merkleRoot);
        vm.stopPrank();

        // Verify each leaf
        for (uint256 i = 0; i < leaves.length; i++) {
            bytes32[] memory proof = generateMerkleProof(leaves, i);
            bool isValid = registry.verifyLeaf("BATCH_ODD", "2025-06-23", leaves[i], proof);
            assertTrue(isValid, string.concat("Odd leaf ", vm.toString(i), " verification failed"));
        }
    }

    function test_MerkleTreeWithSingleLeaf() public {
        // Test with single leaf
        string memory batchData = "Single_Product_Lot_001";
        bytes32 leaf = keccak256(abi.encodePacked(batchData));

        bytes32[] memory leaves = new bytes32[](1);
        leaves[0] = leaf;

        bytes32 merkleRoot = computeMerkleRoot(leaves);

        vm.startPrank(owner);
        registry.submitBatchRoot("BATCH_SINGLE", "2025-06-23", merkleRoot);
        vm.stopPrank();

        bytes32[] memory proof = generateMerkleProof(leaves, 0);
        bool isValid = registry.verifyLeaf("BATCH_SINGLE", "2025-06-23", leaf, proof);
        assertTrue(isValid, "Single leaf verification failed");
    }

    function test_InvalidLeafRejection() public {
        // Create valid Merkle tree
        string[] memory batchData = new string[](2);
        batchData[0] = "Valid_Product_1";
        batchData[1] = "Valid_Product_2";

        bytes32[] memory leaves = new bytes32[](2);
        for (uint256 i = 0; i < batchData.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(batchData[i]));
        }

        bytes32 merkleRoot = computeMerkleRoot(leaves);

        vm.startPrank(owner);
        registry.submitBatchRoot("BATCH_VALID", "2025-06-23", merkleRoot);
        vm.stopPrank();

        // Try to verify invalid leaf
        bytes32 invalidLeaf = keccak256(abi.encodePacked("Invalid_Product"));
        bytes32[] memory proof = generateMerkleProof(leaves, 0); // Use proof for first leaf

        bool isValid = registry.verifyLeaf("BATCH_VALID", "2025-06-23", invalidLeaf, proof);
        assertFalse(isValid, "Invalid leaf should be rejected");
    }

    function test_BatchVersioning() public {
        // Create initial batch
        string[] memory initialData = new string[](2);
        initialData[0] = "Product_A_v1";
        initialData[1] = "Product_B_v1";

        bytes32[] memory initialLeaves = new bytes32[](2);
        for (uint256 i = 0; i < initialData.length; i++) {
            initialLeaves[i] = keccak256(abi.encodePacked(initialData[i]));
        }

        bytes32 initialRoot = computeMerkleRoot(initialLeaves);

        vm.startPrank(owner);
        registry.submitBatchRoot("BATCH_VERSIONED", "2025-06-23", initialRoot);
        vm.stopPrank();

        // Create updated batch (2025-06-24)
        string[] memory updatedData = new string[](3);
        updatedData[0] = "Product_A_v2";
        updatedData[1] = "Product_B_v2";
        updatedData[2] = "Product_C_v2";

        bytes32[] memory updatedLeaves = new bytes32[](3);
        for (uint256 i = 0; i < updatedData.length; i++) {
            updatedLeaves[i] = keccak256(abi.encodePacked(updatedData[i]));
        }

        bytes32 updatedRoot = computeMerkleRoot(updatedLeaves);

        vm.startPrank(owner);
        registry.submitBatchRoot("BATCH_VERSIONED", "2025-06-24", updatedRoot);
        vm.stopPrank();

        // Verify both versions work independently
        for (uint256 i = 0; i < initialLeaves.length; i++) {
            bytes32[] memory proof = generateMerkleProof(initialLeaves, i);
            bool isValidV1 = registry.verifyLeaf("BATCH_VERSIONED", "2025-06-23", initialLeaves[i], proof);
            assertTrue(isValidV1, string.concat("2025-06-23 leaf ", vm.toString(i), " verification failed"));
        }

        for (uint256 i = 0; i < updatedLeaves.length; i++) {
            bytes32[] memory proof = generateMerkleProof(updatedLeaves, i);
            bool isValidV2 = registry.verifyLeaf("BATCH_VERSIONED", "2025-06-24", updatedLeaves[i], proof);
            assertTrue(isValidV2, string.concat("2025-06-24 leaf ", vm.toString(i), " verification failed"));
        }

        // Verify that 2025-06-23 leaves don't work with 2025-06-24
        bytes32[] memory v1Proof = generateMerkleProof(initialLeaves, 0);
        bool isValidCrossVersion = registry.verifyLeaf("BATCH_VERSIONED", "2025-06-24", initialLeaves[0], v1Proof);
        assertFalse(isValidCrossVersion, "2025-06-23 leaf should not work with 2025-06-24 root");
    }
}
