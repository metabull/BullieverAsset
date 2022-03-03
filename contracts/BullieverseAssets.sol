// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

struct Asset {
    uint256 price;
    uint256 collectionId;
    uint256 maxSupply;
    uint256 maxPerWallet;
    uint256 openMintTimestamp; // unix timestamp in seconds
}

contract BullieverseAssets is ERC1155, ERC1155Supply, Ownable {
    using Strings for uint256;

    // The name of the token ("Bullieverse Assets - Gaming")
    string public name;
    // The token symbol ("BAG")
    string public symbol;

    // A mapping of the number of Collection minted per collectionId per user
    // assetMintedPerTokenId[msg.sender][collectionId] => number of minted Asset
    mapping(address => mapping(uint256 => uint256))
        private assetMintedPerTokenId;

    // A mapping from collectionId to its Asset
    mapping(uint256 => Asset) private collectionToAsset;

    // Define if sale is active
    bool public saleIsActive = false;

    // Event emitted when a Asset is bought
    event AssetBought(
        uint256 collectionId,
        address indexed account,
        uint256 amount
    );

    // Event emitted when a new Asset is created
    event CreatedAsset(
        uint256 price,
        uint256 collectionId,
        uint256 maxSupply,
        uint256 maxPerWallet,
        uint256 openMintTimestamp
    );

    /**
     * @dev Initializes the contract by setting the name and the token symbol
     */
    constructor(string memory baseURI) ERC1155(baseURI) {
        name = "Bullieverse Assets - Gaming";
        symbol = "BAG";
    }

    /*
     * Pause sale if active, make active if paused
     */
    function setSaleState(bool newState) public onlyOwner {
        saleIsActive = newState;
    }

    /**
     * @dev Retrieves the Asset Details for a given collectionId.
     */
    function getcollectionToAsset(uint256 collectionId)
        external
        view
        returns (Asset memory)
    {
        return collectionToAsset[collectionId];
    }

    /**
     * @dev Contracts the metadata URI for the Asset of the given collectionId.
     *
     * Requirements:
     *
     * - The Asset exists for the given collectionId
     */
    function uri(uint256 collectionId)
        public
        view
        override
        returns (string memory)
    {
        require(
            collectionToAsset[collectionId].collectionId != 0,
            "Invalid collection"
        );
        return
            string(
                abi.encodePacked(
                    super.uri(collectionId),
                    collectionId.toString(),
                    ".json"
                )
            );
    }

    /**
     * Owner-only methods
     */

    /**
     * @dev Sets the base URI for the Collection metadata.
     */
    function setBaseURI(string memory baseURI) external onlyOwner {
        _setURI(baseURI);
    }

    /**
     * @dev Sets the parameters on the Collection struct for the given collection.
     * Emits CreatedAsset indicating new assest is created
     */
    function createAsset(
        uint256 price,
        uint256 collectionId,
        uint256 maxSupply,
        uint256 maxPerWallet,
        uint256 openMintTimestamp
    ) external onlyOwner {
        collectionToAsset[collectionId] = Asset(
            price,
            collectionId,
            maxSupply,
            maxPerWallet,
            openMintTimestamp
        );

        emit CreatedAsset(
            price,
            collectionId,
            maxSupply,
            maxPerWallet,
            openMintTimestamp
        );
    }

    /**
     * @dev Withdraws the balance
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    /**
     * @dev Creates a reserve of Assets to set aside for gifting.
     *
     * Requirements:
     *
     * - There are enough Assets to mint for the given collection
     * - The supply for the given collection does not exceed the maxSupply of the Collection
     */
    function reserveAssetesForGifting(
        uint256 collectionId,
        uint256 amountEachAddress,
        address[] calldata addresses
    ) public onlyOwner {
        Asset memory pass = collectionToAsset[collectionId];
        require(amountEachAddress > 0, "Amount cannot be 0");
        require(
            totalSupply(collectionId) < pass.maxSupply,
            "No passes to mint"
        );
        require(
            totalSupply(collectionId) + amountEachAddress * addresses.length <=
                pass.maxSupply,
            "Cannot mint that many"
        );
        require(addresses.length > 0, "Need addresses");
        for (uint256 i = 0; i < addresses.length; i++) {
            address add = addresses[i];
            _mint(add, collectionId, amountEachAddress, "");
        }
    }

    /**
     * @dev Mints a set number of Asset for a given collection.
     *
     * Emits a `AssetBought` event indicating the Collection was minted successfully.
     *
     * Requirements:
     *
     * - The current time is within the minting window for the given collection
     * - There are Assets available to mint for the given collection
     * - The user is not trying to mint more than the maxSupply
     * - The user is not trying to mint more than the maxPerWallet
     * - The user has enough ETH for the transaction
     */
    function mintAsset(uint256 collectionId, uint256 amount) external payable {
        require(saleIsActive, "Mint is not available right now");
        Asset memory pass = collectionToAsset[collectionId];
        require(
            block.timestamp >= pass.openMintTimestamp,
            "Mint is not available"
        );
        require(totalSupply(collectionId) < pass.maxSupply, "Sold out");
        require(
            totalSupply(collectionId) + amount <= pass.maxSupply,
            "Cannot mint that many"
        );

        uint256 totalMintedAssets = assetMintedPerTokenId[msg.sender][
            collectionId
        ];
        require(
            totalMintedAssets + amount <= pass.maxPerWallet,
            "Exceeding maximum per wallet"
        );
        require(msg.value == pass.price * amount, "Not enough eth");

        assetMintedPerTokenId[msg.sender][collectionId] =
            totalMintedAssets +
            amount;
        _mint(msg.sender, collectionId, amount, "");

        emit AssetBought(collectionId, msg.sender, amount);
    }

    /**
     * @dev Retrieves the number of Asset a user has minted by collectionId.
     */
    function assetMintedByCollectionID(address user, uint256 collectionId)
        external
        view
        returns (uint256)
    {
        return assetMintedPerTokenId[user][collectionId];
    }

    /**
     * @dev Boilerplate override for `_beforeTokenTransfer`
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
