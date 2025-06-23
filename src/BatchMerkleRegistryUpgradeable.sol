// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { IBatchMerkleRegistry } from "@src/interfaces/IBatchMerkleRegistry.sol";

contract BatchMerkleRegistryUpgradeable is Initializable, OwnableUpgradeable, UUPSUpgradeable, IBatchMerkleRegistry {
    mapping(string batchId => mapping(string version => bytes32 root)) public override batchRoots;
    // Do we need reverse mapping for batchId?

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function submitBatchRoot(
        string calldata batchId,
        string calldata version,
        bytes32 root
    )
        external
        override
        onlyOwner
    {
        _submitBatchRoot(batchId, version, root);
    }

    function submitMultipleBatchRoots(BatchSubmission[] calldata submissions) external override onlyOwner {
        uint256 len = submissions.length;
        for (uint256 i = 0; i < len; ++i) {
            BatchSubmission calldata submission = submissions[i];
            _submitBatchRoot(submission.batchId, submission.version, submission.root);
        }
    }

    function verifyLeaf(
        string calldata batchId,
        string calldata version,
        bytes32 leaf,
        bytes32[] calldata proof
    )
        external
        view
        override
        returns (bool)
    {
        bytes32 root = batchRoots[batchId][version];
        if (root == bytes32(0)) {
            revert BatchVersionNotFound(batchId, version);
        }

        return MerkleProof.verify(proof, root, leaf);
    }

    function getRoot(string calldata batchId, string calldata version) external view override returns (bytes32) {
        return batchRoots[batchId][version];
    }

    function _submitBatchRoot(string calldata batchId, string calldata version, bytes32 root) internal {
        if (batchRoots[batchId][version] != bytes32(0)) {
            revert BatchVersionAlreadyExists(batchId, version);
        }
        batchRoots[batchId][version] = root;
        emit MerkleRootSubmitted(batchId, version, root);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
