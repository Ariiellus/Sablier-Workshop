// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {MerkleTreeGenerator} from "../src/AirdropCampaign.sol";
import {console2} from "forge-std/console2.sol";

/**
 * @title GenerateMerkleTree
 * @notice Script to generate a Merkle tree root for airdrop recipients
 * @dev Generates 1000 random addresses with random amounts totaling 4000e18 tokens
 *      Run: forge script script/GenerateMerkle.s.sol:GenerateMerkleTree -vvv
 *      Or use: make generate-merkle
 */
contract GenerateMerkleTree is Script {
    struct Recipient {
        uint256 index;
        address recipient;
        uint256 amount;
    }

    function run() public {
        uint256 recipientCount = 1000;
        uint256 totalAmount = 4000e18; // COMMUNITY_AMOUNT
        uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao)));
        
        console2.log("Generating", recipientCount, "random recipients...");
        
        // Generate random recipients
        Recipient[] memory recipients = new Recipient[](recipientCount);
        uint256 totalDistributed = 0;
        
        for (uint256 i = 0; i < recipientCount; i++) {
            // Generate random address from seed + index
            address randomAddress = address(uint160(uint256(keccak256(abi.encodePacked(seed, i)))));
            
            uint256 amount;
            
            // For the last recipient, adjust amount to ensure total equals exactly totalAmount
            if (i == recipientCount - 1) {
                // Last recipient gets the remainder to make total exactly 4000e18
                amount = totalAmount > totalDistributed ? totalAmount - totalDistributed : 1e18;
            } else {
                // Generate random amount between 1e18 and 10e18
                // Use a pseudo-random number based on seed and index
                uint256 randomValue = uint256(keccak256(abi.encodePacked(seed, i, "amount")));
                // Amount between 1e18 and 10e18
                amount = 1e18 + (randomValue % (9e18));
                
                // Ensure we don't exceed total for remaining recipients
                uint256 remaining = totalAmount - totalDistributed;
                uint256 minForRemaining = 1e18 * (recipientCount - i - 1); // Minimum for remaining recipients
                uint256 maxForThis = remaining > minForRemaining ? remaining - minForRemaining : 1e18;
                
                if (amount > maxForThis) {
                    amount = maxForThis > 1e18 ? maxForThis : 1e18;
                }
            }
            
            recipients[i] = Recipient({
                index: i,
                recipient: randomAddress,
                amount: amount
            });
            
            totalDistributed += amount;
        }
        
        console2.log("Total amount distributed:", totalDistributed / 1e18, "tokens");

        // Generate leaves
        console2.log("Generating Merkle leaves...");
        bytes32[] memory leaves = new bytes32[](recipients.length);
        for (uint256 i = 0; i < recipients.length; i++) {
            leaves[i] = MerkleTreeGenerator.generateLeaf(
                recipients[i].index,
                recipients[i].recipient,
                recipients[i].amount
            );
        }

        // Sort leaves (required for Merkle tree)
        console2.log("Sorting leaves...");
        sortLeaves(leaves);

        // Calculate root
        console2.log("Calculating Merkle root...");
        bytes32 root = calculateRoot(leaves);

        console2.log("=== Merkle Tree Generated ===");
        console2.log("Merkle Root:", vm.toString(root));
        console2.log("Recipient Count:", recipients.length);
        console2.log("\nSet these environment variables:");
        console2.log("export MERKLE_ROOT=", vm.toString(root));
        console2.log("export RECIPIENT_COUNT=", recipients.length);
    }

    function sortLeaves(bytes32[] memory leaves) internal pure {
        // Insertion sort - more efficient than bubble sort for larger arrays
        // Still O(n²) but better constant factors
        uint256 n = leaves.length;
        for (uint256 i = 1; i < n; i++) {
            bytes32 key = leaves[i];
            uint256 j = i;
            while (j > 0 && leaves[j - 1] > key) {
                leaves[j] = leaves[j - 1];
                j--;
            }
            leaves[j] = key;
        }
    }

    function calculateRoot(bytes32[] memory leaves) internal pure returns (bytes32) {
        if (leaves.length == 0) {
            revert("Empty leaves array");
        }
        
        if (leaves.length == 1) {
            return leaves[0];
        }

        // Build tree bottom-up
        bytes32[] memory currentLevel = leaves;
        
        while (currentLevel.length > 1) {
            bytes32[] memory nextLevel = new bytes32[]((currentLevel.length + 1) / 2);
            
            for (uint256 i = 0; i < currentLevel.length; i += 2) {
                if (i + 1 < currentLevel.length) {
                    bytes32 left = currentLevel[i];
                    bytes32 right = currentLevel[i + 1];
                    
                    // Hash in sorted order
                    if (left < right) {
                        nextLevel[i / 2] = keccak256(abi.encodePacked(left, right));
                    } else {
                        nextLevel[i / 2] = keccak256(abi.encodePacked(right, left));
                    }
                } else {
                    nextLevel[i / 2] = currentLevel[i];
                }
            }
            
            currentLevel = nextLevel;
        }
        
        return currentLevel[0];
    }
}
