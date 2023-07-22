// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract BasicERC1155 is ERC1155 {

    event Fractionalized(uint256 tokenId,address caller,uint256 shares);

    event Defractionalized(uint256 tokenId,address caller, address withdrawAddress);

    struct Uri{
        string value;
        uint256 tokenId;
    }

    address public nftContract;
    mapping(address => mapping(uint256 => uint256)) balances;
    mapping(address => mapping(address => bool)) approvals;
    mapping(uint256 => uint256) tokenSupply;
    //mapping(address => mapping(uint256 => bool)) isFractionalized;
    mapping(address => uint256[]) userHoldings;

    function Fractionalize(uint256 _nftId, uint256 _shares) public {
        require(!isFractionalized(_nftId), "NFT is already fractionalized");
        require(_shares>0, "Shares must be greater than zero");

        safeTransferFrom(msg.sender, msg.sender, _nftId, _shares, "");

        tokenSupply[_nftId]+=_shares;
        addToHolding(msg.sender, _nftId);
        
        emit Fractionalized(_nftId, msg.sender, _shares);
    }

    function Defractionalize(uint256 _nftId, address _accountId) public {
        require(isFractionalized(_nftId), "Token is non-existent");
        require(balances[msg.sender][_nftId]==tokenSupply[_nftId], "Insufficient balance");

        uint256 userBalance = balances[msg.sender][_nftId];
        tokenSupply[_nftId] = 0;
        balances[msg.sender][_nftId] = 0;
        userHoldings[_accountId] = new uint256[](0);

        safeTransferFrom(msg.sender, _accountId, _nftId, userBalance, "");

        emit Defractionalized(_nftId, msg.sender, _accountId);
    }

    function addToHolding(address account, uint256 tokenId )private{
        uint256[] storage holdings = userHoldings[account];
        holdings.push(tokenId);
        userHoldings[account] = holdings;
    }

    function isFractionalized(uint256 _nftId) public view returns(bool){
        if (tokenSupply[_nftId]==0){
            return false;
        }
        return true;
    }

    function isContract(address addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    function getUserHoldings(address _accountId) public view returns(uint256[][] memory){
        uint256[][] memory result = new uint256[][](100) ;
        uint256[] storage holdings = userHoldings[_accountId];
        for (uint256 i=0;i<holdings.length;i++){
            uint256[] memory row = new uint256[](3);
            row[0] = i;
            row[1] = balances[_accountId][i];
            row[2] = tokenSupply[i];
            result[i] = row;
        }
        return result;
    }

    constructor(string memory uri) ERC1155(uri) {
    }
}