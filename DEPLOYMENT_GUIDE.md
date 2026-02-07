# CarLife - 智能合约部署指南

## 📋 前置准备

### 1. 安装依赖（已完成）
```bash
cd /root/clawd/CarLife
npm install
```

### 2. 配置环境变量

编辑 `.env` 文件，填入你的私钥：

```bash
# .env
PRIVATE_KEY=你的私钥（不要包含 0x 前缀）
SEPOLIA_RPC_URL=https://rpc.sepolia.org
ETHERSCAN_API_KEY=你的etherscan密钥（可选）
```

### 3. 获取钱包私钥

#### 选项 A: 创建新钱包
```bash
cd /root/clawd/CarLife
node -e "const { ethers } = require('ethers'); const wallet = ethers.Wallet.createRandom(); console.log('Address:', wallet.address); console.log('Private Key:', wallet.privateKey);"
```

#### 选项 B: 使用已有钱包（推荐）
- 从 MetaMask 导出私钥
- 或者使用已存在的钱包地址

### 4. 获取 Sepolia 测试币

访问以下水龙头获取测试 ETH：

- https://sepoliafaucet.com
- https://cloud.google.com/application/web3/faucet/ethereum/sepolia
- https://faucet.quicknode.com/ethereum/sepolia

**推荐步骤**：
1. 复制你的钱包地址
2. 访问水龙头网站
3. 粘贴地址并请求测试币
4. 等待几分钟确认到账

---

## 🚀 部署步骤

### 1. 编译合约

```bash
cd /root/clawd/CarLife
npx hardhat compile
```

### 2. 检查账户余额

```bash
npx hardhat run scripts/check-balance.js --network sepolia
```

### 3. 部署到 Sepolia 测试网

```bash
npx hardhat run scripts/deploy.js --network sepolia
```

### 4. 验证合约（可选）

```bash
npx hardhat verify --network sepolia <合约地址>
```

---

## 📊 部署输出示例

```
============================================================
🚗 CarLife - 智能合约部署
============================================================

🌐 网络: sepolia (Chain ID: 11155111)

👤 部署者地址: 0x1234567890abcdef1234567890abcdef12345678
💰 账户余额: 0.1 ETH

🚀 部署 CarNFT_Mini 合约...
✅ 合约部署成功!
📋 合约地址: 0x9876543210fedcba9876543210fedcba98765432

🧪 验证合约功能...
📝 代币名称: CarLife NFT
🔤 代币符号: CLFT
👤 合约所有者: 0x1234567890abcdef1234567890abcdef12345678

✅ 部署者是管理员: true

💾 部署信息已保存到 deployment.json

📝 验证合约 (可选):
npx hardhat verify --network sepolia 0x9876543210fedcba9876543210fedcba98765432

============================================================
✅ 部署完成!
============================================================
```

---

## 🔧 常见问题

### 问题 1: 余额不足
**错误**: `❌ 余额不足，至少需要 0.01 ETH`

**解决**: 访问水龙头获取测试币，等待几分钟后再试

### 问题 2: RPC 连接失败
**错误**: `Error: could not detect network`

**解决**: 检查 `hardhat.config.js` 中的 RPC URL 是否正确

### 问题 3: 合约部署超时
**错误**: `Timeout exceeded`

**解决**: 
1. 增加 gas limit
2. 检查网络连接
3. 尝试其他 RPC 提供商

### 问题 4: Gas 费用过高
**解决**: 
1. 等待网络不太拥堵时部署
2. 设置合理的 gas price
3. 使用 `optimization` 设置

---

## 📝 合约功能测试

部署成功后，可以测试合约功能：

### 测试 Mint 车辆 NFT
```bash
npx hardhat run scripts/test-mint.js --network sepolia
```

### 测试查询车辆信息
```bash
npx hardhat run scripts/test-query.js --network sepolia
```

---

## 🔍 查看合约

- **Sepolia Etherscan**: https://sepolia.etherscan.io/address/<合约地址>
- **交易历史**: https://sepolia.etherscan.io/tx/<交易哈希>

---

## 📦 下一步

部署成功后：
1. ✅ 记录合约地址
2. ✅ 保存 deployment.json
3. ✅ 配置前端连接合约
4. ✅ 测试合约功能
5. ✅ 编写部署文档

---

**最后更新**: 2026-02-04
**作者**: 上等兵•甘
