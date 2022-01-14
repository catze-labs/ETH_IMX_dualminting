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


// File: contracts/galz/utils/Bytes.sol


pragma solidity ^0.8.4;

library Bytes {
    /**
     * @dev Converts a `uint256` to a `string`.
     * via OraclizeAPI - MIT licence
     * https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol
     */
    function fromUint(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        uint256 index = digits - 1;
        temp = value;
        while (temp != 0) {
            buffer[index--] = bytes1(uint8(48 + (temp % 10)));
            temp /= 10;
        }
        return string(buffer);
    }

    bytes constant alphabet = "0123456789abcdef";

    /**
     * Index Of
     *
     * Locates and returns the position of a character within a string starting
     * from a defined offset
     *
     * @param _base When being used for a data type this is the extended object
     *              otherwise this is the string acting as the haystack to be
     *              searched
     * @param _value The needle to search for, at present this is currently
     *               limited to one character
     * @param _offset The starting point to start searching from which can start
     *                from 0, but must not exceed the length of the string
     * @return int The position of the needle starting from 0 and returning -1
     *             in the case of no matches found
     */
    function indexOf(
        bytes memory _base,
        string memory _value,
        uint256 _offset
    ) internal pure returns (int256) {
        bytes memory _valueBytes = bytes(_value);

        assert(_valueBytes.length == 1);

        for (uint256 i = _offset; i < _base.length; i++) {
            if (_base[i] == _valueBytes[0]) {
                return int256(i);
            }
        }

        return -1;
    }

    function substring(
        bytes memory strBytes,
        uint256 startIndex,
        uint256 endIndex
    ) internal pure returns (string memory) {
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }
        return string(result);
    }

    function toUint(bytes memory b) internal pure returns (uint256) {
        uint256 result = 0;
        for (uint256 i = 0; i < b.length; i++) {
            uint256 val = uint256(uint8(b[i]));
            if (val >= 48 && val <= 57) {
                result = result * 10 + (val - 48);
            }
        }
        return result;
    }
}
// File: contracts/galz/utils/Minting.sol


pragma solidity ^0.8.4;


library Minting {
    // Split the minting blob into token_id and blueprint portions
    // {token_id}:{blueprint}

    function split(bytes calldata blob)
        internal
        pure
        returns (uint256, bytes memory)
    {
        int256 index = Bytes.indexOf(blob, ":", 0);
        require(index >= 0, "Separator must exist");
        // Trim the { and } from the parameters
        uint256 tokenID = Bytes.toUint(blob[1:uint256(index) - 1]);
        uint256 blueprintLength = blob.length - uint256(index) - 3;
        if (blueprintLength == 0) {
            return (tokenID, bytes(""));
        }
        bytes calldata blueprint = blob[uint256(index) + 2:blob.length - 1];
        return (tokenID, blueprint);
    }
}

// File: contracts/galz/GalzAutomatImx.sol

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
 * @title GalzAutomatImx
 * @dev Used for ImmutableX projects compatible with OpenSea
 */

abstract contract GalzCharacterInterface {
    function mintTransfer(address to) public virtual returns(uint256);
}

contract GalzAutomatImx is ERC721, Ownable { 
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

    address public paymentAddress;
    address galzContractAddress;
    address galzAutomatEthAddress;
    address public imx;

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
        address[] memory _presaleWallets,
        uint8[] memory _presaleAmounts,
        address _paymentAddress,
        address _imx
    ) ERC721(_name, _ticker) {
        price = _price;
        earlySupply = _totalSupply;
        totalSupply = _totalSupply;
        maxAttempts = _maxAttempts;
        maxPublic = _maxPublic;
        _baseURIextended = baseURI_;
        paymentAddress = _paymentAddress;
        setPresaleWalletsAmounts(_presaleWallets, _presaleAmounts);
        imx = _imx;
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
    }

    function giveaway(address _to, uint8 _qty) external onlyOwner {
        require(uint16(_qty) + nonce - 1 <= totalSupply, 'No more supply');

        uint16 initialTokenId = uint16(nonce);
        nonce = nonce.add(_qty);

        emit PaymentComplete(_to, initialTokenId, _qty);
    }

    // mint galzAutomatImx using galzAutomatEth
    function mintTransfer(address to) public returns(uint256) {
        require(msg.sender == galzAutomatEthAddress, "Not authorized");
        
        uint16 initialTokenId = uint16(nonce);
        nonce = nonce.add(1);
        
        emit PaymentComplete(to, initialTokenId, 1);

        //mint

        return initialTokenId;
    }

    // Allow to use the ERC-821 to get the CLoneX ERC-721 final token
    function revealToken(uint256 id) public returns(uint256) {
        require(migrationStarted == true, "Migration has not started");
        require(balanceOf(msg.sender) > 0, "Doesn't own the token"); // Check if the user own one of the ERC-1155

        _burn(id); // Burn one the ERC-721 token
        GalzCharacterInterface galzContract = GalzCharacterInterface(galzContractAddress);
        uint256 mintedId = galzContract.mintTransfer(msg.sender); // Mint the ERC-721 token
        return mintedId; // Return the minted ID
    }

    // Allow to use the ERC-721 to get the Galz ERC-721 final token (Forced)
    function forceRevealToken(uint256 id) public onlyOwner {
        require(balanceOf(msg.sender) > 0, "Doesn't own the token"); // Kept so no one can't force someone else to open a CloneX
        
        _burn(id); // Burn one the ERC-721 token
        GalzCharacterInterface galzContract = GalzCharacterInterface(galzContractAddress);
        galzContract.mintTransfer(msg.sender); // Mint the ERC-721 token
    }

    // Check if the mintpass has been used to mint an ERC-721
    function checkIfRedeemed(address _contractAddress, uint256 _tokenId) view public returns(bool) {
        return usedToken[_contractAddress][_tokenId];
    }

    //burn galzAutomatEth and mint galzAutomatImx
    function mintFromEth(address to, uint256 id) public returns(uint256) {
        require(msg.sender == galzAutomatEthAddress, "Not authorized");

        uint16 initialTokenId = uint16(nonce);
        nonce = nonce.add(1);

        emit PaymentComplete(to, initialTokenId, 1);

        return initialTokenId;
    }

    function setgalzContractAddress(address _address) external onlyOwner {
        galzContractAddress = _address;
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
    function setGalzContract(address contractAddress) public onlyOwner {
        galzContractAddress = contractAddress;
    }

    // Authorize specific smart contract to be used for minting an ERC-1155 token
    function toggleMigration() public onlyOwner {
        migrationStarted = !migrationStarted;
    }

    //imx part starts
    modifier onlyIMX() {
        require(msg.sender == imx, "Function can only be called by IMX");
        _;
    }

    function setIMX(address _imx) external onlyOwner {
        imx = _imx;
    }

    // this part is essential, the condition for IMX minting. Should be here with all IMX compatible contracts
    function mintFor(
        address user,
        uint256 quantity,
        bytes calldata mintingBlob
    ) external onlyIMX {
        require(quantity == 1, 'Mintable: invalid quantity');
        (uint256 id, bytes memory blueprint) = Minting.split(mintingBlob);
        _mintFor(user, id, blueprint);

        emit Minted(user, id);
    }

    function _mintFor(
        address user,
        uint256 id,
        bytes memory
    ) internal {
        _safeMint(user, id);
    }
    //imx part ends
    
}