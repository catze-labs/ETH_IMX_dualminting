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

pragma solidity >=0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Bytes.sol";
import "./Minting.sol";
import "./GalzRandomizer.sol";

abstract contract GalzRandomizer {
    function getTokenId(uint256 tokenId) public view virtual returns(string memory);
}

contract Galz is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    
    event GalzRevealed(uint256 tokenId, string fileId); // Sending the event for offchain script to transform the right file
    event PaymentComplete(address indexed to, uint16 nonce, uint16 quantity); // then mint
    event Minted(address indexed to, uint256 id);
    event Withdraw(uint amount);
    
    address randomizerAddress; // Approved randomizer contract
    address galzAutomatImxAddress; // Approved galzAutomatEth contract
    //address[] galzPartAddressList;
    address public imx;

    string public _tokenUri = "https://api-galz.cybergalznft.com/"; // Initial base URI

    mapping (uint256 => uint256) tokenIdToPart; //partBytokenId
    mapping (address => tokenIdToPart) onchainMetadata;
    
    bool public contractLocked = false;

    constructor() ERC721("Galz", "Galz", _imx) {
        _tokenIdCounter.increment(); // Making sure we start at token ID 1
        imx = _imx;
    }

    function mintTransfer(address to) public returns(uint256) {
        require(msg.sender == galzAutomatImxAddress, "Not authorized");
        
        GalzRandomizer tokenAttribution = GalzRandomizer(randomizerAddress);
        
        string memory realId = tokenAttribution.getTokenId(_tokenIdCounter.current());
        uint256 mintedId =  _tokenIdCounter.current();
        
        //_safeMint(to, _tokenIdCounter.current());
        emit PaymentComplete(to, initialTokenId, _qty);
        emit GalzRevealed(_tokenIdCounter.current(), realId);
        _tokenIdCounter.increment();
        return mintedId;
    }
    
    // Change the galzAutomatEth address contract
    function setgalzAutomatEthAddress(address newAddress) public onlyOwner { 
        galzAutomatImxAddress = newAddress;
    }

    // Change the randomizer address contract
    function setRandomizerAddress(address newAddress) public onlyOwner {
        randomizerAddress = newAddress;
    }
    
    function secureBaseUri(string memory newUri) public onlyOwner {
        require(contractLocked == false, "Contract has been locked and URI can't be changed");
        _tokenUri = newUri;
    }
    
    function lockContract() public onlyOwner {
        contractLocked = true;   
    }

    /*
    mapping (uint256 => uint256) tokenIdToPart; //partBytokenId
    mapping (address => tokenIdToPart) onchainMetadata;
    */

    /*
    // Set authorized contract address for minting the ERC-721 token
    function addGalzPartContract(address contractAddress) public onlyOwner {
        galzPartAddressList.push(contractAddress);
    }

    // Set Onchain Metadata
    function setOnchainMetadata(address contractAddress, uint256 tokenId, uint256 value) public {
        bool partExists = false;
        for(uint256 i = 0; i < galzPartAddressList.length; i++) {
            if ( msg.sender == galzPartAddressList[i] ) {partExists = true;}
        }
        require(partExists, "Not Authorized");
        onchainMetadata[contractAddress][tokenId] = value;
    }

    function getOnchainMetadata(address contractAddress, uint256 tokenId) public returns (uint256 value) {
        return onchainMetadata[contractAddress][tokenId];
    }
    */
    
	/*
	 * Helper function
	 */
	function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
		uint256 tokenCount = balanceOf(_owner);
		if (tokenCount == 0) return new uint256[](0);
		else {
			uint256[] memory result = new uint256[](tokenCount);
			uint256 index;
			for (index = 0; index < tokenCount; index++) {
				result[index] = tokenOfOwnerByIndex(_owner, index);
			}
			return result;
		}
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

    /** OVERRIDES */
    function _baseURI() internal view override returns (string memory) {
        return _tokenUri;
    }
    
	function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}