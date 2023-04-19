// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {StakingRewardsTestHelpers} from "../utils/StakingRewardsTestHelpers.t.sol";
import {Kwenta} from "../../../contracts/Kwenta.sol";
import {RewardEscrow} from "../../../contracts/RewardEscrow.sol";
import {SupplySchedule} from "../../../contracts/SupplySchedule.sol";
import {StakingRewardsV2} from "../../../contracts/StakingRewardsV2.sol";
import "../utils/Constants.t.sol";

contract StakingV2CheckpointingTests is StakingRewardsTestHelpers {
    /*//////////////////////////////////////////////////////////////
                        Balance Checkpoint Tests
    //////////////////////////////////////////////////////////////*/

    function testBalancesCheckpointsAreUpdated() public {
        // stake
        stakeFundsV2(address(this), TEST_VALUE);

        // get last checkpoint
        (uint256 blockNum, uint256 value) = stakingRewardsV2.balances(address(this), 0);

        // check values
        assertEq(blockNum, block.number);
        assertEq(value, TEST_VALUE);

        // move beyond cold period
        vm.warp(block.timestamp + stakingRewardsV2.unstakingCooldownPeriod());

        // update block number
        vm.roll(block.number + 1);

        // unstake
        stakingRewardsV2.unstake(TEST_VALUE);

        // get last checkpoint
        (blockNum, value) = stakingRewardsV2.balances(address(this), 1);

        // check values
        assertEq(blockNum, block.number);
        assertEq(value, 0);
    }

    function testBalancesCheckpointsAreUpdatedEscrowStaking() public {
        // stake
        stakeEscrowedFundsV2(address(this), TEST_VALUE);

        // get last checkpoint
        (uint256 blockNum, uint256 value) = stakingRewardsV2.balances(address(this), 0);

        // check values
        assertEq(blockNum, block.number);
        assertEq(value, TEST_VALUE);

        // move beyond cold period
        vm.warp(block.timestamp + stakingRewardsV2.unstakingCooldownPeriod());

        // update block number
        vm.roll(block.number + 1);

        // unstake
        unstakeEscrowedFundsV2(address(this), TEST_VALUE);

        // get last checkpoint
        (blockNum, value) = stakingRewardsV2.balances(address(this), 1);

        // check values
        assertEq(blockNum, block.number);
        assertEq(value, 0);
    }

    function testBalancesCheckpointsAreUpdatedFuzz(uint32 maxAmountStaked, uint8 numberOfRounds) public {
        vm.assume(maxAmountStaked > 0);
        // keep the number of rounds low to keep tests fast
        vm.assume(numberOfRounds < 50);

        // Stake and unstake in each iteration/round and check that the checkpoints are updated correctly
        for (uint8 i = 0; i < numberOfRounds; i++) {
            // get random values for each round
            uint256 amountToStake = getPseudoRandomNumber(maxAmountStaked, 1, i);
            uint256 amountToUnstake = getPseudoRandomNumber(amountToStake, 1, i);
            uint256 blockAdvance = getPseudoRandomNumber(amountToUnstake, 0, i);

            // get initial values
            uint256 previousTotal = stakingRewardsV2.balanceOf(address(this));

            // stake
            stakeFundsV2(address(this), amountToStake);

            // get last checkpoint
            uint256 length = stakingRewardsV2.balancesLength(address(this));
            uint256 finalIndex = length == 0 ? 0 : length - 1;
            (uint256 blockNum, uint256 value) = stakingRewardsV2.balances(address(this), finalIndex);

            // check checkpoint values
            assertEq(blockNum, block.number);
            assertEq(value, previousTotal + amountToStake);

            // move beyond cold period
            vm.warp(block.timestamp + stakingRewardsV2.unstakingCooldownPeriod());

            // update block number
            vm.roll(block.number + blockAdvance);

            // // unstake
            stakingRewardsV2.unstake(amountToUnstake);

            // get last checkpoint
            uint256 newIndex = finalIndex;
            if (blockAdvance > 0) {
                newIndex += 1;
            }
            (blockNum, value) = stakingRewardsV2.balances(address(this), newIndex);

            // check checkpoint values
            assertEq(blockNum, block.number);
            assertEq(value, previousTotal + amountToStake - amountToUnstake);

            // update block number
            vm.roll(block.number + blockAdvance);
        }
    }

    function testBalancesCheckpointsAreUpdatedEscrowStakedFuzz(uint32 maxAmountStaked, uint8 numberOfRounds) public {
        vm.assume(maxAmountStaked > 0);
        // keep the number of rounds low to keep tests fast
        vm.assume(numberOfRounds < 50);

        // Stake and unstake in each iteration/round and check that the checkpoints are updated correctly
        for (uint8 i = 0; i < numberOfRounds; i++) {
            // get random values for each round
            uint256 amountToStake = getPseudoRandomNumber(maxAmountStaked, 1, i);
            uint256 amountToUnstake = getPseudoRandomNumber(amountToStake, 1, i);
            uint256 blockAdvance = getPseudoRandomNumber(amountToUnstake, 0, i);

            // get initial values
            uint256 previousTotal = stakingRewardsV2.balanceOf(address(this));

            // stake
            stakeEscrowedFundsV2(address(this), amountToStake);

            // get last checkpoint
            uint256 length = stakingRewardsV2.balancesLength(address(this));
            uint256 finalIndex = length == 0 ? 0 : length - 1;
            (uint256 blockNum, uint256 value) = stakingRewardsV2.balances(address(this), finalIndex);

            // check checkpoint values
            assertEq(blockNum, block.number);
            assertEq(value, previousTotal + amountToStake);

            // move beyond cold period
            vm.warp(block.timestamp + stakingRewardsV2.unstakingCooldownPeriod());

            // update block number
            vm.roll(block.number + blockAdvance);

            // unstake
            unstakeEscrowedFundsV2(address(this), amountToUnstake);

            // get last checkpoint
            uint256 newIndex = finalIndex;
            if (blockAdvance > 0) {
                newIndex += 1;
            }
            (blockNum, value) = stakingRewardsV2.balances(address(this), newIndex);

            // check checkpoint values
            assertEq(blockNum, block.number);
            assertEq(value, previousTotal + amountToStake - amountToUnstake);

            // update block number
            vm.roll(block.number + blockAdvance);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    Escrowed Balance Checkpoint Tests
    //////////////////////////////////////////////////////////////*/

    function testEscrowedBalancesCheckpointsAreUpdated() public {
        // stake
        stakeEscrowedFundsV2(address(this), TEST_VALUE);

        // get last checkpoint
        (uint256 blockNum, uint256 value) = stakingRewardsV2.escrowedBalances(address(this), 0);

        // check values
        assertEq(blockNum, block.number);
        assertEq(value, TEST_VALUE);

        // move beyond cold period
        vm.warp(block.timestamp + stakingRewardsV2.unstakingCooldownPeriod());

        // update block number
        vm.roll(block.number + 1);

        // unstake
        unstakeEscrowedFundsV2(address(this), TEST_VALUE);

        // get last checkpoint
        (blockNum, value) = stakingRewardsV2.escrowedBalances(address(this), 1);

        // check values
        assertEq(blockNum, block.number);
        assertEq(value, 0);
    }

    function testEscrowedBalancesCheckpointsAreUpdatedFuzz(uint32 maxAmountStaked, uint8 numberOfRounds) public {
        vm.assume(maxAmountStaked > 0);
        // keep the number of rounds low to keep tests fast
        vm.assume(numberOfRounds < 50);

        // Stake and unstake in each iteration/round and check that the checkpoints are updated correctly
        for (uint8 i = 0; i < numberOfRounds; i++) {
            // get random values for each round
            uint256 amountToStake = getPseudoRandomNumber(maxAmountStaked, 1, i);
            uint256 amountToUnstake = getPseudoRandomNumber(amountToStake, 1, i);
            uint256 blockAdvance = getPseudoRandomNumber(amountToUnstake, 0, i);

            // get initial values
            uint256 previousTotal = stakingRewardsV2.balanceOf(address(this));

            // stake
            stakeEscrowedFundsV2(address(this), amountToStake);

            // get last checkpoint
            uint256 length = stakingRewardsV2.escrowedBalancesLength(address(this));
            uint256 finalIndex = length == 0 ? 0 : length - 1;
            (uint256 blockNum, uint256 value) = stakingRewardsV2.escrowedBalances(address(this), finalIndex);

            // check checkpoint values
            assertEq(blockNum, block.number);
            assertEq(value, previousTotal + amountToStake);

            // move beyond cold period
            vm.warp(block.timestamp + stakingRewardsV2.unstakingCooldownPeriod());

            // update block number
            vm.roll(block.number + blockAdvance);

            // // unstake
            unstakeEscrowedFundsV2(address(this), amountToUnstake);

            // get last checkpoint
            uint256 newIndex = finalIndex;
            if (blockAdvance > 0) {
                newIndex += 1;
            }
            (blockNum, value) = stakingRewardsV2.escrowedBalances(address(this), newIndex);

            // check checkpoint values
            assertEq(blockNum, block.number);
            assertEq(value, previousTotal + amountToStake - amountToUnstake);

            // update block number
            vm.roll(block.number + blockAdvance);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    Total Supply Checkpoint Tests
    //////////////////////////////////////////////////////////////*/

    function testTotalSupplyCheckpointsAreUpdated() public {
        // stake
        stakeFundsV2(address(this), TEST_VALUE);

        // get last checkpoint
        (uint256 blockNum, uint256 value) = stakingRewardsV2._totalSupply(0);

        // check values
        assertEq(blockNum, block.number);
        assertEq(value, TEST_VALUE);

        // move beyond cold period
        vm.warp(block.timestamp + stakingRewardsV2.unstakingCooldownPeriod());

        // update block number
        vm.roll(block.number + 1);

        // unstake
        stakingRewardsV2.unstake(TEST_VALUE);

        // get last checkpoint
        (blockNum, value) = stakingRewardsV2._totalSupply(1);

        // check values
        assertEq(blockNum, block.number);
        assertEq(value, 0);
    }

    function testTotalSupplyCheckpointsAreUpdatedEscrowStaked() public {
        // stake
        stakeEscrowedFundsV2(address(this), TEST_VALUE);

        // get last checkpoint
        (uint256 blockNum, uint256 value) = stakingRewardsV2._totalSupply(0);

        // check values
        assertEq(blockNum, block.number);
        assertEq(value, TEST_VALUE);

        // move beyond cold period
        vm.warp(block.timestamp + stakingRewardsV2.unstakingCooldownPeriod());

        // update block number
        vm.roll(block.number + 1);

        // unstake
        unstakeEscrowedFundsV2(address(this), TEST_VALUE);

        // get last checkpoint
        (blockNum, value) = stakingRewardsV2._totalSupply(1);

        // check values
        assertEq(blockNum, block.number);
        assertEq(value, 0);
    }

    function testTotalSupplyCheckpointsAreUpdatedFuzz(uint32 maxAmountStaked, uint8 numberOfRounds) public {
        vm.assume(maxAmountStaked > 0);
        // keep the number of rounds low to keep tests fast
        vm.assume(numberOfRounds < 50);

        // Stake and unstake in each iteration/round and check that the checkpoints are updated correctly
        for (uint8 i = 0; i < numberOfRounds; i++) {
            // get random values for each round
            uint256 amountToStake = getPseudoRandomNumber(maxAmountStaked, 1, i);
            uint256 amountToUnstake = getPseudoRandomNumber(amountToStake, 1, i);
            uint256 blockAdvance = getPseudoRandomNumber(amountToUnstake, 0, i);
            bool escrowStake = flipCoin(blockAdvance);

            // get initial values
            uint256 previousTotal = stakingRewardsV2.balanceOf(address(this));

            // stake
            if (escrowStake) {
                stakeEscrowedFundsV2(address(this), amountToStake);
            } else {
                stakeFundsV2(address(this), amountToStake);
            }

            // get last checkpoint
            uint256 length = stakingRewardsV2.totalSupplyLength();
            uint256 finalIndex = length == 0 ? 0 : length - 1;
            (uint256 blockNum, uint256 value) = stakingRewardsV2._totalSupply(finalIndex);

            // check checkpoint values
            assertEq(blockNum, block.number);
            assertEq(value, previousTotal + amountToStake);

            // move beyond cold period
            vm.warp(block.timestamp + stakingRewardsV2.unstakingCooldownPeriod());

            // update block number
            vm.roll(block.number + blockAdvance);

            // unstake
            if (escrowStake) {
                unstakeEscrowedFundsV2(address(this), amountToUnstake);
            } else {
                stakingRewardsV2.unstake(amountToUnstake);
            }

            // get last checkpoint
            uint256 newIndex = finalIndex;
            if (blockAdvance > 0) {
                newIndex += 1;
            }
            (blockNum, value) = stakingRewardsV2._totalSupply(newIndex);

            // check checkpoint values
            assertEq(blockNum, block.number);
            assertEq(value, previousTotal + amountToStake - amountToUnstake);

            // update block number
            vm.roll(block.number + blockAdvance);
        }
    }

    /*//////////////////////////////////////////////////////////////
                    Binary Search Balance Checkpoints
    //////////////////////////////////////////////////////////////*/

    function testBalanceAtBlock() public {
        uint256 blockToFind = 4;
        uint256 expectedValue;
        uint256 totalStaked;

        for (uint256 i = 0; i < 10; i++) {
            uint256 amount = TEST_VALUE * (i + 1);
            totalStaked += amount;
            if (blockToFind == block.number) {
                expectedValue = totalStaked;
            }
            stakeFundsV2(address(this), amount);
            vm.roll(block.number + 1);
        }

        uint256 value = stakingRewardsV2.balanceAtBlock(address(this), blockToFind);

        assertEq(value, expectedValue);
    }

    function testBalanceAtBlockAtEachBlock() public {
        vm.roll(3);
        stakeFundsV2(address(this), 1);

        vm.roll(6);
        stakeFundsV2(address(this), 1);

        vm.roll(8);
        stakeFundsV2(address(this), 1);

        vm.roll(12);
        stakeFundsV2(address(this), 1);

        vm.roll(23);
        stakeFundsV2(address(this), 1);

        uint256 value;

        for (uint256 i = 0; i < 30; i++) {
            value = stakingRewardsV2.balanceAtBlock(address(this), i);
            if (i < 3) {
                assertEq(value, 0);
            } else if (i < 6) {
                assertEq(value, 1);
            } else if (i < 8) {
                assertEq(value, 2);
            } else if (i < 12) {
                assertEq(value, 3);
            } else if (i < 23) {
                assertEq(value, 4);
            } else {
                assertEq(value, 5);
            }
        }
    }

    function testBalanceAtBlockFuzz(uint256 blockToFind, uint8 numberOfRounds) public {
        vm.assume(numberOfRounds < 50);
        vm.assume(blockToFind > 0);

        uint256 expectedValue;
        uint256 totalStaked;
        bool notYetPassedBlock = true;

        for (uint256 i = 0; i < numberOfRounds; i++) {
            // get random values
            uint256 amount = getPseudoRandomNumber(1 ether, 1, blockToFind);
            uint256 blockAdvance = getPseudoRandomNumber(1000, 0, amount);

            // if we are at the block to find, set the expected value
            if (block.number == blockToFind) {
                expectedValue = totalStaked + amount;
                notYetPassedBlock = false;
                // otherwise if we just passed the block to find, set the expected value
            } else if (block.number > blockToFind && notYetPassedBlock) {
                expectedValue = totalStaked;
                notYetPassedBlock = false;
            }

            // stake funds
            stakeFundsV2(address(this), amount);
            totalStaked += amount;

            // don't advance the block if we are on the last round
            if (i != numberOfRounds - 1) vm.roll(block.number + blockAdvance);
        }

        uint256 value = stakingRewardsV2.balanceAtBlock(address(this), blockToFind);
        // if we are before the block to find, the expected value is the total staked
        if (blockToFind > block.number) {
            assertEq(value, totalStaked);
        } else {
            // otherwise, the expected value is the value at the block to find
            assertEq(value, expectedValue);
        }
    }

    /*//////////////////////////////////////////////////////////////
                Binary Search EscrowBalance Checkpoints
    //////////////////////////////////////////////////////////////*/

    function testEscrowBalanceAtBlock() public {
        uint256 blockToFind = 4;
        uint256 expectedValue;
        uint256 totalStaked;

        for (uint256 i = 0; i < 10; i++) {
            uint256 amount = TEST_VALUE * (i + 1);
            totalStaked += amount;
            if (blockToFind == block.number) {
                expectedValue = totalStaked;
            }
            stakeEscrowedFundsV2(address(this), amount);
            vm.roll(block.number + 1);
        }

        uint256 value = stakingRewardsV2.escrowedBalanceAtBlock(address(this), blockToFind);

        assertEq(value, expectedValue);
    }

    function testEscrowBalanceAtBlockAtEachBlock() public {
        vm.roll(3);
        stakeEscrowedFundsV2(address(this), 1);

        vm.roll(6);
        stakeEscrowedFundsV2(address(this), 1);

        vm.roll(8);
        stakeEscrowedFundsV2(address(this), 1);

        vm.roll(12);
        stakeEscrowedFundsV2(address(this), 1);

        vm.roll(23);
        stakeEscrowedFundsV2(address(this), 1);

        uint256 value;

        for (uint256 i = 0; i < 30; i++) {
            value = stakingRewardsV2.escrowedBalanceAtBlock(address(this), i);
            if (i < 3) {
                assertEq(value, 0);
            } else if (i < 6) {
                assertEq(value, 1);
            } else if (i < 8) {
                assertEq(value, 2);
            } else if (i < 12) {
                assertEq(value, 3);
            } else if (i < 23) {
                assertEq(value, 4);
            } else {
                assertEq(value, 5);
            }
        }
    }

    function testEscrowBalanceAtBlockFuzz(uint256 blockToFind, uint8 numberOfRounds) public {
        vm.assume(numberOfRounds < 50);
        vm.assume(blockToFind > 0);

        uint256 expectedValue;
        uint256 totalStaked;
        bool notYetPassedBlock = true;

        for (uint256 i = 0; i < numberOfRounds; i++) {
            // get random values
            uint256 amount = getPseudoRandomNumber(1 ether, 1, blockToFind);
            uint256 blockAdvance = getPseudoRandomNumber(1000, 0, amount);

            // if we are at the block to find, set the expected value
            if (block.number == blockToFind) {
                expectedValue = totalStaked + amount;
                notYetPassedBlock = false;
                // otherwise if we just passed the block to find, set the expected value
            } else if (block.number > blockToFind && notYetPassedBlock) {
                expectedValue = totalStaked;
                notYetPassedBlock = false;
            }

            // stake funds
            stakeEscrowedFundsV2(address(this), amount);
            totalStaked += amount;

            // don't advance the block if we are on the last round
            if (i != numberOfRounds - 1) vm.roll(block.number + blockAdvance);
        }

        uint256 value = stakingRewardsV2.escrowedBalanceAtBlock(address(this), blockToFind);
        // if we are before the block to find, the expected value is the total staked
        if (blockToFind > block.number) {
            assertEq(value, totalStaked);
        } else {
            // otherwise, the expected value is the value at the block to find
            assertEq(value, expectedValue);
        }
    }

    /*//////////////////////////////////////////////////////////////
                Binary Search TotalSupply Checkpoints
    //////////////////////////////////////////////////////////////*/

    function testTotalSupplyAtBlock() public {
        uint256 blockToFind = 4;
        uint256 expectedValue;
        uint256 totalStaked;

        for (uint256 i = 0; i < 10; i++) {
            uint256 amount = TEST_VALUE * (i + 1);
            totalStaked += amount;
            if (blockToFind == block.number) {
                expectedValue = totalStaked;
            }
            if (flipCoin()) stakeFundsV2(address(this), amount);
            else stakeEscrowedFundsV2(address(this), amount);

            vm.roll(block.number + 1);
        }

        uint256 value = stakingRewardsV2.totalSupplyAtBlock(blockToFind);
        assertEq(value, expectedValue);
    }

    function testTotalSupplyAtBlockAtEachBlock() public {
        vm.roll(3);
        stakeEscrowedFundsV2(address(this), 1);

        vm.roll(6);
        stakeFundsV2(address(this), 1);

        vm.roll(8);
        stakeEscrowedFundsV2(address(this), 1);

        vm.roll(12);
        stakeFundsV2(address(this), 1);

        vm.roll(23);
        stakeEscrowedFundsV2(address(this), 1);

        uint256 value;

        for (uint256 i = 0; i < 30; i++) {
            value = stakingRewardsV2.totalSupplyAtBlock(i);
            if (i < 3) {
                assertEq(value, 0);
            } else if (i < 6) {
                assertEq(value, 1);
            } else if (i < 8) {
                assertEq(value, 2);
            } else if (i < 12) {
                assertEq(value, 3);
            } else if (i < 23) {
                assertEq(value, 4);
            } else {
                assertEq(value, 5);
            }
        }
    }

    function testTotalSupplyeAtBlockFuzz(uint256 blockToFind, uint8 numberOfRounds) public {
        vm.assume(numberOfRounds < 50);
        vm.assume(blockToFind > 0);

        uint256 expectedValue;
        uint256 totalStaked;
        bool notYetPassedBlock = true;

        for (uint256 i = 0; i < numberOfRounds; i++) {
            // get random values
            uint256 amount = getPseudoRandomNumber(1 ether, 1, blockToFind);
            uint256 blockAdvance = getPseudoRandomNumber(1000, 0, amount);

            // if we are at the block to find, set the expected value
            if (block.number == blockToFind) {
                expectedValue = totalStaked + amount;
                notYetPassedBlock = false;
                // otherwise if we just passed the block to find, set the expected value
            } else if (block.number > blockToFind && notYetPassedBlock) {
                expectedValue = totalStaked;
                notYetPassedBlock = false;
            }

            // stake funds
            if (flipCoin()) {
                stakeFundsV2(address(this), amount);
            } else {
                stakeEscrowedFundsV2(address(this), amount);
            }
            totalStaked += amount;

            // don't advance the block if we are on the last round
            if (i != numberOfRounds - 1) vm.roll(block.number + blockAdvance);
        }

        uint256 value = stakingRewardsV2.totalSupplyAtBlock(blockToFind);
        // if we are before the block to find, the expected value is the total staked
        if (blockToFind > block.number) {
            assertEq(value, totalStaked);
        } else {
            // otherwise, the expected value is the value at the block to find
            assertEq(value, expectedValue);
        }
    }
}
