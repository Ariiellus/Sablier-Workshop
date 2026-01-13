// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ISablierFactoryMerkleInstant} from "@sablier/airdrops/src/interfaces/ISablierFactoryMerkleInstant.sol";
import {ISablierMerkleInstant} from "@sablier/airdrops/src/interfaces/ISablierMerkleInstant.sol";
import {MerkleInstant} from "@sablier/airdrops/src/types/DataTypes.sol";

contract AirdropCampaign {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////////////////
                                   CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    uint256 public constant COMMUNITY_AMOUNT = 4000e18;

    /*//////////////////////////////////////////////////////////////////////////
                                   STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    ISablierFactoryMerkleInstant public immutable SABLIER_FACTORY;
    IERC20 public immutable TOKEN;
    ISablierMerkleInstant public airdropCampaign;

    /*//////////////////////////////////////////////////////////////////////////
                                   EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event AirdropCreated(address indexed campaign, bytes32 merkleRoot, uint256 totalAmount);

    /*//////////////////////////////////////////////////////////////////////////
                                  CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor(ISablierFactoryMerkleInstant _sablierFactory, IERC20 _token) {
        SABLIER_FACTORY = _sablierFactory;
        TOKEN = _token;
    }

    /*//////////////////////////////////////////////////////////////////////////
                              PUBLIC FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function createAirdrop(
        bytes32 merkleRoot,
        uint256 recipientCount,
        string calldata campaignName,
        string calldata ipfsCID,
        uint40 expirationDays
    ) external returns (ISablierMerkleInstant campaign) {
        TOKEN.safeTransferFrom(msg.sender, address(this), COMMUNITY_AMOUNT);
        TOKEN.approve(address(SABLIER_FACTORY), COMMUNITY_AMOUNT);

        uint40 expiration = expirationDays > 0 ? uint40(block.timestamp + (expirationDays * 1 days)) : 0;

        MerkleInstant.ConstructorParams memory params = MerkleInstant.ConstructorParams({
            campaignName: campaignName,
            campaignStartTime: uint40(block.timestamp),
            expiration: expiration,
            initialAdmin: msg.sender,
            ipfsCID: ipfsCID,
            merkleRoot: merkleRoot,
            token: TOKEN
        });

        campaign = SABLIER_FACTORY.createMerkleInstant(params, COMMUNITY_AMOUNT, recipientCount);
        TOKEN.safeTransfer(address(campaign), COMMUNITY_AMOUNT);
        airdropCampaign = campaign;

        emit AirdropCreated(address(campaign), merkleRoot, COMMUNITY_AMOUNT);
    }

    /*//////////////////////////////////////////////////////////////////////////
                              VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function hasClaimed(uint256 index) external view returns (bool) {
        if (address(airdropCampaign) == address(0)) return false;
        return airdropCampaign.hasClaimed(index);
    }

    function getExpiration() external view returns (uint40) {
        if (address(airdropCampaign) == address(0)) return 0;
        return airdropCampaign.EXPIRATION();
    }
}

library MerkleTreeGenerator {
    function generateLeaf(uint256 index, address recipient, uint256 amount) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(index, recipient, amount))));
    }

    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        return MerkleProof.verify(proof, root, leaf);
    }
}
