// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol";


contract Handler is Test {
    DSCEngine public dscengine;
    DecentralizedStableCoin public dsc;
    ERC20Mock public weth;
    ERC20Mock public wbtc;
    uint256 public constant MAX_DEPOSITE_AMOUNT = type(uint96).max;
    
    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dscengine = _dscEngine;
        dsc = _dsc;
        address[] memory collateralTokens = dscengine.getCollaterTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        console.log(address(weth));
        console.log(address(wbtc));

    }
    //
    function depositeCollateral(
        uint256 collateralSeed, 
        uint256 amountCollateral) 
        public 
    {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        amountCollateral = bound(amountCollateral, 0, MAX_DEPOSITE_AMOUNT);
        vm.prank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dscengine), amountCollateral);
        console.log(address(collateral));
        dscengine.depositeCollateral(address(weth), amountCollateral);
    
    }



    //Helper Functions 
    function _getCollateralFromSeed(uint256 collateralSeed)
    private 
    view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }else {
            return wbtc;  
        }
        
    }
}