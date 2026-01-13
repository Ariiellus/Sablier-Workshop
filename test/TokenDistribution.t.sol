// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISablierLockup} from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import {ISablierBatchLockup} from "@sablier/lockup/src/interfaces/ISablierBatchLockup.sol";
import {Lockup} from "@sablier/lockup/src/types/Lockup.sol";

import {ERC20} from "../src/TokenERC20.sol";
import {TokenDistributor} from "../src/TokenDistributor.sol";

/// @title TokenDistributionTest
/// @notice Tests for the Sablier Workshop token distribution
contract TokenDistributionTest is Test {

    // Sepolia Sablier addresses
    address constant SABLIER_LOCKUP = 0x6b0307b4338f2963A62106028E3B074C2c0510DA;
    address constant SABLIER_BATCH_LOCKUP = 0x44Fd5d5854833975E5Fc80666a10cF3376C088E0;

    ERC20 public token;
    TokenDistributor public distributor;

    address public deployer;
    address public team;
    address public investor;
    address public foundation;

    function setUp() public {
        // Fork Sepolia
        string memory sepoliaRpc = vm.envOr("SEPOLIA_RPC_URL", string("https://rpc.sepolia.org"));
        vm.createSelectFork(sepoliaRpc);

        // Setup addresses
        deployer = makeAddr("deployer");
        team = makeAddr("team");
        investor = makeAddr("investor");
        foundation = makeAddr("foundation");

        // Deploy contracts
        vm.startPrank(deployer);

        // Deploy token
        token = new ERC20("Workshop Token", "WSHP");
        token.mint(deployer, 10_000e18);

        // Deploy distributor
        distributor = new TokenDistributor(
            ISablierLockup(SABLIER_LOCKUP), ISablierBatchLockup(SABLIER_BATCH_LOCKUP), IERC20(address(token))
        );

        vm.stopPrank();
    }

    function test_TokenDeployment() public view {
        assertEq(token.name(), "Workshop Token");
        assertEq(token.symbol(), "WSHP");
        assertEq(token.totalSupply(), 10_000e18);
        assertEq(token.balanceOf(deployer), 10_000e18);
    }

    function test_DistributorDeployment() public view {
        assertEq(address(distributor.SABLIER_LOCKUP()), SABLIER_LOCKUP);
        assertEq(address(distributor.SABLIER_BATCH_LOCKUP()), SABLIER_BATCH_LOCKUP);
        assertEq(address(distributor.TOKEN()), address(token));
    }

    function test_CreateSingleStream() public {
        uint128 amount = 1000e18;
        uint40 cliffDuration = 180 days; // 6 months
        uint40 totalDuration = 365 days; // 1 year

        vm.startPrank(deployer);

        // Approve and create stream
        token.approve(address(distributor), amount);
        uint256 streamId = distributor.createSingleStream(team, amount, cliffDuration, totalDuration);

        vm.stopPrank();

        // Verify stream was created
        assertGt(streamId, 0);

        // Check stream status
        Lockup.Status status = distributor.getStreamStatus(streamId);
        assertEq(uint8(status), uint8(Lockup.Status.STREAMING));

        // Initially no withdrawable amount (before cliff)
        uint128 withdrawable = distributor.getWithdrawableAmount(streamId);
        assertEq(withdrawable, 0);
    }

    function test_CreateAllVestingStreams() public {
        vm.startPrank(deployer);

        // Approve total lockup amount (6000 tokens)
        token.approve(address(distributor), 6000e18);

        // Create all streams
        uint256[] memory streamIds = distributor.createAllVestingStreams(team, investor, foundation);

        vm.stopPrank();

        // Verify 3 streams were created
        assertEq(streamIds.length, 3);

        // Verify stream IDs were stored
        assertEq(distributor.teamStreamId(), streamIds[0]);
        assertEq(distributor.investorStreamId(), streamIds[1]);
        assertEq(distributor.foundationStreamId(), streamIds[2]);

        // All streams should be in STREAMING status
        for (uint256 i = 0; i < 3; i++) {
            Lockup.Status status = distributor.getStreamStatus(streamIds[i]);
            assertEq(uint8(status), uint8(Lockup.Status.STREAMING));
        }

        // Token balance should be reduced
        assertEq(token.balanceOf(deployer), 4000e18); // 10000 - 6000
    }

    function test_StreamVesting() public {
        // Create foundation stream (no cliff, 3 year vesting)
        uint128 amount = 3000e18;

        vm.startPrank(deployer);
        token.approve(address(distributor), amount);

        // Use single stream with no cliff
        uint256 streamId = distributor.createSingleStream(
            foundation,
            amount,
            0, // No cliff
            3 * 365 days // 3 years total
        );
        vm.stopPrank();

        // Fast forward 1 year (1/3 of vesting)
        vm.warp(block.timestamp + 365 days);

        uint128 withdrawable = distributor.getWithdrawableAmount(streamId);
        assertApproxEqRel(withdrawable, 1000e18, 0.01e18);
    }

    function test_DistributionAmounts() public view {
        // Verify distribution matches the chart
        assertEq(distributor.TEAM_AMOUNT(), 1000e18);
        assertEq(distributor.INVESTOR_AMOUNT(), 2000e18);
        assertEq(distributor.FOUNDATION_AMOUNT(), 3000e18);
        assertEq(distributor.TOTAL_LOCKUP_AMOUNT(), 6000e18);

        // Verify percentages
        uint256 totalSupply = 10_000e18;
        assertEq(distributor.TEAM_AMOUNT() * 100 / totalSupply, 10); // 10%
        assertEq(distributor.INVESTOR_AMOUNT() * 100 / totalSupply, 20); // 20%
        assertEq(distributor.FOUNDATION_AMOUNT() * 100 / totalSupply, 30); // 30%
    }

    function test_RevertWhenInsufficientApproval() public {
        vm.startPrank(deployer);
        token.approve(address(distributor), 100e18);
        vm.expectRevert();
        distributor.createAllVestingStreams(team, investor, foundation);

        vm.stopPrank();
    }
}
