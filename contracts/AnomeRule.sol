// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract AnomeRule is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256[] projectIds;
    mapping(uint256 => RuleProperties) ruleManage;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() initializer public {
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    modifier onlyProjectOwner(uint256 projectId) {
        require(ruleManage[projectId].active, "The projectId rule already exist");
        require(ruleManage[projectId].ownerAddress == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /**
     * 开启规则
     *
     * 默认 RuleVersion.V1的规则
     *
     *
     * Requirements:
     *
     * - `projectId` anome项目id
     * - `contractAddress` ERC20 币种合约
     * - `ownerAddress` ERC20 转币的用户, 当关闭规则时会退还所有币
     * - `nftAddress` ERC721 验证相关的币
     * - `received` 领取的数量
     * - `total` 可领取的总数
     */
    function startRule(uint256 projectId, address contractAddress, address ownerAddress, address nftAddress, uint256 received, uint256 total) public {
        startRule(projectId, contractAddress, ownerAddress, nftAddress, received, total, RuleVersion.V1);
    }

    /**
     * 开启规则
     *
     * RuleVersion.V1的规则, 一个用户只能领取一次, 并锁定tokenId
     *
     * Requirements:
     *
     * - `projectId` anome项目id
     * - `contractAddress` ERC20 币种合约
     * - `ownerAddress` ERC20 转币的用户, 当关闭规则时会退还所有币
     * - `nftAddress` ERC721 验证相关的币
     * - `received` 领取的数量
     * - `total` 可领取的总数
     * - `version` 支持验证规则版本号
     * 
     */
    function startRule(uint256 projectId, address contractAddress, address ownerAddress, address nftAddress, uint256 received, uint256 total, RuleVersion version) public {
        RuleProperties storage ruleProperties = ruleManage[projectId];
        require(!ruleProperties.active, "The projectId rule already exist");

        ruleProperties.projectId = projectId;
        ruleProperties.contractAddress = contractAddress;
        ruleProperties.ownerAddress = ownerAddress;
        ruleProperties.nftAddress = nftAddress;
        ruleProperties.received = received;
        ruleProperties.amount = 0;
        ruleProperties.total = total;
        ruleProperties.version = version;

        //进行数据上的校验
        _checkStartRule(ruleProperties);

        ruleProperties.active = true;
        projectIds.push(projectId);

        emit ChangeRule(true, ruleProperties.projectId, ruleProperties.contractAddress, ruleProperties.ownerAddress, ruleProperties.nftAddress, ruleProperties.received, ruleProperties.total, ruleProperties.version);
    }

    event ChangeRule(bool isStart, uint256 projectId, address contractAddress, address ownerAddress, address nftAddress, uint256 received, uint256 total, RuleVersion version);

    /**
     * 停止规则, 并返还token
     *
     * 
     *
     * Requirements:
     *
     * - `projectId` anome项目id
     * 
     */
    function stopRule(uint256 projectId) public onlyProjectOwner(projectId) {
        RuleProperties storage ruleProperties = ruleManage[projectId];
        require(!ruleProperties.active, "The projectId rule already exist");

        IERC20 _token = IERC20(ruleProperties.contractAddress); 
        _token.transfer(ruleProperties.ownerAddress, ruleProperties.amount);
        delete ruleManage[projectId];

        emit ChangeRule(false, ruleProperties.projectId, ruleProperties.contractAddress, ruleProperties.ownerAddress, ruleProperties.nftAddress, ruleProperties.received, ruleProperties.total, ruleProperties.version);
    }

    /**
     * 根据规则获取token
     *
     * 
     *
     * Requirements:
     *
     * - `projectId` anome项目id
     * 
     */
    function requestTokens(uint256 projectId) public  {
        RuleProperties storage ruleProperties = ruleManage[projectId];
        require(ruleProperties.active, "The projectId rule already exist");

        IERC20 _token = IERC20(ruleProperties.contractAddress); // 创建IERC20合约对象
        IERC721Enumerable _nft = IERC721Enumerable(ruleProperties.nftAddress);

        uint256 tokenId = _check(ruleProperties, _token, _nft);

        _token.transfer(msg.sender, ruleProperties.received); // 发送token

        //判断是否初始化, 如果初始化在基础上添加
        if(!ruleProperties.requestedAddress[msg.sender].init) {
            RequestAmount storage requestAmount = ruleProperties.requestedAddress[msg.sender];
            requestAmount.amount = ruleProperties.received;
            requestAmount.pull = true;
            requestAmount.init = true;
            requestAmount.count = 1;
            requestAmount.tokenIds.push(tokenId);
            ruleProperties.receivedAddress.push(msg.sender);
        } else {
            ruleProperties.requestedAddress[msg.sender].pull = true;
            ruleProperties.requestedAddress[msg.sender].amount += ruleProperties.received;
            ruleProperties.requestedAddress[msg.sender].count++;
            ruleProperties.requestedAddress[msg.sender].tokenIds.push(tokenId);
        }

        ruleProperties.amount += ruleProperties.received;
        emit Transfer(projectId, msg.sender, tokenId, ruleProperties.received, ruleProperties.tokenName, ruleProperties.decimals); // 释放SendToken事件
    }

    /**
     * 结算指定的用户
     *
     * Requirements:
     *
     * - `projectId` anome项目id
     * - `owner` 用户地址
     * 
     */
    function balanceOf(uint256 projectId, address owner) public view returns (Result memory) {
        require(ruleManage[projectId].active, "The projectId rule already exist");
        return Result(projectId, _isReceived(ruleManage[projectId]), owner, ruleManage[projectId].amount, ruleManage[projectId].total, ruleManage[projectId].version, ruleManage[projectId].tokenName, ruleManage[projectId].decimals, ruleManage[projectId].requestedAddress[owner].tokenIds, ruleManage[projectId].active);
    }


    /**
     * 获取所有项目的结算数据
     *
     * 
     */
   function totalSupply() public view returns (Result[] memory) {
        return totalSupply(msg.sender);
   }

    /**
     * 获取所有项目的结算数据
     *
     * Requirements:
     *
     * - `owner` 用户地址
     * 
     */
   function totalSupply(address owner) public view returns (Result[] memory) {
        Result[] memory results = new Result[](projectIds.length);

        for(uint i = 0; i < projectIds.length; i++){
            results[i] = balanceOf(projectIds[i], owner);
        }

        return results;
   }

    /**
     * 设置ERC20的小数点, 当支持IERC20Metadata的decimals()方法时调用
     *
     * Requirements:
     *
     * - `projectId` 项目id
     * 
     */  
    function decimals(uint256 projectId) public onlyProjectOwner(projectId) {
        require(ruleManage[projectId].active, "The projectId rule already exist");
        // require(ruleManage[projectId].hasDecimals, "The ERC20 exist decimals()");

        IERC20Metadata _token = IERC20Metadata(ruleManage[projectId].contractAddress); 
        
        if(ruleManage[projectId].hasDecimals){
            ruleManage[projectId].decimals = _token.decimals();
            ruleManage[projectId].tokenName = _token.symbol();
        } else {
            try _token.decimals() returns (uint8 decimal) {
                ruleManage[projectId].decimals = decimal;
                ruleManage[projectId].tokenName = _token.symbol();
                ruleManage[projectId].hasDecimals = true;
            } catch {
                revert("The ERC20 exist decimals()");
            }
        }
    }

    /**
     * 设置ERC20的小数点, 当不支持IERC20Metadata的decimals()方法时调用
     *
     * Requirements:
     *
     * - `projectId` 项目id
     * - `decimal` 小数点
     * 
     */  
    function decimals(uint256 projectId, string memory tokenName, uint8 decimal) public onlyProjectOwner(projectId) {
        require(ruleManage[projectId].active, "The projectId rule already exist");
        require(!ruleManage[projectId].hasDecimals, "The ERC20 not exist decimals()");

        ruleManage[projectId].tokenName = tokenName;
        ruleManage[projectId].decimals = decimal;
    }

    /**
     * 推送每次交易的数据
     *
     * Requirements:
     *
     * - `result` 返回的结算数据
     * 
     */
    event Transfer(uint256 indexed projectId, address indexed receivedAddress, uint256 tokenId, uint256 received, string tokenName, uint8 decimals); 


    function referRule() public onlyOwner  {
        for(uint256 i = 0; i <  projectIds.length; i++) {
            _referRule(projectIds[i]);
        }
    }

    function referRule(uint projectId) public onlyProjectOwner(projectId) {
        _referRule(projectId);
    }

    function _checkStartRule(RuleProperties storage properties) private  {
        if(RuleVersion.V1 == properties.version) {
            _checkStartRuleV1(properties);
        } else if(RuleVersion.V2 == properties.version) {
            _checkStartRuleV1(properties);
        } else if(RuleVersion.V3 == properties.version) {
            _checkStartRuleV1(properties);
        } else {
            require(false, "not support RuleVersion");
        }
    }

    function _checkStartRuleV1(RuleProperties storage properties) private {
        IERC20 _token = IERC20(properties.contractAddress); 
        
        uint256 price = _token.balanceOf(properties.ownerAddress);
        require(properties.ownerAddress == msg.sender, "The owner account must be the initiator");
        require(price >= properties.total, "The owner account balance is insufficient");

        //进行转账, 需要自行授权
        _token.transferFrom(properties.ownerAddress, address(this), properties.total);

        IERC20Metadata _tokenMetadata = IERC20Metadata(properties.contractAddress); 
        try _tokenMetadata.decimals() returns (uint8 decimal) {
            properties.decimals = decimal;
            properties.tokenName = _tokenMetadata.symbol();
            properties.hasDecimals = true;
        } catch {
            properties.hasDecimals = false;
        }
    }

    function _isReceived(RuleProperties storage properties) private view returns (bool pull) {
         if(RuleVersion.V1 == properties.version) {
            pull = _isReceivedV1(properties);
        } else if(RuleVersion.V2 == properties.version) {
            pull = _isReceivedV1(properties);
        } else if(RuleVersion.V3 == properties.version) {
            pull = _isReceivedV1(properties);
        } else {
            require(false, "not support RuleVersion");
        }
    }

    function _isReceivedV1(RuleProperties storage properties) private view returns (bool) {
        RequestAmount storage requestAmount = properties.requestedAddress[msg.sender];
        return requestAmount.tokenIds.length > 0;
    }

    function _isReceivedV2(RuleProperties storage properties) private view returns (bool received) {
        RequestAmount storage requestAmount = properties.requestedAddress[msg.sender];
        IERC721Enumerable _nft = IERC721Enumerable(properties.nftAddress);
        uint256 length = _nft.balanceOf(_msgSender());
        received = true;

        //根据tokenId, 判定是否领取过, 
        for(uint i = 0; i < length; i++) {
            uint256 tokenId = _nft.tokenOfOwnerByIndex(_msgSender(), i);

            if(!requestAmount.receivedtokenIds[tokenId]) {
                received = false;
                break;
            }
        }
    }

    function _check(RuleProperties storage properties, IERC20 _token, IERC721Enumerable _nft)  private returns (uint256 tokenId)   {
        if(RuleVersion.V1 == properties.version) {
            tokenId = _checkV1(properties, _token, _nft);
        } else if(RuleVersion.V2 == properties.version) {
            tokenId = _checkV2(properties, _token, _nft);
        } else if(RuleVersion.V3 == properties.version) {
            tokenId = _checkV2(properties, _token, _nft);
        } else {
            require(false, "not support RuleVersion");
        }
    }

    function _checkV1(RuleProperties storage ruleProperties, IERC20 _token, IERC721Enumerable _nft) private returns (uint256) {
        bool received = _isReceived(ruleProperties);

        if(received) {
            if(!ruleProperties.requestedAddress[msg.sender].pull){
                revert("Not has nft");
            } else {
                revert("No further collection is allowed");
            }
        }

        uint256 length = _nft.balanceOf(_msgSender());
        uint256 tokenId;
        bool hasTokenId = false;

        require(length > 0, "Not has nft!"); // 每个地址只能领一次

        //根据tokenId, 判定是否领取过, 
        for(uint i = 0; i < length; i++) {
            tokenId = _nft.tokenOfOwnerByIndex(_msgSender(), i);

            if(!ruleProperties.allTokens[tokenId]) {
                ruleProperties.allTokensCount.push(tokenId);
                ruleProperties.allTokens[tokenId] = true;
                hasTokenId = true;
                break;
            }
        }

        require(hasTokenId, "All nft have been redeemed!");
        require(_token.balanceOf(address(this)) >= ruleProperties.received, "Faucet Empty!"); // 水龙头空了
        require(ruleProperties.received <= ruleProperties.total - ruleProperties.amount, "Complete collection!"); // 水龙头空了

        return tokenId;
    }

    function _checkV2(RuleProperties storage ruleProperties, IERC20 _token, IERC721Enumerable _nft) private returns (uint256) {
        uint256 length = _nft.balanceOf(_msgSender());
        uint256 tokenId;
        bool hasTokenId = false;

        require(length > 0, "Not has nft!"); // 每个地址只能领一次

        //根据tokenId, 判定是否领取过, 
        for(uint i = 0; i < length; i++) {
            tokenId = _nft.tokenOfOwnerByIndex(_msgSender(), i);

            if(!ruleProperties.allTokens[tokenId]) {
                ruleProperties.allTokensCount.push(tokenId);
                ruleProperties.allTokens[tokenId] = true;
                hasTokenId = true;
                break;
            }
        }

        require(hasTokenId, "All nft have been redeemed!");
        require(_token.balanceOf(address(this)) >= ruleProperties.received, "Faucet Empty!"); // 水龙头空了
        require(ruleProperties.received <= ruleProperties.total - ruleProperties.amount, "Complete collection!"); // 水龙头空了

        return tokenId;
    }

    function _referRule(uint projectId) private   {
        RuleProperties storage properties = ruleManage[projectId];

        

        for(uint256 i = 0; i < properties.allTokensCount.length; i++) {
            delete properties.allTokens[properties.allTokensCount[i]];
        }
        delete properties.allTokensCount;

        for(uint256 i = 0; i < properties.receivedAddress.length; i++) {
            delete properties.requestedAddress[properties.receivedAddress[i]];
        }

        delete properties.receivedAddress;

        //进行转账, 需要自行授权
        IERC20 _token = IERC20(properties.contractAddress); 
        _token.transferFrom(properties.ownerAddress, address(this), properties.amount);
        properties.amount = 0;
    }

    struct RuleProperties {
            uint256 projectId;          //项目id
            address contractAddress;    //合约地址
            address ownerAddress;       //超管地址
            address nftAddress;         //nft地址
            uint256 received;           //用户一次领取数量
            uint256 amount;             //所有用户已经领取的数量
            uint256 total;              //初始总数
            bool active;                //是否启用
            string tokenName;           //token的名称
            uint8 decimals;             //几位小数
            bool hasDecimals;           //是否拥有小数点
            RuleVersion version;        //运行的规则版本

            uint256[] allTokensCount;   //所有领取的tokenid
            mapping(uint256 => bool) allTokens; //tokenid 是否领取

            address[] receivedAddress;   // 记录领取过代币的地址
            mapping(address => RequestAmount) requestedAddress;   // 记录领取过代币的地址
    }

    struct RequestAmount {
        uint256 amount;     //当前账户领取的数量
        bool init;          //是否初始化
        bool pull;          //是否可以领取
        uint128 count;      //领取的次数
        uint256[] tokenIds; //兑换的nft的id
        mapping(uint256 => bool) receivedtokenIds;   // 记录领取过代币的地址
    }

    struct Result {
        uint256 projectId;          //项目id
        bool isReceived;            //当前用户是否已领取
        address receivedAddress;    //领取的地址
        uint256 amount;             //该项目领取的数量
        uint256 total;              //该项目的总数
        RuleVersion version;        //版本
        string tokenName;
        uint8 decimals;             //几位小数
        uint256[] tokenIds;
        bool active;                //该项目是否启用
    }

    enum RuleVersion {
        V1, V2, V3
    }
}