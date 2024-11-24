// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {DSCEngine} from "src/DSCEngine.sol";
import {Test, console, Vm} from "forge-std/Test.sol";
import {DeployDSC} from "script/DeployDSC.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
import {MockFailedMintDSC} from "test/mocks/MockFailedMintDSC.sol";
import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";
import {MockMoreDebtDSC} from "../mocks/MockMoreDebtDSC.sol";
contract DSCtest is Test {
    DecentralizedStableCoin dsc;
    DSCEngine dscengine;
    DeployDSC deployer;
    HelperConfig helperconfig;

    address wethUsdPriceFeed;
    address wbtcUsdPriceFeed;
    address weth;
    address wbtc;
    uint256 deployerKey;
    address user = makeAddr("user");
    address user2 = makeAddr("user2");
    uint256 public constant Amount_collateral = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant STARTING_DEPOSITE = 5 ether;
    uint256 public constant AMOUNT_DSC_TO_MINT = 100 ether;
    uint256 public collateralToCover = 20 ether;
    address public liquidator = makeAddr("liquidator");

    function setUp() public {
        deployer = new DeployDSC();
        (dsc, dscengine, helperconfig) = deployer.run();
        (wethUsdPriceFeed,wbtcUsdPriceFeed,weth,wbtc,) = helperconfig.activeNetworkConfig();
        ERC20Mock(weth).mint(user, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_ERC20_BALANCE);
        ERC20Mock(weth).mint(user2, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(user2, STARTING_ERC20_BALANCE);
    }

    address[] public tokenAddresses;
    address[] private priceFeedAddresses;

    function test_RevertsIfTokenLengthDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(wethUsdPriceFeed);
        priceFeedAddresses.push(wbtcUsdPriceFeed);
        vm.expectRevert(DSCEngine.DSCEngine_EachTokenAddrMustHavePriceFeedAddr.selector);
        new DSCEngine(tokenAddresses, priceFeedAddresses, address(dsc));
    }

    function test_getTokenAmountFromUsd() public view{
        uint256 amountInUsd = 100 ether;
        uint256 expectedTokenAmount = 0.05 ether;
        //assertion
        uint256 actualTokenAmount = dscengine.getTokenAmountFromUsd(weth, amountInUsd);

        assertEq(actualTokenAmount, expectedTokenAmount);
    }


            //test__whatfunctionality__forwhat
    function test_getUsdValue_corectness() public view {
        console.log(wethUsdPriceFeed);
        uint256 ethAmount = 15e18;
        // 15e18 * 2000/ETH = 30,000e18
        uint256 expectedValue = 30000e18;
        //assert
        uint256 returnedValue = dscengine.getUsdValue(weth, ethAmount);
        assertEq(returnedValue, expectedValue);
    }

    function test_dpositeCollateral_revertZeroValue() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(user, Amount_collateral);
        vm.expectRevert(DSCEngine.DSCEngine_NeedsMoreThanZero.selector);
        dscengine.depositeCollateral(user, 0);
    }


    function test_revertsWithUnapprovedCollaterl() public {
        ERC20Mock fakeToken = new ERC20Mock("RAN", "RAN", user, Amount_collateral);
        console.log(address(fakeToken));
        vm.prank(user);
        vm.expectRevert(DSCEngine.DSCEngine_NotAllowedToken.selector);
        dscengine.depositeCollateral(address(fakeToken), Amount_collateral);
        
    }
    modifier depositedCollateralandMintDsc() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscengine), Amount_collateral);
        dscengine.depositeCollateral(weth, Amount_collateral);
        dscengine.mintDSC(AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
        _;
    }

    modifier depositedCollateral() {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscengine), Amount_collateral);
        ERC20Mock(wbtc).approve(address(dscengine), Amount_collateral);
        dscengine.depositeCollateral(wbtc, Amount_collateral);
        dscengine.depositeCollateral(weth, Amount_collateral);
        vm.stopPrank();
        _;
    }

    // modifier trnasferOwnership() {
    //     vm.startPrank(address(deployer));
    //     dsc.transferOwnership(address(use));
    //     vm.stopPrank();
    //     _;
    // }

    function test_userAppendedtodpositeCollateralList() public depositedCollateral {
        uint256 amountcollatral = dscengine.getCollateralDeposited(user, weth);
        assert(Amount_collateral == amountcollatral);
    }


    function test_DepositeCollateralAndGetAccounInfo() public depositedCollateral {
        (uint256 totalDscMinted, uint256 collaterallvalueInUsd) = dscengine.getAccountinfo(user);
        uint256 expectedTotalDscMinted = 0;
        
        assert(totalDscMinted == expectedTotalDscMinted);
        assertEq(collaterallvalueInUsd, 30000e18);
        }

//Testing redeeming system
    function test_redeemCollateral() public depositedCollateral {
        vm.prank(user);
        console.log(user);
        dscengine.redeemCollateral(weth, Amount_collateral);
        uint256 collateralAfterRedeem = dscengine.getCollateralDeposited(user, weth);
        assertEq(collateralAfterRedeem, 0);
    }

    function test_redeemCollateralForDSC() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscengine), Amount_collateral);
        dscengine.depositeCollateralAndMintDSC(weth, Amount_collateral, AMOUNT_DSC_TO_MINT);
        dsc.approve(address(dscengine), AMOUNT_DSC_TO_MINT);
        dscengine.redeemCollateralForDSC(weth, Amount_collateral, AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
        
        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, 0);
    }
    function test_liquidateRevertsIfNotNeeded() public  {
        MockMoreDebtDSC mockDsc = new MockMoreDebtDSC(wethUsdPriceFeed);
        tokenAddresses = [weth];
        priceFeedAddresses = [wethUsdPriceFeed];
        address owner = msg.sender;
        vm.prank(owner);
        DSCEngine mockDsce = new DSCEngine(tokenAddresses, priceFeedAddresses, address(mockDsc));
        mockDsc.transferOwnership(address(mockDsce));
        // Arrange - User
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(mockDsce), Amount_collateral);
        mockDsce.depositeCollateralAndMintDSC(weth, Amount_collateral, AMOUNT_DSC_TO_MINT);
        vm.stopPrank();

        // Arrange - Liquidator
        collateralToCover = 1 ether;
        ERC20Mock(weth).mint(liquidator, collateralToCover);

        vm.startPrank(liquidator);
        ERC20Mock(weth).approve(address(mockDsce), collateralToCover);
        uint256 debtToCover = 10 ether;
        mockDsce.depositeCollateralAndMintDSC(weth, collateralToCover, AMOUNT_DSC_TO_MINT);
        mockDsc.approve(address(mockDsce), debtToCover);
        // Act
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);
        // Act/Assert
        console.log(address(MockV3Aggregator(wethUsdPriceFeed)));
        vm.expectRevert(DSCEngine.DSCEngine_StillNotHealthy.selector);
        mockDsce.liquidate(weth, user, debtToCover);
        vm.stopPrank();
    

    }
    //0x90193C961A926261B756D1E5bb255e67ff9498A1

    //dsegine 0x7FA9385bE102ac3EAc297483Dd6233D62b3e1496
    //user 0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D
    function test_tokenAmountfromUSD() public depositedCollateral {
        uint256 collateralusedvalue = dscengine.getUsdValue(weth, 20 ether);
        uint256 colateralamount = dscengine.getTokenAmountFromUsd(weth, collateralusedvalue);
        assertEq(colateralamount, 20 ether);

    }
    
    
    function test_CollateralDeposited_event() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscengine), Amount_collateral);
        vm.recordLogs();
        dscengine.depositeCollateral(weth, Amount_collateral);
        vm.stopPrank();
        Vm.Log[] memory entries = vm.getRecordedLogs();
        address userfromevent = address(uint160(uint256(entries[0].topics[1])));
        address expecteduseraddress = user;
        
        console.log(address(uint160(uint256(entries[0].topics[0]))));
        assertEq(userfromevent, expecteduseraddress);

        assertEq(entries[0].topics[0], keccak256("CollateralDeposited(address,address,uint256)"));
        console.log(entries.length);
    }



    function test_mintingAndOwnership() public depositedCollateral {
        
        vm.prank(user);
        dscengine.mintDSC(AMOUNT_DSC_TO_MINT);

        uint256 userBalance = dsc.balanceOf(user);
        assertEq(userBalance, AMOUNT_DSC_TO_MINT);        
    }

    function test_mintingRevertsIfNotEnoughCollateral() public {
        vm.prank(user);
        vm.expectRevert(DSCEngine.DSCEngine_NotenoughCollateral.selector);
        dscengine.mintDSC(AMOUNT_DSC_TO_MINT);
    }



    function test_getAccountCollateralValue() public depositedCollateral {
        uint256 expectedCollateralValue = 30000e18;
        vm.prank(user);
        uint256 actualcollateralValue = dscengine.getAccountCollateralValue(user);

        assertEq(actualcollateralValue, expectedCollateralValue);
        
    }

    function test_mintingRevertsIfNotHealthy() public {
        vm.prank(user);
        vm.expectRevert(DSCEngine.DSCEngine_NotenoughCollateral.selector);
        dscengine.mintDSC(AMOUNT_DSC_TO_MINT);
    }


//0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D

    function testHealthFactorCanGoBelowOne() public depositedCollateralandMintDsc {
        int256 ethUsdUpdatedPrice = 18e8; // 1 ETH = $18
            // Rememeber, we need $200 at all times if we have $100 of debt

        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(ethUsdUpdatedPrice);

        uint256 userHealthFactor = dscengine.getHealthFactor(user);
            // 180*50 (LIQUIDATION_THRESHOLD) / 100 (LIQUIDATION_PRECISION) / 100 (PRECISION) = 90 / 100 (totalDscMinted) =
            // 0.9
        assertEq(userHealthFactor, 0.9 ether);
    }

    
    function test_revertsIfNotHealthy() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscengine), Amount_collateral);
        ERC20Mock(wbtc).approve(address(dscengine), Amount_collateral);
        dscengine.depositeCollateral(wbtc, (Amount_collateral / 1e4));
        dscengine.depositeCollateral(weth, (Amount_collateral / 1e4));
        vm.expectRevert(DSCEngine.DSCEngine_NotenoughCollateral.selector);
        dscengine.mintDSC(AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
        
    }
    function test_dpositeCollateralAndMintDSC() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dscengine), Amount_collateral);
        dscengine.depositeCollateralAndMintDSC(weth, Amount_collateral, AMOUNT_DSC_TO_MINT);
        assert(dscengine.getCollateralDeposited(user, weth) == Amount_collateral);
        assert(dscengine.getTokenAmountminted(user) == AMOUNT_DSC_TO_MINT);
    }

    function test_burningDsc() public depositedCollateralandMintDsc {
        vm.startPrank(user);
        dsc.approve(address(dscengine), AMOUNT_DSC_TO_MINT);
        dscengine.burnDSC(AMOUNT_DSC_TO_MINT);
        vm.stopPrank();
        console.log(dsc.balanceOf(user));
        uint256 userbalanceAfterBurning = dsc.balanceOf(user);
        assertEq(0, userbalanceAfterBurning);

}



    
    }
    


    
    //you were about to test healthfactor and minting
