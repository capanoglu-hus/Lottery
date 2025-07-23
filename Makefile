-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil 




build:; forge build

test :; forge test 

deploy-sepolia :; forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) --account myaccount --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv




