# Sablier Workshop

Token distribution system using Sablier vesting streams and Merkle airdrops.

## Distribution

| Recipient  | Tokens | Vesting                     |
|------------|--------|----------------------------|
| Team       | 1,000  | 1-year cliff, 4-year total |
| Investors  | 2,000  | 6-month cliff, 2-year total|
| Foundation | 3,000  | No cliff, 3-year linear    |
| Community  | 4,000  | Instant airdrop            |

**Total: 10,000 WSHP tokens**

## Setup

```bash
make install
# Create .env with:
# SEPOLIA_RPC_URL=your_rpc_url
# ACCOUNT_NAME=your_keystore_name (from `cast wallet list`)
```

## Contracts

- **TokenERC20.sol** - Basic ERC20 with mint functionality
- **TokenDistributor.sol** - Creates Sablier vesting streams
- **AirdropCampaign.sol** - Merkle-based airdrop distribution

## Usage

```bash
# Run tests
make test

# Deploy to Sepolia
make deploy-sepolia

# Create vesting streams
export TOKEN_ADDRESS=<from deploy>
export DISTRIBUTOR_ADDRESS=<from deploy>
export TEAM_ADDRESS=<wallet>
export INVESTOR_ADDRESS=<wallet>
export FOUNDATION_ADDRESS=<wallet>
make create-streams

# Create airdrop (optional)
export AIRDROP_CAMPAIGN_ADDRESS=<from deploy>
export MERKLE_ROOT=<generated root>
export RECIPIENT_COUNT=<number>
make create-airdrop
```

View streams at [app.sablier.com](https://app.sablier.com).

## Key Concepts

- **Streams** - Tokens unlock continuously over time
- **Cliffs** - Period where no tokens unlock before linear vesting begins
- **Merkle trees** - Gas-efficient airdrops storing only a 32-byte root on-chain

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Insufficient allowance" | Approve tokens before creating streams |
| Tests fail to fork | Check `SEPOLIA_RPC_URL` is set |
| Stream not visible | Connect with recipient wallet |

## Resources

- [Sablier Docs](https://docs.sablier.com)
- [Sablier App](https://app.sablier.com)
- [Foundry Book](https://book.getfoundry.sh)
