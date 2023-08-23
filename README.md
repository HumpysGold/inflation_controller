# Inflation controller for $GOLD tokens

## What this is ?

Inflation Controller is inspired by [OZ Vesting Wallet](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/finance/VestingWallet.sol) with a few changes.
Let's list them:
1. First and foremost, `InflationController` is Ownable. Ownership is transferred to Humpy's wallet
2. In OZ implementation `owner` is immutable, but in this implementation owner can change beneficiary
3. Owner can also sweep $GOLD with 2 weeks timelock
4. Owner can sweep any other ERC20 token without timelock
5. This implementation has no vesting logic for ETH and all payables are removed


## Deployment
Inflation Controller for $GOLD is deployed at [0x2b55CEd05e9Ff838bcf3581D998468c603648466](https://basescan.org/address/0x2b55CEd05e9Ff838bcf3581D998468c603648466)

Initial parameters:
- Vesting start time is set at 00:00 GMT August 31 2023(ts is **1693440000**)
- Vesting duration is 3 years(ts is **94608000**)

Contract was deployed by deployer address("0x5612de655956236284963d7d99653354a09cfd39") but ownership is transferred
to Humpy's wallet([0x36cc7B13029B5DEe4034745FB4F24034f3F2ffc6](https://debank.com/profile/0x36cc7b13029b5dee4034745fb4f24034f3f2ffc6))
in the constructor: [link](https://basescan.org/tx/0x8adbef9eb7d016f5df44b68eb01a6e0fb08be3afbbe8004e0ada356e7b6cbc4b#eventlog)

**Beneficiary of vesting should be set by current owner of the contract**

## Good to know
Vesting will start at **00:00 GMT August 31 2023**, regardless of the amount of tokens in the contract. This means that if
$GOLD tokens will be sent to the contract after the vesting start time, some portion of them will be available for
withdrawal immediately.

Vesting using linear vesting algorithm.

It is possible to sweep $GOLD tokens from the contract with 2 weeks timelock. Any other ERC20 token can be swept
immediately without timelock.

## Code reviews
Code was reviewed throughly by Humpy's team(and independent auditors) and no critical issues were found. However, we would like to point out
some comments that were made during the review process:

1. Vars by default private so no need to specify the private keyword
2. No need for public getters for storage vars instead the vars can be declared as public
3. Reentrancy concern in `sweepTimelock` which was remediated by using using CEI pattern
4. `sweepTimelock` was at first accepting `address token` as an argument, but we removed it, since only $GOLD tokens
can be swept from the contract via time lock
5. Added multiple checks-requires when trying to set critical addresses to 0x0
6. Minor concerns that timelock can be reset by owner if they want to

Credit to reviewers:
- [viraj124](https://github.com/viraj124)
- [goldenkapusta](https://github.com/goldenkapusta)
- [KD](https://github.com/kitty-the-kat)
- [gosuto](https://github.com/gosuto-inzasheru)