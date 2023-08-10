// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract AnomeRecommendation is AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address[] public referrers;

    mapping(uint256 => address) referrerCode;

    mapping(address => ReferrerData) referrerData;

    constructor(){
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
    }

    struct ReferrerData {
        Referrer[] data;
        uint256 code;
        address referrer;
    }

    struct Referrer {
        address to;
        uint256 status;
        uint256 fee;
    }

    function getData() public view returns (ReferrerData memory) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "AnomeRecommendation: must have minter role to get code");
        return referrerData[msg.sender];
    }

    function getData(address from) public view returns (ReferrerData memory) {
        require(hasRole(MINTER_ROLE, _msgSender()), "AnomeRecommendation: must have minter role to get code");
        return referrerData[from];
    }

    function recommendationCode(address from) public  {
        require(hasRole(MINTER_ROLE, _msgSender()), "AnomeRecommendation: must have minter role to get code");
        _recommendationCode(from);
    }

    function _recommendationCode(address from) public  {
        if(referrerData[from].code != 0) {
            return;
        }

        uint256 code = _rand();

        referrerCode[code] = from;
        referrerData[from].code = code;
        emit ReferrerBind(from, code);

        referrers.push(from);
    }

    function getRecommendationCode(address from) public view returns(uint256) {
        require(referrerData[from].code != 0, "AnomeRecommendation: must recommendationCode first");

        return referrerData[from].code;
    }

    function referrerBind(address from, uint256 code) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "AnomeRecommendation: must have minter role to bind");
        _referrerBind(from, code);
    }

    function _referrerBind(address from, uint256 code) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "AnomeRecommendation: must have minter role to bind");
        address referrer = referrerCode[code];
        require(referrerCode[code] != address(0), "Create a recommendation code first");
        require(referrer != from, "AnomeRecommendation: not bind this");
        require(referrerData[referrer].referrer == address(0), "The recommendation code has been bound");
        referrerData[from].referrer = referrer;
    }

    event ReferrerBind(address from, uint256 code);

    event ReferrerTransfer(address from, address referrer, uint256 status, uint256 fee);

    function referrerTransfer(address from, uint256 status, uint256 fee) public {
        require(hasRole(MINTER_ROLE, _msgSender()), "AnomeRecommendation: must have minter role to transfer");
        ReferrerData storage data = referrerData[from];
        address referrer = data.referrer;

        if(referrer != address(0)) {
            referrerData[referrer].data.push(Referrer(from, status, fee));
            emit ReferrerTransfer(from, referrer, status, fee);
        }
    }

    function _rand() private returns (uint256) {
        uint256 random = uint256(keccak256(abi.encodePacked(block.difficulty, msg.sender)));
        uint256 code = random % 10000000000;

        if(referrerCode[code] == address(0)) {
            return code;
        } else {
            return _rand();
        }
    }
}