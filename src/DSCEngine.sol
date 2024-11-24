// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.19;

/**
 * @title DSCEngine
 * @author IDIR BADACHE
 * This system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 peg
 * This stableCoin has the properties:
 * -Exogenous Collateral
 * -Dollar Pegged
 * -Algorithmically stable
 * 
 * @notice the DC system should always be "overcollateralized". At no point, should the value of all collateral <= the value of all the DSC
 * @notice This contract is the core of the DSC System. It handles all the logic for mining and redeeming DSC, as well as depositing & withdrawing collateral.
 * @notice this contrac is very loosely based on the MakerDAO DSS (DAI) system.
 * 
 * 
 * 
 */
import {DecentralizedStableCoin} from "src/DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {console} from "forge-std/console.sol";

contract DSCEngine is ReentrancyGuard {
    ////////////////////////////Errors////////////////////////
    error DSCEngine_NeedsMoreThanZero();
    error DSCEngine_EachTokenAddrMustHavePriceFeedAddr();
    error DSCEngine_NotAllowedToken();
    error DSCEngine_TransferFaild();
    error DSCEngine_MintingFaild();
    error DSCEngine_liquidationNotRequired();
    error DSCEngine_StillNotHealthy();
    error DSCEngine_NOtokensToBurnOrExeedsAmountOwned();
    ////////////////////////////Types Declarations/////////////////
    error DSCEngine_NotenoughCollateral();
    ////////////////////////////State variables////////////////////////
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant ADDITIONALL_PRECISION = 1e10;

    address[] private s_collateralTokens;
    mapping (address token => address priceFeed) private s_priceFeeds;
    DecentralizedStableCoin private immutable i_dsc;
    mapping (address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping (address user => uint256 amount) private s_DSCminted;
    ////////////////////////////Events////////////////////////
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemedto , address indexed token, uint256 amount);
    


    ////////////////////////////Modifiers////////////////////////
    //we can actually have modifiers take formal arguments
    modifier moreThanZero(uint256 amount) {
        if (amount == 0){
            revert DSCEngine_NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine_NotAllowedToken();
        }
        _;
    }

    // modifier isHealthy(address user) {
    //     uint256 healthfactor = _healthFactor(user);
    //     if (healthfactor < 1) {
    //         liquidate();
    //     }
    //     _;
    // }
    // modifier isAlloewedToken(address token) {
        
    // }

    ////////////////////////////functions////////////////////////
    constructor(
        address[] memory tokenAddresses, 
        address[] memory pricFeeds,
        address dscAddress
        ){
        if (tokenAddresses.length < pricFeeds.length) {
            revert DSCEngine_EachTokenAddrMustHavePriceFeedAddr();
        }

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = pricFeeds[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        /****/
        i_dsc = DecentralizedStableCoin(dscAddress);
    
    /**
     * 
     * @param tokenCollateralAddress Thea address fo the token to deposite as a collateral
     * @param amountCollateral the amount of collateral to deposite
     * @param amountDscToMint the amount of DSC to deposite
     * @notice this function will deposite your collateral and mint DSC
     * @notice the minting process will happen only you are overcollaterized
     * 
     */

    }
    function depositeCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral, 
        uint256 amountDscToMint 
    ) external {
        depositeCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDscToMint);
    }

    /**
     * @notice following CEI
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're deposoting 
     */
    /**
     * 
     * @param tokenCollateral The Tokencollateral addres to redeem
     * @param amountCollateral the amount to be redeemed
     * @param amountDscToBurn the amount of DSC to burn
     * @notice this function burns DSC and redeems underlying collateral in on transaction
     */
    function redeemCollateralForDSC(
    address tokenCollateral,
    uint256 amountCollateral,
    uint256 amountDscToBurn) 
    external {
        burnDSC(amountDscToBurn);
        redeemCollateral(tokenCollateral, amountCollateral);
    }


    function depositeCollateral(
        address tokenCollateralAddress, uint256 amountCollateral) 
        public moreThanZero(amountCollateral) 
        nonReentrant 
        isAllowedToken(tokenCollateralAddress) 
        {
            s_collateralDeposited[msg.sender][tokenCollateralAddress] = amountCollateral; 
            emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
            bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
            if (!success) {
                revert DSCEngine_TransferFaild();
            }
        }


    /**
     * 
     * @param collateral the erc20 collateral address to liquidate from the user 
     * @param user the user to liquidate
     * @param debtTocover the amount of DSC you want to burn to improve the users health
     * factor
     * @notice you can partially liquidate a user.
     * @notice You will get a 10% LIQUIDATION_BONUS for taking the users funds
     * @notice This function working assumes that the protocol will be roughly 200% overcollateralized in order for this
     * @notice A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate
    anyone.
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     */
    function liquidate(address collateral, address user, uint256 debtTocover) 
    external moreThanZero(debtTocover) /*nonReentrant*/ {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine_liquidationNotRequired();
        }
        //we want to burn their DSC 'debt'
        //And take their collateral
        // Bad User; $140 eth, $100 DSC "undercollaterlized" 
        // debtTocover = $100
        // $100 of DSC == ??? ETH?

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtTocover);
        //AndGive them a 10% bonus
        //giving the liquidator $110 of WETH for $100 DSC

        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateral = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(collateral, totalCollateral, user, msg.sender);
        //burning the DSC
        _burnDsc(debtTocover, user, msg.sender);

        uint256 userHealthAfterLiquidation = _healthFactor(user);
        if (userHealthAfterLiquidation <= startingUserHealthFactor) {
            revert DSCEngine_StillNotHealthy();
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }




    /**
     * @notice follwing CEI
     * @param amountToMint the amount of stablecoin to be minted
     * @notice must have more collateral value than the minimum threshold
     */
    function mintDSC(uint256 amountToMint) public
    moreThanZero(amountToMint)  {
        s_DSCminted[msg.sender] += amountToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountToMint);
        if (!minted) {
            revert DSCEngine_MintingFaild();
        }
        
    }

    function redeemCollateral(address tokenCollateral, uint256 tokenAmount)
    public moreThanZero(tokenAmount) isAllowedToken(tokenCollateral){
        
        _redeemCollateral(tokenCollateral, tokenAmount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
    }
//////mark here///
////////////////////////workflow///////////////////////


////////////////////////workflow///////////////////////
    function burnDSC(uint256 amount) 
    public 
    moreThanZero(amount) 
     {
        console.log(msg.sender);

        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); //seems sensible that this probably won't hit
    }

    function getHealtFactor() external view {} 

    function _getAccountInformation(address user) 
    private 
    view returns (uint256 totalDSCMinted, uint256 collateralValueInUsd) {
        totalDSCMinted = s_DSCminted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
        return (totalDSCMinted, collateralValueInUsd);
    }


    function getAccountCollateralValue(address user) public  view returns (uint256 collateralvalue) {
        uint256 totalcollateralValueInUsd;
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalcollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalcollateralValueInUsd;

    }

    
    function getUsdValue(address token, uint256 amount) 
    public view returns(uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        uint256 totalvalueInUsd = (uint256(price * 1e10) * amount) / PRECISION;
        return totalvalueInUsd;
    }

    function getTokenAmountFromUsd(address token, uint256 usdAmountInwei)
    public 
    view returns (uint256)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        return (usdAmountInwei * PRECISION) / (uint256(price) * ADDITIONALL_PRECISION);
    }
    function _healthFactor(address user) private view returns (uint256) {
        //total DSC minted
        //total collateral VALUE
        (uint256 totalDSCMinted, uint256 collateralValueInUSD) = _getAccountInformation(user);

        
        return _calculateHealthFactor(totalDSCMinted, collateralValueInUSD);
    }

    function _calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    )
        internal
        pure
        returns (uint256)
    {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }
//1:36
    //1. Check health factor (do thye have enough collateral?)
    //2. Revert if they don't 
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 healthFactor = _healthFactor(user);
        if (healthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine_NotenoughCollateral();
        }
    }
    

    function _burnDsc(uint256 amountDscToBurn, address onBehalfOf, address dscFrom) private {
        if (s_DSCminted[onBehalfOf] == 0 || s_DSCminted[onBehalfOf] < amountDscToBurn) {
            revert DSCEngine_NOtokensToBurnOrExeedsAmountOwned();
        }
        s_DSCminted[onBehalfOf] -= amountDscToBurn;
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        if (!success) {
            revert DSCEngine_TransferFaild();
        }
        i_dsc.burn(amountDscToBurn);
    }

    function _redeemCollateral(
        address tokenCollateralAddress, 
        uint256 amountCollateral, address from, address to)  
        private moreThanZero(amountCollateral) nonReentrant{
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine_TransferFaild();
            }
        }
    function getTokenAmountminted(address user) external view returns (uint256 dscAmountMinted) {
        return s_DSCminted[user];
    }

    function getCollateralDeposited(address user, address tokenCollateral)
    external view returns (uint256 amounDeposited) {
        return s_collateralDeposited[user][tokenCollateral];
    }

    function getAccountinfo(address user)external view
    returns (
        uint256 totalDSCMinted, 
        uint256 collateralValueInUsd) {
            (totalDSCMinted, collateralValueInUsd) = _getAccountInformation(user);
        }


    function gethealthFactor(address user) external view returns(uint256) {
        uint256 healthFactor = _healthFactor(user);
        return healthFactor;

    }   
    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
    function getCollaterTokens() external view returns (address[] memory collateralTokens) {
        return s_collateralTokens;
    }
}   



