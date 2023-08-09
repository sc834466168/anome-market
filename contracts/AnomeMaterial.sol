// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";

contract AnomeMaterial is ERC1155, ERC1155URIStorage, ERC1155PresetMinterPauser, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    constructor() ERC1155PresetMinterPauser("") {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(address account, bytes memory data)
        public
    {
        uint256 id = counter();
        mint(account, id, data);
    }

    function mint(address account, uint256 id, bytes memory data)
        public
    {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have minter role to mint");
        _mint(account, id, 1, data);
    }

    function counter() public returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        return tokenId;
    }

    function mintBatch(address to, uint256 size,  bytes memory data)
        public
    {
        uint256[] memory ids = new uint256[](size);

        for(uint256 i = 0; i < size ;i++){
            ids[i] = counter();
        }

        mintBatch(to, ids, data);
    }

    function mintBatch(address to, uint256[] memory ids,  bytes memory data)
        public
    {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have minter role to mint");
        uint256[] memory amounts = new uint256[](ids.length);

        for(uint256 i = 0; i < ids.length ;i++){
            amounts[i] = 1;
        }

        _mintBatch(to, ids, amounts, data);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155, ERC1155PresetMinterPauser)
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for(uint256 i = 0; i < ids.length; i++) {
            if(ids[i] > _tokenIdCounter._value){
                _tokenIdCounter._value = ids[i];
            }
        }
    }


    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, ERC1155PresetMinterPauser)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function uri(uint256 tokenId) 
        public 
        view 
        virtual 
        override(ERC1155, ERC1155URIStorage) 
        returns (string memory) 
    {
        return super.uri(tokenId);
    }
}