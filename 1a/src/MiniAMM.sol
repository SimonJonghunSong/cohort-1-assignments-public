// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {IMiniAMM, IMiniAMMEvents} from "./IMiniAMM.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Add as many variables or functions as you would like
// for the implementation. The goal is to pass `forge test`.
contract MiniAMM is IMiniAMM, IMiniAMMEvents {
    uint256 public k = 0;
    uint256 public xReserve = 0;
    uint256 public yReserve = 0;

    address public tokenX;
    address public tokenY;

    // implement constructor
    constructor(address _tokenX, address _tokenY) {
        // if(_tokenX < _tokenY)   tokenX = _tokenX;
        // else                    tokenY = _tokenY;
        require(_tokenX != address(0), "tokenX cannot be zero address");
        require(_tokenY != address(0), "tokenY cannot be zero address");
        require(_tokenX != _tokenY, "Tokens must be different");
        if(_tokenX < _tokenY) {
            tokenX = _tokenX;
            tokenY = _tokenY;
        } else {
            tokenX = _tokenY;
            tokenY = _tokenX;
        }        
    }

    // add parameters and implement function.
    // this function will determine the initial 'k'.
    function _addLiquidityFirstTime(uint256 xAmountIn, uint256 yAmountIn) internal {
        require(xAmountIn > 0 && yAmountIn > 0, "Amounts must be greater than 0");
        require(k == 0, "Already initialized");

        // Transfer tokens from sender to contract
        IERC20(tokenX).transferFrom(msg.sender, address(this), xAmountIn);
        IERC20(tokenY).transferFrom(msg.sender, address(this), yAmountIn);

        xReserve = xAmountIn;
        yReserve = yAmountIn;
        k = xAmountIn * yAmountIn;
    }

    // add parameters and implement function.
    // this function will increase the 'k'
    // because it is transferring liquidity from users to this contract.
    // function _addLiquidityNotFirstTime() internal {}
    function _addLiquidityNotFirstTime(uint256 xAmountIn, uint256 yAmountIn) internal {
        require(xAmountIn > 0 && yAmountIn > 0, "Amounts must be greater than 0");

        IERC20(tokenX).transferFrom(msg.sender, address(this), xAmountIn);
        IERC20(tokenY).transferFrom(msg.sender, address(this), yAmountIn);

        xReserve += xAmountIn;
        yReserve += yAmountIn;
        k = xReserve * yReserve;
    }


    // complete the function
    function addLiquidity(uint256 xAmountIn, uint256 yAmountIn) external {
        uint256 amountX;
        uint256 amountY;
        if (tokenX < tokenY) {
            amountX = xAmountIn;
            amountY = yAmountIn;
        } else {
            amountX = yAmountIn;
            amountY = xAmountIn;
        }

        emit AddLiquidity(xAmountIn, yAmountIn);
        if (k == 0) {
            // add params
            _addLiquidityFirstTime(xAmountIn, yAmountIn);
        } else {
            // add params
            _addLiquidityNotFirstTime(xAmountIn, yAmountIn);
        }
    }


    function swap(uint256 xAmountIn, uint256 yAmountIn) external {
        require(k > 0, "No liquidity in pool");
        require(xAmountIn > 0 || yAmountIn > 0, "Must swap at least one token");
        require((xAmountIn == 0) != (yAmountIn == 0), "Can only swap one direction at a time");

        uint256 amountX;
        uint256 amountY;
        if (tokenX < tokenY) {
            amountX = xAmountIn;
            amountY = yAmountIn;
        } else {
            amountX = yAmountIn;
            amountY = xAmountIn;
        }

        if (amountX > 0) {
            // Check that user has enough tokens to swap
            require(amountX <= IERC20(tokenX).balanceOf(msg.sender), "Insufficient balance");
            
            // Check that we have enough liquidity in the pool for this swap
            // We need to ensure that the pool can actually handle this swap
            uint256 poolBalance = IERC20(tokenX).balanceOf(address(this));
            require(amountX <= poolBalance, "Insufficient liquidity");
            
            // Check that pool has enough liquidity for this swap
            uint256 newXReserve = xReserve + amountX;
            uint256 yOut = yReserve - (k / newXReserve);
            
            // Output must be strictly positive and strictly less than yReserve
            require(yOut > 0 && yOut < yReserve, "Insufficient liquidity");

            IERC20(tokenX).transferFrom(msg.sender, address(this), amountX);
            IERC20(tokenY).transfer(msg.sender, yOut);

            xReserve = newXReserve;
            yReserve -= yOut;
            k = xReserve * yReserve;

            emit Swap(amountX, yOut);
        } else {
            // Check that user has enough tokens to swap
            require(amountY <= IERC20(tokenY).balanceOf(msg.sender), "Insufficient balance");
            
            // Check that we have enough liquidity in the pool for this swap
            // We need to ensure that the pool can actually handle this swap
            uint256 poolBalance = IERC20(tokenY).balanceOf(address(this));
            require(amountY <= poolBalance, "Insufficient liquidity");
            
            // Check that pool has enough liquidity for this swap
            uint256 newYReserve = yReserve + amountY;
            uint256 xOut = xReserve - (k / newYReserve);
            
            // Output must be strictly positive and strictly less than xReserve
            require(xOut > 0 && xOut < xReserve, "Insufficient liquidity");

            IERC20(tokenY).transferFrom(msg.sender, address(this), amountY);
            IERC20(tokenX).transfer(msg.sender, xOut);

            yReserve = newYReserve;
            xReserve -= xOut;
            k = xReserve * yReserve;

            emit Swap(xOut, amountY);
        }
    }

}
