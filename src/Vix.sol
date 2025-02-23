// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency,CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {Volatility} from "./Volatility.sol";
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
            console.log("isUSDC: ",isUsdc);
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

   

}