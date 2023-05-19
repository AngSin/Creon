// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "operator-filter-registry/src/DefaultOperatorFilterer.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CreonPass is ERC721, Pausable, DefaultOperatorFilterer, Ownable {
    address public usdtContract;
    address public busdContract;
    uint256 public usdPrice = 155 ether;
    uint256 public nativePrice = 0.5 ether;
    uint256 public cumulativePhaseLimit = 3333;
    uint256 public constant MAX_PER_WALLET = 10;
    uint256 public totalSupply = 0;
    string public baseUri;

    mapping(address => uint256) mintedCount;

    using Strings for uint256;

    event ReferralMint(string , string token, uint256 totalPrice);

    constructor(address _usdtContract, address _busdContract) ERC721("CreonPass", "CPASS") {
        usdtContract = _usdtContract;
        busdContract = _busdContract;
    }

    function setBaseUri(string memory _baseUri) public onlyOwner {
        baseUri = _baseUri;
    }

    function setUsdtContract(address _usdtContract) public onlyOwner {
        usdtContract = _usdtContract;
    }

    function setBusdContract(address _busdContract) public onlyOwner {
        busdContract = _busdContract;
    }

    function setUsdPrice(uint256 _usdPrice) public onlyOwner {
        usdPrice = _usdPrice;
    }

    function setNativePrice(uint256 _nativePrice) public onlyOwner {
        nativePrice = _nativePrice;
    }

    function setLimit(uint256 _limit) public onlyOwner {
        cumulativePhaseLimit = _limit;
    }

    function usdMint(string calldata _referral, address _usdContract, uint _amount) public {
        require(_usdContract == busdContract || _usdContract == usdtContract, "Unrecognized USD token contract!");
        require(_amount % usdPrice == 0, "Invalid USD amount!");
        uint256 mintAmount = _amount/usdPrice;
        require(mintedCount[msg.sender] + mintAmount <= MAX_PER_WALLET, "Personal mint limit exceeded!");
        require(mintedCount[msg.sender] + mintAmount <= cumulativePhaseLimit, "Max Limit exceeded!");
        IERC20(_usdContract).transferFrom(msg.sender, address(this), _amount);
        mintedCount[msg.sender] += mintAmount;
        for (uint256 i = 0; i < mintAmount; i++) {
            totalSupply += 1;
            super._safeMint(msg.sender, totalSupply);
        }
        emit ReferralMint(_referral, "USD", _amount);
    }

    function nativeMint(string calldata _referral) public payable {
        require(msg.value % nativePrice == 0, "Invalid Native Token amount!");
        uint256 mintAmount = msg.value/nativePrice;
        require(mintedCount[msg.sender] + mintAmount <= MAX_PER_WALLET, "Personal mint limit exceeded!");
        require(mintedCount[msg.sender] + mintAmount <= cumulativePhaseLimit, "Max Limit exceeded!");
        mintedCount[msg.sender] += mintAmount;
        for (uint256 i = 0; i < mintAmount; i++) {
            totalSupply += 1;
            super._safeMint(msg.sender, totalSupply);
        }
        emit ReferralMint(_referral, "BNB", msg.value);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize) internal whenNotPaused override {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // ---- DefaultOperatorFilterRegistry ----
    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function approve(address operator, uint256 tokenId) public override onlyAllowedOperatorApproval(operator) {
        super.approve(operator, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        override
        onlyAllowedOperator(from)
    {
        super.safeTransferFrom(from, to, tokenId, data);
    }

    // ---- ERC165 ----
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function withdraw() public onlyOwner {
        (bool sent,) = payable(super.owner()).call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
        (bool usdtSent) = IERC20(usdtContract).transfer(super.owner(), IERC20(usdtContract).balanceOf(address(this)));
        require(usdtSent, "Failed to send USDT!");
        (bool busdSent) = IERC20(busdContract).transfer(super.owner(), IERC20(busdContract).balanceOf(address(this)));
        require(busdSent, "Failed to send BUSD!");
    }

    function tokenURI(uint256 _tokenId) override public view returns (string memory) {
        return string(abi.encodePacked(baseUri, _tokenId.toString()));
    }
}