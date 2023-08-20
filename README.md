# Inflation controller for $GOLD tokens

## What this is ?

Inflation Controller is inspired by [OZ Vesting Wallet](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/finance/VestingWallet.sol) with a few changes.
Let's list them:
1. First and foremost, `InflationController` is Ownable. Ownership is transferred to Humpy's wallet
2. In OZ implementation `owner` is immutable, but in this implementation owner can change beneficiary
3. Owner can also sweep $GOLD with 2 weeks timelock
4. Owner can sweep any other ERC20 token without timelock
5. This implementation has no vesting logic for ETH and all payables are removed
