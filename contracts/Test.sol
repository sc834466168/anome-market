// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "contracts/Utils.sol";
import "contracts/AnomeMaterialOwner.sol";

contract Test {
    using Utils for *;
    uint256[] te;

//0x05a3782B98a846063531bF20F589cC35CF5c4dB4
//https://ipfs.io/ipfs/Qma4mH3qXoyWscdGHTJj8UrHAnCn1gq1x97aPjf5WRumX2?filename=metadata.json
//0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6

    function convert(uint256 number) public pure returns (bytes memory) {
        return number.toBytes();
    }

    function convertUint(bytes memory number) public pure returns (uint256) {
        return number.toUint();
    }

    function admin() public pure returns (bytes32) {
       return keccak256("MINTER_ROLE");
    }

    function addressThis() public view returns (address){
        return address(this);
    }

    function test() public virtual {
        te.push(123);
    }

    function get() public view returns (uint256[] memory) {
        return te;
    }

    function remove() external  {
        te.remove(0);
    }
}