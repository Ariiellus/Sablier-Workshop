# Sablier Workshop Makefile

-include .env

# Default target
.PHONY: all
all: install build

# Install dependencies
.PHONY: install
install:
	forge install

# Build contracts
.PHONY: build
build:
	forge build

# Run tests
.PHONY: test
test:
	forge test -vvv

# Run tests with gas report
.PHONY: test-gas
test-gas:
	forge test -vvv --gas-report

# Run specific test
.PHONY: test-match
test-match:
	forge test --match-test $(TEST) -vvv

# Clean build artifacts
.PHONY: clean
clean:
	forge clean

# Format code
.PHONY: fmt
fmt:
	forge fmt

# Check formatting
.PHONY: fmt-check
fmt-check:
	forge fmt --check

# Deploy to Sepolia
.PHONY: deploy-sepolia
deploy-sepolia:
	forge script script/Deploy.s.sol:DeployWorkshop \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--broadcast \
		--account $(ACCOUNT_NAME) \
		--verify \
		-vvv

# Create vesting streams (requires env vars: TOKEN_ADDRESS, DISTRIBUTOR_ADDRESS, TEAM_ADDRESS, INVESTOR_ADDRESS, FOUNDATION_ADDRESS)
.PHONY: create-streams
create-streams:
	forge script script/Deploy.s.sol:CreateVestingStreams \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--broadcast \
		--account $(ACCOUNT_NAME) \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvv

# Generate Merkle tree root (modify recipients in script/GenerateMerkle.s.sol)
.PHONY: generate-merkle
generate-merkle:
	forge script script/GenerateMerkle.s.sol:GenerateMerkleTree -vvv

# Create airdrop (requires env vars: TOKEN_ADDRESS, AIRDROP_CAMPAIGN_ADDRESS, MERKLE_ROOT, RECIPIENT_COUNT)
.PHONY: create-airdrop
create-airdrop:
	forge script script/Deploy.s.sol:CreateAirdrop \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--broadcast \
		--account $(ACCOUNT_NAME) \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvv

# Run local fork of Sepolia
.PHONY: fork
fork:
	anvil --fork-url $(SEPOLIA_RPC_URL)

# Help
.PHONY: help
help:
	@echo "Sablier Workshop Commands:"
	@echo ""
	@echo "  make install        - Install dependencies"
	@echo "  make build          - Build contracts"
	@echo "  make test           - Run all tests"
	@echo "  make test-gas       - Run tests with gas report"
	@echo "  make test-match TEST=<name> - Run specific test"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make fmt            - Format code"
	@echo "  make fmt-check      - Check code formatting"
	@echo ""
	@echo "  make deploy-sepolia - Deploy contracts to Sepolia"
	@echo "  make create-streams - Create vesting streams"
	@echo "  make generate-merkle - Generate Merkle tree root for airdrop"
	@echo "  make create-airdrop - Create airdrop campaign"
	@echo "  make fork           - Run local Anvil fork of Sepolia"
