// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "contracts/AnomeMaterial.sol";
import "contracts/Utils.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

contract AnomeMaterialOwner is ERC721, ERC721Enumerable, ERC721URIStorage, ERC1155Receiver, Ownable {
    using Counters for Counters.Counter;
    using Utils for *;

    Counters.Counter private _tokenIdCounter;

    ERC20 private _token;

    AnomeMaterial private _anomeMaterial;

    uint256 private _mintFee;

    uint256[] private _allTokens;

    mapping (uint256 => Material) private _materials;

    struct Material {
        uint256[] _materialTokens;
        uint256[] _materialAllTokens;
        uint256 _transferFee;
        bool init;
    }

    constructor(address tokenAddress, address material) ERC721("AnomeMaterialOwner", "MTK") payable  {
        _token = ERC20(tokenAddress);
        _anomeMaterial = AnomeMaterial(material);
        uint256 decimals = _token.decimals();
        _mintFee = 1 * (10 ** decimals);
    }

    function getMaterialTokens(uint256 tokenId) public view returns (uint256[] memory) {
        return _materials[tokenId]._materialTokens;
    }

    function safeMint(address to, uint256 tokenId, string memory uri, uint256 transferFee, uint256 size) external payable {
        uint256 mintFee = _mintFee;

        //判断是否有对应的token支付, 并转账
        _token.approve(owner(), mintFee);
        require(_token.balanceOf(msg.sender) >= mintFee, "Underpayment of commission");
        _token.transferFrom(msg.sender, owner(), mintFee);
        _allTokens.push(tokenId);

        //设置交易金额
        Material storage material = _materials[tokenId];
        material._transferFee = transferFee;
        material.init = true;
        uint256[] memory ids = new uint256[](size);

        for(uint256 i = 0; i < size; i++) {
            ids[i] = _anomeMaterial.counter();
        }

        //创建1155 token
        _anomeMaterial.mintBatch(address(this), ids, tokenId.toBytes());

        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);

        for(uint256 i = 0; i < size; i++) {
            material._materialAllTokens.push(ids[i]);
            material._materialTokens.push(ids[i]);
        }
    }

    function transferMaterialFrom(uint256 tokenId) external payable  {
        Material storage material = _materials[tokenId];
        address ownerOf = ownerOf(tokenId);
        address owner = owner();
        require(ownerOf != address(0), "ERC721: address zero is not a valid owner");

        uint256 mintFee = material._transferFee;

        //判断是否有对应的token支付, 并转账
        require(_token.balanceOf(msg.sender) >= mintFee, "Underpayment of commission");

        //授权不足
        require(_token.allowance(msg.sender, address(this)) >= mintFee, "Underpayment of commission");

        _token.transferFrom(msg.sender, address(this), mintFee);

        _token.approve(address(this), mintFee);
        _token.transferFrom(address(this), ownerOf, mintFee / 2);
        _token.transferFrom(address(this), owner, mintFee / 2);

        require(material._materialTokens.length > 0, "Have closed the deal");

        _anomeMaterial.safeTransferFrom(address(this), msg.sender, material._materialTokens[0], 1, "");
        material._materialTokens.remove(0);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) public virtual  override returns (bytes4 selector) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, ERC1155Receiver)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function convert(uint256 number) public pure returns (string memory) {
        return number.toString();
    }

    function convertUint(bytes memory number) public pure returns (uint256) {
        return number.toUint();
    }
}