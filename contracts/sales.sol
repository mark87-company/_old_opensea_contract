// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./Factory.sol";
contract NFTSales is Ownable, Pausable, ReentrancyGuard {
    using Strings for string;
    ERC1155 public nftAddress;
    address _owner=msg.sender;
    uint256 public _transactionCounter=0;
    struct priceMapping{
        uint256 price;
        uint256 amount;
    }
    struct transactionStructure{
        address _buyer;
        address _seller;
        uint256 _tokenId;
        uint256 _selling_price;
        uint256 _buying_total_price;
        uint256 _amount;
        bool _batch_purchase;
    }
    //address public this_address  = address(this);
    mapping(uint256 => mapping(address => priceMapping)) public tokenPrice;
    mapping(uint256 => transactionStructure) public transactionMapping;
    //transactionStructure [] public transactionArray;
    constructor(address _nftAddress) public {
        nftAddress = ERC1155(_nftAddress);
    }
    event transactionlog(uint256 index,address _buyer, address _seller, uint256 _tokenId, uint256 _amount,uint256 _sellingPrice,uint256 _purchasePrice);
    event transactionlog_batch(uint256 [] indexes,address _buyer, address _seller, uint256 [] _tokenIds, uint256 [] _amount,uint256  _total_selling_prices,uint256 _purchasePrice);
    event setPricelogbatch(address _seller, uint256 [] _tokenIds, uint256 [] _amounts, uint256 [] _prices);
    event subAmountBatch(address _seller,uint256 [] _tokenIds,uint256 [] _subAmount);
    event setPricelog(address _seller, uint256 _tokenId, uint256 _amount, uint256 _price);
    event setRemovePriceLog(address _seller,uint256 [] _tokenIds);
    //price is price per token
    //판매가격은 wei 로 설정한다.
    function setForSale(uint256 _tokenId, uint256 _price, uint256 _amount) public whenNotPaused{
        //uint256 possess_amount = nftAddress.balanceOf(msg.sender,_tokenId); //해당 계정의 소유자
        require(nftAddress.balanceOf(msg.sender,_tokenId)>0,"the caller does not ");
        //require(tokenOwner ==msg.sender, "caller is not the token owner"); //토큰소유자만 판매가능
        require(_price >0,"price is zero or lower"); //가격이 0보다 커야함.
        require(nftAddress.isApprovedForAll(msg.sender,address(this)), "token owner did not approve the tokensales contract");//플랫폼 대리판매 승인 확인
        tokenPrice[_tokenId][msg.sender].price = _price;
        tokenPrice[_tokenId][msg.sender].amount += _amount; //위에 조건이 만족될때, 가격을 맵핑해서 저장시켜놓음.
        emit setPricelog(msg.sender,_tokenId,_amount,_price);
    }
    //배치 판매 갸격은 wei 로 설정한다.
    function SetForBatchSales(uint256 [] memory _tokenIds, uint256 [] memory _prices, uint256 [] memory _amounts) public whenNotPaused{
        require(nftAddress.isApprovedForAll(msg.sender,address(this)), "token owner did not approve the tokensales contract");//플랫폼 대리판매 승인 확인
        require(_tokenIds.length>0 && _tokenIds.length==_prices.length && _tokenIds.length==_amounts.length,"the array is not matched nor length is 0");
        for (uint256 i; i<_tokenIds.length; i++){
            require(nftAddress.balanceOf(msg.sender,_tokenIds[i])>0,"the caller does not have the token");
            require(_prices[i] >0,"price is zero or lower"); //가격이 0보다 커야함.
            tokenPrice[_tokenIds[i]][msg.sender].price = _prices[i];
            tokenPrice[_tokenIds[i]][msg.sender].amount += _amounts[i];
        }
        emit setPricelogbatch(msg.sender,_tokenIds,_amounts,_prices);
    }
    //판매 수량 빼기
    function subAmountOfSales(uint256 [] memory _tokenIds, uint256 [] memory _sub_amount) public whenNotPaused {
        require(_tokenIds.length>0,"token Ids are required!");
        require(_tokenIds.length==_sub_amount.length,"the length of array is not matched");
        for (uint256 i=0; i<_tokenIds.length;i++){
            require(nftAddress.balanceOf(msg.sender,_tokenIds[i])>0,"the caller does not have the token");
            //require(tokenPrice[_tokenIds[i]][msg.sender].price>0,"token is already not on Sale");
            //tokenPrice[_tokenIds[i]][msg.sender].price=0;
            tokenPrice[_tokenIds[i]][msg.sender].amount-=_sub_amount[i];
        }
        emit subAmountBatch(msg.sender,_tokenIds,_sub_amount);
    }
    //판매 철회
    function withdrawSales(uint256 [] memory _tokenIds) public whenNotPaused{
        require(_tokenIds.length>0,"token Ids are required!");
        for (uint256 i=0; i<_tokenIds.length;i++){
            //require(tokenPrice[_tokenIds[i]][msg.sender].price>0,"token is already not on Sale");
            tokenPrice[_tokenIds[i]][msg.sender].price=0;
            tokenPrice[_tokenIds[i]][msg.sender].amount=0;
        }
        emit setRemovePriceLog(msg.sender,_tokenIds);
    }
    //가격은 wei로 설정한다.
    function purchaseToken(uint256 _tokenId, address _sellerAddress, uint256 _amount) public payable whenNotPaused nonReentrant returns(uint256){
         uint256 price = tokenPrice[_tokenId][_sellerAddress].price*_amount;
         //require(nftAddress.balanceOf(_sellerAddress,_tokenId) >= _amount,"seller do not have enough tokens to sell");
         require(tokenPrice[_tokenId][_sellerAddress].price >0,"the sales item is not on sales or all sold out");
         require(tokenPrice[_tokenId][_sellerAddress].amount >= _amount,"the sales item(s) with the seller address is/are not enough to sell");
         require(msg.value >= price, "the caller sent value lower than its total price");
         require(msg.sender != _sellerAddress,"the caller is a token seller");
         //address payable payableTokenSeller = address(uint160(_sellerAddress));
         (bool success, )= payable(_owner).call{value:msg.value}(""); //change to the bank contract
         require(success, "Transfer failed.");
         nftAddress.safeTransferFrom(_sellerAddress, msg.sender, _tokenId, _amount,""); //전송
         tokenPrice[_tokenId][_sellerAddress].amount-=_amount; // 판매후 가격및 수량 조정.
         //uint256 transactionIndex=transactionArray.length;
         uint256 index = _transactionCounter;
         _transactionCounter++;
         transactionMapping[index]=transactionStructure(msg.sender,_sellerAddress,_tokenId,price,msg.value,_amount,false);
         emit transactionlog(index,msg.sender,_sellerAddress,_tokenId,_amount,price,msg.value);
         return index;
         //return transactionIndex;
    }
    //배치 판매
    function purchaseBatchTokens(uint256 [] memory _tokenIds , uint256 [] memory _amounts , address _sellerAddress)public payable whenNotPaused nonReentrant returns(uint256 [] memory){
        uint256 _price=0;
        uint256[] memory txIndex = new uint256[](_tokenIds.length);
        //uint256[] memory selling_prices = new uint256[](_tokenIds.length);
        require(msg.sender != _sellerAddress,"the caller is a token seller");
        require(_tokenIds.length>0,"no empty array as input");
        for (uint256 i=0;i<_tokenIds.length;i++){
            _price += tokenPrice[_tokenIds[i]][_sellerAddress].price*_amounts[i];
            require(tokenPrice[_tokenIds[i]][_sellerAddress].price >0,"the sales item is not on sales or all sold out");
            require(tokenPrice[_tokenIds[i]][_sellerAddress].amount >= _amounts[i],"the sales item(s) with the seller address is/are not enough to sell");
            tokenPrice[_tokenIds[i]][_sellerAddress].amount-=_amounts[i];
            uint256 index=_transactionCounter;
            transactionMapping[index]=transactionStructure(msg.sender,_sellerAddress,_tokenIds[i],_price,msg.value,_amounts[i],true);
            txIndex[i]=index;
            //selling_prices[i]=tokenPrice[_tokenIds[i]][_sellerAddress].price;
            _transactionCounter++;
        }
        require(msg.value >= _price, "the caller sent value lower than its total price");
        (bool success, )= payable(_owner).call{value:msg.value}(""); //change to the bank contract
        require(success, "Transfer failed.");
        nftAddress.safeBatchTransferFrom(_sellerAddress, msg.sender, _tokenIds, _amounts,""); //전송
        emit transactionlog_batch(txIndex,msg.sender,_sellerAddress,_tokenIds,_amounts,_price,msg.value);
        return txIndex;
    }
    //only Contract Owner
    function emergencyStop() public onlyOwner nonReentrant{
        _pause();
    }
    function removeEmergencyStop() public onlyOwner nonReentrant{
        _unpause();
    }
}