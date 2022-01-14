// SPDX-License-Identifier: MIT

/*

╋╋╋╋╋╋╋┏┓╋╋╋╋╋╋╋╋╋╋╋╋┏┓
╋╋╋╋╋╋╋┃┃╋╋╋╋╋╋╋╋╋╋╋╋┃┃
┏━━┳┓╋┏┫┗━┳━━┳━┳━━┳━━┫┃┏━━━┓
┃┏━┫┃╋┃┃┏┓┃┃━┫┏┫┏┓┃┏┓┃┃┣━━┃┃
┃┗━┫┗━┛┃┗┛┃┃━┫┃┃┗┛┃┏┓┃┗┫┃━━┫
┗━━┻━┓┏┻━━┻━━┻┛┗━┓┣┛┗┻━┻━━━┛
╋╋╋┏━┛┃╋╋╋╋╋╋╋╋┏━┛┃
╋╋╋┗━━┛╋╋╋╋╋╋╋╋┗━━┛

*/

// File: contracts/galz/GalzAutomatEth.sol

pragma solidity >=0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title GalzAutomatEth
 * @dev Used for ImmutableX projects compatible with OpenSea
 */

abstract contract GalzCharacterInterface {
    function mintTransfer(address to) public virtual returns(uint256);
}

contract GalzAutomatEth is ERC721, Ownable { 
    using SafeMath for uint256;

    bool public sale = false;
    bool public presale = false;
    bool migrationStarted = false;

    string private _baseURIextended;

    uint256 public nonce = 1;
    uint public price; // 0.2 = 200000000000000000
    uint16 public earlySupply;
    uint16 public totalSupply;
    uint8 public maxAttempts;
    uint8 public maxPublic;

    address public paymentAddress; // destination of payment eths
    address galzAutomatImxAddress; // ETH automats goes IMX automats int the end

    event PaymentComplete(address indexed to, uint16 nonce, uint16 quantity); // then mint
    event Minted(address indexed to, uint256 id);
    event Withdraw(uint amount);

    mapping (address => uint8) private presaleWallets;
    mapping (address => uint8) private saleWallets;
    mapping (address => mapping (uint256 => bool)) usedToken;

    constructor(
        string memory _name,
        string memory _ticker,
        uint _price,
        uint16 _totalSupply,
        uint8 _maxAttempts,
        uint8 _maxPublic,
        string memory baseURI_,
        address _paymentAddress
    ) ERC721(_name, _ticker) {
        price = _price;
        earlySupply = _totalSupply;
        totalSupply = _totalSupply;
        maxAttempts = _maxAttempts;
        maxPublic = _maxPublic;
        _baseURIextended = baseURI_;
        paymentAddress = _paymentAddress;
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        _baseURIextended = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    function setPrice(uint _newPrice) external onlyOwner {
        price = _newPrice;
    }

    // function setPaymentAddress(address _address) external onlyOwner {
    //     paymentAddress = _address;
    // }

    function setEarlySupply(uint16 _limitSupply) external onlyOwner {
        earlySupply = _limitSupply;
    }

    function setTotalSupply(uint16 _newSupply) external onlyOwner {
        totalSupply = _newSupply;
    }

    function setPresale(bool _value) public onlyOwner {
        presale = _value;
    }

    function setSale(bool _value) public onlyOwner {
        sale = _value;
    }

    function setMaxAttempts(uint8 _maxAttempts) external onlyOwner {
        maxAttempts = _maxAttempts;
    }

    function setMaxPublic(uint8 _maxPublic) external onlyOwner {
        maxPublic = _maxPublic;
    }

    function setPresaleWalletsAmounts(address[] memory _a, uint8[] memory _amount) public onlyOwner {
        require(_a.length == _amount.length, "invalid param length");
        for (uint256 i = 0; i < _a.length; i++) {
            presaleWallets[_a[i]] = _amount[i];
        }
    }

    function getPresaleWalletAmount(address _wallet) public view onlyOwner returns(uint8) {
        return presaleWallets[_wallet];
    }

    function getSaleWalletAmount(address _wallet) public view onlyOwner returns(uint8) {
        return saleWallets[_wallet];
    }

    function buyPresale(uint8 _qty) external payable {
        uint8 _qtyAllowed = presaleWallets[msg.sender];
        require(presale, 'Presale is not active');
        require(uint16(_qty) + nonce - 1 <= earlySupply, 'No more supply');
        require(uint16(_qty) + nonce - 1 <= totalSupply, 'No more supply');
        require(_qty <= _qtyAllowed, 'You can not buy more than allowed');
        require(_qtyAllowed > 0, 'You can not mint on presale');
        require(msg.value >= price * _qty, 'Invalid price value');

        presaleWallets[msg.sender] = _qtyAllowed - _qty;

        payable(paymentAddress).transfer(msg.value);
        uint16 initialTokenId = uint16(nonce);
        nonce = nonce + uint256(_qty);
        emit PaymentComplete(msg.sender, initialTokenId, _qty);

        for(uint256 i = 0; i < _qty; i++ ) {
            _safeMint(msg.sender, initialTokenId + i);
        }
    }

    function buy(uint8 _qty) external payable {
        uint8 _qtyMinted = saleWallets[msg.sender];
        require(sale, 'Sale is not active');
        require(uint16(_qty) + nonce - 1 <= earlySupply, 'No more supply');
        require(uint16(_qty) + nonce - 1 <= totalSupply, 'No more supply');
        require(_qtyMinted + _qty <= maxPublic, 'You can not buy more than allowed');
        require(_qty > 0, "quantity should be positive number");
        require(_qty <= maxPublic, 'You can not buy more than allowed');
        require(msg.value >= price * _qty, 'Invalid price value');

        saleWallets[msg.sender] = saleWallets[msg.sender] + _qty;

        uint16 initialTokenId = uint16(nonce);
        nonce = nonce.add(_qty);
        payable(paymentAddress).transfer(msg.value);

        emit PaymentComplete(msg.sender, initialTokenId, _qty);

        for(uint256 i = 0; i < _qty; i++ ) {
            _safeMint(msg.sender, initialTokenId + i);
        }
    }

    function giveaway(address _to, uint8 _qty) external onlyOwner {
        require(uint16(_qty) + nonce - 1 <= totalSupply, 'No more supply');

        uint16 initialTokenId = uint16(nonce);
        nonce = nonce.add(_qty);

        emit PaymentComplete(_to, initialTokenId, _qty);

        for(uint256 i = 0; i < _qty; i++ ) {
            _safeMint(_to, initialTokenId + i);
        }
    }

    // Check if the mintpass has been used to mint an ERC-721
    function checkIfRedeemed(address _contractAddress, uint256 _tokenId) view public returns(bool) {
        return usedToken[_contractAddress][_tokenId];
    }

    // Allow to use the ERC-721 to get the Galz ERC-721 final token
    function migrateToken(uint256 id) public returns(uint256) {
        require(migrationStarted == true, "Migration has not started");
        require(balanceOf(msg.sender) > 0, "Doesn't own the token"); // Check if the user own one of the ERC-721
        _burn(id); // Burn one the ERC-721 token
        GalzCharacterInterface galzContract = GalzCharacterInterface(galzAutomatImxAddress);
        uint256 mintedId = galzContract.mintTransfer(msg.sender); // Mint the ERC-721 token
        return mintedId; // Return the minted ID
    }

    // Allow to use the ERC-721 to get the galz ERC-721 final token (Forced)
    function forceMigrateToken(uint256 id) public onlyOwner {
        require(balanceOf(msg.sender) > 0, "Doesn't own the token"); // Kept so no one can't force someone else to open a Galz
        _burn(id); // Burn one the ERC-721 token
        GalzCharacterInterface galzContract = GalzCharacterInterface(galzAutomatImxAddress);
        galzContract.mintTransfer(msg.sender); // Mint the ERC-721 token
    }

    // Get amount of minted
    function getAmountMinted() view public returns(uint256) {
        uint256 amountMinted;
        amountMinted = nonce - 1;
        return amountMinted;
    }

    // wrong transfer token. Just in case.
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    // Set authorized contract address for minting the ERC-721 token
    function setGalzAutomatImxContract(address contractAddress) public onlyOwner {
        galzAutomatImxAddress = contractAddress;
    }

    // Authorize specific smart contract to be used for minting an ERC-1155 token
    function toggleMigration() public onlyOwner {
        migrationStarted = !migrationStarted;
    }
    
}