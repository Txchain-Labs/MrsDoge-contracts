// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;



library MathUtils {

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function eighthRoot(uint y) internal pure returns (uint z) {
        return sqrt(sqrt(sqrt(y)));
    }
}


