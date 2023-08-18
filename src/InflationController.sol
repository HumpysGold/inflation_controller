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
    uint256 public constant SWEEP_TIMELOCK_DURATION = 14 days;
    address public constant PROTECTED_TOKEN =
        address(0xbeFD5C25A59ef2C1316c5A4944931171F30Cd3E4);

    uint256 private _released;
    mapping(address => uint256) private _erc20Released;
    uint64 private immutable _start;
    uint64 private immutable _duration;

    address private _beneficiary;
    uint256 public timelockEnd;

    event BeneficiaryChanged(
        address indexed previousBeneficiary,
        address indexed newBeneficiary
    );
    event EtherReleased(uint256 amount);
    event ERC20Released(address indexed token, uint256 amount);
    event TimelockSet(uint256 timelockEnd);
    event ERC20Swept(
        address indexed token,
        address indexed receiver,
        uint256 amount
    );
    event GasTokenWithdrawn(uint256 amount, address indexed recipient);

    /**
     * @dev Set start timestamp and vesting duration of the inflation controller.
     */
    constructor(uint64 startTimestamp, uint64 durationSeconds) payable {
        _start = startTimestamp;
        _duration = durationSeconds;
    }

    /**
     * @dev The contract should be able to receive Eth.
     */
    receive() external payable {}

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
     * @dev Amount of eth already released
     */
    function released() public view returns (uint256) {
        return _released;
    }

    /**
     * @dev Amount of token already released
     */
    function released(address token) public view returns (uint256) {
        return _erc20Released[token];
    }

    /**
     * @dev Getter for the amount of releasable eth.
     */
    function releasable() public view returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }

    /**
     * @dev Getter for the amount of releasable `token` tokens. `token` should be the address of an
     * IERC20 contract.
     */
    function releasable(address token) public view returns (uint256) {
        return vestedAmount(token, uint64(block.timestamp)) - released(token);
    }

    /**
     * @dev Release the native token (ether) that have already vested.
     *
     * Emits a {EtherReleased} event.
     */
    function release() public {
        uint256 amount = releasable();
        _released += amount;
        emit EtherReleased(amount);
        Address.sendValue(payable(beneficiary()), amount);
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {ERC20Released} event.
     */
    function release(address token) public {
        uint256 amount = releasable(token);
        _erc20Released[token] += amount;
        emit ERC20Released(token, amount);
        SafeERC20.safeTransfer(IERC20(token), beneficiary(), amount);
    }

    /**
     * @dev Calculates the amount of ether that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(uint64 timestamp) public view returns (uint256) {
        return _vestingSchedule(address(this).balance + released(), timestamp);
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(
        address token,
        uint64 timestamp
    ) public view returns (uint256) {
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
    /// @param token Protocol token to sweep
    function sweepTimelock(address token, address receiver) external onlyOwner {
        require(
            token == PROTECTED_TOKEN,
            "InflationController: not protected token"
        );
        if (timelockEnd == 0) {
            timelockEnd = block.timestamp + SWEEP_TIMELOCK_DURATION;
            emit TimelockSet(timelockEnd);
        } else if (block.timestamp >= timelockEnd) {
            uint256 amount = IERC20(token).balanceOf(address(this));
            SafeERC20.safeTransfer(IERC20(token), receiver, amount);
            timelockEnd = 0;
            emit TimelockSet(timelockEnd);
            emit ERC20Swept(token, receiver, amount);
        } else {
            revert("InflationController: timelock not over");
        }
    }

    /// @notice sweep unwanted tokens from the contract, no timelock for non-protected tokens
    /// @param token token to sweep
    /// @param receiver address to send the tokens to
    function sweep(address token, address receiver) external onlyOwner {
        require(
            token != PROTECTED_TOKEN,
            "InflationController: protected token"
        );
        require(receiver != address(0), "InflationController: zero address");
        uint256 balance = IERC20(token).balanceOf(address(this));
        SafeERC20.safeTransfer(IERC20(token), receiver, balance);
        emit ERC20Swept(token, receiver, balance);
    }

    /// @notice withdraw gas token from the contract
    /// @param receiver address to send the gas token to
    function sweepGasToken(address payable receiver) external onlyOwner {
        require(receiver != address(0), "InflationController: zero address");
        uint256 amount = address(this).balance;
        receiver.transfer(amount);
        emit GasTokenWithdrawn(amount, receiver);
    }
}
