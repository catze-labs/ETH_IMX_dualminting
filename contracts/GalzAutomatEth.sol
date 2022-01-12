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

abstract contract GalzRandomizer {
    function getTokenId(uint256 tokenId) public view virtual returns(string memory);
}

contract Galz is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("Galz", "Galz") {
        _tokenIdCounter.increment(); // Making sure we start at token ID 1
    }
    
    event GalzRevealed(uint256 tokenId, string fileId); // Sending the event for offchain script to transform the right file
    
    address randomizerAddress; // Approved randomizer contract
    address galzAutomatEthAddress; // Approved galzAutomatEth contract
    string public _tokenUri = "https://api-galz.cybergalznft.com/"; // Initial base URI
    
    bool public contractLocked = false;

    function mintTransfer(address to) public returns(uint256) {
        require(msg.sender == galzAutomatEthAddress, "Not authorized");
        
        GalzRandomizer tokenAttribution = GalzRandomizer(randomizerAddress);
        
        string memory realId = tokenAttribution.getTokenId(_tokenIdCounter.current());
        uint256 mintedId =  _tokenIdCounter.current();
        
        _safeMint(to, _tokenIdCounter.current());
        emit GalzRevealed(_tokenIdCounter.current(), realId);
        _tokenIdCounter.increment();
        return mintedId;
    }
    
    // Change the galzAutomatEth address contract
    function setgalzAutomatEthAddress(address newAddress) public onlyOwner { 
        galzAutomatEthAddress = newAddress;
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