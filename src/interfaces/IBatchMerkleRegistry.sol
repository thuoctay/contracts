// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

interface IBatchMerkleRegistry {
    error BatchVersionNotFound(string batchId, string version);
    error BatchVersionAlreadyExists(string batchId, string version);

    event MerkleRootSubmitted(string batchId, string version, bytes32 root);

    struct BatchSubmission {
        string batchId;
        string version;
        bytes32 root;
    }

    function submitBatchRoot(string calldata batchId, string calldata version, bytes32 root) external;

    function submitMultipleBatchRoots(BatchSubmission[] calldata submissions) external;

    function verifyLeaf(
        string calldata batchId,
        string calldata version,
        bytes32 leaf,
        bytes32[] calldata proof
    )
        external
        view
        returns (bool);

    function getRoot(string calldata batchId, string calldata version) external view returns (bytes32);

    function batchRoots(string calldata batchId, string calldata version) external view returns (bytes32);
}
