// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISablierLockup} from "@sablier/lockup/src/interfaces/ISablierLockup.sol";
import {ISablierBatchLockup} from "@sablier/lockup/src/interfaces/ISablierBatchLockup.sol";
import {Lockup} from "@sablier/lockup/src/types/Lockup.sol";
import {LockupLinear} from "@sablier/lockup/src/types/LockupLinear.sol";
import {BatchLockup} from "@sablier/lockup/src/types/BatchLockup.sol";

/// @title TokenDistributor
/// @notice Workshop contract for distributing tokens using Sablier Lockup streams
contract TokenDistributor {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    uint128 public constant TEAM_AMOUNT = 1000e18; // 10% - 1000 tokens
    uint128 public constant INVESTOR_AMOUNT = 2000e18; // 20% - 2000 tokens
    uint128 public constant FOUNDATION_AMOUNT = 3000e18; // 30% - 3000 tokens
    uint128 public constant TOTAL_LOCKUP_AMOUNT = 6000e18; // 60% total for lockup

    /*//////////////////////////////////////////////////////////////////////////
                                   STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    ISablierLockup public immutable SABLIER_LOCKUP;
    ISablierBatchLockup public immutable SABLIER_BATCH_LOCKUP;
    IERC20 public immutable TOKEN;
    uint256 public teamStreamId;
    uint256 public investorStreamId;
    uint256 public foundationStreamId;

    /*//////////////////////////////////////////////////////////////////////////
                                   EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event StreamsCreated(
        uint256 indexed teamStreamId, uint256 indexed investorStreamId, uint256 indexed foundationStreamId
    );

    /*//////////////////////////////////////////////////////////////////////////
                                  CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(ISablierLockup _sablierLockup, ISablierBatchLockup _sablierBatchLockup, IERC20 _token) {
        SABLIER_LOCKUP = _sablierLockup;
        SABLIER_BATCH_LOCKUP = _sablierBatchLockup;
        TOKEN = _token;
    }

    /*//////////////////////////////////////////////////////////////////////////
                              PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function createSingleStream(address recipient, uint128 amount, uint40 cliffDuration, uint40 totalDuration)
        external
        returns (uint256 streamId)
    {
        // Transfer tokens from sender to this contract
        TOKEN.transferFrom(msg.sender, address(this), amount);

        // Approve Sablier to spend the tokens
        TOKEN.approve(address(SABLIER_LOCKUP), amount);

        // Create the lockup linear stream parameters
        Lockup.CreateWithDurations memory params = Lockup.CreateWithDurations({
            sender: msg.sender, // Can cancel the stream
            recipient: recipient, // Receives the tokens
            depositAmount: amount,
            token: TOKEN,
            cancelable: true, // Stream can be canceled
            transferable: false, // NFT cannot be transferred
            shape: "Linear Vesting"
        });

        // Configure unlock amounts (0 = pure linear unlock after cliff)
        LockupLinear.UnlockAmounts memory unlockAmounts = LockupLinear.UnlockAmounts({
            start: 0, // No instant unlock at start
            cliff: 0 // No instant unlock at cliff
        });

        // Configure the vesting schedule
        LockupLinear.Durations memory durations = LockupLinear.Durations({cliff: cliffDuration, total: totalDuration});

        // Create the stream
        streamId = SABLIER_LOCKUP.createWithDurationsLL(params, unlockAmounts, durations);
    }

    function createAllVestingStreams(address teamAddress, address investorAddress, address foundationAddress)
        external
        returns (uint256[] memory streamIds)
    {
        // Transfer all tokens from sender to this contract
        TOKEN.transferFrom(msg.sender, address(this), TOTAL_LOCKUP_AMOUNT);

        // Approve the batch contract to spend tokens
        TOKEN.approve(address(SABLIER_BATCH_LOCKUP), TOTAL_LOCKUP_AMOUNT);

        // Create batch array for 3 streams
        BatchLockup.CreateWithDurationsLL[] memory batch = new BatchLockup.CreateWithDurationsLL[](3);

        // Stream 0: Team - 10%, 1 year cliff, 4 year total vesting
        batch[0] = BatchLockup.CreateWithDurationsLL({
            sender: msg.sender,
            recipient: teamAddress,
            depositAmount: TEAM_AMOUNT,
            cancelable: true,
            transferable: false,
            durations: LockupLinear.Durations({
                cliff: 365 days, // 1 year cliff
                total: 4 * 365 days // 4 year total
            }),
            unlockAmounts: LockupLinear.UnlockAmounts({start: 0, cliff: 0}),
            shape: "Team Vesting"
        });

        // Stream 1: Investors - 20%, 6 month cliff, 2 year total vesting
        batch[1] = BatchLockup.CreateWithDurationsLL({
            sender: msg.sender,
            recipient: investorAddress,
            depositAmount: INVESTOR_AMOUNT,
            cancelable: true,
            transferable: false,
            durations: LockupLinear.Durations({
                cliff: 180 days, // 6 month cliff
                total: 2 * 365 days // 2 year total
            }),
            unlockAmounts: LockupLinear.UnlockAmounts({start: 0, cliff: 0}),
            shape: "Investor Vesting"
        });

        // Stream 2: Foundation - 30%, no cliff, 3 year linear vesting
        batch[2] = BatchLockup.CreateWithDurationsLL({
            sender: msg.sender,
            recipient: foundationAddress,
            depositAmount: FOUNDATION_AMOUNT,
            cancelable: true,
            transferable: false,
            durations: LockupLinear.Durations({
                cliff: 0, // No cliff
                total: 3 * 365 days // 3 year total
            }),
            unlockAmounts: LockupLinear.UnlockAmounts({start: 0, cliff: 0}),
            shape: "Foundation Vesting"
        });

        // Create all streams in one transaction
        streamIds = SABLIER_BATCH_LOCKUP.createWithDurationsLL(SABLIER_LOCKUP, TOKEN, batch);

        // Store stream IDs
        teamStreamId = streamIds[0];
        investorStreamId = streamIds[1];
        foundationStreamId = streamIds[2];

        emit StreamsCreated(teamStreamId, investorStreamId, foundationStreamId);
    }

    /*//////////////////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function getWithdrawableAmount(uint256 streamId) external view returns (uint128) {
        return SABLIER_LOCKUP.withdrawableAmountOf(streamId);
    }

    function getStreamStatus(uint256 streamId) external view returns (Lockup.Status) {
        return SABLIER_LOCKUP.statusOf(streamId);
    }
}
