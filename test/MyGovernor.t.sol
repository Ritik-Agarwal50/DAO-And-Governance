//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {TimeLock} from "../src/TimeLock.sol";
import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";

contract MyGovernorTest is Test {
    MyGovernor governor;
    TimeLock timelock;
    Box box;
    GovToken token;

    address[] proposers;
    address[] executors;

    uint256[] values;
    bytes[] calldatas;
    address[] targets;

    uint constant VOTING_PERIOD = 50400;

    address public USER = makeAddr("USER");

    function setUp() public {
        token = new GovToken();
        token.mint(USER, 1000);

        vm.prank(USER);
        token.delegate(USER);
        timelock = new TimeLock(3600, proposers, executors);
        governor = new MyGovernor(token, timelock);
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.TIMELOCK_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, msg.sender);

        box = new Box();

        box.transferOwnership(address(timelock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testGoveranceUpdateBox() public {
        uint256 valuToStore = 121;
        string memory description = "Store some value in box";
        bytes memory encodedFunctionCall = abi.encodeWithSignature(
            "store(uint256)",
            valuToStore
        );
        values.push(0);
        calldatas.push(encodedFunctionCall);
        targets.push(address(box));

        //Propose to DAo

        uint256 proposalId = governor.propose(
            targets,
            values,
            calldatas,
            description
        );

        vm.warp(block.timestamp + 1 + 1);
        vm.roll(block.number + 1 + 1);

        //vote

        string memory reason = "I am Cool af!!";
        uint8 voteWay = 1;
        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        //QUEUE TO DAO

        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.roll(block.number + 3600 + 1);
        vm.warp(block.timestamp + 3600 + 1);

        //execute

        governor.execute(targets, values, calldatas, descriptionHash);

        assert(box.getNumber() == valuToStore);
    }
}
