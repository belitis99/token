// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {StakingRewardsTestHelpers} from "../utils/StakingRewardsTestHelpers.t.sol";
import {Kwenta} from "../../../contracts/Kwenta.sol";
import {RewardEscrow} from "../../../contracts/RewardEscrow.sol";
import {SupplySchedule} from "../../../contracts/SupplySchedule.sol";
import {StakingRewardsV2} from "../../../contracts/StakingRewardsV2.sol";
import "../utils/Constants.t.sol";

contract StakingRewardsV2Test is StakingRewardsTestHelpers {
    event RewardsDurationUpdated(uint256 newDuration);

    /*//////////////////////////////////////////////////////////////
                        Constructor & Settings
    //////////////////////////////////////////////////////////////*/

    function testTokenSet() public {
        address token = address(stakingRewardsV2.token());
        assertEq(token, address(kwenta));
    }

    function testOwnerSet() public {
        address owner = stakingRewardsV2.owner();
        assertEq(owner, address(this));
    }

    function testRewardEscrowSet() public {
        address rewardEscrowAddress = address(stakingRewardsV2.rewardEscrow());
        assertEq(rewardEscrowAddress, address(rewardEscrow));
    }

    function testSupplyScheduleSet() public {
        address supplyScheduleAddress = address(
            stakingRewardsV2.supplySchedule()
        );
        assertEq(supplyScheduleAddress, address(supplySchedule));
    }

    /*//////////////////////////////////////////////////////////////
                        Function Permissions
    //////////////////////////////////////////////////////////////*/

    function testOnlySupplyScheduleCanCallNotifyRewardAmount() public {
        vm.expectRevert("StakingRewards: Only Supply Schedule");
        stakingRewardsV2.notifyRewardAmount(TEST_VALUE);
    }

    // TODO: test happy path - see fast forward in hardhat tests
    function testOnlyOwnerCanCallSetRewardsDuration() public {
        vm.prank(user1);
        vm.expectRevert("Only the contract owner may perform this action");
        stakingRewardsV2.setRewardsDuration(1 weeks);
    }

    function testOnlyOwnerCanCallRecoverERC20() public {
        vm.prank(user1);
        vm.expectRevert("Only the contract owner may perform this action");
        stakingRewardsV2.recoverERC20(address(kwenta), 0);
    }

    function testOnlyRewardEscrowCanCallStakeEscrow() public {
        vm.expectRevert("StakingRewards: Only Reward Escrow");
        stakingRewardsV2.stakeEscrow(address(this), TEST_VALUE);
    }

    function testOnlyRewardEscrowCanCallUnStakeEscrow() public {
        vm.expectRevert("StakingRewards: Only Reward Escrow");
        stakingRewardsV2.unstakeEscrow(address(this), TEST_VALUE);
    }

    function testCannotUnStakeEscrowInvalidAmount() public {
        vm.prank(address(rewardEscrow));
        vm.expectRevert("StakingRewards: Invalid Amount");
        stakingRewardsV2.unstakeEscrow(address(this), TEST_VALUE);
    }

    function testOnlyOwnerCanPauseContract() public {
        // attempt to pause
        vm.prank(user1);
        vm.expectRevert("Only the contract owner may perform this action");
        stakingRewardsV2.pauseStakingRewards();

        // pause
        stakingRewardsV2.pauseStakingRewards();

        // attempt to unpause
        vm.prank(user1);
        vm.expectRevert("Only the contract owner may perform this action");
        stakingRewardsV2.unpauseStakingRewards();

        // unpause
        stakingRewardsV2.unpauseStakingRewards();
    }

    function testOnlyOwnerCanNominateNewOwner() public {
        // attempt to nominate new owner
        vm.prank(user1);
        vm.expectRevert("Only the contract owner may perform this action");
        stakingRewardsV2.nominateNewOwner(address(this));

        // nominate new owner
        stakingRewardsV2.nominateNewOwner(address(user1));

        // attempt to accept ownership
        vm.prank(user2);
        vm.expectRevert(
            "You must be nominated before you can accept ownership"
        );
        stakingRewardsV2.acceptOwnership();

        // accept ownership
        vm.prank(user1);
        stakingRewardsV2.acceptOwnership();

        // check ownership
        assertEq(stakingRewardsV2.owner(), address(user1));
    }

    /*//////////////////////////////////////////////////////////////
                                Pausable
    //////////////////////////////////////////////////////////////*/

    function testCannotStakeWhenPaused() public {
        // pause
        stakingRewardsV2.pauseStakingRewards();

        // fund so that staking would succeed if not paused
        fundAndApproveAccount(address(this), TEST_VALUE);

        // attempt to stake
        vm.expectRevert("Pausable: paused");
        stakingRewardsV2.stake(TEST_VALUE);
    }

    function testCanStakeWhenUnpaused() public {
        // pause
        stakingRewardsV2.pauseStakingRewards();

        // unpause
        stakingRewardsV2.unpauseStakingRewards();

        // fund so that staking can succeed
        fundAndApproveAccount(address(this), TEST_VALUE);

        // stake
        stakingRewardsV2.stake(TEST_VALUE);
    }

    /*//////////////////////////////////////////////////////////////
                        External Rewards Recovery
    //////////////////////////////////////////////////////////////*/

    function testCannotRecoverStakingToken() public {
        vm.expectRevert("StakingRewards: Cannot unstake the staking token");
        stakingRewardsV2.recoverERC20(address(kwenta), TEST_VALUE);
    }

    function testCanRecoverNonStakingToken() public {
        // transfer in non staking tokens
        vm.prank(treasury);
        mockToken.transfer(address(stakingRewardsV2), TEST_VALUE);
        assertEq(mockToken.balanceOf(address(stakingRewardsV2)), TEST_VALUE);

        // recover non staking tokens
        stakingRewardsV2.recoverERC20(address(mockToken), TEST_VALUE);

        // check balances
        assertEq(mockToken.balanceOf(address(stakingRewardsV2)), 0);
        assertEq(mockToken.balanceOf(address(this)), TEST_VALUE);
    }

    /*//////////////////////////////////////////////////////////////
                        lastTimeRewardApplicable
    //////////////////////////////////////////////////////////////*/

    function testLastTimeRewardApplicable() public {
        // check periodFinish starts as 0
        assertEq(stakingRewardsV2.lastTimeRewardApplicable(), 0);

        // update reward amount
        vm.prank(address(supplySchedule));
        stakingRewardsV2.notifyRewardAmount(TEST_VALUE);

        // check last time reward applicable updated
        assertEq(stakingRewardsV2.lastTimeRewardApplicable(), block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                            rewardPerToken
    //////////////////////////////////////////////////////////////*/

    function testRewardPerToken() public {
        // fund so that staking can succeed
        uint256 stakedAmount = 1 weeks;
        fundAndApproveAccount(address(this), stakedAmount);

        // check reward per token starts as 0
        assertEq(stakingRewardsV2.rewardPerToken(), 0);

        // stake
        stakingRewardsV2.stake(stakedAmount);
        assertEq(stakingRewardsV2.totalSupply(), stakedAmount);

        // set rewards
        uint256 reward = stakedAmount;
        vm.prank(address(supplySchedule));
        stakingRewardsV2.notifyRewardAmount(reward);

        // ff to end of period
        vm.warp(block.timestamp + 1 weeks);

        // check reward per token updated
        assertEq(stakingRewardsV2.rewardPerToken(), 1 ether);
    }

    // // TODO: fuzz test this
    // function testRewardPerTokenFuzz() public {
    //     // get rewards duration
    //     uint256 rewardsDuration = stakingRewardsV2.rewardsDuration();

    //     // fund so that staking can succeed
    //     uint256 stakedAmount = TEST_VALUE;
    //     fundAndApproveAccount(address(this), stakedAmount);

    //     // check reward per token starts as 0
    //     assertEq(stakingRewardsV2.rewardPerToken(), 0);

    //     // stake
    //     stakingRewardsV2.stake(stakedAmount);
    //     uint256 totalSupply = stakingRewardsV2.totalSupply();
    //     assertEq(totalSupply, stakedAmount);

    //     // set rewards
    //     uint256 reward = rewardsDuration * 2;
    //     vm.prank(address(supplySchedule));
    //     stakingRewardsV2.notifyRewardAmount(reward);

    //     // ff to end of period
    //     vm.warp(block.timestamp + rewardsDuration);

    //     uint256 rewardPerToken = reward * 1e18 / totalSupply;

    //     // check reward per token updated
    //     assertEq(stakingRewardsV2.rewardPerToken(), rewardPerToken);
    // }

    /*//////////////////////////////////////////////////////////////
                                stake
    //////////////////////////////////////////////////////////////*/

    function testStakeIncreasesTokenBalance() public {
        uint256 initialBalance = kwenta.balanceOf(address(stakingRewardsV2));

        // fund so that staking can succeed
        fundAndApproveAccount(address(this), TEST_VALUE);

        // stake
        stakingRewardsV2.stake(TEST_VALUE);

        // check balance increased
        assertEq(
            kwenta.balanceOf(address(stakingRewardsV2)),
            initialBalance + TEST_VALUE
        );
    }

    function testStakeIncreasesBalancesMapping() public {
        uint256 initialBalance = stakingRewardsV2.balanceOf(address(this));

        // fund so that staking can succeed
        fundAndApproveAccount(address(this), TEST_VALUE);

        // stake
        stakingRewardsV2.stake(TEST_VALUE);

        // check balances mapping updated
        assertEq(
            stakingRewardsV2.balanceOf(address(this)),
            initialBalance + TEST_VALUE
        );
    }

    function testStakeDoesNotIncreaseEscrowedBalances() public {
        uint256 initialBalance = stakingRewardsV2.escrowedBalanceOf(
            address(this)
        );

        // fund so that staking can succeed
        fundAndApproveAccount(address(this), TEST_VALUE);

        // stake
        stakingRewardsV2.stake(TEST_VALUE);

        // check balances mapping updated
        assertEq(
            stakingRewardsV2.escrowedBalanceOf(address(this)),
            initialBalance
        );
    }

    function testStakeIncreasesTotalSupply() public {
        uint256 initialTotalSupply = stakingRewardsV2.totalSupply();

        // fund so that staking can succeed
        fundAndApproveAccount(address(this), TEST_VALUE);

        // stake
        stakingRewardsV2.stake(TEST_VALUE);

        // check total supply updated
        assertEq(
            stakingRewardsV2.totalSupply(),
            initialTotalSupply + TEST_VALUE
        );
    }

    function testCannotStake0() public {
        fundAndApproveAccount(address(this), TEST_VALUE);
        vm.expectRevert("StakingRewards: Cannot stake 0");
        stakingRewardsV2.stake(0);
    }

    /*//////////////////////////////////////////////////////////////
                                stakeEscrow
    //////////////////////////////////////////////////////////////*/

    function testEscrowStakingDoesNotIncreaseTokenBalance() public {
        uint256 initialBalance = kwenta.balanceOf(address(stakingRewardsV2));

        // stake
        vm.prank(address(rewardEscrow));
        stakingRewardsV2.stakeEscrow(address(this), TEST_VALUE);

        // check balance increased
        assertEq(kwenta.balanceOf(address(stakingRewardsV2)), initialBalance);
    }

    function testEscrowStakingIncreasesBalancesMapping() public {
        uint256 initialBalance = stakingRewardsV2.balanceOf(address(this));

        // stake
        vm.prank(address(rewardEscrow));
        stakingRewardsV2.stakeEscrow(address(this), TEST_VALUE);

        // check balances mapping updated
        assertEq(
            stakingRewardsV2.balanceOf(address(this)),
            initialBalance + TEST_VALUE
        );
    }

    function testEscrowStakingIncreasesEscrowedBalances() public {
        uint256 initialBalance = stakingRewardsV2.escrowedBalanceOf(
            address(this)
        );

        // stake
        vm.prank(address(rewardEscrow));
        stakingRewardsV2.stakeEscrow(address(this), TEST_VALUE);

        // check balances mapping updated
        assertEq(
            stakingRewardsV2.escrowedBalanceOf(address(this)),
            initialBalance + TEST_VALUE
        );
    }

    function testEscrowStakingIncreasesTotalSupply() public {
        uint256 initialTotalSupply = stakingRewardsV2.totalSupply();

        // stake
        vm.prank(address(rewardEscrow));
        stakingRewardsV2.stakeEscrow(address(this), TEST_VALUE);

        // check total supply updated
        assertEq(
            stakingRewardsV2.totalSupply(),
            initialTotalSupply + TEST_VALUE
        );
    }

    function testCannotEscrowStake0() public {
        vm.prank(address(rewardEscrow));
        vm.expectRevert("StakingRewards: Cannot stake 0");
        stakingRewardsV2.stakeEscrow(address(this), 0);
    }

    // TODO: test happy path for this
    function testCannotUnstakeStakedEscrow() public {
        // stake escrow
        vm.prank(address(rewardEscrow));
        stakingRewardsV2.stakeEscrow(address(this), TEST_VALUE);

        // this would work if unstakeEscrow was called
        // but unstake is called so it fails
        vm.expectRevert("StakingRewards: Invalid Amount");
        stakingRewardsV2.unstake(TEST_VALUE);
    }

    function testCannotExitWithOnlyEscrowStakedBalance() public {
        // stake escrow
        vm.prank(address(rewardEscrow));
        stakingRewardsV2.stakeEscrow(address(this), TEST_VALUE);

        // exit - this fails because exit uses unstake not unstakeEscrow
        vm.expectRevert("StakingRewards: Cannot Unstake 0");
        stakingRewardsV2.exit();
    }

    function testExit() public {
        uint256 nonEscrowStakedBalance = TEST_VALUE / 2;
        uint256 escrowStakedBalance = TEST_VALUE;

        // transfer kwenta to this address
        vm.prank(treasury);
        kwenta.transfer(address(this), nonEscrowStakedBalance);

        // stake non-escrowed kwenta
        kwenta.approve(address(stakingRewardsV2), nonEscrowStakedBalance);
        stakingRewardsV2.stake(nonEscrowStakedBalance);

        // stake escrowed kwenta
        vm.prank(address(rewardEscrow));
        stakingRewardsV2.stakeEscrow(address(this), escrowStakedBalance);

        // exit
        stakingRewardsV2.exit();

        // check only non-escrow staked balance has been returned after exit
        assertEq(kwenta.balanceOf(address(this)), nonEscrowStakedBalance);
    }

    /*//////////////////////////////////////////////////////////////
                                earned
    //////////////////////////////////////////////////////////////*/

    function testNoRewardsWhenNotStaking() public {
        assertEq(stakingRewardsV2.earned(address(this)), 0);
    }

    function testEarnedIncreasesAfterStaking() public {
        fundAndApproveAccount(address(this), TEST_VALUE);

        // stake
        stakingRewardsV2.stake(TEST_VALUE);

        // configure reward rate
        vm.prank(address(supplySchedule));
        stakingRewardsV2.notifyRewardAmount(TEST_VALUE);

        // fast forward 2 weeks
        vm.warp(2 weeks);

        // check some stake has been earned
        assertTrue(stakingRewardsV2.earned(address(this)) > 0);
    }

    function testRewardRateShouldIncreaseIfNewRewardsComeBeforeDurationEnds()
        public
    {
        fundAndApproveAccount(address(this), 1 weeks);

        uint256 totalToDistribute = 5 ether;

        // stake
        stakingRewardsV2.stake(1 weeks);

        // send kwenta to stakingRewardsV2 contract
        vm.prank(treasury);
        kwenta.transfer(address(stakingRewardsV2), totalToDistribute);

        // configure reward rate
        vm.prank(address(supplySchedule));
        stakingRewardsV2.notifyRewardAmount(totalToDistribute);

        uint256 initialRewardRate = stakingRewardsV2.rewardRate();

        vm.prank(treasury);
        kwenta.transfer(address(stakingRewardsV2), totalToDistribute);

        // increase reward rate further
        vm.prank(address(supplySchedule));
        stakingRewardsV2.notifyRewardAmount(totalToDistribute);

        uint256 finalRewardRate = stakingRewardsV2.rewardRate();

        assertEq(finalRewardRate / 2, initialRewardRate);
    }

    function testRewardTokenBalanceRollsOverAfterDuration() public {
        fundAndApproveAccount(address(this), 1 weeks);

        // stake
        stakingRewardsV2.stake(1 weeks);

        // configure reward rate
        vm.prank(address(supplySchedule));
        stakingRewardsV2.notifyRewardAmount(1 weeks);

        // fast forward 1 weeks
        vm.warp(block.timestamp + 1 weeks);
        uint256 initialEarnings = stakingRewardsV2.earned(address(this));

        // configure same reward week for the following period
        vm.prank(address(supplySchedule));
        stakingRewardsV2.notifyRewardAmount(1 weeks);

        vm.warp(block.timestamp + 2 weeks);

        uint256 finalEarnings = stakingRewardsV2.earned(address(this));

        assertEq(finalEarnings, initialEarnings * 2);
    }

    /*//////////////////////////////////////////////////////////////
                                getReward
    //////////////////////////////////////////////////////////////*/

    function testGetRewardIncreasesBalanceInEscrow() public {
        fundAndApproveAccount(address(this), TEST_VALUE);

        uint256 initialEscrowBalance = rewardEscrow.balanceOf(address(this));

        // stake
        stakingRewardsV2.stake(TEST_VALUE);

        // configure reward rate
        vm.prank(address(supplySchedule));
        stakingRewardsV2.notifyRewardAmount(TEST_VALUE);

        // fast forward 2 weeks
        vm.warp(2 weeks);

        // get reward
        stakingRewardsV2.getReward();

        // check reward escrow balance increased
        assertGt(rewardEscrow.balanceOf(address(this)), initialEscrowBalance);
    }

    /*//////////////////////////////////////////////////////////////
                            setRewardsDuration
    //////////////////////////////////////////////////////////////*/

    function testSetRewardsDurationBeforeDistribution() public {
        uint256 defaultDuration = stakingRewardsV2.rewardsDuration();
        assertEq(defaultDuration, 1 weeks);

        stakingRewardsV2.setRewardsDuration(30 days);

        assertEq(stakingRewardsV2.rewardsDuration(), 30 days);
    }

    function testSetRewardDurationBeforePeriodFinished() public {
        fundAndApproveAccount(address(this), TEST_VALUE);

        // stake
        stakingRewardsV2.stake(TEST_VALUE);

        // configure reward rate
        vm.prank(address(supplySchedule));
        stakingRewardsV2.notifyRewardAmount(TEST_VALUE);

        // fast 1 day
        vm.warp(1 days);

        // set rewards duration
        vm.expectRevert(
            "StakingRewards: Previous rewards period must be complete before changing the duration for the new period"
        );
        stakingRewardsV2.setRewardsDuration(30 days);
    }

    function testSetRewardsDurationAfterPeriodHasFinished() public {
        fundAndApproveAccount(address(this), TEST_VALUE);

        // stake
        stakingRewardsV2.stake(TEST_VALUE);

        // configure reward rate
        vm.prank(address(supplySchedule));
        stakingRewardsV2.notifyRewardAmount(TEST_VALUE);

        // fast forward 2 weeks
        vm.warp(2 weeks);

        // set rewards duration
        vm.expectEmit(true, true, false, false);
        emit RewardsDurationUpdated(30 days);
        stakingRewardsV2.setRewardsDuration(30 days);

        assertEq(stakingRewardsV2.rewardsDuration(), 30 days);

        vm.prank(address(supplySchedule));
        stakingRewardsV2.notifyRewardAmount(TEST_VALUE);
    }

    function testUpdateDurationAfterPeriodHasFinishedAndGetRewards() public {
        fundAndApproveAccount(address(this), TEST_VALUE);

        // stake
        stakingRewardsV2.stake(TEST_VALUE);

        // configure reward rate
        vm.prank(address(supplySchedule));
        stakingRewardsV2.notifyRewardAmount(30 days);

        // fast forward 2 weeks
        vm.warp(block.timestamp + 1 weeks);
        stakingRewardsV2.getReward();
        vm.warp(block.timestamp + 1 weeks);

        // set rewards duration
        vm.expectEmit(true, true, false, false);
        emit RewardsDurationUpdated(30 days);
        stakingRewardsV2.setRewardsDuration(30 days);

        assertEq(stakingRewardsV2.rewardsDuration(), 30 days);

        vm.warp(block.timestamp + 1 weeks);
        stakingRewardsV2.getReward();
    }

    /*//////////////////////////////////////////////////////////////
                            getRewardForDuration
    //////////////////////////////////////////////////////////////*/

    function testGetRewardForDuration() public {
        vm.prank(treasury);
        kwenta.transfer(address(stakingRewardsV2), TEST_VALUE);

        vm.prank(address(supplySchedule));
        stakingRewardsV2.notifyRewardAmount(TEST_VALUE);

        uint256 rewardForDuration = stakingRewardsV2.getRewardForDuration();
        uint256 duration = stakingRewardsV2.rewardsDuration();
        uint256 rewardRate = stakingRewardsV2.rewardRate();

        assertGt(rewardForDuration, 0);
        assertEq(rewardForDuration, rewardRate * duration);
    }

    /*//////////////////////////////////////////////////////////////
                                unstake
    //////////////////////////////////////////////////////////////*/

    function testCannotUnstakeIfNothingStaked() public {
        vm.expectRevert("StakingRewards: Invalid Amount");
        stakingRewardsV2.unstake(TEST_VALUE);
    }

    function testUnstakingTokenAndStakingBalanceUpdates() public {
        fundAndApproveAccount(address(this), TEST_VALUE);

        stakingRewardsV2.stake(TEST_VALUE);

        uint256 initialTokenBalance = kwenta.balanceOf(address(this));
        uint256 initialStakingBalance = stakingRewardsV2.balanceOf(address(this));

        stakingRewardsV2.unstake(TEST_VALUE);

        uint256 finalTokenBalance = kwenta.balanceOf(address(this));
        uint256 finalStakingBalance = stakingRewardsV2.balanceOf(address(this));

        assertEq(finalStakingBalance + TEST_VALUE, initialStakingBalance);
        assertEq(finalTokenBalance - TEST_VALUE, initialTokenBalance);

    }
}
