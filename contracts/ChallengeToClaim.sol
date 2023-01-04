// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
 
import "@danielabalde/token-client/contracts/TokenClient.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol"; 
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/*
    @title Challenge To Claim
    @author Daniel Gonzalez Abalde aka DaniGA
    @notice Allows ERC721, ERC1155 and ERC20 tokens to be set to challenges where participants must find a solution that allows them to claim the token.
*/
contract ChallengeToClaim is EIP712("ChallengeToClaim", "2"), Context
{
    using Counters for Counters.Counter;

    struct Challenge
    {
        Token Token;
        address Owner;  
        uint256 EndsAt;
        uint256 Nonce;
        string InfoURL; 
        bool IsClaimed;
    }

    struct ChallengeSet
    {
        TokenSet Tokens;
        address Owner; 
        uint256 EndsAt;
        uint256 Nonce; 
        string InfoURL; 
        bool IsClaimed;
    }

    TokenClient private _client;
    bytes32[] private _challengeKeys;
    mapping(bytes32=>Challenge) private _challenges;
    mapping(bytes32=>ChallengeSet) private _challengeSets;
    mapping(address=>Counters.Counter) private _nonces;

    event NewChallenge(bytes32 indexed key);
    event ChallengeSolved(bytes32 indexed key);

    bytes32 constant CHALLENGE_TYPEHASH = keccak256("Challenge(address owner,address contractAddress,bytes32 id,uint256 amount,uint256 nonce,bytes32 secretKey)");
    bytes32 constant CHALLENGESET_TYPEHASH = keccak256("ChallengeSet(address owner,address contractAddress,bytes32[] ids,uint256[] amounts,uint256 nonce,bytes32 secretKey)");
   
    constructor(address clientTokenAddress){
        _client = TokenClient(clientTokenAddress);
    }

    /*
        @return the current nonce of the sender.
    */
    function getNonce() external view returns (uint256){ return _nonces[_msgSender()].current(); }
    /*
        @return the challenge for given 'key'.
    */
    function getChallenge(bytes32 key) external view returns(Challenge memory){ return _challenges[key]; }
    /*
        @return the challengeSet for given 'key'.
    */
    function getChallengeSet(bytes32 key) external view returns(ChallengeSet memory){ return _challengeSets[key]; }
    /*
        @return all the keys of each challenge.
    */
    function getChallenges() external view returns(bytes32[] memory){ return _challengeKeys; }

    function makeChallenge(Token calldata token, uint256 endsAt, string calldata infoURL, bytes calldata signature) external returns(bytes32) {
        return _makeChallenge(token, endsAt, infoURL, signature);
    }
    function makeChallengeSet(TokenSet calldata tokenSet, uint256 endsAt, string calldata infoURL, bytes calldata signature) external returns(bytes32) {
        return _makeChallengeSet(tokenSet, endsAt, infoURL, signature);
    }

    /*  
        @notice Register a challenge.
        @dev This method requires that the sender owns the tokens, that contractAddress is IERC20 compilant, and be approved. Use {makeChallengeERC20} to avoid this in order to safe gas.
        @param contractAddress is the address of the IERC20 token. 
        @param amount is the token amount.
        @param infoURL is an optional URL that directs to a description or instructions of the challenge.
        @param signature is the message that the token owner must sign.
    */
    function makeSafeChallenge(Token calldata token, uint256 endsAt, string calldata infoURL, bytes calldata signature) external returns(bytes32) {
        require(_client.isOwner(token, _msgSender()), "ChallengeToClaim: not the owner");
        require(_client.isApproved(token, _msgSender(), address(_client)), "ChallengeToClaim: TokenClient not approved");
        return _makeChallenge(token, endsAt, infoURL, signature);
    }
    function makeSafeChallengeSet(TokenSet calldata tokenSet, uint256 endsAt, string calldata infoURL, bytes calldata signature) external returns(bytes32) {
        require(_client.isOwnerSet(tokenSet, _msgSender()), "ChallengeToClaim: not the owner");
        require(_client.isApprovedSet(tokenSet, _msgSender(), address(_client)), "ChallengeToClaim: TokenClient not approved");
        return _makeChallengeSet(tokenSet, endsAt, infoURL, signature);
    }
     /*  
        @notice Register a challenge so that an ERC20 token can be claimed.
        @dev This method requires that the sender owns the tokens, that contractAddress is IERC20 compilant, and be approved. Use {makeChallengeERC20} to avoid this in order to safe gas.
        @param contractAddress is the address of the IERC20 token. 
        @param amount is the token amount.
        @param infoURL is an optional URL that directs to a description or instructions of the challenge.
        @param signature is the message that the token owner must sign.
    */
    function _makeChallenge(Token calldata token, uint256 endsAt, string calldata infoURL, bytes calldata signature) internal returns(bytes32) {
        require(endsAt == 0 || endsAt > block.timestamp, "ChallengeToClaim: endsAt less than block.timestamp");
        bytes32 key = _getChallengeKey(signature); 
        require(_challenges[key].Owner == address(0), "ChallengeToClaim: Signature already used"); 
        _challenges[key] = Challenge(token, _msgSender(), endsAt, _nonces[_msgSender()].current(), infoURL, false);
        _challengeKeys.push(key); 
        _nonces[_msgSender()].increment(); 
        emit NewChallenge(key);
        return key;
    } 
    
    function _makeChallengeSet(TokenSet calldata tokenSet, uint256 endsAt, string calldata infoURL, bytes calldata signature) internal returns(bytes32) {
        require(endsAt == 0 || endsAt > block.timestamp, "ChallengeToClaim: endsAt less than block.timestamp");
        bytes32 key = _getChallengeKey(signature); 
        require(_challengeSets[key].Owner == address(0), "ChallengeToClaim: Signature already used"); 
        _challengeSets[key] = ChallengeSet(tokenSet, _msgSender(), endsAt, _nonces[_msgSender()].current(), infoURL, false);
        _challengeKeys.push(key); 
        _nonces[_msgSender()].increment(); 
        emit NewChallenge(key);
        return key;
    }
 
    /*  
        @notice Claim a token to be transferred to you. 
        @param secretKey is the hash of the solution or secret message that participants must find to solve the challenge.
        @param signature is the signed message that identifies the challenge.
    */
    function claim(bytes32 secretKey, bytes calldata signature) external
    { 
        bytes32 key = _getChallengeKey(signature);
        (bool exists, bool isSet) = _isChallengeSet(key);
        require(exists, "ChallengeToClaim: No challenge for this signature");
        if(isSet){
            ChallengeSet storage ch = _challengeSets[key];
            require(!ch.IsClaimed, "ChallengeToClaim: Challenge already claimed");
            require(ch.EndsAt >= block.timestamp, "ChallengeToClaim: Challenge has ended");
            require(_msgSender() != ch.Owner, "ChallengeToClaim: Owner can not claim its own challenge");
            require(ECDSA.recover(_hashAndDigestSet(ch, secretKey), signature) == ch.Owner, "ChallengeToClaim: Invalid secretKey"); 
            require(_client.transferSet(ch.Tokens, ch.Owner, _msgSender()), "ChallengeToClaim: transfer failed"); 
            ch.IsClaimed = true;
        }else{
            Challenge storage ch = _challenges[key];
            require(!ch.IsClaimed, "ChallengeToClaim: Challenge already claimed");
            require(ch.EndsAt >= block.timestamp, "ChallengeToClaim: Challenge has ended");
            require(_msgSender() != ch.Owner, "ChallengeToClaim: Owner can not claim its own challenge");
            require(ECDSA.recover(_hashAndDigest(ch, secretKey), signature) == ch.Owner, "ChallengeToClaim: Invalid secretKey"); 
            require(_client.transfer(ch.Token, ch.Owner, _msgSender()), "ChallengeToClaim: transfer failed"); 
            ch.IsClaimed = true;
        }
      
        emit ChallengeSolved(key);
    }
  
    function removeChallenge(bytes calldata signature) external
    {
        bytes32 key = _getChallengeKey(signature);
        (bool exists, bool isSet) = _isChallengeSet(key);
        require(exists, "ChallengeToClaim: No challenge for this signature");
        if(isSet){
            require(_challengeSets[key].Owner == _msgSender(), "ChallengeToClaim: Not the owner of this challange");
            delete _challengeKeys[_challengeSets[key].Nonce];
            delete _challengeSets[key];
        }else{ 
            require(_challenges[key].Owner == _msgSender(), "ChallengeToClaim: Not the owner of this challange");
            delete _challengeKeys[_challenges[key].Nonce];
            delete _challenges[key];
        } 
    }

    function _isChallengeSet(bytes32 key) internal view returns (bool exists, bool isSet){
        isSet = _challengeSets[key].Owner != address(0);
        if(isSet){
            exists = true; 
        }else{
            exists = _challenges[key].Owner != address(0);
        } 
    }
 
    function _getChallengeKey(bytes calldata signature) internal pure returns(bytes32){
        return keccak256(abi.encodePacked(signature));
    } 
    function _hashAndDigest(Challenge memory ch, bytes32 secretKey) internal view returns (bytes32) { 
        return _hashTypedDataV4(keccak256(abi.encode(CHALLENGE_TYPEHASH, ch.Owner, ch.Token.Contract, ch.Token.Id, ch.Token.Amount, ch.Nonce, secretKey)));
    }
    function _hashAndDigestSet(ChallengeSet memory ch, bytes32 secretKey) internal view returns (bytes32) { 
        return _hashTypedDataV4(keccak256(abi.encode(CHALLENGESET_TYPEHASH, ch.Owner, ch.Tokens.Contract,
             keccak256(abi.encodePacked(ch.Tokens.Ids)), keccak256(abi.encodePacked(ch.Tokens.Amounts)), ch.Nonce, secretKey)));
    }
}