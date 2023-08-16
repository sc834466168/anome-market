// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library Utils {

    function toBytes(uint256 number) public pure returns (bytes memory) {
        bytes memory numberInBytes = abi.encodePacked(number);
        return numberInBytes;
    }

    function toString(uint256 number) public pure returns (string memory) {
        bytes memory numberInBytes = abi.encodePacked(number);
        return string(numberInBytes);
    }

    function toString(bytes memory number) public pure returns (string memory) {
        return string(number);
    }

    function toUint(bytes calldata data) public pure returns (uint256) {
        return uint256(bytes32(data));
    }

    function remove(uint256[] storage array, uint256 index) public returns (uint256[] memory)  {
        if (index >= array.length) return array;

        for (uint256 i = index; i < array.length - 1; i++){
            array[i] = array[i + 1];
        }
        
        array.pop();

        return array;
    }
}