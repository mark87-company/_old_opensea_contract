// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../EIP2981-implementation/contracts/ERC2981PerTokenRoyalties.sol";

contract OwnableDelegateProxy {}

//Rinkeby:0xf57b2c51ded3a29e6891aba85459d600256cf317
//Mainnet:0xa5409ec958c83c3f309868babaca7c86dcb077c1
contract ProxyRegistry {
  mapping(address => OwnableDelegateProxy) public proxies;
}

contract ERC1155Factory is
  ERC1155,
  Ownable,
  ReentrancyGuard,
  ERC2981PerTokenRoyalties
{
  using Strings for string;
  address proxyRegistryAddress;
  uint256 private _currentTokenID = 0;
  struct Royalty_data {
    //address royalty_owner;
    uint16 royalty_percentage;
    bool royalty_set;
  }
  mapping(uint256 => address) public creators;
  mapping(uint256 => uint256) public tokenSupply;
  mapping(uint256 => bool) public tokenNFT;
  mapping(uint256 => Royalty_data) public royaltyInfo;
  mapping(uint256 => string) private _mapURI;
  mapping(address => bool) private _mapAllowed;
  // Contract name
  string public name;
  // Contract symbol
  string public symbol;
  event royalty_record(address tokenOwner, uint256 royaltySetup);
  //event mint_record(uint256 token_id, address tokenOwner,)
  modifier allowed(address _address) {
    require(_mapAllowed[_address] == true, "REGISTERED_USERS_ONLY");
    _;
  }
  /**
   * @dev Require msg.sender to be the creator of the token id
   */
  modifier creatorOnly(uint256 _id) {
    require(
      creators[_id] == msg.sender,
      "ERC1155Tradable#creatorOnly: ONLY_CREATOR_ALLOWED"
    );
    _;
  }
  /**
   * @dev Require msg.sender to own more than 0 of the token id
   */
  modifier ownersOnly(uint256 _tokenId) {
    require(
      balanceOf(msg.sender, _tokenId) > 0,
      "ERC1155Tradable#ownersOnly: ONLY_OWNERS_ALLOWED"
    );
    _;
  }

  constructor(
    string memory _name,
    string memory _symbol,
    address _proxyRegistryAddress,
    string memory _uri
  ) public ERC1155(_uri) {
    name = _name;
    symbol = _symbol;
    proxyRegistryAddress = _proxyRegistryAddress;
    _mint_byOnlyOwner();
    setUserRegistered(msg.sender);
  }

  //1155:0xd9b67a26, 2981 0x2a55205a
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC1155, ERC2981Base)
    returns (bool)
  {
    return
      ERC1155.supportsInterface(interfaceId) ||
      ERC2981Base.supportsInterface(interfaceId);
  }

  //토큰이 존재하는지 체크
  function _exists(uint256 _id) internal view returns (bool) {
    return creators[_id] != address(0);
  }

  //토큰 현재 수량
  function getTokenNumber() public view returns (uint256) {
    return _currentTokenID;
  }

  //토큰 수량 +1 업데이트
  function _setTokenIncrement() private {
    _currentTokenID += 1;
  }

  //발행된 현재 토큰 수량 id 별
  function totalSupply(uint256 _id) public view returns (uint256) {
    return tokenSupply[_id];
  }

  //최초 nft 발행
  function mint_byOtherUsers_1st(
    uint256 _amount,
    string memory _uri,
    bool _nft
  ) public allowed(msg.sender) {
    uint256 _tokenId = getTokenNumber() + 1;
    require(_exists(_tokenId) == false, "the token exists");
    require(_amount > 0, "the token need to be greater than 0");
    if (_nft == true) {
      require(_amount == 1, "nft token should be 1");
    }
    _mint(msg.sender, _tokenId, _amount, "");
    creators[_tokenId] = msg.sender;
    _setURI(_uri);
    seturi(_tokenId, _uri);
    tokenSupply[_tokenId] += _amount;
    tokenNFT[_tokenId] = _nft;
    _setTokenIncrement();
  }

  //추가 nft 발행
  function mint_additionalByOtherusers(uint256 _tokenId, uint256 _amount)
    public
    creatorOnly(_tokenId)
    allowed(msg.sender)
  {
    require(tokenNFT[_tokenId] == false, "NFT is not able to re-generate");
    _mint(msg.sender, _tokenId, _amount, "");
    tokenSupply[_tokenId] += _amount;
  }

  // 배치 nft 발행 처음 발행
  function mint_byAnyOneBatch_1st(
    uint256 _numberOfgenerates,
    uint256[] memory _amounts,
    bool[] memory _nfts,
    string[] memory _uris
  ) public allowed(msg.sender) {
    require(_numberOfgenerates > 0, "at least more than 0 creation");
    require(
      _numberOfgenerates == _nfts.length && _numberOfgenerates == _uris.length,
      "length of array is not matched"
    );
    //uint256 [_numberOfgenerates] memory tokenIds;
    uint256[] memory tokenIds = new uint256[](_numberOfgenerates);
    for (uint256 i = 0; i < _numberOfgenerates; i++) {
      //uint256 _tokenId=getTokenNumber()+1;
      tokenIds[i] = getTokenNumber() + 1;
      tokenNFT[getTokenNumber() + 1] = _nfts[i];
      creators[getTokenNumber() + 1] = msg.sender;
      tokenSupply[getTokenNumber() + 1] += _amounts[i];
      //_setURI(_uris[i]);
      _mapURI[getTokenNumber() + 1] = _uris[i];
      _setTokenIncrement();
    }
    _mintBatch(msg.sender, tokenIds, _amounts, ""); //배치 민트
  }

  // 배치 nft 발행. 추가 발행
  function mint_byAnyOneForAdditional_Batch(
    uint256[] memory _tokenIds,
    uint256[] memory _amounts
  ) public allowed(msg.sender) {
    require(_tokenIds.length > 0, "array length more than 0");
    //require(_tokenIds.length == _nfts.length && _tokenIds.length == _uris.length,"array length is not right");
    for (uint256 i = 0; i < _tokenIds.length; i++) {
      require(_exists(_tokenIds[i]), "token Id is not able to use it");
      require(
        creators[_tokenIds[i]] == msg.sender,
        "you are not the token creator"
      ); //실행자가 토큰 원작자인지 확인
      require(
        tokenNFT[_tokenIds[i]] == false,
        "you are not able to re-generate the token because it is NFT"
      ); //토큰이 NFT인지 확인.(재발행시)
      tokenSupply[_tokenIds[i]] += _amounts[i];
    }
    _mintBatch(msg.sender, _tokenIds, _amounts, ""); //배치 민트
  }

  function getRoyalty(uint256 _tokenId)
    public
    view
    returns (Royalty_data memory)
  {
    return royaltyInfo[_tokenId];
  }

  function uri(uint256 _tokenId) public view override returns (string memory) {
    return _mapURI[_tokenId];
  }

  //only contract owner
  function setUserRegistered(address _userAddress) public onlyOwner {
    _mapAllowed[_userAddress] = true;
  }

  function banUserRegistered(address _userAddress) public onlyOwner {
    _mapAllowed[_userAddress] = false;
  }

  function changeRoyaltySettings(
    uint256 _tokenId,
    uint16 _new_royalty,
    bool _royalty
  ) public onlyOwner {
    royaltyInfo[_tokenId].royalty_percentage = _new_royalty;
    royaltyInfo[_tokenId].royalty_set = _royalty;
  }

  function _mint_byOnlyOwner() private onlyOwner {
    //TotalUtilities address_superContract=TotalUtilities(superContract);
    //uint256 _tokenCounter = address_superContract.getCounter();
    //require(totalSupply(_tokenId) == 0,"token Already occupied");
    uint256 _tokenId = getTokenNumber() + 1;
    require(_exists(_tokenId) == false, "token ID already occupied");
    _mint(msg.sender, _tokenId, 1, "");
    //_setURI(_uri);
    _setTokenIncrement();
    creators[_tokenId] = msg.sender;
    tokenSupply[_tokenId] += 1;
    tokenNFT[_tokenId] = true;
  }

  //only token Owner
  function burn(uint256 _tokenId, uint256 _burnAmount)
    public
    ownersOnly(_tokenId)
  {
    if (balanceOf(msg.sender, _tokenId) < _burnAmount) {
      _burnAmount = balanceOf(msg.sender, _tokenId);
    }
    _burn(msg.sender, _tokenId, _burnAmount);
    tokenSupply[_tokenId] -= _burnAmount;
  }

  // onlye token Creator
  function _setRoyalty(uint256 _tokenId, uint16 _royalties)
    public
    creatorOnly(_tokenId)
  {
    //only original owner can set the royalty!
    //royalties 0%=>0,10% => 1000, 50% => 5000,100% => 10000
    //require(balanceOf(msg.sender,_tokenId)>0,"token is not available for this caller!");//caller has the token
    //require(creators[_tokenId]==msg.sender,"You are not the original token owner!");//caller is the original owner
    require(_royalties > 0, "royalties should set more than 0"); //set proper values for royalty not 0
    _setTokenRoyalty(_tokenId, msg.sender, _royalties);
    royaltyInfo[_tokenId] = Royalty_data(_royalties, true);
    emit royalty_record(msg.sender, _royalties);
  }

  function seturi(uint256 _tokenId, string memory _uri) private {
    _mapURI[_tokenId] = _uri;
  }
}
