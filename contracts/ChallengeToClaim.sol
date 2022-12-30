// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
 
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol"; 
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol"; 
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/*
    @title Challenge To Claim
    @author Daniel Gonzalez Abalde aka DaniGA
    @notice Allows ERC721, ERC1155 and ERC20 tokens to be set to challenges where participants must find a solution that allows them to claim the token.
*/
contract ChallengeToClaim is EIP712("ChallengeToClaim", "1"), Context
{
    using Counters for Counters.Counter;

    enum TokenType { ERC721, ERC1155, ERC20 }

    struct Challenge
    {
        address Owner;
        address ContractAddress;
        uint256 TokenId;
        uint256 Amount;
        uint256 Nonce;
        string InfoURL;
        TokenType Type;
        bool IsClaimed;
    }

    bytes32[] private _challengeKeys;
    mapping(bytes32=>Challenge) private _challenges;
    mapping(address=>Counters.Counter) private _nonces;

    event NewChallenge(bytes32 indexed key);
    event ChallengeSolved(bytes32 indexed key);

    bytes32 constant CHALLENGE_TYPEHASH = keccak256("Challenge(address owner,address contractAddress,uint256 tokenId,uint256 amount,uint256 nonce,bytes32 secretKey)");
   
    /*
        @return the current nonce of the sender.
    */
    function getNonce() external view returns (uint256){ return _nonces[_msgSender()].current(); }
    /*
        @return the challenge for given 'key'.
    */
    function getChallenge(bytes32 key) external view returns(Challenge memory){ return _challenges[key]; }
    /*
        @return all the keys of each challenge.
    */
    function getChallenges() external view returns(bytes32[] memory){ return _challengeKeys; }
    
    /*  
        @notice Register a challenge so that an ERC721 token can be claimed.
        @dev This method does not require that the sender owns the token or that contractAddress is IERC721 or approved, in order to safe save gas. Use {makeSafeChallengeERC721} to include these requirements.
        @param contractAddress is the address of the IERC721 token.
        @param tokenId is the token id.
        @param infoURL is an optional URL that directs to a description or instructions of the challenge.
        @param signature is the message that the token owner must sign.
    */
    function makeChallengeERC721(address contractAddress, uint256 tokenId, string memory infoURL, bytes memory signature) external
    { 
        _makeChallenge(_getChallengeKey(signature), Challenge(_msgSender(), contractAddress, tokenId, 1, _nonces[_msgSender()].current(), infoURL, TokenType.ERC721, false));
    }
    /*  
        @notice Register a challenge so that an ERC721 token can be claimed.
        @dev This method requires that the sender owns the token, that contractAddress is IERC721 compilant, and be approved. Use {makeChallengeERC721} to avoid this in order to safe gas.
        @param contractAddress is the address of the IERC721 token.
        @param tokenId is the token id.
        @param infoURL is an optional URL that directs to a description or instructions of the challenge.
        @param signature is the message that the token owner must sign.
    */
    function makeSafeChallengeERC721(address contractAddress, uint256 tokenId, string memory infoURL, bytes memory signature) external
    { 
        require(IERC721(contractAddress).ownerOf(tokenId) == _msgSender(), "ChallengeToClaim: not the owner");
        require(IERC721(contractAddress).isApprovedForAll(_msgSender(), address(this)) || IERC721(contractAddress).getApproved(tokenId) == address(this), "ChallengeToClaim: First you have to approve this contract in the contractAddress");      
        _makeChallenge(_getChallengeKey(signature), Challenge(_msgSender(), contractAddress, tokenId, 1, _nonces[_msgSender()].current(), infoURL, TokenType.ERC721, false));
    }  
    function makeChallengeBatchERC721(address contractAddress, uint256[] memory tokenIds, string[] memory infoURLs, bytes[] memory signatures) external
    { 
        require(tokenIds.length == infoURLs.length, "ChallengeToClaim: length mismatch");
        require(tokenIds.length == signatures.length, "ChallengeToClaim: length mismatch");
        require(contractAddress != address(0), "ChallengeToClaim: zero address");
        for(uint256 i=0; i<tokenIds.length; i++)
        {
            _makeChallenge(_getChallengeKey(signatures[i]), Challenge(_msgSender(), contractAddress, tokenIds[i], 1, _nonces[_msgSender()].current(), infoURLs[i], TokenType.ERC721, false));
        } 
    }    
    function makeSafeChallengeBatchERC721(address contractAddress, uint256[] memory tokenIds, string[] memory infoURLs, bytes[] memory signatures) external
    { 
        require(tokenIds.length == infoURLs.length, "ChallengeToClaim: length mismatch");
        require(tokenIds.length == signatures.length, "ChallengeToClaim: length mismatch");
        require(contractAddress != address(0), "ChallengeToClaim: zero address");
        IERC721 _contract = IERC721(contractAddress);
        bool approvedForAll = _contract.isApprovedForAll(_msgSender(), address(this));
        for(uint256 i=0; i<tokenIds.length; i++)
        {
            require(_contract.ownerOf(tokenIds[i]) == _msgSender(), "ChallengeToClaim: not the owner");
            if(!approvedForAll){
                require(_contract.getApproved(tokenIds[i]) == address(this), "ChallengeToClaim: First you have to approve this contract in the contractAddress");  
            }
            _makeChallenge(_getChallengeKey(signatures[i]), Challenge(_msgSender(), contractAddress, tokenIds[i], 1, _nonces[_msgSender()].current(), infoURLs[i], TokenType.ERC721, false));
        } 
    }

    /*  
        @notice Register a challenge so that an ERC1155 token can be claimed.
        @dev This method does not require that the sender owns the token or that contractAddress is IERC1155 or approved, in order to safe save gas. Use {makeSafeChallengeERC1155} to include these requirements.
        @param contractAddress is the address of the IERC1155 token.
        @param tokenId is the token id.
        @param amount is the token amount.
        @param infoURL is an optional URL that directs to a description or instructions of the challenge.
        @param signature is the message that the token owner must sign.
    */
    function makeChallengeERC1155(address contractAddress, uint256 tokenId, uint256 amount, string memory infoURL, bytes memory signature) external
    { 
        _makeChallenge(_getChallengeKey(signature), Challenge(_msgSender(), contractAddress, tokenId, amount, _nonces[_msgSender()].current(), infoURL, TokenType.ERC1155, false));
    }
    /*  
        @notice Register a challenge so that an ERC1155 token can be claimed.
        @dev This method requires that the sender owns the token, that contractAddress is IERC1155 compilant, and be approved. Use {makeChallengeERC1155} to avoid this in order to safe gas.
        @param contractAddress is the address of the IERC1155 token.
        @param tokenId is the token id.
        @param amount is the token amount.
        @param infoURL is an optional URL that directs to a description or instructions of the challenge.
        @param signature is the message that the token owner must sign.
    */
    function makeSafeChallengeERC1155(address contractAddress, uint256 tokenId, uint256 amount, string memory infoURL, bytes memory signature) external
    { 
        require(IERC1155(contractAddress).balanceOf(_msgSender(), tokenId) >= amount, "ChallengeToClaim: not the owner");
        require(IERC1155(contractAddress).isApprovedForAll(_msgSender(), address(this)), "ChallengeToClaim: First you have to approve this contract in the contractAddress");       
        _makeChallenge(_getChallengeKey(signature), Challenge(_msgSender(), contractAddress, tokenId, amount, _nonces[_msgSender()].current(), infoURL, TokenType.ERC1155, false));
    }
    function makeChallengeBatchERC1155(address contractAddress, uint256[] memory tokenIds, uint256[] memory amounts, string[] memory infoURLs, bytes[] memory signatures) external
    { 
        require(tokenIds.length == amounts.length, "ChallengeToClaim: length mismatch");
        require(tokenIds.length == infoURLs.length, "ChallengeToClaim: length mismatch");
        require(tokenIds.length == signatures.length, "ChallengeToClaim: length mismatch");
        require(contractAddress != address(0), "ChallengeToClaim: zero address");
        for(uint256 i=0; i<tokenIds.length; i++)
        {
            _makeChallenge(_getChallengeKey(signatures[i]), Challenge(_msgSender(), contractAddress, tokenIds[i], 1, _nonces[_msgSender()].current(), infoURLs[i], TokenType.ERC1155, false));
        }      
    } 
    function makeSafeChallengeBatchERC1155(address contractAddress, uint256[] memory tokenIds, uint256[] memory amounts, string[] memory infoURLs, bytes[] memory signatures) external
    { 
        require(tokenIds.length == amounts.length, "ChallengeToClaim: length mismatch");
        require(tokenIds.length == infoURLs.length, "ChallengeToClaim: length mismatch");
        require(tokenIds.length == signatures.length, "ChallengeToClaim: length mismatch");
        require(contractAddress != address(0), "ChallengeToClaim: zero address");
        IERC1155 _contract = IERC1155(contractAddress);
        require(_contract.isApprovedForAll(_msgSender(), address(this)), "ChallengeToClaim: First you have to approve this contract in the contractAddress");
        for(uint256 i=0; i<tokenIds.length; i++)
        {
            require(_contract.balanceOf(_msgSender(), tokenIds[i]) >= amounts[i], "ChallengeToClaim: not the owner"); 
            _makeChallenge(_getChallengeKey(signatures[i]), Challenge(_msgSender(), contractAddress, tokenIds[i], 1, _nonces[_msgSender()].current(), infoURLs[i], TokenType.ERC1155, false));
        }      
    }

    /*  
        @notice Register a challenge so that an ERC20 token can be claimed.
        @dev This method does not require that the sender owns the tokens or that contractAddress is IERC20 or approved, in order to safe save gas. Use {makeSafeChallengeERC20} to include these requirements.
        @param contractAddress is the address of the IERC20 token. 
        @param amount is the token amount.
        @param infoURL is an optional URL that directs to a description or instructions of the challenge.
        @param signature is the message that the token owner must sign.
    */
    function makeChallengeERC20(address contractAddress, uint256 amount, string memory infoURL, bytes memory signature) external
    {
        _makeChallenge(_getChallengeKey(signature), Challenge(_msgSender(), contractAddress, 0, amount, _nonces[_msgSender()].current(), infoURL, TokenType.ERC20, false));
    }
    /*  
        @notice Register a challenge so that an ERC20 token can be claimed.
        @dev This method requires that the sender owns the tokens, that contractAddress is IERC20 compilant, and be approved. Use {makeChallengeERC20} to avoid this in order to safe gas.
        @param contractAddress is the address of the IERC20 token. 
        @param amount is the token amount.
        @param infoURL is an optional URL that directs to a description or instructions of the challenge.
        @param signature is the message that the token owner must sign.
    */
    function makeSafeChallengeERC20(address contractAddress, uint256 amount, string memory infoURL, bytes memory signature) external
    {
        require(IERC20(contractAddress).balanceOf(_msgSender()) >= amount, "ChallengeToClaim: not the owner");
        require(IERC20(contractAddress).allowance(_msgSender(), address(this)) >= amount, "ChallengeToClaim: First you have to allow this contract in the contractAddress");
        _makeChallenge(_getChallengeKey(signature), Challenge(_msgSender(), contractAddress, 0, amount, _nonces[_msgSender()].current(), infoURL, TokenType.ERC20, false));
    }
    function _makeChallenge(bytes32 key, Challenge memory challenge) internal {
        require(_challenges[key].ContractAddress == address(0), "ChallengeToClaim: Signature already used"); 
        _challenges[key] = challenge;
        _challengeKeys.push(key); 
        _nonces[_msgSender()].increment();
        emit NewChallenge(key);
    }
 
    /*  
        @notice Claim a token to be transferred to you. 
        @param secretKey is the hash of the solution or secret message that participants must find to solve the challenge.
        @param signature is the signed message that identifies the challenge.
    */
    function claim(bytes32 secretKey, bytes memory signature) external
    { 
        bytes32 key = _getChallengeKey(signature);
        require(_challenges[key].ContractAddress != address(0), "ChallengeToClaim: No challenge for this signature");
        Challenge storage ch = _challenges[key];
        require(!ch.IsClaimed, "ChallengeToClaim: Challenge already claimed");
        require(_msgSender() != ch.Owner, "ChallengeToClaim: Owner can not claim its own challenge");
        require(ECDSA.recover(_hashAndDigest(ch, secretKey), signature) == ch.Owner, "ChallengeToClaim: Invalid secretKey"); 
        if(ch.Type == TokenType.ERC1155){
            IERC1155(ch.ContractAddress).safeTransferFrom(ch.Owner, _msgSender(), ch.TokenId, ch.Amount, "");
        }else if(ch.Type == TokenType.ERC721){ 
            IERC721(ch.ContractAddress).safeTransferFrom(ch.Owner, _msgSender(), ch.TokenId);
        }else if(ch.Type == TokenType.ERC20){
            require(IERC20(ch.ContractAddress).transferFrom(ch.Owner, _msgSender(), ch.Amount), "ChallengeToClaim: IERC20 transferFrom failed");
        }else{
            revert("ChallengeToClaim: Not implemented");
        }
        ch.IsClaimed = true;
        emit ChallengeSolved(key);
    }
  
    function removeChallenge(bytes memory signature) external
    {
        bytes32 key = _getChallengeKey(signature);
        require(_challenges[key].ContractAddress != address(0), "ChallengeToClaim: No challenge for this signature");
        require(_challenges[key].Owner == _msgSender(), "ChallengeToClaim: Not the owner of this challange");
        delete _challengeKeys[_challenges[key].Nonce];
        delete _challenges[key];
    }

    function _getChallengeKey(bytes memory signature) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(signature));
    } 
    function _hashAndDigest(Challenge memory ch, bytes32 secretKey) internal view returns (bytes32) { 
        return _hashTypedDataV4(keccak256(abi.encode(CHALLENGE_TYPEHASH, ch.Owner, ch.ContractAddress, ch.TokenId, ch.Amount, ch.Nonce, secretKey)));
    }
}