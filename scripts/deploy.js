const hre = require("hardhat");

async function main() {
  const BullieverseAssets = await hre.ethers.getContractFactory(
    "BullieverseAssets"
  );
  const deployedBullieverseAssets = await BullieverseAssets.deploy("test"
  );

  await deployedBullieverseAssets.deployed();

  console.log(
    "Deployed BullieverseAssets Address:",
    deployedBullieverseAssets.address
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
