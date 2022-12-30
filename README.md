<h1 align="center">Challenge to Claim Token (BETA)</h1> 
<p align="center">Claim a token if you know the secret!</p>

<p align="center" style="font-style: italic">⚠️<small>This project still needs to be audited and used in testnets, use it under your own risk</small>⚠️</p>

This [contract](./contracts/ChallengeToClaim.sol) allows you to put your ERC721, ERC1155 and ERC20 tokens under challenge, so that whoever finds the answer will be able to claim the token to transfer it to himself. You present a challenge, problem, puzzle, quiz or gymkhana, and this contract takes care of the transfer to whomever provides the correct solution.


## 🚀 Motivation

The motivation is to let anyone to offer a more fun alternative to random airdrops or giveaways and to do this type of activity on-chain to automate it and let the transfer (including its gas cost) be handled by the winners instead of the owner. 

## 🔑 Deployments

| Name | Chain | Contract |
|:----:|:-----:|:--------:|
| [ChallengeToClaim](./contracts/ChallengeToClaim.sol) | Mumbai | [0xa758C748A6e9907A79456B0A5d9Ed67cd95073CC](https://mumbai.polygonscan.com/address/0xa758C748A6e9907A79456B0A5d9Ed67cd95073CC#code) |
| [TestERC721](./contracts/test_contracts/TestERC721.sol) | Mumbai | [0x34a543c3f84Ea167DF84d5ed0a80A0Ce9916FF42](https://mumbai.polygonscan.com/address/0x34a543c3f84Ea167DF84d5ed0a80A0Ce9916FF42#code) |


## 🗺️ How it works

Each challenge is made up of a prize token, a secret hash, and a unique encrypted signature derived from both, using the [EIP712](https://eips.ethereum.org/EIPS/eip-712) standard. The challenger registers the token along with the signature, and the winner must present that signature and its corresponding secret hash, to verify that the prize can be claimed.

```js
  // This is what the challenger does under the hood:
  // 1) Connects to the dapp:
  const owner = "<input address>";
  // 3) Hash the solution to challenge
  const secretKey = ethers.utils.formatBytes32String("secret message or solution");
  // 4) Generate the EIP721 signature
  const signature = await signChallenge(owner, token.address, token.tokenId, token.amount, secretKey);
  // 5) Register a new challenge
  await challengeContract.connect(owner).makeChallengeERC721(token.address, token.tokenId, "", signature);
```

The idea is that you share the signature with the participants, from which they cannot get information because it is encrypted, and give clues or challenges to find the secret hash. This hash can be derived from text, numbers, or bytes, so the solution can be any data type.
 

```js
   // This is what the participant does under the hood:
   // 1) Connects to the dapp:
   const account = "<input address>";
   // 2) Provides the solution to the challenge
   const secretKey = "<input solution>";
   // 3) Provides the signature given by the challenger
   const signature = "<input signature>";
   // 4) If secretKey is correct, claim and receive the token
   await challengeContract.connect(account).claim(secretKey, signature);
```

Because one part of the signature is derived from information determined by the blockchain and the token, it is necessary that the other part, the secretKey, must be unique to each token.


## ☕ Contribute 
* Issues and Pull Request on Github are welcome.
* Let me know if you deploy the contracts on a different EVM blockchain.
* Invite me a coffee at daniga.eth or 0x4443049b49Caf8Eb4E9235aA1Efe38FcFA0055a1
* Share it on social media!

## 🛠️ Testing

You can also help by testing the project using the scripts or from polygonscan. The NFT test contracts allow you to mint your own tokens for testing. Try to break the contract!
 
The [challenge #1](https://github.com/DanielAbalde/Challenge-To-Claim-Token/blob/master/test/test_tokens/ERC721/challenges/Challenge_1.txt) and [challenge #3](https://github.com/DanielAbalde/Challenge-To-Claim-Token/blob/master/test/test_tokens/ERC721/challenges/Challenge_3.txt) are still active. If you know some answer, 1) go to any online tool like [this one](https://www.devoven.com/string-to-bytes32) to hash the solution to bytes32, and 2) go the claim function in [polygonscan](https://mumbai.polygonscan.com/address/0xa758C748A6e9907A79456B0A5d9Ed67cd95073CC#writeContract#F1), connect your wallet, set the secretKey (the hashed solution) and signature (which you can find in the challenge links), and if you have the right solution the [token #1](https://testnets.opensea.io/assets/mumbai/0x34a543c3f84ea167df84d5ed0a80a0ce9916ff42/1) or [token #3](https://testnets.opensea.io/assets/mumbai/0x34a543c3f84ea167df84d5ed0a80a0ce9916ff42/3) will be yours!

## 🧱 TODO
* Tests for batch methods.
* Add expiration time.
* Add multiple token reward.

## ✉️ Contact 
 * Twitter: [@DGANFT](https://twitter.com/DGANFT)
 * Discord: [DaniGA#9856](https://discord.com/invite/H4WMdnz5nw)
