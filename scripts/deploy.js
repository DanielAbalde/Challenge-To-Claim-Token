const hre = require("hardhat");
const { ethers } = require("hardhat"); 
const fs = require('fs');

const tokenClientArtifact = JSON.parse(fs.readFileSync("./node_modules/@danielabalde/token-client/artifacts/contracts/TokenClient.sol/TokenClient.json"));
const tokenERC20Artifact = JSON.parse(fs.readFileSync("./node_modules/@danielabalde/token-client/artifacts/contracts/concretes/TokenERC20.sol/TokenERC20.json"));
const tokenERC721Artifact = JSON.parse(fs.readFileSync("./node_modules/@danielabalde/token-client/artifacts/contracts/concretes/TokenERC721.sol/TokenERC721.json")); 
const tokenERC1155Artifact = JSON.parse(fs.readFileSync("./node_modules/@danielabalde/token-client/artifacts/contracts/concretes/TokenERC1155.sol/TokenERC1155.json"));

async function main() { 

  const [account] = await ethers.getSigners();  

  const tokenClient = await deployFromArtifact(tokenClientArtifact, account); 
  await tokenClient.support((await deployFromArtifact(tokenERC20Artifact, account)).address);
  await tokenClient.support((await deployFromArtifact(tokenERC721Artifact, account)).address);
  await tokenClient.support((await deployFromArtifact(tokenERC1155Artifact, account)).address);
  
  const challengeContract = await deploy("ChallengeToClaim", tokenClient.address);
 
  await tokenClient.allowCaller(challengeContract.address, true);

  console.log("ChallengeToClaim deployed to:", challengeContract.address);
  console.log("TokenClient deployed to:", tokenClient.address);
}
 
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

async function deploy(contractName, ...params){
  const factory = await hre.ethers.getContractFactory(contractName);
  const contract = await factory.deploy(...params); 
  await contract.deployed();
  return contract;
}
async function deployFromArtifact(json, signer, ...params){
  const factory = new ethers.ContractFactory(json.abi, json.bytecode, signer); 
  const contract = await factory.deploy();
  await contract.deployed();
  return contract;
}
  