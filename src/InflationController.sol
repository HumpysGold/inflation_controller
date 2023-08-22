// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../lib/openzeppelin-contracts/contracts/utils/Address.sol";
import "../lib//openzeppelin-contracts/contracts/access/Ownable.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title InflationController
 * @dev This contract handles the vesting of Eth and ERC20 tokens for a given beneficiary. Custody of multiple tokens
 * can be given to this contract, which will release the token to the beneficiary following a given vesting schedule.
 * The vesting schedule is customizable through the {vestedAmount} function.
 *
 * Any token transferred to this contract will follow the vesting schedule as if they were locked from the beginning.
 * Consequently, if the vesting has already started, any amount of tokens sent to this contract will (at least partly)
 * be immediately releasable.
 */
contract InflationController is Ownable {
    //////////////////////////////////////////
    //////////      Constants    /////////////
    //////////////////////////////////////////
    uint256 public constant SWEEP_TIMELOCK_DURATION = 14 days;
    IERC20 public constant PROTECTED_TOKEN =
        IERC20(address(0xbeFD5C25A59ef2C1316c5A4944931171F30Cd3E4));

    // Humpy's wallet
    address public constant OWNER_ADDRESS =
        address(0x36cc7B13029B5DEe4034745FB4F24034f3F2ffc6);
    //////////////////////////////////////////
    ///////////      Storage     /////////////
    //////////////////////////////////////////
    struct TimeLock {
        address receiver;
        uint256 timelockEnd;
    }
    TimeLock public timelock;
    mapping(address => uint256) private _erc20Released;
    uint64 private immutable _start;
    uint64 private immutable _duration;

    address private _beneficiary;

    //////////////////////////////////////////
    ///////////      Events     //////////////
    //////////////////////////////////////////
    event BeneficiaryChanged(
        address indexed previousBeneficiary,
        address indexed newBeneficiary
    );
    event StartSet(uint256 start);
    event DurationSet(uint256 duration);
    event ERC20Released(address indexed token, uint256 amount);
    event TimelockSet(uint256 timelockEnd);
    event ERC20Swept(
        address indexed token,
        address indexed receiver,
        uint256 amount
    );

    /**
     * @dev Set start timestamp and vesting duration of the inflation controller.
     */
    constructor(uint64 startTimestamp, uint64 durationSeconds) {
        _start = startTimestamp;
        _duration = durationSeconds;

        // Transfer ownership to the owner address
        transferOwnership(OWNER_ADDRESS);
        emit StartSet(startTimestamp);
        emit DurationSet(durationSeconds);
    }

    /**
     * @dev Getter for the beneficiary address.
     */
    function beneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
     * @dev Getter for the start timestamp.
     */
    function start() public view returns (uint256) {
        return _start;
    }

    /**
     * @dev Getter for the vesting duration.
     */
    function duration() public view returns (uint256) {
        return _duration;
    }

    /**
     * @dev Amount of token already released
     */
    function released(address token) public view returns (uint256) {
        return _erc20Released[token];
    }

    /**
     * @dev Getter for the amount of releasable `token` tokens. `token` should be the address of an
     * IERC20 contract.
     */
    function releasable(address token) public view returns (uint256) {
        return _vestedAmount(token, uint64(block.timestamp)) - released(token);
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {ERC20Released} event.
     */
    function release(address token) public {
        // Can only be released by the beneficiary and owner
        require(
            msg.sender == beneficiary() || msg.sender == owner(),
            "InflationController: not the beneficiary or owner"
        );
        require(
            beneficiary() != address(0),
            "InflationController: beneficiary not set"
        );
        uint256 amount = releasable(token);
        _erc20Released[token] += amount;
        emit ERC20Released(token, amount);
        SafeERC20.safeTransfer(IERC20(token), beneficiary(), amount);
    }

    /// @notice Calculates the amount of tokens that has already vested
    /// @param token token to calculate vested amount for
    /// @param timestamp timestamp to calculate vested amount for
    function vestedAmount(
        address token,
        uint64 timestamp
    ) external view returns (uint256) {
        return _vestedAmount(token, timestamp);
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function _vestedAmount(
        address token,
        uint64 timestamp
    ) internal view returns (uint256) {
        return
            _vestingSchedule(
                IERC20(token).balanceOf(address(this)) + released(token),
                timestamp
            );
    }

    /// @notice Set the beneficiary address
    /// @param _newBeneficiary Address of the beneficiary
    function setBeneficiary(address _newBeneficiary) external onlyOwner {
        require(
            _newBeneficiary != address(0),
            "InflationController: zero address"
        );
        address oldBeneficiary = _beneficiary;
        _beneficiary = _newBeneficiary;
        emit BeneficiaryChanged(oldBeneficiary, _newBeneficiary);
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(
        uint256 totalAllocation,
        uint64 timestamp
    ) internal view returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp > start() + duration()) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - start())) / duration();
        }
    }

    /// @notice If Timelock is over, sweep all ERC20 tokens to the owner, otherwise create a new timelock
    /// @param receiver address to send the tokens to
    function sweepTimelock(address receiver) external onlyOwner {
        uint256 balance = PROTECTED_TOKEN.balanceOf(address(this));
        require(
            balance > 0,
            "InflationController: no protected token to sweep"
        );
        if (timelock.timelockEnd == 0) {
            timelock = TimeLock(
                receiver,
                block.timestamp + SWEEP_TIMELOCK_DURATION
            );
            emit TimelockSet(timelock.timelockEnd);
        } else if (block.timestamp >= timelock.timelockEnd) {
            require(
                timelock.receiver == receiver,
                "InflationController: timelock receiver mismatch"
            );
            timelock.timelockEnd = 0;
            SafeERC20.safeTransfer(PROTECTED_TOKEN, receiver, balance);
            emit TimelockSet(timelock.timelockEnd);
            emit ERC20Swept(address(PROTECTED_TOKEN), receiver, balance);
        } else {
            revert("InflationController: timelock not over");
        }
    }

    /// @notice Owner can reset timelock
    function resetTimelock() external onlyOwner {
        timelock.timelockEnd = 0;
        emit TimelockSet(timelock.timelockEnd);
    }

    /// @notice sweep unwanted tokens from the contract, no timelock for non-protected tokens
    /// @param token token to sweep
    /// @param receiver address to send the tokens to
    function sweep(address token, address receiver) external onlyOwner {
        require(
            token != address(PROTECTED_TOKEN),
            "InflationController: protected token"
        );
        require(receiver != address(0), "InflationController: zero address");
        uint256 balance = IERC20(token).balanceOf(address(this));
        SafeERC20.safeTransfer(IERC20(token), receiver, balance);
        emit ERC20Swept(token, receiver, balance);
    }
}
