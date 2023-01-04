// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
 
import "@danielabalde/token-client/contracts/TokenClient.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol"; 
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

/*
    @title Challenge To Claim
    @author Daniel Abalde aka DaniGA#9856
    @notice Allows you to put your NFT or fungible tokens under challenge,
    for whoever finds the answer to receive the reward tokens.
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
        @return the Challenge for given 'key'.
    */
    function getChallenge(bytes32 key) external view returns(Challenge memory){ return _challenges[key]; }
    /*
        @return the ChallengeSet for given 'key'.
    */
    function getChallengeSet(bytes32 key) external view returns(ChallengeSet memory){ return _challengeSets[key]; }
    /*
        @return all the keys of each challenge.
    */
    function getChallenges() external view returns(bytes32[] memory){ return _challengeKeys; }
    /*
        Get the address of the TokenClient instance
    */
    function getTokenClient() external view returns(address){ return address(_client); }

    /*  
        @notice Register a new Challenge.
        @dev This method does not require the sender to own the token or to have approved TokenClient, in order to save gas.
             If you want these requires, use {makeSafeChallenge} instead. 
        @param token is the Token to make the challenge. 
        @param endsAt is the block timestamp when the challenge expires.
        @param infoURL is an optional URL that directs to a description or instructions of the challenge.
        @param signature is the message that the token owner must sign.
    */
    function makeChallenge(Token calldata token, uint256 endsAt, string calldata infoURL, bytes calldata signature) external returns(bytes32) {
        return _makeChallenge(token, endsAt, infoURL, signature);
    }
    /*  
        @notice Register a new ChallengeSet.
        @dev This method does not require the sender to own the tokens or to have approved TokenClient, in order to save gas.
             If you want these requires, use {makeSafeChallengeSet} instead. 
        @param tokens is the TokenSet to make the challenge. 
        @param endsAt is the block timestamp when the challenge expires.
        @param infoURL is an optional URL that directs to a description or instructions of the challenge.
        @param signature is the message that the token owner must sign.
    */
    function makeChallengeSet(TokenSet calldata tokens, uint256 endsAt, string calldata infoURL, bytes calldata signature) external returns(bytes32) {
        return _makeChallengeSet(tokens, endsAt, infoURL, signature);
    }

    /*  
        @notice Register a new Challenge.
        @dev This method does require the sender to own the token or to have approved TokenClient.
             If you want to save gas, use {makeChallenge} instead. 
        @param token is the Token to make the challenge. 
        @param endsAt is the block timestamp when the challenge expires.
        @param infoURL is an optional URL that directs to a description or instructions of the challenge.
        @param signature is the message that the token owner must sign.
    */
    function makeSafeChallenge(Token calldata token, uint256 endsAt, string calldata infoURL, bytes calldata signature) external returns(bytes32) {
        require(_client.isOwner(token, _msgSender()), "ChallengeToClaim: not the owner");
        require(_client.isApproved(token, _msgSender(), address(_client)), "ChallengeToClaim: TokenClient not approved");
        return _makeChallenge(token, endsAt, infoURL, signature);
    }
    /*  
        @notice Register a new ChallengeSet.
        @dev This method does require the sender to own the tokens or to have approved TokenClient.
             If you want to save gas, use {makeChallengeSet} instead. 
        @param tokens is the TokenSet to make the challenge. 
        @param endsAt is the block timestamp when the challenge expires.
        @param infoURL is an optional URL that directs to a description or instructions of the challenge.
        @param signature is the message that the token owner must sign.
    */
    function makeSafeChallengeSet(TokenSet calldata tokens, uint256 endsAt, string calldata infoURL, bytes calldata signature) external returns(bytes32) {
        require(_client.isOwnerSet(tokens, _msgSender()), "ChallengeToClaim: not the owner");
        require(_client.isApprovedSet(tokens, _msgSender(), address(_client)), "ChallengeToClaim: TokenClient not approved");
        return _makeChallengeSet(tokens, endsAt, infoURL, signature);
    }
 
    function _makeChallenge(Token calldata token, uint256 endsAt, string calldata infoURL, bytes calldata signature) internal returns(bytes32) {
        require(_client.supportsStandard(token.Standard), "ChallengeToClaim: standard not supported");
        require(endsAt == 0 || endsAt > block.timestamp, "ChallengeToClaim: endsAt less than block.timestamp");
        bytes32 key = _getChallengeKey(signature); 
        require(_challenges[key].Owner == address(0), "ChallengeToClaim: Signature already used"); 
        _challenges[key] = Challenge(token, _msgSender(), endsAt, _nonces[_msgSender()].current(), infoURL, false);
        _challengeKeys.push(key); 
        _nonces[_msgSender()].increment(); 
        emit NewChallenge(key);
        return key;
    } 
    
    function _makeChallengeSet(TokenSet calldata tokens, uint256 endsAt, string calldata infoURL, bytes calldata signature) internal returns(bytes32) {
        require(_client.supportsStandard(tokens.Standard), "ChallengeToClaim: standard not supported");
        require(endsAt == 0 || endsAt > block.timestamp, "ChallengeToClaim: endsAt less than block.timestamp");
        bytes32 key = _getChallengeKey(signature); 
        require(_challengeSets[key].Owner == address(0), "ChallengeToClaim: Signature already used"); 
        _challengeSets[key] = ChallengeSet(tokens, _msgSender(), endsAt, _nonces[_msgSender()].current(), infoURL, false);
        _challengeKeys.push(key); 
        _nonces[_msgSender()].increment(); 
        emit NewChallenge(key);
        return key;
    }
 
    /*  
        @notice Claim the reward to be transferred to you. 
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