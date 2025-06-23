// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract BatchMerkleRegistryUpgradeable is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    error BatchVersionNotFound(string batchId, string version);

    mapping(string batchId => mapping(string version => bytes32 root)) public batchRoots;

    event MerkleRootSubmitted(string batchId, string version, bytes32 root);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner) public initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function submitBatchRoot(string calldata batchId, string calldata version, bytes32 root) external onlyOwner {
        batchRoots[batchId][version] = root;
        emit MerkleRootSubmitted(batchId, version, root);
    }

    function verifyLeaf(
        string memory batchId,
        string memory version,
        bytes32 leaf,
        bytes32[] calldata proof
    )
        external
        view
        returns (bool)
    {
        bytes32 root = batchRoots[batchId][version];
        if (root == bytes32(0)) {
            revert BatchVersionNotFound(batchId, version);
        }

        return MerkleProof.verify(proof, root, leaf);
    }

    function getRoot(string memory batchId, string memory version) external view returns (bytes32) {
        return batchRoots[batchId][version];
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner { }
}
