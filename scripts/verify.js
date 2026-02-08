const { ethers, run } = require("hardhat");
require("dotenv").config();

async function main() {
  const contractAddress = process.env.CONTRACT_ADDRESS;
  const constructorArgs = process.env.CONSTRUCTOR_ARGS;

  // 1. 验证参数
  if (!contractAddress) {
    console.error("❌ 错误：未设置 CONTRACT_ADDRESS 环境变量");
    console.error("用法: npx hardhat run scripts/verify.js --network <network>");
    console.error("环境变量:");
    console.error("  CONTRACT_ADDRESS=<合约地址>");
    console.error("  CONSTRUCTOR_ARGS=<构造函数参数，多个参数用逗号分隔>");
    console.error();
    console.error("示例:");
    console.error('  CONTRACT_ADDRESS=0x123... CONSTRUCTOR_ARGS="arg1,arg2" npx hardhat run scripts/verify.js --network sepolia');
    process.exit(1);
  }

  const etherscanApiKey = process.env.ETHERSCAN_API_KEY;
  if (!etherscanApiKey || etherscanApiKey === "your_etherscan_api_key_here") {
    console.error("❌ 错误：未设置有效的 ETHERSCAN_API_KEY");
    console.error("请在 .env 文件中设置有效的 ETHERSCAN_API_KEY");
    console.error("获取地址: https://etherscan.io/apis");
    process.exit(1);
  }

  const network = await ethers.provider.getNetwork();
  console.log("========================================");
  console.log("验证合约源代码");
  console.log("========================================");
  console.log(`网络: ${network.name}`);
  console.log(`合约地址: ${contractAddress}`);
  console.log(`Etherscan API Key: ${etherscanApiKey.substring(0, 8)}...`);
  console.log();

  // 2. 解析构造函数参数
  let args = [];
  if (constructorArgs) {
    try {
      // 尝试解析为 JSON 数组
      args = JSON.parse(`[${constructorArgs}]`);
    } catch (e) {
      // 如果 JSON 解析失败，按逗号分割
      args = constructorArgs.split(',').map(arg => arg.trim());
    }
  }

  console.log(`构造函数参数: ${args.length > 0 ? args : "无"}`);
  console.log();

  // 3. 验证合约
  try {
    console.log("⏳ 开始验证合约...");
    console.log("   (这可能需要 1-3 分钟)");
    console.log();

    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });

    console.log();
    console.log("✅ 合约验证成功！");
    console.log();
    console.log(`查看验证后的合约: https://${network.name === 'sepolia' ? 'sepolia.' : ''}etherscan.io/address/${contractAddress}#code`);

  } catch (error) {
    console.log();
    console.error("❌ 合约验证失败:", error.message);
    console.log();
    console.log("可能的原因:");
    console.log("1. 合约已经验证过");
    console.log("2. 合约正在编译中，请稍后重试");
    console.log("3. Etherscan API 密钥无效或额度不足");
    console.log("4. 构造函数参数不正确");
    console.log();

    // 如果合约已验证，提供查看链接
    console.log(`查看合约: https://${network.name === 'sepolia' ? 'sepolia.' : ''}etherscan.io/address/${contractAddress}#code`);
  }

  console.log();
  console.log("========================================");
}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ 验证过程中发生错误:", error);
    process.exit(1);
  });
