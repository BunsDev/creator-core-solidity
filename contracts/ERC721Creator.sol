// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @author: manifold.xyz

import "openzeppelin-solidity/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-solidity/contracts/utils/Strings.sol";
import "openzeppelin-solidity/contracts/utils/structs/EnumerableSet.sol";
import "./IERC721Creator.sol";
import "./IERC721CreatorExtension.sol";
import "./ERC721CreatorExtension.sol";

contract ERC721Creator is ReentrancyGuard, ERC721Enumerable, Ownable, IERC721Creator {
    using Strings for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    // Track registered extensions    
    EnumerableSet.AddressSet private _extensions;

    // Track registered admins
    EnumerableSet.AddressSet private _admins;

    mapping (uint256 => address) private _originatingContract;

    /**
     * @dev Only allows registered extensions to call the specified function
     */
    modifier extensionRequired() {
        require(_extensions.contains(msg.sender), "ERC721Creator: Must be a registered extension to call this function");
        _;
    }   

    /**
     * @dev Only allows approved admins to call the specified function
     */
    modifier adminRequired() {
        require(owner() == msg.sender || _admins.contains(msg.sender), "ERC721Creator: Must be the contract owner or admin to call this function");
        _;
    }   

    constructor (string memory _name, string memory _symbol) ERC721(_name, _symbol)
    {
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721Enumerable) returns (bool) {
        return interfaceId == type(IERC721Creator).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721Creator-getAdmins}.
     */
    function getAdmins() external view override returns (address[] memory) {
        address[] memory admins = new address[](_admins.length());
        for (uint i = 0; i < _admins.length(); i++) {
            admins[i] = _admins.at(i);
        }
        return admins;
    }

    /**
     * @dev See {IERC721Creator-approveAdmin}.
     */
    function approveAdmin(address admin) external override onlyOwner returns (bool) {
        return _admins.add(admin);
    }

    /**
     * @dev See {IERC721Creator-revokeAdmin}.
     */
    function revokeAdmin(address admin) external override onlyOwner returns (bool) {
        return _admins.remove(admin);
    }

    /**
     * @dev See {IERC721Creator-getExtensions}.
     */
    function getExtensions() external view override returns (address[] memory) {
        address[] memory extensions = new address[](_extensions.length());
        for (uint i = 0; i < _extensions.length(); i++) {
            extensions[i] = _extensions.at(i);
        }
        return extensions;
    }

    /**
     * @dev See {IERC721Creator-registerExtension}.
     */
    function registerExtension(address extension) external override adminRequired returns (bool) {
        require(ERC721CreatorExtension(msg.sender).supportsInterface(type(IERC721CreatorExtension).interfaceId), "ERC721Creator: Must implement IERC721CreatorExtension");
        return _extensions.add(extension);
    }

    /**
     * @dev See {IERC721Creator-unregisterExtension}.
     */
    function unregisterExtension(address extension) external override adminRequired returns (bool) {
        return _extensions.remove(extension);
    }

    /**
     * @dev See {IERC721Creator-mint}.
     */
    function mint(address to, uint256 tokenId) external override nonReentrant extensionRequired virtual {
        _safeMint(to, tokenId);
        _originatingContract[tokenId] = msg.sender;
    }
    
    /**
     * @dev See {IERC721Creator-burn}.
     */
    function burn(uint256 tokenId) external override nonReentrant virtual {
        address originatingContract = _originatingContract[tokenId];
        _burn(tokenId);
        _originatingContract[tokenId] = address(0);
        
        // Callback to originating contract
        require(ERC721CreatorExtension(originatingContract).onBurn(tokenId));
    }
    
    
}