// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

library Merkle {
    function efficientKeccak256(bytes32 a, bytes32 b) internal pure returns (bytes32 value) {
        assembly ("memory-safe") {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    function commutativeKeccak256(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return a < b ? efficientKeccak256(a, b) : efficientKeccak256(b, a);
    }

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
}
