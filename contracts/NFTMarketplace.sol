//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
//import "contracts/FNFToken.sol";

/*
1. transfer ownership to contract while fractionalise
2. createAFNftSell func
tokenId, qty
erc20addressId = tokenId;
transfer(msg.sender, qty)
tokenId.qty - qty
qty*price == price
ListedToken - add field -uint fPrice;
fractionalise(uint fPrice;){token.uint fPrice; = fPrice}
*/

contract NFTMarketplace is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemsSold;
    address payable owner;
    uint256 public listPrice = 1 gwei;

    struct ListedToken {
        uint256 tokenId;
        address payable owner;
        address payable seller;
        uint256 price;
        bool currentlyListed;
        bool fractionalise;
        address fnft;
        uint256 amount;
        uint256 fnftPrice;
    }

    event TokenListedSuccess (uint256 indexed tokenId,address owner,address seller,uint256 price,bool currentlyListed);

    mapping(uint256 => ListedToken) private idToListedToken;

    constructor() ERC721("NFTMarketplace", "NFTM") {
        owner = payable(msg.sender);
    }

    function getTokenFromTokenId(uint256 _tokenId) public view returns (ListedToken memory) {
        return idToListedToken[_tokenId];
    }

    function getListedTokenForId(uint256 tokenId) public view returns (ListedToken memory) {
        return idToListedToken[tokenId];
    }

    function getCurrentToken() public view returns (uint256) {
        return _tokenIds.current();
    }

    function getListPrice() public view returns (uint256) {
        return listPrice;
    }

    function fractionalise(uint256 _tokenId, uint256 _totalFractionalTokens, uint256 _fnftPrice) public returns (ListedToken memory){
        ListedToken memory token = idToListedToken[_tokenId];
        require(!token.fractionalise, "Token already fractionalised");

        FNFToken _fnftoken = (new FNFToken)();
        _fnftoken.mint(address(this), _totalFractionalTokens);
        _fnftoken.approve(address(this), _totalFractionalTokens);
        //_fnftoken.transferFrom(msg.sender, address(this), _totalFractionalTokens * 100000000000000000);

        token.fractionalise = true;
        token.amount = _totalFractionalTokens;
        token.fnft = address(_fnftoken);
        token.fnftPrice = _fnftPrice;
        idToListedToken[_tokenId] = token;
        return token;
    }

    function nftSell(uint256 _tokenId, uint256 _qty) public payable {
        ListedToken memory token = idToListedToken[_tokenId];
        //require(msg.value==_qty*token.fnftPrice, "Pay proper price");
        require(token.amount>=_qty, "Quantity must be less than or equal to amount of tokens");
        ERC20Burnable(token.fnft).transferFrom(address(this), msg.sender, _qty);
        token.amount -= _qty;
        idToListedToken[_tokenId] = token;
    }

    function createToken(string memory tokenURI, uint256 price) public payable returns (uint) {
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        createListedToken(newTokenId, price);
        return newTokenId;
    }

    function createListedToken(uint256 tokenId, uint256 price) private {
        require(msg.value == listPrice, "Hopefully sending the correct price");
        require(price > 0, "Make sure the price isn't negative");
        idToListedToken[tokenId] = ListedToken(tokenId,payable(address(this)),payable(msg.sender),price,true,false,address(0),0,0);
        //_transfer(msg.sender, address(this), tokenId);
        emit TokenListedSuccess(tokenId,address(this),msg.sender,price,true);
    }
    
    //This will return all the NFTs currently listed to be sold on the marketplace
    function getAllNFTs() public view returns (ListedToken[] memory) {
        uint nftCount = _tokenIds.current();
        ListedToken[] memory tokens = new ListedToken[](nftCount);
        uint currentIndex = 0;
        uint currentId;
        //at the moment currentlyListed is true for all, if it becomes false in the future we will 
        //filter out currentlyListed == false over here
        for(uint i=0;i<nftCount;i++)
        {
            currentId = i + 1;
            ListedToken storage currentItem = idToListedToken[currentId];
            tokens[currentIndex] = currentItem;
            currentIndex += 1;
        }
        //the array 'tokens' has the list of all NFTs in the marketplace
        return tokens;
    }
    
    //Returns all the NFTs that the current user is owner or seller in
    function getMyNFTs() public view returns (ListedToken[] memory) {
        uint totalItemCount = _tokenIds.current();
        uint itemCount = 0;
        uint currentIndex = 0;
        uint currentId;
        //Important to get a count of all the NFTs that belong to the user before we can make an array for them
        for(uint i=0; i < totalItemCount; i++)
        {
            if(idToListedToken[i+1].owner == msg.sender || idToListedToken[i+1].seller == msg.sender){
                itemCount += 1;
            }
        }

        //Once you have the count of relevant NFTs, create an array then store all the NFTs in it
        ListedToken[] memory items = new ListedToken[](itemCount);
        for(uint i=0; i < totalItemCount; i++) {
            if(idToListedToken[i+1].owner == msg.sender || idToListedToken[i+1].seller == msg.sender) {
                currentId = i+1;
                ListedToken storage currentItem = idToListedToken[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function executeSale(uint256 tokenId) public payable {
        uint price = idToListedToken[tokenId].price;
        address seller = idToListedToken[tokenId].seller;
        require(msg.value == price, "Please submit the asking price in order to complete the purchase");

        //update the details of the token
        idToListedToken[tokenId].currentlyListed = true;
        idToListedToken[tokenId].seller = payable(msg.sender);
        _itemsSold.increment();

        //Actually transfer the token to the new owner
        _transfer(address(this), msg.sender, tokenId);
        //approve the marketplace to sell NFTs on your behalf
        approve(address(this), tokenId);

        //Transfer the listing fee to the marketplace creator
        payable(owner).transfer(listPrice);
        //Transfer the proceeds from the sale to the seller of the NFT
        payable(seller).transfer(msg.value);
    }
}

contract FNFToken is ERC20, ERC20Burnable, Ownable {
    constructor() ERC20("FNFToken", "FNT") {}

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}