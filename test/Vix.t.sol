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
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {Vix} from "../src/Vix.sol";
contract VixTest is Test,Deployers {
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

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
            liquidityDelta: 1000 ether,
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
            liquidityDelta: 100 ether,
            salt: bytes32(0)
        }),
        ZERO_BYTES
        );
    
        }


    function test_Swap() public {
    console.log("Before swap");
    console.log("Current Tick Means: ", hook.currentTickMeans(key.currency0.toId(), key.currency1.toId()));
    console.log("Current M2: ", hook.currentM2(key.currency0.toId(), key.currency1.toId()));

    PoolSwapTest.TestSettings memory settings = PoolSwapTest.TestSettings({
        takeClaims: false,
        settleUsingBurn: false
    });

    // Define swap parameters with varying amounts
    IPoolManager.SwapParams[] memory swapParams = new IPoolManager.SwapParams[](10);
    swapParams[0] = IPoolManager.SwapParams(true, 0.5 ether, TickMath.MIN_SQRT_PRICE + 1);
    swapParams[1] = IPoolManager.SwapParams(true, 1 ether, TickMath.MIN_SQRT_PRICE + 1);
    swapParams[2] = IPoolManager.SwapParams(false, 3 ether, TickMath.MAX_SQRT_PRICE - 1);
    swapParams[3] = IPoolManager.SwapParams(true, 2 ether, TickMath.MIN_SQRT_PRICE + 1);
    swapParams[4] = IPoolManager.SwapParams(false, 1.5 ether, TickMath.MAX_SQRT_PRICE - 1);
    swapParams[5] = IPoolManager.SwapParams(true, 0.4 ether, TickMath.MIN_SQRT_PRICE + 1);
    swapParams[6] = IPoolManager.SwapParams(true, 0.5 ether, TickMath.MIN_SQRT_PRICE + 1);
    swapParams[7] = IPoolManager.SwapParams(false, 0.5 ether, TickMath.MAX_SQRT_PRICE - 1);
    swapParams[8] = IPoolManager.SwapParams(true, 1 ether, TickMath.MIN_SQRT_PRICE + 1);
    swapParams[9] = IPoolManager.SwapParams(false, 1 ether, TickMath.MAX_SQRT_PRICE - 1);

    uint160[] memory sqrtPrices = new uint160[](10);

    for (uint i = 0; i < swapParams.length; i++) {
        swapRouter.swap(key, swapParams[i], settings, ZERO_BYTES);
        (sqrtPrices[i], , , ) = manager.getSlot0(key.toId());
        console.log("SqrtPriceX96 ", i + 1, ": ", sqrtPrices[i]);
    }

    console.log("Liquidity: ", manager.getLiquidity(key.toId()));
    console.log("After swap");
    console.log("Current Tick Means: ", hook.currentTickMeans(key.currency0.toId(), key.currency1.toId()));
    console.log("Current M2: ", hook.currentM2(key.currency0.toId(), key.currency1.toId()));

    (int volatility,int normalizedVolatility) = hook.getPairVolatility(key);

    console.log("raw volatility: ",volatility);
    console.log("normalized Volatility (%): ",normalizedVolatility);
    console.log("Max volatility: ",hook.maxVolatility(key.currency0.toId(), key.currency1.toId()));
    assert(normalizedVolatility >= 0 && normalizedVolatility <= 100);
    assert(hook.maxVolatility(key.currency0.toId(), key.currency1.toId()) > volatility);
}

    

}