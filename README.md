# CarLife - 区块链汽车生活平台

一个基于区块链的汽车生活服务平台，连接车主、服务商和区块链生态。

## 🌟 核心特性

### 🚗 车辆 NFT 系统
- ✅ **车辆信息上链** - 不可篡改的所有权证明
- ✅ **VIN 验证** - 防止重复注册（17 字符，字母数字验证）
- ✅ **里程记录** - 透明可信的里程管理
- ✅ **维修记录** - 完整的维修历史
- ✅ **NFT 转移** - 支持车辆所有权变更
- ✅ **动态外观系统** - 基于车况自动更新 NFT 外观（5 个等级）

### 🎨 动态 NFT (Dynamic NFT)
- ✅ **EIP-4906 标准** - 元数据更新事件通知
- ✅ **动态外观** - 根据车况变化（Poor/Fair/Good/Excellent/TotalLoss）
- ✅ **生命周期追踪** - 里程、维护、事故记录
- ✅ **Base64 元数据** - 链上元数据生成
- ✅ **完整事件系统** - 所有操作都有事件记录

### 🔧 服务注册系统
- ✅ **服务商注册** - 去中心化的服务商认证
- ✅ **服务发布** - 透明的服务信息和报价
- ✅ **评价系统** - 不可删除的链上评价
- ✅ **评分机制** - 自动计算平均评分

### 💰 数据 Token 化
- ✅ **数据记录铸造** - 里程、维修、驾驶等数据上链
- ✅ **加密存储** - 保护用户隐私
- ✅ **数据交易** - 数据所有者可以安全交易
- ✅ **哈希验证** - 防止重复记录

## 🛡️ 安全增强（v3.0.0+）

### CarNFT_Secure (v3.0.0)
- **输入验证**：VIN、Year、Mileage 验证
- **审计日志**：完整的操作审计（尝试、完成、旧值、新值）
- **Gas 优化**：存储布局优化（uint16, uint96, uint64）
- **安全事件**：里程减少等安全事件记录

### CarNFT_Enhanced (v3.1.0) - 新增！
- **输入验证**：VIN 长度（17 字符）、年份范围（>= 1900）
- **ReentrancyGuard**：防止重入攻击
- **批处理功能**：
  - `batchMintCars`：最多 50 辆
  - `batchUpdateCarInfo`：批量更新车辆信息
  - `batchGetCarInfo`：批量查询车辆信息
- **Gas 优化**：13% 批量铸造节省
- **NatSpec 文档**：完整的函数文档和使用示例
- **测试覆盖**：36 个测试，100% 通过

### CarLifeDynamicNFT (v3.2.0) - 全新！
- **EIP-4906 标准**：元数据更新事件通知
- **动态外观系统**：
  - Poor (0-39)：较差状态
  - Fair (40-59)：一般状态
  - Good (60-79)：良好状态
  - Excellent (80-100)：优秀状态
  - TotalLoss：报废状态
- **生命周期追踪**：
  - 里程管理（每 1000 公里降低 1 点车况）
  - 维护系统（恢复车况到 80-95）
  - 事故记录（根据严重程度影响车况）
  - 报废机制（严重事故触发）
- **完善的事件系统**：
  - `CarMinted`：铸造事件
  - `MileageAdded`：里程添加事件
  - `ServicePerformed`：维护事件
  - `AccidentRecorded`：事故记录事件
  - `AppearanceUpdated`：外观更新事件
  - `MetadataUpdate`：元数据更新事件
- **管理员功能**：
  - 暂停/恢复合约
  - 提取合约余额
  - 设置基础 IPFS URI
- **费用结构**：
  - 铸造费：0.01 ETH
  - 维护费：0.005 ETH
  - 里程费：0.0001 ETH/1000 公里
- **测试覆盖**：44 个测试，100% 通过

### 安全特性（所有版本）
- **VIN 验证**：17 个字符，仅允许字母数字
- **Year 验证**：1900-当前年份范围
- **Mileage 验证**：非负数
- **VIN 唯一性**：防止重复 VIN 注册
- **批量限制**：每次最多 50-100 个（视版本而定）

### Gas 优化
- **存储布局优化**：
  - year: `uint16`（节省 gas）
  - mileage: `uint96`（节省 gas）
  - lastServiceDate: `uint64`（节省 gas）
- **unchecked**：在安全位置使用
- **viaIR 编译器**：解决 Stack too deep 问题

## 🛠️ 技术栈

### 区块链
- **Solidity ^0.8.23** - 智能合约
- **OpenZeppelin 5.x** - ERC721、Ownable、Pausable
- **Hardhat 2.22.5** - 开发框架
- **Ethers.js** - 区块链交互

### 后端
- **Go 1.21+** - 高性能后端服务
- **Gin** - Web 框架
- **GORM** - ORM
- **PostgreSQL** - 数据库

### 前端（开发中）
- **Vue 3** - 渐进式框架
- **TypeScript** - 类型安全
- **Element Plus** - UI 组件库
- **Vite** - 构建工具

## 📂 项目结构

```
CarLife/
├── contracts/              # 智能合约
│   ├── CarNFT_Fixed.sol     # 修复版 CarNFT（主合约）
│   ├── CarNFT_Secure.sol    # 安全增强版 CarNFT（v3.0.0）
│   ├── CarNFT_Enhanced.sol  # 增强版 CarNFT（v3.1.0）- 批处理 + 文档
│   └── CarLifeDynamicNFT.sol # 动态 NFT（v3.2.0）- EIP-4906 + 动态外观
├── test/                    # 测试
│   ├── CarNFT_Fixed.test.js  # 完整测试套件（35 测试）
│   ├── CarNFT_Secure.test.js  # 安全增强测试（22 测试）
│   ├── CarNFT_Enhanced.test.js # 增强版测试（36 测试，100% 通过）
│   └── CarLifeDynamicNFT.test.js # 动态 NFT 测试（44 测试，100% 通过）
├── scripts/                 # 部署脚本
│   ├── deploy.js            # 部署脚本
│   ├── deploy-all.js        # 批量部署
│   ├── verify.js            # 合约验证
│   └── check-balance.js      # 余额检查
├── backup/                  # 备份合约（历史版本）
├── backend/                 # 后端（Python 示例）
├── frontend/                # 前端（简单演示）
└── reports/                 # 报告
```

## 🚀 快速开始

### 环境要求

- **Node.js**: 16+
- **Python**: 3.8+
- **Go**: 1.21+
- **Hardhat**: 2.22.5+

### 安装依赖

```bash
# 安装 Node.js 依赖
npm install

# 安装 Python 依赖
cd backend
pip install -r requirements.txt

# 安装 Go 依赖
cd backend-go
go mod download
```

### 运行测试

```bash
# 运行所有测试
npm test

# 运行指定测试
npx hardhat test test/CarNFT_Secure.test.js

# 运行 Gas 报告
REPORT_GAS=true npx hardhat test
```

### 部署合约

```bash
# 部署到本地网络
npx hardhat run scripts/deploy.js --network hardhat

# 部署到测试网
npx hardhat run scripts/deploy.js --network sepolia

# 部署所有合约
npx hardhat run scripts/deploy-all.js --network sepolia
```

## 📊 测试覆盖

### CarNFT_Fixed（基础版）
- **总测试数**：35
- **通过率**：97.2% (35/36)
- **Gas 性能**：5/5 通过

### CarNFT_Secure（安全增强版）
- **总测试数**：22
- **通过率**：100% (22/22)
- **测试分类**：
  - 输入验证：9 个测试 ✅
  - 审计日志：5 个测试 ✅
  - 批量 Mint：3 个测试 ✅
  - 存储优化：1 个测试 ✅
  - Gas 优化：2 个测试 ✅
  - 查询功能：2 个测试 ✅

## 🔐 安全审计

### Slither 扫描结果

```
检测到的问题：
- 高：0
- 中：0
- 低：2

修复状态：✅ 已全部修复
```

### 安全增强功能

1. **输入验证**
   - VIN 格式验证（17 字符，字母数字）
   - Year 范围验证（1900-2100）
   - Mileage 上限验证（< 1 亿公里）
   - VIN 唯一性检查（防止重复）

2. **审计日志**
   - 所有关键操作记录
   - 包含时间戳、操作者、旧值、新值
   - 可追溯的完整操作历史

3. **数学运算精度**
   - `mulDiv` 安全函数
   - 防止除零
   - 防止溢出

4. **Gas 优化**
   - 存储布局优化（uint16/uint96/uint64）
   - `unchecked` 使用（安全位置）
   - viaIR 编译器启用

## 📈 性能优化

### Gas 优化效果

| 操作 | 优化前 | 优化后 | 节省 |
|------|-------|-------|------|
| mintCar | ~340K | ~295K | 14.4% |
| updateCarInfo | ~50K | ~42K | 16% |
| addMaintenance | ~55K | ~45K | 18.2% |

### 存储优化

```solidity
// 优化前
uint256 year;          // 32 bytes
uint256 mileage;       // 32 bytes
uint256 lastServiceDate; // 32 bytes

// 优化后
uint16 year;          // 2 bytes (节省 94%)
uint96 mileage;        // 12 bytes (节省 62.5%)
uint64 lastServiceDate; // 8 bytes (节省 75%)
```

## 📚 详细文档

### 集成测试文档
- **文档**: [docs/INTEGRATION_TESTS.md](docs/INTEGRATION_TESTS.md)
- **内容**:
  - 105 个测试用例详解
  - 测试覆盖率分析
  - 测试最佳实践
  - 已知问题和修复计划

### Gas 优化报告
- **文档**: [docs/GAS_OPTIMIZATION_REPORT.md](docs/GAS_OPTIMIZATION_REPORT.md)
- **内容**:
  - 详细的优化技术分析
  - Gas 消耗对比（优化前/后）
  - 成本分析（主网/ Layer 2）
  - 未来优化计划

## 📝 API 参考

### CarNFT_Secure 合约

#### 主要函数

```solidity
// 铸造车辆 NFT
function mintCar(
    address to,
    string memory vin,
    string memory make,
    string memory model,
    uint256 year,
    uint256 mileage,
    string memory condition,
    string memory uri
) public onlyOwner whenNotPaused whenNotPausedMinting

// 批量铸造（最多 100 个）
function batchMintCars(
    address[] calldata to,
    string[] calldata vins,
    string[] calldata makes,
    string[] calldata models,
    uint256[] calldata carYears,
    uint256[] calldata mileages,
    string[] calldata conditions,
    string[] calldata uris
) public onlyOwner whenNotPaused whenNotPausedMinting

// 更新车辆信息
function updateCarInfo(
    uint256 tokenId,
    uint256 mileage,
    string memory condition
) public onlyCustomAuthorized

// 添加维护记录
function addMaintenance(
    uint256 tokenId,
    uint256 mileage,
    string memory notes
) public onlyCustomAuthorized
```

#### 查询函数

```solidity
// 获取车辆信息
function getCarInfo(uint256 tokenId) public view returns (CarInfo memory)

// 检查 VIN 是否存在
function vinExists(string memory vin) public view returns (bool)

// 获取总车辆数
function totalCars() public view returns (uint256)

// 获取授权地址
function isCustomAuthorized(address account) public view returns (bool)
```

#### 事件

```solidity
// 铸造事件
event CarMinted(uint256 indexed tokenId, address indexed owner, string vin);

// 更新事件
event CarInfoUpdated(uint256 indexed tokenId, uint256 mileage, string condition);

// 维护事件
event MaintenanceAdded(uint256 indexed tokenId, uint256 mileage, string notes);

// 审计事件
event MintingAttempted(address indexed caller, uint256 indexed timestamp, address to, string vin);
event MintingCompleted(address indexed caller, uint256 indexed tokenId, uint256 indexed timestamp);
event CarInfoUpdatedAttempted(address indexed caller, uint256 indexed tokenId, uint256 indexed timestamp, uint256 oldMileage, uint256 newMileage);
event CarInfoUpdatedCompleted(address indexed caller, uint256 indexed tokenId, uint256 indexed timestamp);
event MaintenanceAddedAttempted(address indexed caller, uint256 indexed tokenId, uint256 indexed timestamp, uint256 mileage);
event MaintenanceAddedCompleted(address indexed caller, uint256 indexed tokenId, uint256 indexed timestamp);
event SecurityEvent(address indexed caller, uint256 indexed timestamp, string eventType, string details);
```

## 🔧 配置

### Hardhat 配置

```javascript
module.exports = {
  solidity: {
    version: "0.8.23",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      },
      viaIR: true  // 启用 IR 编译器
    }
  },
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    },
    mainnet: {
      url: process.env.MAINNET_RPC_URL,
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
```

## 📦 版本历史

### v3.2.0 (2026-02-18)
- ✨ 新增 `CarLifeDynamicNFT.sol` - 动态 NFT 合约
- ✨ 实现 EIP-4906 元数据更新事件
- ✨ 添加动态外观系统（5 个等级）
- ✨ 实现车辆生命周期追踪（里程、维护、事故）
- ✨ 添加完善的事件系统
- ✨ 实现管理员功能（暂停、提取、IPFS URI）
- ✨ 添加 44 个测试（100% 通过）

### v3.1.0 (2026-02-15)
- ✨ 新增 `CarNFT_Enhanced.sol` - 增强版
- ✨ 添加批处理功能（批量铸造、更新、查询）
- ✨ 优化 Gas 使用（13% 批量铸造节省）
- ✨ 添加完整的 NatSpec 文档
- ✨ 添加 36 个测试（100% 通过）

### v3.0.0 (2026-02-13)
- ✨ 新增 `CarNFT_Secure.sol` - 安全增强版
- ✨ 添加完整的输入验证
- ✨ 添加审计日志系统
- ✨ 添加 `mulDiv` 安全数学函数
- ✨ 优化存储布局
- ✨ 启用 viaIR 编译器
- ✨ 添加 22 个安全测试（100% 通过）

### v2.0.0 (2026-02-12)
- ✅ 优化 Gas 使用（节省 14.4%）
- ✅ 添加 35 个集成测试
- ✅ 完成 Slither 安全扫描
- ✅ 修复 2 个低危安全问题

### v1.0.0 (2026-02-08)
- ✅ 实现基础 CarNFT 功能
- ✅ 实现 ServiceRegistry
- ✅ 实现 DataToken
- ✅ 添加基础测试套件

## 🤝 贡献指南

我们欢迎所有形式的贡献！

### 开发流程

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 代码规范

- Solidity 代码遵循 [Solidity Style Guide](https://solidity.readthedocs.io/en/latest/style-guide/)
- 测试覆盖率要求 > 80%
- 所有公共函数必须有 NatSpec 注释

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 📮 联系方式

- **项目地址**: https://github.com/Pheglovog/carlife-eth
- **问题反馈**: [GitHub Issues](https://github.com/Pheglovog/carlife-eth/issues)

## 🙏 致谢

- OpenZeppelin - 安全的智能合约库
- Hardhat - 优秀的开发框架
- 以太坊基金会 - 支持

---

**文档版本**: 3.2.0
**更新日期**: 2026-02-18
**作者**: 上等兵•甘
