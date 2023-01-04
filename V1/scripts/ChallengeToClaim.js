const { ethers } = require("hardhat"); 
const fs = require('fs');


exports.challengeToClaimABI = JSON.parse(fs.readFileSync("./artifacts/contracts/ChallengeToClaim.sol/ChallengeToClaim.json")).abi;  

exports.makeChallengeERC721 = async function(challengeContractAddress, chainId, signer, tokenAddress, tokenId, infoURL, secretKey, safe=true, name="ChallengeToClaim", version="1")
{   
    const contract = new ethers.Contract(challengeContractAddress, exports.challengeToClaimABI, signer); 
    const nonce = (await contract.getNonce()).toNumber(); 
    const signature = await exports.signChallenge(contract, chainId, nonce, signer, tokenAddress, tokenId, 1, secretKey, name, version); 
    if(safe){
        await contract.makeSafeChallengeERC721(tokenAddress, tokenId, infoURL, signature); 
    } else{
        await contract.makeChallengeERC721(tokenAddress, tokenId, infoURL, signature); 
    } 
    return signature;
}

exports.claim = async function(challengeContractAddress, signer, secretKey, signature){
    const contract = new ethers.Contract(challengeContractAddress, exports.challengeToClaimABI, signer); 
    await contract.claim(secretKey, signature);
}

exports.signChallenge = async function (challengeContract, chainId, nonce, signer, tokenAddress, tokenId, amount, secretKey, name="ChallengeToClaim", version="1"){  
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
  
  exports.getChallenge = async function (challengeContractAddress, signer, signature){
    const key = ethers.utils.solidityKeccak256(['bytes'], [signature]);
    const contract = new ethers.Contract(challengeContractAddress, exports.challengeToClaimABI, signer); 
    return await contract.getChallenge(key);
  }
  
  exports.getChallengeKeyFromSignature = function (signature){
    return ethers.utils.solidityKeccak256(['bytes'], [signature]);
  }
