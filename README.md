# SUID - Staking pool module

The SUID module is a simple staking pool that allows users to stake SUI and receive SUID in return.User can also stake and unstake SUI with the given validator.

## Functions

#### 1. add_liquidity:

- Add liquidity to the pool by transferring SUI to the pool and receiving SUID in return.

#### 2. remove_liquidity:

- Remove liquidity from the pool by burning SUID and receiving SUI in return.

#### 3. stake:

- Stake the SUI with the given validator.

#### 4. unstake:

- Unstake the SUI. 5. get_supply: Return the total supply of SUID. 6. get_assets: Return the total amount of SUI in the pool.

## How to Build

```bash
sui move build
```

## How to Test

```bash
sui move test
```

## How to Publish

This guide assumes you have a private key, already have faucet coins in testnet or devnet.

```bash
sui client publish --gas-budget 100000000 --json
```
