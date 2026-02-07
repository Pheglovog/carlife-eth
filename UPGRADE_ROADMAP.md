# CarLife 项目升级路线图

## 📋 当前状态

- ✅ 基础 CarNFT 合约
- ✅ 基础后端 API
- ⚠️  OpenZeppelin 5.x 兼容性问题
- ⚠️  缺少高级功能（跨链、Layer2）

---

## 🎯 升级目标

### 阶段 1: 安全增强（本周）

#### 1.1 使用 OpenZeppelin 标准实现
```solidity
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract CarLifeNFT is
    ERC721,
    ERC721URIStorage,
    AccessControl,
    Pausable,
    ReentrancyGuard
{
    // 使用标准接口，无需自定义
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant SERVICE_ROLE = keccak256("SERVICE_ROLE");
}
```

#### 1.2 添加高级安全特性
- 重入攻击防护（ReentrancyGuard）
- 时间锁攻击防护
- 针对合约攻击防护
- Gas 优化（存储打包）

#### 1.3 完善测试套件
- 安全漏洞测试
- Gas 优化测试
- 边界条件测试
- 重入攻击模拟

---

### 阶段 2: 功能增强（本月）

#### 2.1 元数据标准
- 实现 ERC721Metadata
- 动态元数据更新
- IPFS 集成（去中心化存储）
- 链下元数据（降低 Gas）

#### 2.2 批量操作
```solidity
// 批量铸造
function mintBatch(
    address[] calldata recipients,
    string[] calldata uris
) external onlyRole(MINTER_ROLE) {
    for (uint256 i = 0; i < recipients.length; i++) {
        _mint(recipients[i], uris[i]);
    }
}

// 批量查询
function getCarInfosBatch(uint256[] calldata tokenIds)
    external
    view
    returns (CarInfo[] memory)
{
    CarInfo[] memory infos = new CarInfo[](tokenIds.length);
    for (uint256 i = 0; i < tokenIds.length; i++) {
        infos[i] = _carInfos[tokenIds[i]];
    }
    return infos;
}
```

#### 2.3 燃烧机制
```solidity
function burn(uint256 tokenId) external {
    require(_isApprovedOrOwner(msg.sender, tokenId), "Not owner");
    _burn(tokenId);
    emit Burned(tokenId, msg.sender);
}
```

---

### 阶段 3: Layer2 集成（下月）

#### 3.1 多链支持
```solidity
// 配置多个网络
mapping(uint256 chainId => bool) public supportedChains;

function addSupportedChain(uint256 chainId) external onlyAdmin {
    supportedChains[chainId] = true;
}

function isChainSupported(uint256 chainId) external view returns (bool) {
    return supportedChains[chainId];
}
```

#### 3.2 跨链桥接
- 实现 CCIP 标准（跨链 Token 标准）
- 集成 Layer2 Bridge
- 支持 Arbitrum, Optimism, Base

#### 3.3 Gas 优化（Layer2）
- 使用 Layer2 降低交易费用
- 批量操作减少交互次数
- 状态通道（可选）

---

### 阶段 4: 高级功能（下季度）

#### 4.1 动态 NFT
- 允许 NFT 属性变化
- 链下属性存储
- 可组装 NFT

#### 4.2 租赁功能
```solidity
function rent(uint256 tokenId, uint256 duration) external payable {
    require(_isApprovedOrOwner(msg.sender, tokenId), "Not authorized");

    _rent(tokenId, duration, msg.value);

    emit Rented(tokenId, msg.sender, duration, msg.value);
}

function claim(uint256 tokenId) external {
    // 领取收益
}
```

#### 4.3 DeFi 集成
- NFT 抵押借贷
- 流动性池
- 收益 farming

---

## 🔧 开发工具

### Hardhat 配置优化
```javascript
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200  // Gas 优化
      },
      viaIR: true  // 启用中间表示
    }
  },
  networks: {
    mainnet: { url: process.env.MAINNET_RPC },
    sepolia: { url: process.env.SEPOLIA_RPC },
    arbitrum: { url: process.env.ARBITRUM_RPC },
    optimism: { url: process.env.OPTIMISM_RPC }
  },
  gasReporter: {
    enabled: true,
    currency: 'USD'
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY
  }
};
```

### 前端 web3.js 集成
```typescript
import { ethers } from 'ethers';
import { CarLifeNFT__factory } from './typechain';

// Provider 管理
const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();

// 合约实例
const contract = CarLifeNFT__factory.connect(signer);

// Gas 优化
const estimatedGas = await contract.mint.estimateGas(
    recipient,
    vin,
    make,
    model,
    year,
    mileage,
    condition,
    uri
);

// 增加缓冲（避免 Gas 不足）
const gasLimit = Math.floor(estimatedGas * 1.1);

// 发送交易
const tx = await contract.mint(
    recipient,
    vin,
    make,
    model,
    year,
    mileage,
    condition,
    uri,
    { gasLimit }
);

await tx.wait();
```

---

## 📊 测试计划

### 单元测试
```typescript
describe("CarLifeNFT", function () {
  // 部署
  it("Should deploy with correct initial state", async function () {
    // 测试
  });

  // Minting
  it("Should mint with correct token ID", async function () {
    // 测试
  });

  // 访问控制
  it("Should only allow admin to pause", async function () {
    // 测试
  });

  // 重入保护
  it("Should prevent reentrancy", async function () {
    // 测试
  });

  // Gas 优化
  it("Should use optimized gas", async function () {
    // 测试
  });
});
```

### 集成测试
```typescript
describe("CarLifeNFT Integration", function () {
  // 多用户场景
  it("Should handle multiple users", async function () {
    // 测试
  });

  // 批量操作
  it("Should handle batch operations", async function () {
    // 测试
  });

  // 跨链场景
  it("Should handle cross-chain operations", async function () {
    // 测试
  });
});
```

### Gas 报告
```bash
npx hardhat test
npx hardhat gas-report
```

---

## 🚀 部署计划

### 测试网络
1. Sepolia - 以太坊测试网
2. Goerli - 以太坊测试网（如果可用）
3. Arbitrum Sepolia - Layer2 测试网
4. Optimism Sepolia - Layer2 测试网

### 主网
1. 以太坊主网
2. Arbitrum One
3. Optimism
4. Base

---

## 📝 技术债务

### 高优先级
- [ ] 修复 OpenZeppelin 5.x 兼容性
- [ ] 添加完整的测试套件
- [ ] Gas 优化审计
- [ ] 安全审计

### 中优先级
- [ ] 实现批量操作
- [ ] 添加元数据标准
- [ ] 集成 Layer2 网络
- [ ] 前端优化

### 低优先级
- [ ] 添加租赁功能
- [ ] DeFi 集成
- [ ] 动态 NFT
- [ ] 跨链桥接

---

## 🎯 成功指标

### 技术指标
- 合约 Gas 使用 < 500,000 (部署）
- 单次操作 Gas < 100,000
- 测试覆盖率 > 90%
- 安全审计通过

### 业务指标
- 用户采用率
- 交易成功率
- 平均 Gas 费用
- 用户满意度

---

**创建时间**: 2026-02-03
**负责人**: Pheglovog
**状态**: 🚧 进行中
