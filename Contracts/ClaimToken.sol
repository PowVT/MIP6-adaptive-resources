pragma solidity >=0.6.0 <0.9.0;
//SPDX-License-Identifier: MIT

import "./BeneficiaryStream.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ClaimToken is ERC721, ERC721URIStorage, ERC721Enumerable,  Ownable, BeneficiaryStream  {
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;                  // Claim Token Ids global variable, no two claims will ever have same ID number
    Counters.Counter public totalClaimTokens;            // Counter for total claim tokens created.
    using SafeMath for uint256;                          // Protects against overfill/underfill
    using EnumerableSet for EnumerableSet.AddressSet;    // Enumerable set of addresses
    
    
    // Initiate ERC721 contract using OpenZep library
    constructor() public ERC721("AdaptiveClaim", "AC") {
        //UNICEF, MUMA, DevSol
        approvedBeneficiaries = [ 0x7Fd8898fBf22Ba18A50c0Cb2F8394a15A182a07d, 0xF08E19B6f75686f48189601Ac138032EBBd997f2, 0x93eb95075A8c49ef1BF3edb56D0E0fac7E3c72ac];
        benePayout30[approvedBeneficiaries[0]] = true;
        benePayout40[approvedBeneficiaries[1]] = true;
        benePayout20[approvedBeneficiaries[2]] = true;
    }


    //------------------------------------------------Overrides---------------------------------------------------------------------//
    function _baseURI() internal pure override returns (string memory) {
        return "https://ipfs.io/ipfs/";
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

    //------------------------------------------------Events-----------------------------------------------------------------------//
    event newClaimCreated(uint256 id, uint256 barcodeId, address assetManager, string propertiesHash, bool exists, uint256 beneficiaryPay);
    event Attest(address sender, string hash);
    event OnMarket(uint256 tokenID, address claimOwner);
    event Sold(uint256 tokenID, address newOwner);
    //-----------------------------------------------------------------------------------------------------------------------------//


    // Claim Struct
    struct Claim {
      uint256 Id;                                                   // ID of goldAsset relative to the totalAssets counter.
      uint256 barcodeId;                                            // Direct identifier of physical asset, can be scanable via QR to barcode. This property connects the item in real life to this struct. Can be verified via propertiesHash
      address payable assetManager;                                 // Address associated can create and mint the asset as well as add beneficiaries to the asset.
      string propertiesHash;                                        // An algorithic hash of the claim properties.
      bool exists;                                                  // Used for security of the asset. More protection against duplicates.
      EnumerableSet.AddressSet Beneficiaries;                       // Beneficiaries which can recieve incentive tokens upon minting of asset. (NGO's, local exporter, Co-op, etc...). Can be added only by asset manager.
      uint256 beneficiaryPay;                                       // Amount of ADP the Beneficiaries will recieve. Based on the weight and purity inputted to claim. 
    }
    
    // Mappings
    mapping (uint256 => uint256) public claimIdByBarcodeId;            // Input asset barcodeId to access ID of that specific asset.   
    mapping (uint256 => Claim) claimById;                              // Input asset ID provided from the mapping above to access asset struct.
    mapping (uint256 => uint256) public assetBarcodeIdByTokenId;       // Input asset ID to get barcodeId of that asset.
    mapping (uint256 => string) public URIByBarcodeId;                 // Input asset barcode to get claim properties hash.
    mapping (address => string) public attestations;                   // Input a user address to see what token URIs they have attested to.
    mapping (address => bool) private benePayout20;                    // Benficiaries percent payout mappings for verification.
    mapping (address => bool) private benePayout30;
    mapping (address => bool) private benePayout40;


    // Create a struct for a specific asset. Private Function.
    // Emit the tokenId for the event created. tokenId to be the totalAssets.incremented.
    function _createClaim(uint256 barcodeId, address payable assetManager, string memory propertiesHash, uint256 benePay, address[] memory beneAddresses) private returns (uint256) {
        totalClaimTokens.increment();             // Add to claim total
        uint id = totalClaimTokens.current();     // use current total integer as the token id
        Claim storage cm = claimById[id];         // set properties
        cm.Id = id;                               // set new token ID
        cm.barcodeId = barcodeId;                 // set barcode
        cm.assetManager = assetManager;           // set msg.sender as assetManager
        cm.propertiesHash = propertiesHash;       // set properties hash
        cm.exists = true;                         // for quick lookup
        for (uint i=0; i<beneAddresses.length; i++) {
            cm.Beneficiaries.add(beneAddresses[i]);                  // Add a beneficiary from pre-approved list. 
        }
        cm.beneficiaryPay = benePay;
        claimIdByBarcodeId[barcodeId] = cm.Id;    // Connect claim token ID with the physical barcode on product.
        URIByBarcodeId[barcodeId] = cm.propertiesHash;

        emit newClaimCreated(cm.Id, cm.barcodeId, cm.assetManager, cm.propertiesHash, cm.exists, cm.beneficiaryPay); 
    }
    
    // Call this function for creating an claim struct. Then call the mintClaimToken function to mint the current token ID.
    function createClaim(uint256 barcodeId, string memory propertiesHash, uint256 benePay, address[] memory beneAddresses) public returns (uint256) {
        require(!(claimIdByBarcodeId[barcodeId] > 0), "This event already exists!");
        uint256 assetId = _createClaim(barcodeId, payable (msg.sender), propertiesHash, benePay, beneAddresses);

        return assetId;
    }

    // Internal function used to mint tokens for a specific event. Private Function.
    // Determine whether asset has been already minted or not. Validate inputs to the struct claim created.
    // This is taking the place of a "claims" office. This fucntion with others can validate information like the claims office. 
    function _mintClaim(address to, uint256 barcodeId, string memory propertiesHash) private returns (uint256) {
        _tokenIds.increment();                          // New token ID.
        uint256 id = _tokenIds.current();               // Gets current events ID.
        assetBarcodeIdByTokenId[id] = barcodeId;        // Access the specific asset after inputing the barcodeId information.
        
        _mint(to, id);
        _setTokenURI(id, propertiesHash);
        
        return id;
    }
    
    // Call this function for minting an asset to a specific assetManager.
    // Function checks the msg.sender is the assetManager and that particular asset has not already been minted.
    function mintClaim(uint256 barcodeId, string memory propertiesHash) public returns (uint256) {
        string memory claimPropHash = URIByBarcodeId[barcodeId];
        if ( keccak256(abi.encodePacked((claimPropHash))) == keccak256(abi.encodePacked((propertiesHash))) ){
            uint256 claimId = _mintClaim(msg.sender, barcodeId, propertiesHash);
            return claimId;
        }
        else{
            return(0);
        }
    }

    // One function to call createClaim and mintClaim using same barcode Id, URI, and token ID.
    // BarcodeId (string)
    // propertiesHash (string)
    // benePay (unit)*10**18
    // beneAddresses (address array)
    function mintAndCreateClaim(uint256 barcodeId, string memory propertiesHash, uint256 benePay, address[] memory beneAddresses) public returns (uint256) {
        createClaim(barcodeId, propertiesHash, benePay, beneAddresses);
        mintClaim(barcodeId, propertiesHash);
    }

    // 3rd party claim validation.
    // Input a hash sting and your address will be stored in the attestations mapping with the corresponding hash.
    function attest(string memory hash) public {
        emit Attest(msg.sender,hash);
        attestations[msg.sender] = hash;
    }
  
    function sell(uint256 tokenId) public {
        require(ownerOf(tokenId)==msg.sender,"You are not the owner of this token");
        transferFrom(msg.sender,address(this),tokenId);
        emit OnMarket(tokenId, address(this));
    }

    // Transfer function which also sets the allowance of all beneficiaries connected to an asset to the benficiary pay specified.
    function buySetBeneAllowance(uint256 tokenID) public payable {
        
        address tokenOwner = ownerOf(tokenID);
        require(tokenOwner == address(this), "This token is not for sale.");
        _transfer(tokenOwner, msg.sender, tokenID);
        
        streamDeposit(); // This is to be specified in the frontend.
        Claim storage cm = claimById[tokenID];
        
        // All proper checksum addresses
        for (uint256 i=0; i < cm.Beneficiaries.length(); i++) {

            //DevSol 20% of claim token value
            if (benePayout20[cm.Beneficiaries.at(i)] == true){
                increasePayout(cm.Beneficiaries.at(i), cm.beneficiaryPay*(2)/(10)); 
            }
            // UNICEF 30% of claim token value
            if (benePayout30[cm.Beneficiaries.at(i)] == true){
                increasePayout(cm.Beneficiaries.at(i), cm.beneficiaryPay*(3)/(10));
            }
            //MUMA 40% of claim token value
            if (benePayout40[cm.Beneficiaries.at(i)] == true){
                increasePayout(cm.Beneficiaries.at(i), cm.beneficiaryPay*(4)/(10));
            } 

        }

        emit Sold(tokenID, msg.sender);

    }

}