// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ISimpleSwap } from "./interface/ISimpleSwap.sol";
import { Math } from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import { TestERC20 } from "./test/TestERC20.sol";

contract SimpleSwap is ISimpleSwap, ERC20 {
    using SafeMath for uint256;
    address private tokenA;
    address private tokenB;
    uint256 private reserveA;
    uint256 private reserveB;

    constructor(address _tokenA, address _tokenB) ERC20("LpToken", "LP") {
        uint256 codeSizeA;
        assembly {
            codeSizeA := extcodesize(_tokenA)
        }
        require(codeSizeA > 0, "SimpleSwap: TOKENA_IS_NOT_CONTRACT");
        uint256 codeSizeB;
        assembly {
            codeSizeB := extcodesize(_tokenB)
        }
        require(codeSizeB > 0, "SimpleSwap: TOKENB_IS_NOT_CONTRACT");
        require(_tokenA != _tokenB, "SimpleSwap: TOKENA_TOKENB_IDENTICAL_ADDRESS");
        require(_tokenA != address(0) && _tokenB != address(0), "Invalid token addresses");
        (tokenA, tokenB) = _tokenA <= _tokenB ? (_tokenA, _tokenB) : (_tokenB, _tokenA);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn) external override returns (uint256 amountOut) {
        require(tokenIn == tokenA || tokenIn == tokenB, "SimpleSwap: INVALID_TOKEN_IN");
        require(tokenOut == tokenA || tokenOut == tokenB, "SimpleSwap: INVALID_TOKEN_OUT");
        require(tokenIn != tokenOut, "SimpleSwap: IDENTICAL_ADDRESS");
        require(amountIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        uint256 K = reserveA * reserveB;
        if (tokenIn == tokenA) {
            amountOut = reserveB.sub(K.div(reserveA.add(amountIn)));
            reserveA = reserveA.add(amountIn);
            reserveB = reserveB.sub(amountOut);
        } else {
            amountOut = reserveA.sub(K.div(reserveB.add(amountIn)));
            reserveB = reserveB.add(amountIn);
            reserveA = reserveA.sub(amountOut);
        }
        TestERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        TestERC20(tokenOut).transfer(msg.sender, amountOut);

        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    function addLiquidity(
        uint256 amountAIn,
        uint256 amountBIn
    ) external override returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(amountAIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");
        require(amountBIn > 0, "SimpleSwap: INSUFFICIENT_INPUT_AMOUNT");

        if (reserveA == 0 && reserveB == 0) {
            amountA = amountAIn;
            amountB = amountBIn;
        } else {
            amountB = amountAIn.mul(reserveB).div(reserveA);
            amountA = amountAIn;
            if (amountB > amountBIn) {
                amountB = amountBIn;
                amountA = amountBIn.mul(reserveA).div(reserveB);
            }
        }
        reserveA += amountA;
        reserveB += amountB;

        liquidity = Math.sqrt(amountA * amountB);
        TestERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        TestERC20(tokenB).transferFrom(msg.sender, address(this), amountB);
        _mint(msg.sender, liquidity);
        emit AddLiquidity(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity) external override returns (uint256 amountA, uint256 amountB) {
        require(liquidity > 0, "SimpleSwap: INSUFFICIENT_LIQUIDITY_BURNED");

        amountA = (reserveA * liquidity) / totalSupply();
        amountB = (reserveB * liquidity) / totalSupply();
        this.transferFrom(msg.sender, address(this), liquidity);
        _burn(address(this), liquidity);
        TestERC20(tokenA).transfer(msg.sender, amountA);
        TestERC20(tokenB).transfer(msg.sender, amountB);

        emit RemoveLiquidity(msg.sender, amountA, amountB, liquidity);
    }

    function getReserves() external view override returns (uint256 reserveAValue, uint256 reserveBValue) {
        return (reserveA, reserveB);
    }

    function getTokenA() external view override returns (address tokenAAddress) {
        return tokenA;
    }

    function getTokenB() external view override returns (address tokenBAddress) {
        return tokenB;
    }
}
