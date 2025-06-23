// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Test } from "forge-std/Test.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { IBatchMerkleRegistry } from "@src/interfaces/IBatchMerkleRegistry.sol";
import { BatchMerkleRegistryUpgradeable } from "@src/BatchMerkleRegistryUpgradeable.sol";

contract BatchMerkleRegistryTest is Test {
    BatchMerkleRegistryUpgradeable public registry;
    address public owner;
    address public user;
    address public unauthorized;

    string public constant BATCH_ID = "BATCH_001";
    string public constant VERSION = "2025-06-23";
    bytes32 public constant MERKLE_ROOT = 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        unauthorized = makeAddr("unauthorized");

        vm.startPrank(owner);
        address proxy = Upgrades.deployUUPSProxy(
            "BatchMerkleRegistryUpgradeable.sol", abi.encodeCall(BatchMerkleRegistryUpgradeable.initialize, (owner))
        );
        registry = BatchMerkleRegistryUpgradeable(proxy);
        vm.stopPrank();
    }

    function test_Initialization() public view {
        assertEq(registry.owner(), owner);
    }

    function test_SubmitBatchRoot() public {
        vm.startPrank(owner);
        registry.submitBatchRoot(BATCH_ID, VERSION, MERKLE_ROOT);
        vm.stopPrank();

        assertEq(registry.getRoot(BATCH_ID, VERSION), MERKLE_ROOT);
    }

    function test_SubmitBatchRootEmitsEvent() public {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IBatchMerkleRegistry.MerkleRootSubmitted(BATCH_ID, VERSION, MERKLE_ROOT);
        registry.submitBatchRoot(BATCH_ID, VERSION, MERKLE_ROOT);
        vm.stopPrank();
    }

    function test_OnlyOwnerCanSubmitBatchRoot() public {
        vm.startPrank(unauthorized);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", unauthorized));
        registry.submitBatchRoot(BATCH_ID, VERSION, MERKLE_ROOT);
        vm.stopPrank();
    }

    function test_GetRootReturnsZeroForNonExistentBatch() public view {
        assertEq(registry.getRoot("NON_EXISTENT", VERSION), bytes32(0));
    }

    function test_VerifyLeafWithValidProof() public {
        bytes32 leaf = keccak256(abi.encodePacked("test_data"));
        bytes32[] memory proof = new bytes32[](0); // An empty proof is valid when the leaf is the root
        bytes32 testRoot = leaf;

        vm.startPrank(owner);
        registry.submitBatchRoot(BATCH_ID, VERSION, testRoot);
        vm.stopPrank();

        bool isValid = registry.verifyLeaf(BATCH_ID, VERSION, leaf, proof);
        assertTrue(isValid, "Leaf verification should be valid when leaf is the root");
    }

    function test_VerifyLeafWithInvalidProof() public {
        vm.startPrank(owner);
        registry.submitBatchRoot(BATCH_ID, VERSION, MERKLE_ROOT);
        vm.stopPrank();

        bytes32 leaf = keccak256(abi.encodePacked("test_data"));
        bytes32[] memory invalidProof = new bytes32[](1);
        invalidProof[0] = bytes32(0x1111111111111111111111111111111111111111111111111111111111111111);

        bool isValid = registry.verifyLeaf(BATCH_ID, VERSION, leaf, invalidProof);
        assertFalse(isValid);
    }

    function test_VerifyLeafRevertsForNonExistentBatch() public {
        bytes32 leaf = keccak256(abi.encodePacked("test_data"));
        bytes32[] memory proof = new bytes32[](0);

        vm.expectRevert(
            abi.encodeWithSelector(IBatchMerkleRegistry.BatchVersionNotFound.selector, "NON_EXISTENT", VERSION)
        );
        registry.verifyLeaf("NON_EXISTENT", VERSION, leaf, proof);
    }

    function test_RevertOnUpdatingBatchRoot() public {
        vm.startPrank(owner);
        registry.submitBatchRoot(BATCH_ID, VERSION, MERKLE_ROOT);
        assertEq(registry.getRoot(BATCH_ID, VERSION), MERKLE_ROOT);

        bytes32 newRoot = 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890;
        vm.expectRevert(
            abi.encodeWithSelector(IBatchMerkleRegistry.BatchVersionAlreadyExists.selector, BATCH_ID, VERSION)
        );
        registry.submitBatchRoot(BATCH_ID, VERSION, newRoot);
        vm.stopPrank();
    }

    function test_MultipleBatchVersions() public {
        vm.startPrank(owner);

        registry.submitBatchRoot(BATCH_ID, VERSION, MERKLE_ROOT);
        registry.submitBatchRoot(
            BATCH_ID, "2025-06-24", 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
        );
        registry.submitBatchRoot(
            BATCH_ID, "2025-06-25", 0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321
        );

        vm.stopPrank();

        assertEq(registry.getRoot(BATCH_ID, VERSION), MERKLE_ROOT);
        assertEq(
            registry.getRoot(BATCH_ID, "2025-06-24"), 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
        );
        assertEq(
            registry.getRoot(BATCH_ID, "2025-06-25"), 0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321
        );
    }

    function test_MultipleBatches() public {
        vm.startPrank(owner);

        registry.submitBatchRoot(BATCH_ID, VERSION, MERKLE_ROOT);
        registry.submitBatchRoot(
            "BATCH_002", VERSION, 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
        );
        registry.submitBatchRoot(
            "BATCH_003", VERSION, 0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321
        );

        vm.stopPrank();

        assertEq(registry.getRoot(BATCH_ID, VERSION), MERKLE_ROOT);
        assertEq(
            registry.getRoot("BATCH_002", VERSION), 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
        );
        assertEq(
            registry.getRoot("BATCH_003", VERSION), 0xfedcba0987654321fedcba0987654321fedcba0987654321fedcba0987654321
        );
    }
}
