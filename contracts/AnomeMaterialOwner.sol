// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "contracts/AnomeMaterial.sol";
import "contracts/Utils.sol";
import "contracts/AnomeBill.sol";
import "contracts/AnomeRecommendation.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


contract AnomeMaterialOwner is ERC1155Receiver, Initializable, OwnableUpgradeable, UUPSUpgradeable{
    using Utils for *;

    AnomeBill private _nft;
    ERC20 private _token;

    AnomeMaterial private _anomeMaterial;

    uint256 private _mintFee;

    uint256[] private _allTokens;

    AnomeRecommendation private _recommendation;

    mapping (uint256 => Material) private _materials;

    struct Material {
        uint256[] _materialTokens;
        uint256[] _materialAllTokens;
        uint256 _transferFee;
        bool init;
    }

    constructor()  {
        _disableInitializers();

    }

    function initialize() initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function start(address tokenAddress, address nft, address material, address recommendation) public onlyOwner payable {

        _token = ERC20(tokenAddress);
        _nft = AnomeBill(nft);
        _anomeMaterial = AnomeMaterial(material);
        _recommendation = AnomeRecommendation(recommendation);
        uint256 decimals = _token.decimals();
        _mintFee = 1 * (10 ** decimals);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    function getMaterial(uint256 tokenId) public view returns (Material memory) {
        return _materials[tokenId];
    }

    /**
     * 获取剩余的素材1155的token信息
     *
     * Requirements:
     *
     * - `tokenId` NFT的tokenId, 也是交易市场中的项目id
     */
    function getMaterialTokens(uint256 tokenId) public view returns (uint256[] memory) {
        return _materials[tokenId]._materialTokens;
    }

    /**
     * 获取所有素材1155的token信息, 用于校验
     *
     * Requirements:
     *
     * - `tokenId` NFT的tokenId, 也是交易市场中的项目id
     */
    function getMaterialAllTokens(uint256 tokenId) public view returns (uint256[] memory) {
        return _materials[tokenId]._materialAllTokens;
    }

    /**
     * 进行mint, 只有一次mint机会, 需要交易_mintFee预设的交易费用
     * 需要提前授权_mintFee的费用交易授权
     *
     * Requirements:
     *
     * - `to` NFT的凭证的具体地址
     * - `tokenId` NFT铸造的tokenId
     * - `uri` NFT的metadata地址
     * - `transferFee` 交易的费用
     * - `size` 创建素材1155的数量
     */
    function safeMint(address to, uint256 tokenId, string memory uri, uint256 transferFee, uint256 size) external payable {
        //设置交易金额
        Material storage material = _materials[tokenId];

        require(!material.init, "Non-repeatable mint");
        uint256 mintFee = _mintFee;

        //判断是否有对应的token支付, 并转账
        _token.approve(owner(), mintFee);
        require(_token.balanceOf(msg.sender) >= mintFee, "transfer amount exceeds balance");

        //授权不足
        require(_token.allowance(msg.sender, address(this)) >= mintFee, "insufficient allowance");

        //交易手续费
        _token.transferFrom(msg.sender, owner(), mintFee);
        _allTokens.push(tokenId);

        material._transferFee = transferFee;

        //创建1155 token
        _anomeMaterial.mintBatch(address(this), size, uri, tokenId.toBytes());

        //nft创建
        _nft.safeMint(to, tokenId, uri);

        material.init = true;

        _recommendation.referrerTransfer(msg.sender, 1, mintFee);
    }

    function recommendationCode() public payable {
        return _recommendation.recommendationCode(msg.sender);
    }

    function getRecommendationCode() public view returns (uint256) {
        return _recommendation.getRecommendationCode(msg.sender);
    }

    function referrerBind(uint256 code) public payable  {
        _recommendation.referrerBind(msg.sender, code);
    }

    /**
     * 进行交易, 并转账给当前tokenId的owner用户, 并转账transferFee的50%的费用给owner用户
     * 需要提前授权transferFee等值的费用交易授权
     *
     * Requirements:
     *
     * - `tokenId` NFT的tokenId
     */
    function transferMaterialFrom(uint256 tokenId) external payable  {
        Material storage material = _materials[tokenId];
        //nft拥有者
        address ownerOf = _nft.ownerOf(tokenId);
        //当前合约拥有者
        address owner = owner();

        require(ownerOf != address(0), "ERC721: address zero is not a valid owner");

        uint256 mintFee = material._transferFee;

        //判断是否有对应的token支付, 并转账
        require(_token.balanceOf(msg.sender) >= mintFee, "transfer amount exceeds balance");

        //授权不足
        require(_token.allowance(msg.sender, address(this)) >= mintFee, "insufficient allowance");

        //交易费用至当前合约中
        _token.transferFrom(msg.sender, address(this), mintFee);

        //进行分账
        _token.approve(address(this), mintFee);
        _token.transferFrom(address(this), ownerOf, mintFee / 2);
        _token.transferFrom(address(this), owner, mintFee / 2);

        require(material._materialTokens.length > 0, "Have closed the deal");

        _anomeMaterial.safeTransferFrom(address(this), msg.sender, material._materialTokens[0], 1, "");
        emit TransferMaterial(address(this), msg.sender, tokenId, material._materialTokens[0]);

        material._materialTokens.remove(0);

        _recommendation.referrerTransfer(msg.sender, 2, mintFee);
    }

    /**
     * 交易素材事件, 
     *
     * Requirements:
     *
     * - `from` 来源
     * - `to` 交易者
     * - `tokenId` nft的tokenId
     * - `materialTokenId` 素材tokenId
     */
    event TransferMaterial(address from, address to, uint256 tokenId, uint256 materialTokenId);


    event MintMaterial(address to, uint256 tokenId, uint256[] materialTokenIds);

    function onERC1155Received(
        address,
        address,
        uint256 id,
        uint256,
        bytes calldata data
    ) public virtual override returns (bytes4) {
        uint256 tokenId = data.toUint();
        Material storage material = _materials[tokenId];
        //拒绝铸造的数据创建
        require(!material.init, "Non-repeatable mint");

        //增加铸造完成的数据至缓存中
        material._materialAllTokens.push(id);
        material._materialTokens.push(id);
        
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address to,
        uint256[] calldata ids,
        uint256[] calldata,
        bytes calldata data
    ) public virtual  override returns (bytes4 selector) {
        uint256 tokenId = data.toUint();
        Material storage material = _materials[tokenId];
        //拒绝铸造的数据创建
        require(!material.init, "Non-repeatable mint");

        //增加铸造完成的数据至缓存中
        for(uint256 i = 0; i < ids.length; i++) {
            material._materialAllTokens.push(ids[i]);
            material._materialTokens.push(ids[i]);
        }

        emit MintMaterial(to, tokenId, ids);
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }

    function convert(uint256 number) public pure returns (string memory) {
        return number.toString();
    }

    function convertUint(bytes memory number) public pure returns (uint256) {
        return number.toUint();
    }
}