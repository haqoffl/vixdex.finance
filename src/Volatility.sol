// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/**
 * @title Volatility Library
 * @notice This library provides functions to calculate volatility of a pool.
 */
library Volatility{

    /**  
     * @notice Updates the mean of the tick price.
     * @param oldTickMean The current mean of the tick price.
     * @param newTick The new tick price.
     * @param n The number of samples.
     * @return tickMean The new mean of the tick price.
     */
    function updateTickMean(int oldTickMean, int newTick, int n) internal pure returns (int tickMean) {
        tickMean = oldTickMean + (newTick - oldTickMean) / n;
        return tickMean;
    }

    /** 
     * @notice Updates the M2 value which is used to calculate the variance.
     * @param M2 The current M2 value.
     * @param newTick The new tick price.
     * @param oldTickMean The current mean of the tick price.
     * @param newTickMean The new mean of the tick price.
     * @return m2 The new M2 value.
     */
    function updateM2(int M2,int newTick,int oldTickMean,int newTickMean) internal pure returns (int m2) {
        m2 = M2 + (newTick - oldTickMean) * (newTick - newTickMean);
        return m2;
    }

    /** 
     * @notice Calculates the variance of the tick price.
     * @param M2 The M2 value.
     * @param n_greaterThanOne The number of samples minus one.
     * @return variance The variance of the tick price.
     */
    function calculateVariance(int M2,int n_greaterThanOne) internal pure returns (int variance) {
        require(n_greaterThanOne > 1,"N should be greater than 1");
        variance = M2 /(n_greaterThanOne -1);
        return variance;   
    }

    /** 
     * @notice Calculates the volatility of the tick price.
     * @param variance The variance of the tick price.
     * @param meanTick The mean of the tick price.
     * @return volatility  The volatility of the tick price.
     */
    function getVolatality(int variance,int meanTick) internal pure returns(int volatility){
        require(variance >= 0, "Variance cannot be negative");
        require(meanTick != 0, "Mean tick cannot be zero to avoid division by zero");
        int stdDev = sqrt(uint(variance));
        volatility = (stdDev * 100)/meanTick;
        return volatility;
    }

    /** 
     * @notice it is babylonian square root method
     * @param x The variance of the tick price.
     * @return y  square root.
     */
    function sqrt(uint x) internal pure returns (int y) {
        if (x == 0) return 0;
        uint z = (x + 1) / 2;
        y = int(x);
        while (z < uint(y)) {
            y = int(z);
            z = (x / z + z) / 2;
        }
    }
}
