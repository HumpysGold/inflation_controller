// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./utils.sol";
import "../src/interfaces/IBpt.sol";

contract Fixture is Test {
    IBpt public constant BPT = IBpt(0xE40cBcCba664C7B1a953827C062F5070B78de868);
    using stdStorage for StdStorage;

    Utils internal utils;
    address payable[] internal users;
    address internal alice;
    address internal bob;

    function setUp() public virtual {
        utils = new Utils();
        users = utils.createUsers(2);
        alice = users[0];
        bob = users[1];
    }

    function setStorage(
        address _user,
        bytes4 _selector,
        address _contract,
        uint256 value
    ) public {
        uint256 slot = stdstore
            .target(_contract)
            .sig(_selector)
            .with_key(_user)
            .find();
        vm.store(_contract, bytes32(slot), bytes32(value));
    }
}
