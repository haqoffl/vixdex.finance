// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency,CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Volatility} from "./lib/Volatility.sol";
import {VolatileERC20} from "./VolatileERC20.sol";
import "forge-std/console.sol";  // Foundry's console library
contract Vix is BaseHook{
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;
    using Volatility for int;
    mapping(uint256=>mapping(uint256=>bool)) public isPairInitiated;
    mapping(uint256=>mapping(uint256=>uint)) public pairInitiatedTime;
    mapping(uint256=>mapping(uint256=>uint)) public pairEndingTime;
    mapping(uint256=>mapping(uint256=>int)) public currentTickMeans;
    mapping(uint256=>mapping(uint256=>int)) public currentM2;
    mapping(uint256=>mapping(uint256=>uint24)) public n; //mean length
    mapping(uint256=>mapping(uint256=>int)) public maxVolatility; // maximum volatility
    struct VixTokenData {
        address VIXHIGHTOKEN;
        address VIXLOWTOKEN;
    }

    mapping(uint256=>mapping(uint256=>VixTokenData)) vixTokens;
    address public USDC;

    //initiating BaseHook with IPoolManager
    constructor(IPoolManager _poolManager,address _usdc) BaseHook(_poolManager) {
        USDC = _usdc;
    }

    //getting Hook permission  
    function getHookPermissions() public pure override returns (Hooks.Permissions memory){
            return Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: true,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

     function _beforeAddLiquidity(address, PoolKey calldata key, IPoolManager.ModifyLiquidityParams calldata , bytes calldata)internal view override  returns (bytes4){
            address add0 = Currency.unwrap(key.currency0);
            address add1 = Currency.unwrap(key.currency1);
            bool isUsdc = add0 == USDC || add1 == USDC;
            require(isUsdc == true,"only USDC pair");
            return this.beforeAddLiquidity.selector;
     }

    function _afterAddLiquidity(address,PoolKey calldata key,IPoolManager.ModifyLiquidityParams calldata,BalanceDelta delta,BalanceDelta,bytes calldata) internal override returns (bytes4, BalanceDelta){
            uint256 token0Id = key.currency0.toId();
            uint256 token1Id = key.currency1.toId();
            if(isPairInitiated[token0Id][token1Id]){
                return (this.afterAddLiquidity.selector, delta);
            }else{
                
                isPairInitiated[token0Id][token1Id] = true;
                pairInitiatedTime[token0Id][token1Id] = block.timestamp;
                pairEndingTime[token0Id][token1Id] = block.timestamp + 24 hours;
                // bitcoins max raw volatile is 6000, so i set it like this. It will increase when pair cross it max volatile
                maxVolatility[token0Id][token1Id] = 500;
                return (this.afterAddLiquidity.selector, delta);

            }
    }

    function _afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata) internal override returns (bytes4, int128){
        uint256 token0Id = key.currency0.toId();
        uint256 token1Id = key.currency1.toId();
        n[token0Id][token1Id]++;
       (, int24 currentTick, , ) = poolManager.getSlot0(key.toId());
      
        int oldTickMeans = currentTickMeans[token0Id][token1Id];
        uint24 currentN = n[token0Id][token1Id];
        int newTickMean = oldTickMeans.updateTickMean(int(currentTick),int24(currentN));
        currentTickMeans[token0Id][token1Id] = newTickMean;
        int M2 = currentM2[token0Id][token1Id];
        int newM2 = M2.updateM2(int(currentTick),oldTickMeans,newTickMean);
        currentM2[token0Id][token1Id] = newM2;
        return (this.afterSwap.selector, 0);
    }

    function getPairVolatility(PoolKey calldata key) public returns (int, int) {
        uint256 token0Id = key.currency0.toId();
        uint256 token1Id = key.currency1.toId();

        int M2 = currentM2[token0Id][token1Id];
        int sampleCount = int24(n[token0Id][token1Id]);  // Renamed `n` to `sampleCount`
        int variance = M2.calculateVariance(sampleCount);
        int currentTickMean = currentTickMeans[token0Id][token1Id];
        console.log("variance: ",variance);
        int vol = variance.getVolatility(currentTickMean);
        int maxVol = maxVolatility[token0Id][token1Id];

        // Adaptive max volatility update
        if (vol > maxVol) {
        maxVol = vol + (vol / 10); // Increase by 10% instead of a fixed 100
        maxVolatility[token0Id][token1Id] = maxVol;
        }
        console.log("volatility: ",vol);
        // Normalize volatility using Min-Max Scaling
        int normVol = vol.getNormalizedVolatility(maxVol);
  

        return (vol, normVol);
    }

    function deploy2Currency(uint256 _currency1Id,uint256 _currency2Id, string[2] memory _tokenName, string[2] memory _tokenSymbol) public returns(address[2] memory){
        address[2] memory vixTokenAddresses;
        for(uint i = 0; i < 2; i++){
            VolatileERC20 v_token = new VolatileERC20(_tokenName[i], _tokenSymbol[i],18);
            vixTokenAddresses[i] = address(v_token);
            mintVixToken(address(this),address(v_token),50 * 1000000 * (10**18));
        }
        vixTokens[_currency1Id][_currency2Id] = VixTokenData(vixTokenAddresses[0],vixTokenAddresses[1]);
        return (vixTokenAddresses);
    }

    function mintVixToken(address to,address _token,uint _amount) internal returns (bool){
        VolatileERC20 v_token = VolatileERC20(_token);
        v_token.mint(to, _amount);
        return true;
    }


}