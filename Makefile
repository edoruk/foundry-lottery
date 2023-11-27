-include .env

build:; forge build

deploy-sepolia:
	forge script script/DeployLottery.s.sol:DeployLottery --rpc-url ${RPC_URL_SEP} --private-key ${PRIVATE_KEY_SEP} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

deploy:
	forge script script/DeployLottery.s.sol:DeployLottery --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast
