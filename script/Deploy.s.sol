// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISablierLockup} from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import {ISablierBatchLockup} from "@sablier/lockup/src/interfaces/ISablierBatchLockup.sol";
import {ISablierFactoryMerkleInstant} from "@sablier/airdrops/src/interfaces/ISablierFactoryMerkleInstant.sol";

import {ERC20} from "../src/TokenERC20.sol";
import {TokenDistributor} from "../src/TokenDistributor.sol";
import {AirdropCampaign} from "../src/AirdropCampaign.sol";
import {console2} from "forge-std/console2.sol";

contract DeployWorkshop is Script {
    // Sepolia Testnet Addresses (Sablier v3.0)
    address constant SABLIER_LOCKUP_SEPOLIA = 0x6b0307b4338f2963A62106028E3B074C2c0510DA;
    address constant SABLIER_BATCH_LOCKUP_SEPOLIA = 0x44Fd5d5854833975E5Fc80666a10cF3376C088E0;
    address constant SABLIER_FACTORY_MERKLE_INSTANT_SEPOLIA = 0x3633462151339dea950cBED2fd4d132Bd942b64b;

    ERC20 public token;
    TokenDistributor public tokenDistributor;
    AirdropCampaign public airdropCampaign;

    function run() public {
        uint256 chainId = block.chainid;

        address sablierLockup;
        address sablierBatchLockup;
        address sablierFactoryMerkleInstant;

        address deployer = "DeployerPublicAddress";

        if (chainId == 11155111) {
            sablierLockup = SABLIER_LOCKUP_SEPOLIA;
            sablierBatchLockup = SABLIER_BATCH_LOCKUP_SEPOLIA;
            sablierFactoryMerkleInstant = SABLIER_FACTORY_MERKLE_INSTANT_SEPOLIA;
        } else {
            revert("Unsupported chain ID");
        }

        vm.startBroadcast();

        token = new ERC20("Workshop Token", "WSHP");
        token.mint(deployer, 10_000e18);

        tokenDistributor = new TokenDistributor(
            ISablierLockup(sablierLockup), ISablierBatchLockup(sablierBatchLockup), IERC20(address(token))
        );

        airdropCampaign =
            new AirdropCampaign(ISablierFactoryMerkleInstant(sablierFactoryMerkleInstant), IERC20(address(token)));

        vm.stopBroadcast();

        console2.log(address(token), address(tokenDistributor), address(airdropCampaign));
    }
}

contract CreateVestingStreams is Script {
    function run() public {
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address distributorAddress = vm.envAddress("DISTRIBUTOR_ADDRESS");
        address teamAddress = vm.envAddress("TEAM_ADDRESS");
        address investorAddress = vm.envAddress("INVESTOR_ADDRESS");
        address foundationAddress = vm.envAddress("FOUNDATION_ADDRESS");

        IERC20 token = IERC20(tokenAddress);
        TokenDistributor distributor = TokenDistributor(distributorAddress);

        vm.startBroadcast();
        token.approve(distributorAddress, 6000e18);
        uint256[] memory streamIds =
            distributor.createAllVestingStreams(teamAddress, investorAddress, foundationAddress);

        vm.stopBroadcast();

        console2.log(streamIds[0], streamIds[1], streamIds[2]);
    }
}

contract CreateAirdrop is Script {
    function run() public {
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address airdropCampaignAddress = vm.envAddress("AIRDROP_CAMPAIGN_ADDRESS");
        bytes32 merkleRoot = vm.envBytes32("MERKLE_ROOT");
        uint256 recipientCount = vm.envUint("RECIPIENT_COUNT");

        IERC20 token = IERC20(tokenAddress);
        AirdropCampaign campaign = AirdropCampaign(airdropCampaignAddress);

        vm.startBroadcast();

        token.approve(airdropCampaignAddress, 4000e18);
        address airdropAddress =
            address(campaign.createAirdrop(merkleRoot, recipientCount, "Community Airdrop", "", 90));

        vm.stopBroadcast();

        console2.log(airdropAddress);
    }
}
