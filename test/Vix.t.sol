// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;
import {Test,console} from "forge-std/Test.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import { IPoolManager } from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Vix} from "../src/Vix.sol";
contract VixTest is Test,Deployers {
    using CurrencyLibrary for Currency;

    Vix hook;
    function setUp()external {

        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        address hookAddress = address(
            uint160(
                    Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
                    Hooks.AFTER_ADD_LIQUIDITY_FLAG |
                    Hooks.AFTER_SWAP_FLAG
            )
        );       
        console.log(hookAddress);
        address usdc = address(Currency.unwrap(currency0));
        console.log(usdc);
        deployCodeTo("Vix.sol",abi.encode(manager,address(usdc)),hookAddress);
        hook = Vix(hookAddress);
        (key, ) = initPool(
            currency0,
            currency1,
            hook,
            3000,
            SQRT_PRICE_1_1
        );
        
        MockERC20(Currency.unwrap(currency0)).approve(
            address(hook),
            type(uint256).max
        );

        MockERC20(Currency.unwrap(currency1)).approve(
            address(hook),
            type(uint256).max
        );

         modifyLiquidityRouter.modifyLiquidity(
        key,
        IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 10 ether,
            salt: bytes32(0)
        }),
        ZERO_BYTES
    );
        assertEq(hook.isPairInitiated(key.currency0.toId(),key.currency1.toId()),true);

    }

    function test_addLiquidity() public {
        MockERC20  token0;
        MockERC20  token1;
        Currency tokenCurrency0;
        Currency tokenCurrency1;
        token0 = new MockERC20("$TOKEN0", "TKN0", 18);
        token1 = new MockERC20("$TOKEN1", "TKN1", 18);
        console.log("address of token0",address(token0));
        console.log("address of token1",address(token1));
        tokenCurrency0 = Currency.wrap(address(token0));
        tokenCurrency1 = Currency.wrap(address(token1));
        (key, ) = initPool(tokenCurrency0,tokenCurrency1,hook,3000,SQRT_PRICE_1_1);
        vm.expectRevert();
        modifyLiquidityRouter.modifyLiquidity(
        key,
        IPoolManager.ModifyLiquidityParams({
            tickLower: -60,
            tickUpper: 60,
            liquidityDelta: 10 ether,
            salt: bytes32(0)
        }),
        ZERO_BYTES
        );
    
        }

    

}