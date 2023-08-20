// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/InflationController.sol";
import "./Fixture.t.sol";
import "./utils.sol";

contract TestInflationController is Fixture {
    InflationController public inflationController;

    IERC20 public constant GOLD =
        IERC20(0xbeFD5C25A59ef2C1316c5A4944931171F30Cd3E4);

    function setUp() public override {
        super.setUp();
        // Create a new InflationController with a start timestamp of now and a duration of 1 year
        inflationController = new InflationController(
            uint64(block.timestamp),
            // 3 years
            uint64(3 * 365 days)
        );
        // Make sure inflation contract has correct owner:
        assertEq(
            inflationController.owner(),
            inflationController.OWNER_ADDRESS()
        );
    }

    function testSetBeneficiaryHappy() public {
        vm.prank(inflationController.OWNER_ADDRESS());
        inflationController.setBeneficiary(alice);
        assertEq(inflationController.beneficiary(), alice);
    }

    function testSetBeneficiaryFail() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        inflationController.setBeneficiary(alice);
        vm.stopPrank();

        // Try to set the beneficiary to address(0)
        vm.startPrank(inflationController.OWNER_ADDRESS());
        vm.expectRevert("InflationController: zero address");
        inflationController.setBeneficiary(address(0));
        vm.stopPrank();
    }

    /// @dev Happy case when owner wants to sweep all timelocked tokens
    function testSweepTimelockHappy() public {
        uint256 arbitraryAmount = 1000e18;
        // Make sure timelock is 0 now
        (, uint256 timelockEnd) = inflationController.timelock();
        assertEq(timelockEnd, 0);
        // Make alice owner of the contract
        vm.prank(inflationController.OWNER_ADDRESS());
        inflationController.transferOwnership(alice);

        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            GOLD.balanceOf.selector,
            address(GOLD),
            arbitraryAmount
        );
        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(alice);

        // Make sure timelock is set to 14 days from now
        (, timelockEnd) = inflationController.timelock();
        assertEq(
            timelockEnd,
            block.timestamp + inflationController.SWEEP_TIMELOCK_DURATION()
        );

        // Warp 14 days into the future
        vm.warp(
            block.timestamp + inflationController.SWEEP_TIMELOCK_DURATION()
        );

        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(alice);

        // Make sure alice now has the ERC20 tokens
        assertEq(GOLD.balanceOf(alice), arbitraryAmount);
        // Make sure timelock is set to 0
        (, timelockEnd) = inflationController.timelock();
        assertEq(timelockEnd, 0);
    }

    /// @dev Happy case when owner wants to sweep all timelocked tokens multiple times
    function testSweepTimelockHappyMulTimes() public {
        uint256 arbitraryAmount = 1000e18;
        // Make sure timelock is 0 now
        (, uint256 timelockEnd) = inflationController.timelock();
        assertEq(timelockEnd, 0);
        // Make alice owner of the contract
        vm.prank(inflationController.OWNER_ADDRESS());
        inflationController.transferOwnership(alice);

        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            GOLD.balanceOf.selector,
            address(GOLD),
            arbitraryAmount
        );
        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(alice);

        // Warp 14 days into the future
        vm.warp(
            block.timestamp + inflationController.SWEEP_TIMELOCK_DURATION()
        );

        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(alice);

        // Make sure alice now has the ERC20 tokens
        assertEq(GOLD.balanceOf(alice), arbitraryAmount);

        // Now alice wants to sweep more ERC20 tokens, let's make sure Timelock struct is updated properly
        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            GOLD.balanceOf.selector,
            address(GOLD),
            arbitraryAmount
        );
        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(alice);
        // Warp another 14 days into the future
        vm.warp(
            block.timestamp + inflationController.SWEEP_TIMELOCK_DURATION()
        );
        // Now alice wants to sweep the ERC20 tokens again after 14 days. Let's make sure she has double the amount
        uint256 balanceSnapshot = GOLD.balanceOf(alice);
        vm.prank(alice);
        inflationController.sweepTimelock(alice);
        assertEq(GOLD.balanceOf(alice), balanceSnapshot + arbitraryAmount);
    }

    /// @dev Check timelock reset by owner
    function testSweepTimeLockReset() public {
        uint256 arbitraryAmount = 1000e18;
        // Make sure timelock is 0 now
        (, uint256 timelockEnd) = inflationController.timelock();
        assertEq(timelockEnd, 0);
        // Make alice owner of the contract
        vm.prank(inflationController.OWNER_ADDRESS());
        inflationController.transferOwnership(alice);

        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            GOLD.balanceOf.selector,
            address(GOLD),
            arbitraryAmount
        );

        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(alice);

        // Make sure timelock is set to 14 days from now
        (, timelockEnd) = inflationController.timelock();
        assertEq(
            timelockEnd,
            block.timestamp + inflationController.SWEEP_TIMELOCK_DURATION()
        );

        // Now reset timelock
        vm.prank(alice);
        inflationController.resetTimelock();

        // Make sure timelock is set to 0
        (address receiver, uint256 newTimelockEnd) = inflationController
            .timelock();
        assertEq(newTimelockEnd, 0);
    }

    /// @dev Case when owner tries to sweep timelocked tokens before timelock is over
    function testSweepTimelockTooEarly() public {
        uint256 arbitraryAmount = 1000e18;
        // Make sure timelock is 0 now
        (, uint256 timelockEnd) = inflationController.timelock();
        assertEq(timelockEnd, 0);
        // Make alice owner of the contract
        vm.prank(inflationController.OWNER_ADDRESS());
        inflationController.transferOwnership(alice);

        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            GOLD.balanceOf.selector,
            address(GOLD),
            arbitraryAmount
        );

        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(alice);

        // Make sure timelock is set to 14 days from now
        (, timelockEnd) = inflationController.timelock();
        assertEq(
            timelockEnd,
            block.timestamp + inflationController.SWEEP_TIMELOCK_DURATION()
        );

        // Warp 13 days into the future
        vm.warp(
            block.timestamp +
                inflationController.SWEEP_TIMELOCK_DURATION() -
                1 days
        );

        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        vm.expectRevert("InflationController: timelock not over");
        inflationController.sweepTimelock(alice);

        // Make sure alice has no ERC20 tokens
        assertEq(GOLD.balanceOf(alice), 0);
        // Make sure timelock is not 0
        (, timelockEnd) = inflationController.timelock();
        assertNotEq(timelockEnd, 0);
    }

    /// @dev Case when owner tries to sweep timelocked tokens before timelock is over
    function testSweepTimelockReceiverChanged() public {
        // Make sure timelock is 0 now
        (, uint256 timelockEnd) = inflationController.timelock();
        assertEq(timelockEnd, 0);
        // Make alice owner of the contract
        vm.prank(inflationController.OWNER_ADDRESS());
        inflationController.transferOwnership(alice);
        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            GOLD.balanceOf.selector,
            address(GOLD),
            10000e18
        );
        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        inflationController.sweepTimelock(alice);

        // Warp 13 days into the future
        vm.warp(
            block.timestamp +
                inflationController.SWEEP_TIMELOCK_DURATION() +
                1 days
        );

        // Now alice wants to sweep the ERC20 tokens
        vm.prank(alice);
        // Change the address of the receiver which should revert
        vm.expectRevert("InflationController: timelock receiver mismatch");
        inflationController.sweepTimelock(bob);
    }

    function testSweepNormal() public {
        uint256 arbitraryAmount = 1000e18;
        // Make alice owner of the contract
        vm.prank(inflationController.OWNER_ADDRESS());
        inflationController.transferOwnership(alice);

        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            BPT.balanceOf.selector,
            address(BPT),
            arbitraryAmount
        );
        // Sweep and check that alice has the ERC20 tokens
        vm.prank(alice);
        inflationController.sweep(address(BPT), alice);
        assertEq(BPT.balanceOf(alice), arbitraryAmount);
    }

    function testSweepFails() public {
        // Make alice owner of the contract
        vm.prank(inflationController.OWNER_ADDRESS());
        inflationController.transferOwnership(alice);
        // Tries to sweep ERC20 tokens that are timelocked and fails
        vm.startPrank(alice);
        vm.expectRevert("InflationController: protected token");
        inflationController.sweep(address(GOLD), alice);
        vm.stopPrank();
    }

    //////////////////////////////////////////
    ///////////   Vesting Logic  /////////////
    //////////////////////////////////////////
    function testVestTokensHappy(uint256 arbitraryAmount) public {
        vm.assume(arbitraryAmount > 0);
        // 100b should be enough
        vm.assume(arbitraryAmount < 100_000_000_000e18);
        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            GOLD.balanceOf.selector,
            address(GOLD),
            arbitraryAmount
        );

        // Check that no tokens are vested yet
        assertEq(
            inflationController.vestedAmount(
                address(GOLD),
                uint64(block.timestamp)
            ),
            0
        );
        // Check no released tokens yet
        assertEq(inflationController.releasable(address(GOLD)), 0);
        // Checked no tokens released:
        assertEq(inflationController.released(address(GOLD)), 0);

        // Set alice as beneficiary
        vm.prank(inflationController.OWNER_ADDRESS());
        inflationController.setBeneficiary(alice);

        // Roll time forward 1 year
        vm.warp(block.timestamp + 365 days);
        // Calculate releaseble amount after 1 year
        uint256 releasableAmount = inflationController.releasable(
            address(GOLD)
        );
        // Check that releasable amount is 1/3 of total amount
        assertEq(releasableAmount, arbitraryAmount / 3);
        // Alice takes the releasable amount
        vm.prank(alice);
        inflationController.release(address(GOLD));
        // Check that released amount is 1/3 of total amount
        assertEq(
            inflationController.released(address(GOLD)),
            arbitraryAmount / 3
        );
        // Check alice has the released amount
        assertEq(GOLD.balanceOf(alice), arbitraryAmount / 3);
        // Make sure no more releasable tokens at the moment
        assertEq(inflationController.releasable(address(GOLD)), 0);

        // Roll time forward one more year
        vm.warp(block.timestamp + 365 days);
        // Calculate releaseble amount after 2 years and release it
        vm.prank(alice);
        inflationController.release(address(GOLD));
        // Check that released amount is 2/3 of total amount
        assertEq(
            inflationController.released(address(GOLD)),
            (arbitraryAmount * 2) / 3
        );
        // Check alice has the released amount
        assertEq(GOLD.balanceOf(alice), (arbitraryAmount * 2) / 3);

        // Roll time forward one more year
        vm.warp(block.timestamp + 365 days);
        // Release rest of it to alice and make sure all tokens are released
        vm.prank(alice);
        inflationController.release(address(GOLD));
        // Check that released amount is 3/3 of total amount
        assertEq(inflationController.released(address(GOLD)), arbitraryAmount);
        // Check alice has the released amount
        assertEq(GOLD.balanceOf(alice), arbitraryAmount);
    }

    /// @dev Only owner or beneficiary can release
    function testVestTokensUnhappy(uint256 arbitraryAmount) public {
        uint256 arbitraryAmount = 1000e18;
        // Generate some ERC20 tokens to sweep
        setStorage(
            address(inflationController),
            GOLD.balanceOf.selector,
            address(GOLD),
            arbitraryAmount
        );

        // Set alice as beneficiary
        vm.prank(inflationController.OWNER_ADDRESS());
        inflationController.setBeneficiary(alice);

        // Make sure it reverts if trying to release from another address
        vm.startPrank(bob);
        vm.expectRevert("InflationController: not the beneficiary or owner");
        inflationController.release(address(GOLD));
    }
}
