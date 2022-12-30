const challengeToClaimABI = JSON.parse(fs.readFileSync("./artifacts/contracts/ChallengeToClaim.sol/ChallengeToClaim.json")).abi; 

exports.makeChallengeERC721 = async function(challengeContract, chainId, signer, tokenAddress, tokenId, infoURL, secretKey, name="ChallengeToClaim", version="1")
{  
    const signature = await signChallenge(signer, chainId, tokenAddress, tokenId, amount, secretKey, name, version); 
    
    const contract = new ethers.Contract(challengeContract, challengeToClaimABI, signer); 
    
    await contract.makeChallengeERC721(tokenAddress, tokenId, infoURL, signature);
        
    return getChallengeKeyFromSignature(signature);
}

exports.signChallenge = async function (challengeContract, chainId, signer, tokenAddress, tokenId, amount, secretKey, name="ChallengeToClaim", version="1"){  
    const nonce = (await challengeContract.connect(signer).getNonce()).toNumber(); 
    return await signer._signTypedData(
        {
            name: name,
            version: version,
            chainId: chainId,
            verifyingContract: challengeContract.address
        }, 
      { Challenge: [
        { name: 'owner', type: 'address' },
        { name: 'contractAddress', type: 'address' },
        { name: 'tokenId', type: 'uint256' },
        { name: 'amount', type: 'uint256' },
        { name: 'nonce', type: 'uint256' },
        { name: 'secretKey', type: 'bytes32' } 
      ] }, 
      { owner: signer.address, contractAddress: tokenAddress, tokenId: tokenId, amount: amount, nonce: nonce, secretKey: secretKey });
  }
  
  exports.getChallengeKeyFromSignature = function (signature){
    return ethers.utils.solidityKeccak256(['bytes'], [signature]);
  }