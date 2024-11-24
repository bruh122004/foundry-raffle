// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.18;
// //What are our invariants 
// // 1. The total supply of DSC should be less than the total value of collateral
// // 2. Getter view fnctions should never revert <- evergreen invariant
// import {Test, console} from "forge-std/Test.sol";
// import {DeployDSC} from "../../script/DeployDSC.s.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
// import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol";
// import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import { StdInvariant } from "forge-std/StdInvariant.sol";
// import {DSCEngine} from "../../src/DSCEngine.sol";
// contract InvariantsTest is StdInvariant, Test {
//     DeployDSC deployer;
//     DSCEngine dscengine;
//     HelperConfig configer;
//     DecentralizedStableCoin dsc;
//     address user = makeAddr("user");
//     address weth;
//     address wbtc;
//     function setUp() external {
//         deployer = new DeployDSC();
//         (dsc, dscengine, configer) = deployer.run();
//         (,, weth, wbtc,) = configer.activeNetworkConfig();
//         targetContract(address(dscengine));
//     }

//     function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
//         // get the value of all the collateral in the protocol
//         // compare it to all the debt
//         uint256 totalSupply = dsc.totalSupply();
//         uint256 totalwethDeposited = IERC20(weth).balanceOf(address(dscengine));
//         uint256 totalwbtcDeposited = IERC20(wbtc).balanceOf(address(dscengine));
//         uint256 totalwethValue = dscengine.getUsdValue(weth, totalwethDeposited);
//         uint256 totalwbtcValue = dscengine.getUsdValue(wbtc, totalwbtcDeposited);

//         assert(totalwbtcValue + totalwethValue >= totalSupply);

//     }

// }