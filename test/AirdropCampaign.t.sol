// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISablierFactoryMerkleInstant} from "@sablier/airdrops/src/interfaces/ISablierFactoryMerkleInstant.sol";
import {ISablierMerkleInstant} from "@sablier/airdrops/src/interfaces/ISablierMerkleInstant.sol";

import {ERC20} from "../src/TokenERC20.sol";
import {AirdropCampaign, MerkleTreeGenerator} from "../src/AirdropCampaign.sol";

contract AirdropCampaignTest is Test {
    // Sepolia Sablier address
    address constant SABLIER_FACTORY_MERKLE_INSTANT = 0x3633462151339dea950cBED2fd4d132Bd942b64b;

    ERC20 public token;
    AirdropCampaign public campaign;

    address public deployer;
    address public alice;
    address public bob;

    // Merkle tree data for 2 recipients
    bytes32 public merkleRoot;
    bytes32[] public aliceProof;
    bytes32[] public bobProof;

    function setUp() public {
        // Fork Sepolia
        string memory sepoliaRpc = vm.envOr("SEPOLIA_RPC_URL", string("https://rpc.sepolia.org"));
        vm.createSelectFork(sepoliaRpc);

        // Setup addresses
        deployer = makeAddr("deployer");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        // Build merkle tree for 2 recipients
        // Alice: index 0, 2500 tokens
        // Bob: index 1, 1500 tokens
        bytes32 aliceLeaf = MerkleTreeGenerator.generateLeaf(0, alice, 2500e18);
        bytes32 bobLeaf = MerkleTreeGenerator.generateLeaf(1, bob, 1500e18);

        // For a 2-leaf tree, the root is hash of both leaves sorted
        if (aliceLeaf < bobLeaf) {
            merkleRoot = keccak256(abi.encodePacked(aliceLeaf, bobLeaf));
            aliceProof = new bytes32[](1);
            aliceProof[0] = bobLeaf;
            bobProof = new bytes32[](1);
            bobProof[0] = aliceLeaf;
        } else {
            merkleRoot = keccak256(abi.encodePacked(bobLeaf, aliceLeaf));
            aliceProof = new bytes32[](1);
            aliceProof[0] = bobLeaf;
            bobProof = new bytes32[](1);
            bobProof[0] = aliceLeaf;
        }

        // Deploy contracts
        vm.startPrank(deployer);

        token = new ERC20("Workshop Token", "WSHP");
        token.mint(deployer, 10_000e18);

        campaign = new AirdropCampaign(
            ISablierFactoryMerkleInstant(SABLIER_FACTORY_MERKLE_INSTANT),
            IERC20(address(token))
        );

        vm.stopPrank();
    }

    function test_CampaignDeployment() public view {
        assertEq(address(campaign.SABLIER_FACTORY()), SABLIER_FACTORY_MERKLE_INSTANT);
        assertEq(address(campaign.TOKEN()), address(token));
        assertEq(campaign.COMMUNITY_AMOUNT(), 4000e18);
    }

    function test_CreateAirdrop() public {
        vm.startPrank(deployer);

        // Approve campaign to spend tokens
        token.approve(address(campaign), 4000e18);

        // Create airdrop
        ISablierMerkleInstant airdrop = campaign.createAirdrop(
            merkleRoot,
            2, // recipient count
            "Test Airdrop",
            "", // no IPFS CID
            90 // 90 days expiration
        );

        vm.stopPrank();

        // Verify airdrop was created
        assertFalse(address(airdrop) == address(0));
        assertEq(address(campaign.airdropCampaign()), address(airdrop));

        // Verify tokens were transferred
        assertEq(token.balanceOf(deployer), 6000e18); // 10000 - 4000
    }

    function test_AirdropExpiration() public {
        vm.startPrank(deployer);
        token.approve(address(campaign), 4000e18);

        campaign.createAirdrop(merkleRoot, 2, "Test Airdrop", "", 90);

        vm.stopPrank();

        // Check expiration is set correctly (~90 days from now)
        uint40 expiration = campaign.getExpiration();
        assertApproxEqAbs(expiration, uint40(block.timestamp + 90 days), 1);
    }

    function test_HasClaimedInitiallyFalse() public {
        vm.startPrank(deployer);
        token.approve(address(campaign), 4000e18);

        campaign.createAirdrop(merkleRoot, 2, "Test Airdrop", "", 90);

        vm.stopPrank();

        // No one has claimed yet
        assertFalse(campaign.hasClaimed(0));
        assertFalse(campaign.hasClaimed(1));
    }

    function test_HasClaimedBeforeAirdropCreated() public view {
        // Should return false when no airdrop exists
        assertFalse(campaign.hasClaimed(0));
    }

    function test_GetExpirationBeforeAirdropCreated() public view {
        // Should return 0 when no airdrop exists
        assertEq(campaign.getExpiration(), 0);
    }

    function test_CreateAirdropWithNoExpiration() public {
        vm.startPrank(deployer);
        token.approve(address(campaign), 4000e18);

        campaign.createAirdrop(merkleRoot, 2, "Test Airdrop", "", 0); // 0 = no expiration

        vm.stopPrank();

        assertEq(campaign.getExpiration(), 0);
    }

    function test_RevertWhenInsufficientApproval() public {
        vm.startPrank(deployer);

        // Approve less than required
        token.approve(address(campaign), 1000e18);

        vm.expectRevert();
        campaign.createAirdrop(merkleRoot, 2, "Test Airdrop", "", 90);

        vm.stopPrank();
    }

    function test_RevertWhenInsufficientBalance() public {
        address poorUser = makeAddr("poorUser");

        vm.startPrank(poorUser);

        // poorUser has no tokens
        vm.expectRevert();
        campaign.createAirdrop(merkleRoot, 2, "Test Airdrop", "", 90);

        vm.stopPrank();
    }

    function test_MerkleLeafGeneration() public view {
        bytes32 leaf = MerkleTreeGenerator.generateLeaf(0, alice, 2500e18);

        // Verify leaf is deterministic
        bytes32 expectedLeaf = keccak256(bytes.concat(keccak256(abi.encode(0, alice, 2500e18))));
        assertEq(leaf, expectedLeaf);
    }
}