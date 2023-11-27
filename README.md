# Usage

### For Testnet

Need to install `@chainlink` library and create, add fund and add consumer from chainlink.

### For local

There is a script file named Interactions.s.sol which is used for creating, funding and adding consumer locally.
`test/mock/VRfCoordinatorV2Mock.sol` is used for these functions.

## Quickstart

```shell
git clone https://github.com/edoruk/foundry-lottery/
cd foundry-lottery
forge build
```

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Anvil

```shell
$ anvil
```

### Deploy

#### Deploy and Verify on Sepolia Testnet

```shell
$ 	forge script script/DeployLottery.s.sol:DeployLottery --rpc-url ${RPC_URL_SEP} --private-key ${PRIVATE_KEY_SEP} --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY}

```

#### Deploy and Verify on Anvil

```shell
$ 	forge script script/DeployLottery.s.sol:DeployLottery --rpc-url ${RPC_URL} --private-key ${PRIVATE_KEY} --broadcast


```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
