# VictorVoltage Token (V V)

## Overview

VictorVoltage Token (VV) is an ERC20 token implemented on the Ethereum blockchain. It features a deflationary mechanism, reflection rewards, and various tax structures for different transaction types.

## Key Features

- Total Supply: 170 trillion (170,000,000,000,000) VV tokens
- Transfer Tax: 1.7%
- Buy/Sell Tax: 17%
- Burn Mechanism: Part of each transaction is burned, reducing total supply
- Reflection Rewards: Holders receive a share of transaction fees
- Max Transaction Limit: Configurable maximum transaction amount
- Pausable: Contract can be paused/unpaused by the owner

## Tax Distribution

For each taxed transaction:

- Tithing: 1.7%
- Burn: 1.7%
- Reflection: 1.7%
- LP Injection: 1.7%
- Treasury: 10.2%

## Smart Contract Functions

### Admin Functions

- `setUniswapPair(address _uniswapPair)`: Set the Uniswap pair address
- `excludeFromFees(address account, bool excluded)`: Exclude/include an address from fees
- `updateTreasuryWallet(address newTreasuryWallet)`: Update the treasury wallet address
- `updateLpWallet(address newLpWallet)`: Update the LP wallet address
- `updateTithingWallet(address newTithingWallet)`: Update the tithing wallet address
- `excludeFromReward(address account)`: Exclude an address from receiving reflection rewards
- `includeInReward(address account)`: Include an address in receiving reflection rewards
- `setMaxTransactionAmount(uint256 amount)`: Set the maximum transaction amount
- `pause()`: Pause the contract
- `unpause()`: Unpause the contract

### User Functions

- `transfer(address recipient, uint256 amount)`: Transfer tokens
- `approve(address spender, uint256 amount)`: Approve spending of tokens
- `transferFrom(address sender, address recipient, uint256 amount)`: Transfer tokens on behalf of another address
- `burn(uint256 amount)`: Burn tokens

### View Functions

- `balanceOf(address account)`: Get the token balance of an address
- `totalSupply()`: Get the current total supply of tokens
- `isExcludedFromFees(address account)`: Check if an address is excluded from fees

## Security Features

- Pausable: Allows pausing of token transfers in case of emergencies
- Ownership: Critical functions are restricted to the contract owner

## Deployment

When deploying the contract, provide the following parameters:

1. Treasury wallet address
2. LP wallet address
3. Tithing wallet address

## Important Notes

- The contract owner should set the Uniswap pair address after deployment using `setUniswapPair()`
- Ensure all wallet addresses are correctly set and verified after deployment
- The max transaction amount is initially set to 1% of the total supply but can be adjusted by the owner

## Disclaimer

This token contract includes complex mechanisms. It is recommended to have a thorough audit performed by a reputable smart contract auditing firm before deployment to mainnet.
