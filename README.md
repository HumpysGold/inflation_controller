# Inflation controller for $GOLD tokens

## What is it?

The **Inflation Controller** is inspired by the [OZ Vesting Wallet](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/finance/VestingWallet.sol) but with several modifications. Here are the key differences:

1. The Inflation Controller is "Ownable." Ownership is transferred to Humpy's wallet.
2. In the OZ version, the beneficiary is immutable. However, in this version, the owner can change the beneficiary.
3. The owner can sweep $GOLD with a 2-week timelock.
4. The owner can sweep any other ERC20 token immediately, without a timelock.
5. This version has no vesting logic for ETH, and all payable functionalities are removed.

## Deployment Details:

- The Inflation Controller for $GOLD is deployed at: [0x2b55CEd05e9Ff838bcf3581D998468c603648466](https://basescan.org/address/0x2b55CEd05e9Ff838bcf3581D998468c603648466)
- Inflation Controller vesting contract for the GOLD Team is at: [0x45ac5b411bcc919d869826da904be9fbab527d22](https://basescan.org/address/0x45ac5b411bcc919d869826da904be9fbab527d22)

## Initial Parameters:

*For the Inflation Controller for $GOLD:*
- Vesting starts at 00:00 GMT on August 31, 2023 (timestamp: 1693440000).
- The vesting duration is 3 years (timestamp: 94608000).

*For the Inflation Controller vesting contract for the GOLD Team:*
- Vesting begins at 00:00 GMT on August 31, 2023 (timestamp: 1693440000).
- The vesting duration is 1 year (timestamp: 31536000).

*Deployer and Ownership*:

The contract was deployed by the deployer address `0x5612de655956236284963d7d99653354a09cfd39`. However, ownership was transferred to Humpy's wallet ([0x36cc7B13029B5DEe4034745FB4F24034f3F2ffc6](https://debank.com/profile/0x36cc7b13029b5dee4034745fb4f24034f3f2ffc6)) in the [constructor](https://basescan.org/tx/0x8adbef9eb7d016f5df44b68eb01a6e0fb08be3afbbe8004e0ada356e7b6cbc4b#eventlog).

The beneficiary of the vesting should be set by the current owner of the contract.

## Important Notes:
- Vesting will commence at 00:00 GMT on August 31, 2023, irrespective of the number of tokens in the contract. Thus, if $GOLD tokens are sent to the contract post this time, a portion will be immediately available for withdrawal.
- The vesting follows a linear algorithm.
- It's possible to sweep $GOLD tokens from the contract with a 2-week timelock. Any other ERC20 token can be swept immediately without a timelock.

## Code Reviews:
The code underwent rigorous review by both Humpy's team and independent auditors. No critical issues surfaced. However, we'd like to highlight certain comments made during the review:
- Variables are private by default, eliminating the need to specify the 'private' keyword.
- No need for public getters for storage variables; these variables can simply be declared as public.
- There was a reentrancy concern in `sweepTimelock` which was addressed using the CEI pattern.
- Originally, `sweepTimelock` accepted the address token as an argument. We omitted this since only $GOLD tokens can be swept from the contract with a timelock.
- We added multiple checks and requirements to prevent setting critical addresses to `0x0`.
- There were minor concerns about the potential for owners to reset the timelock.

Credit to reviewers:
- [viraj124](https://github.com/viraj124)
- [goldenkapusta](https://github.com/goldenkapusta)
- [KD](https://github.com/kitty-the-kat)
- [gosuto](https://github.com/gosuto-inzasheru)
