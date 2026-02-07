const hre = require("hardhat");

async function main() {
  console.log("\n💰 CarLife - 账户余额检查");
  console.log("=" .repeat(60));

  // 获取网络信息
  const network = await hre.ethers.provider.getNetwork();
  console.log(`🌐 网络: ${network.name} (Chain ID: ${network.chainId})\n`);

  // 获取部署者账户
  const [deployer] = await hre.ethers.getSigners();
  console.log(`👤 钱包地址: ${deployer.address}`);

  // 查询余额
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  const balanceEth = hre.ethers.formatEther(balance);
  const balanceWei = balance.toString();

  console.log(`💰 账户余额: ${balanceEth} ETH`);
  console.log(`📊 余额（Wei）: ${balanceWei}`);

  // 检查是否足够部署
  const minRequired = hre.ethers.parseEther("0.01");
  if (balance < minRequired) {
    console.log("\n❌ 余额不足，无法部署合约");
    console.log(`⚠️  最低需要: 0.01 ETH`);
    console.log(`⚠️  当前余额: ${balanceEth} ETH`);
    console.log(`⚠️  缺少: ${hre.ethers.formatEther(minRequired - balance)} ETH`);
    console.log("\n📝 获取测试币:");
    console.log("  - https://sepoliafaucet.com");
    console.log("  - https://cloud.google.com/application/web3/faucet/ethereum/sepolia");
    console.log("  - https://faucet.quicknode.com/ethereum/sepolia");
  } else {
    console.log("\n✅ 余额充足，可以部署合约");
  }

  console.log("\n" + "=".repeat(60) + "\n");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
