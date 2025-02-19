// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency,CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";


contract Vix is BaseHook{
    using CurrencyLibrary for Currency;
    mapping(uint256=>mapping(uint256=>bool)) public isPairInitiated;

    address public USDC;

    //initiating BaseHook with IPoolManager
    constructor(IPoolManager _manager,address _usdc) BaseHook(_manager) {
        USDC = _usdc;
    }

    //getting Hook permission  
   function getHookPermissions() public pure override returns (Hooks.Permissions memory){
        return Hooks.Permissions({
        beforeInitialize:false,
        afterInitialize:false,
        beforeAddLiquidity:true,
        afterAddLiquidity:false,
        beforeRemoveLiquidity:false,
        afterRemoveLiquidity:false,
        beforeSwap:false,
        afterSwap:false,
        beforeDonate:false,
        afterDonate:false,
        beforeSwapReturnDelta:false,
        afterSwapReturnDelta:false,
        afterAddLiquidityReturnDelta:false,
        afterRemoveLiquidityReturnDelta:false
        });
   }

     function _beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata , bytes calldata hookData)internal view override  returns (bytes4){
            address usdc = abi.decode(hookData, (address));
            require(USDC == usdc,"only USDC pair");
            return "";
     }

    function _afterAddLiquidity(address,PoolKey calldata key,IPoolManager.ModifyLiquidityParams calldata,BalanceDelta delta,BalanceDelta,bytes calldata) internal override returns (bytes4, BalanceDelta){
            uint256 token0Id = key.currency0.toId();
            uint256 token1Id = key.currency1.toId();
            if(isPairInitiated[token0Id][token1Id]){
                return (this.afterAddLiquidity.selector, delta);
            }else{
                isPairInitiated[token0Id][token1Id] = true;
                return (this.afterAddLiquidity.selector, delta);

            }
    }

   

}