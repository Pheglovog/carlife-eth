"""CarLife 集成测试 - 完整流程测试"""
import pytest
from brownie import CarNFTFixed, accounts, reverts, chain
import pandas as pd


class TestCarLifeIntegration:
    """CarLife 集成测试 - 完整流程"""

    @pytest.fixture
    def contract(self):
        """部署合约"""
        deployer = accounts[0]
        return CarNFTFixed.deploy({"from": deployer})

    @pytest.fixture
    def owner(self, contract):
        """获取合约所有者"""
        return contract.owner()

    @pytest.fixture
    def user(self):
        """创建测试用户"""
        return accounts[1]

    def test_deployment(self, contract):
        """测试合约部署"""
        assert contract.name() == "CarLife NFT"
        assert contract.symbol() == "CLFT"
        assert contract.owner() == accounts[0]
        assert contract.totalCars() == 0

    def test_pausable_functionality(self, contract, owner):
        """测试暂停功能"""
        # 测试初始状态
        assert contract.paused() is False
        assert contract.mintingPaused() is True

        # 暂停合约
        contract.pause({"from": owner})
        assert contract.paused() is True

        # 取消暂停
        contract.unpause({"from": owner})
        assert contract.paused() is False

        # 暂停铸造
        contract.pauseMinting({"from": owner})
        assert contract.mintingPaused() is True

        # 取消暂停铸造
        contract.unpauseMinting({"from": owner})
        assert contract.mintingPaused() is False

    def test_mint_workflow(self, contract, owner):
        """测试完整的铸造流程"""
        # 取消暂停铸造
        contract.unpauseMinting({"from": owner})

        # 准备数据
        to = owner
        vin = "VIN1234567890ABCDEFG"
        make = "Toyota"
        model = "Camry"
        year = 2023
        mileage = 50000
        condition = "Excellent"
        uri = "ipfs://QmTest123"

        # 铸造 NFT
        tx = contract.mintCar(to, vin, make, model, year, mileage, condition, uri, {"from": owner})
        tx.wait()

        # 验证结果
        assert contract.totalCars() == 1
        assert contract.ownerOf(0) == to

        # 验证车辆信息
        car_info = contract.getCarInfo(0)
        assert car_info["vin"] == vin
        assert car_info["make"] == make
        assert car_info["model"] == model
        assert car_info["year"] == year
        assert car_info["mileage"] == mileage
        assert car_info["condition"] == condition
        assert car_info["lastServiceDate"] > 0

    def test_custom_authorization_workflow(self, contract, owner, user):
        """测试自定义授权流程"""
        # 取消暂停铸造
        contract.unpauseMinting({"from": owner})

        # 添加自定义授权
        contract.addCustomAuthorized(user, {"from": owner})
        assert contract.isCustomAuthorized(user) is True

        # 铸造 NFT
        contract.mintCar(
            user, "VIN123", "Toyota", "Camry", 2023, 50000, "Excellent", "ipfs://QmTest",
            {"from": owner}
        )

        # 更新车辆信息（使用授权账户）
        new_mileage = 51000
        new_condition = "Good"
        contract.updateCarInfo(0, new_mileage, new_condition, {"from": user})

        # 验证更新
        car_info = contract.getCarInfo(0)
        assert car_info["mileage"] == new_mileage
        assert car_info["condition"] == new_condition

        # 移除授权
        contract.removeCustomAuthorized(user, {"from": owner})
        assert contract.isCustomAuthorized(user) is False

    def test_maintenance_workflow(self, contract, owner, user):
        """测试维护记录添加流程"""
        # 取消暂停铸造
        contract.unpauseMinting({"from": owner})
        contract.addCustomAuthorized(user, {"from": owner})

        # 铸造 NFT
        contract.mintCar(
            user, "VIN123", "Toyota", "Camry", 2023, 50000, "Excellent", "ipfs://QmTest",
            {"from": owner}
        )

        # 添加维护记录
        service_mileage = 51000
        service_notes = "Oil change"
        contract.addMaintenance(0, service_mileage, service_notes, {"from": user})

        # 验证更新
        car_info = contract.getCarInfo(0)
        assert car_info["mileage"] == service_mileage
        assert car_info["lastServiceDate"] > 0

    def test_batch_mint_workflow(self, contract, owner):
        """测试批量铸造流程"""
        # 取消暂停铸造
        contract.unpauseMinting({"from": owner})

        # 批量铸造
        for i in range(10):
            to = owner
            vin = f"VIN{i:010d}"
            make = "Toyota"
            model = "Camry"
            year = 2023 + (i % 3)
            mileage = 50000 + i * 1000
            condition = "Excellent"
            uri = f"ipfs://QmTest{i}"

            contract.mintCar(to, vin, make, model, year, mileage, condition, uri, {"from": owner})

        # 验证结果
        assert contract.totalCars() == 10
        for i in range(10):
            assert contract.ownerOf(i) == owner
            car_info = contract.getCarInfo(i)
            assert car_info["vin"] == f"VIN{i:010d}"

    def test_transfer_workflow(self, contract, owner, user):
        """测试完整的转账流程"""
        # 取消暂停铸造
        contract.unpauseMinting({"from": owner})

        # 铸造 NFT
        contract.mintCar(
            owner, "VIN123", "Toyota", "Camry", 2023, 50000, "Excellent", "ipfs://QmTest",
            {"from": owner}
        )

        # 转账
        contract.transferFrom(owner, user, 0, {"from": owner})

        # 验证结果
        assert contract.ownerOf(0) == user
        assert contract.balanceOf(owner) == 0
        assert contract.balanceOf(user) == 1

    def test_paused_minting(self, contract, owner):
        """测试铸造暂停时的行为"""
        # 确保铸造是暂停的
        assert contract.mintingPaused() is True

        # 尝试铸造（应该失败）
        with reverts("MintingIsPaused"):
            contract.mintCar(
                owner, "VIN123", "Toyota", "Camry", 2023, 50000, "Excellent", "ipfs://QmTest",
                {"from": owner}
            )

        # 取消暂停铸造
        contract.unpauseMinting({"from": owner})

        # 现在应该可以铸造
        contract.mintCar(
            owner, "VIN123", "Toyota", "Camry", 2023, 50000, 'Excellent', "ipfs://QmTest",
            {"from": owner}
        )
        assert contract.totalCars() == 1

    def test_paused_transfer(self, contract, owner, user):
        """测试转账暂停时的行为"""
        # 取消暂停铸造
        contract.unpauseMinting({"from": owner})

        # 铸造 NFT
        contract.mintCar(
            owner, "VIN123", "Toyota", "Camry", 2023, 50000, "Excellent", "ipfs://QmTest",
            {"from": owner}
        )

        # 暂停合约
        contract.pause({"from": owner})

        # 尝试转账（应该失败）
        with reverts("Pausable: paused"):
            contract.transferFrom(owner, user, 0, {"from": owner})

        # 取消暂停
        contract.unpause({"from": owner})

        # 现在应该可以转账
        contract.transferFrom(owner, user, 0, {"from": owner})
        assert contract.ownerOf(0) == user

    def test_token_uri_workflow(self, contract, owner):
        """测试 tokenURI 流程"""
        # 取消暂停铸造
        contract.unpauseMinting({"from": owner})

        # 铸造 NFT
        uri = "ipfs://QmTest123"
        contract.mintCar(
            owner, "VIN123", "Toyota", "Camry", 2023, 50000, "Excellent", uri,
            {"from": owner}
        )

        # 查询 tokenURI
        token_uri = contract.tokenURI(0)
        assert token_uri == uri

        # 验证事件
        tx = contract.mintCar(
            owner, "VIN456", "BMW", "X5", 2022, 35000, "Good", "ipfs://QmTest456",
            {"from": owner}
        )
        assert "CarMinted" in tx.events


class TestCarLifePerformance:
    """CarLife 性能测试"""

    @pytest.fixture
    def contract(self):
        """部署合约"""
        deployer = accounts[0]
        return CarNFTFixed.deploy({"from": deployer})

    def test_batch_mint_performance(self, contract):
        """测试批量铸造性能"""
        # 取消暂停铸造
        contract.unpauseMinting({"from": accounts[0]})

        # 记录 Gas
        total_gas = 0

        # 批量铸造
        for i in range(100):
            uri = f"ipfs://QmTest{i}"
            tx = contract.mintCar(
                accounts[0], f"VIN{i:010d}", "Toyota", "Camry", 2023,
                50000 + i * 100, 'Excellent', uri, {"from": accounts[0]}
            )
            total_gas += tx.gas_used

        # 验证结果
        assert contract.totalCars() == 100
        assert total_gas < 35000000  # 100 次铸造应该在 35M gas 内完成

    def test_batch_transfer_performance(self, contract):
        """测试批量转账性能"""
        # 取消暂停铸造
        contract.unpauseMinting({"from": accounts[0]})

        # 批量铸造
        for i in range(50):
            contract.mintCar(
                accounts[0], f"VIN{i:010d}", "Toyota", "Camry", 2023,
                50000 + i * 100, 'Excellent', f"ipfs://QmTest{i}", {"from": accounts[0]}
            )

        # 批量转账
        total_gas = 0
        for i in range(50):
            tx = contract.transferFrom(accounts[0], accounts[1], i, {"from": accounts[0]})
            total_gas += tx.gas_used

        # 验证结果
        assert total_gas < 3000000  # 50 次转账应该在 3M gas 内完成

    def test_batch_update_performance(self, contract):
        """测试批量更新性能"""
        # 取消暂停铸造
        contract.unpauseMinting({"from": accounts[0]})
        contract.addCustomAuthorized(accounts[1], {"from": accounts[0]})

        # 批量铸造
        for i in range(50):
            contract.mintCar(
                accounts[0], f"VIN{i:010d}", "Toyota", "Camry", 2023,
                50000 + i * 100, 'Excellent', f"ipfs://QmTest{i}", {"from": accounts[0]}
            )

        # 批量更新
        total_gas = 0
        for i in range(50):
            tx = contract.updateCarInfo(i, 60000 + i * 100, "Good", {"from": accounts[1]})
            total_gas += tx.gas_used

        # 验证结果
        assert total_gas < 2500000  # 50 次更新应该在 2.5M gas 内完成


class TestCarLifeEdgeCases:
    """CarLife 边界情况测试"""

    @pytest.fixture
    def contract(self):
        """部署合约"""
        deployer = accounts[0]
        return CarNFTFixed.deploy({"from": deployer})

    def test_nonexistent_token_query(self, contract):
        """测试查询不存在的 token"""
        with reverts("TokenDoesNotExist"):
            contract.getCarInfo(9999)

    def test_zero_mileage(self, contract):
        """测试零里程"""
        # 取消暂停铸造
        contract.unpauseMinting({"from": accounts[0]})

        # 铸造零里程 NFT
        contract.mintCar(
            accounts[0], "VIN123", "Toyota", "Camry", 2023, 0, "Excellent", "ipfs://QmTest",
            {"from": accounts[0]}
        )

        # 验证结果
        car_info = contract.getCarInfo(0)
        assert car_info["mileage"] == 0

    def test_max_year(self, contract):
        """测试最大年份"""
        # 取消暂停铸造
        contract.unpauseMinting({"from": accounts[0]})

        # 铸造最大年份 NFT
        contract.mintCar(
            accounts[0], "VIN123", "Toyota", "Camry", 9999, 50000, "Excellent", "ipfs://QmTest",
            {"from": accounts[0]}
        )

        # 验证结果
        car_info = contract.getCarInfo(0)
        assert car_info["year"] == 9999

    def test_very_long_vin(self, contract):
        """测试很长的 VIN"""
        # 取消暂停铸造
        contract.unpauseMinting({"from": accounts[0]})

        # 铸造长 VIN NFT
        long_vin = "VIN" + "0" * 50
        contract.mintCar(
            accounts[0], long_vin, "Toyota", "Camry", 2023, 50000, "Excellent", "ipfs://QmTest",
            {"from": accounts[0]}
        )

        # 验证结果
        car_info = contract.getCarInfo(0)
        assert car_info["vin"] == long_vin

    def test_special_characters_in_condition(self, contract):
        """测试条件中的特殊字符"""
        # 取消暂停铸造
        contract.unpauseMinting({"from": accounts[0]})

        # 铸造特殊字符条件 NFT
        special_condition = "Excellent - \"Best in Class\""
        contract.mintCar(
            accounts[0], "VIN123", "Toyota", "Camry", 2023, 50000, special_condition,
            "ipfs://QmTest", {"from": accounts[0]}
        )

        # 验证结果
        car_info = contract.getCarInfo(0)
        assert car_info["condition"] == special_condition


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--gas-report"])
