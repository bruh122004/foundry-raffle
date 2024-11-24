// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {Test, console} from "forge-std/Test.sol";

contract DecentralizedStableCoinTest is Test {
    DecentralizedStableCoin stableCoin;
    address public idir = makeAddr("idir");
    address public user = makeAddr("amin");
    uint256 public constant INITIAL_AMOUNT = 10e18;

    function setUp() public {
        vm.startBroadcast(address(this));
        stableCoin = new DecentralizedStableCoin();
        vm.stopBroadcast();
    }

    function test_mintRevertwithAddressZero() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin_CantMintToAddressZero.selector);
        vm.prank(address(this));
        stableCoin.mint(address(0), INITIAL_AMOUNT);
    }

    function test_mintRevertWithZeroAmmount() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin_AmountMustNotBeZero.selector);
        vm.prank(address(this));
        stableCoin.mint(user, 0);
    }

    function test_mintingWasSuccessfull() public {
        vm.prank(address(this));
        stableCoin.mint(user, INITIAL_AMOUNT);

        assertEq(stableCoin.balanceOf(user), INITIAL_AMOUNT);
    }

    function test_burnRevertWhenAmmountislessOrZero() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin_AmountMustNotBeZero.selector);
        vm.prank(address(this));
        stableCoin.burn(0);
    }

    function test_burnRevertIfbalanceIsNotSuffice() public {
        vm.expectRevert(DecentralizedStableCoin.DecentralizedStableCoin_AmountNotOwned.selector);
        vm.prank(address(this));
        stableCoin.burn(20e18);
    }

    function test_burnIsSuccessfull() public {
        vm.prank(address(this));
        stableCoin.mint(address(this), INITIAL_AMOUNT);
        stableCoin.burn(10e18);
        assertEq(stableCoin.balanceOf(address(this)), 0);
        console.log(stableCoin.balanceOf(address(this)));
    }
}
