// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title ServiceRegistry
 * @dev 服务注册合约 - 完整版
 */
contract ServiceRegistry is Ownable {
    using Counters for Counters.Counter;

    // 服务类型
    enum ServiceType {
        MAINTENANCE,  // 维修
        INSURANCE,    // 保险
        WASH,         // 洗车
        GAS,          // 加油
        PARKING,      // 停车
        RENTAL        // 租赁
    }

    // 计数器
    Counters.Counter private _providerIdCounter;
    Counters.Counter private _serviceIdCounter;

    // 服务商
    struct ServiceProvider {
        uint256 id;
        string name;
        address wallet;
        ServiceType serviceType;
        string location;
        uint256 rating;          // 评分 * 100 (0-10000)
        uint256 reviewCount;      // 评价数量
        bool active;
        uint256 registeredAt;
    }

    // 服务
    struct Service {
        uint256 id;
        uint256 providerId;
        string title;
        string description;
        uint256 price;          // 最小报价
        string currency;
        bool available;
    }

    // 评价
    struct Review {
        uint256 id;
        uint256 serviceId;
        address reviewer;
        uint256 rating;         // 1-5 * 100 (100-500)
        string comment;
        uint256 timestamp;
    }

    // 映射
    mapping(uint256 => ServiceProvider) public providers;
    mapping(address => uint256) public providerIdByAddress;
    mapping(uint256 => Service) public services;
    mapping(uint256 => Review[]) public serviceReviews;

    // 事件
    event ProviderRegistered(uint256 indexed providerId, string name, address wallet);
    event ServiceAdded(uint256 indexed serviceId, uint256 providerId, string title);
    event ReviewAdded(uint256 indexed serviceId, address reviewer, uint256 rating);
    event ProviderDeactivated(uint256 indexed providerId);

    function registerProvider(
        string memory name,
        ServiceType serviceType,
        string memory location
    ) public returns (uint256) {
        require(providerIdByAddress[msg.sender] == 0, "Provider already registered");

        uint256 providerId = _providerIdCounter.current();
        _providerIdCounter.increment();

        providers[providerId] = ServiceProvider({
            id: providerId,
            name: name,
            wallet: msg.sender,
            serviceType: serviceType,
            location: location,
            rating: 0,
            reviewCount: 0,
            active: true,
            registeredAt: block.timestamp
        });

        providerIdByAddress[msg.sender] = providerId;

        emit ProviderRegistered(providerId, name, msg.sender);

        return providerId;
    }

    function addService(
        uint256 providerId,
        string memory title,
        string memory description,
        uint256 price,
        string memory currency
    ) public returns (uint256) {
        require(providers[providerId].wallet == msg.sender, "Not provider");
        require(providers[providerId].active, "Provider not active");

        uint256 serviceId = _serviceIdCounter.current();
        _serviceIdCounter.increment();

        services[serviceId] = Service({
            id: serviceId,
            providerId: providerId,
            title: title,
            description: description,
            price: price,
            currency: currency,
            available: true
        });

        emit ServiceAdded(serviceId, providerId, title);

        return serviceId;
    }

    function addReview(
        uint256 serviceId,
        uint256 rating,
        string memory comment
    ) public {
        require(rating >= 100 && rating <= 500, "Invalid rating");
        require(services[serviceId].providerId != 0, "Service not found");

        Review memory newReview = Review({
            id: serviceReviews[serviceId].length,
            serviceId: serviceId,
            reviewer: msg.sender,
            rating: rating,
            comment: comment,
            timestamp: block.timestamp
        });

        serviceReviews[serviceId].push(newReview);

        // 更新服务商评分
        uint256 providerId = services[serviceId].providerId;
        _updateProviderRating(providerId);

        emit ReviewAdded(serviceId, msg.sender, rating);
    }

    function _updateProviderRating(uint256 providerId) internal {
        ServiceProvider storage provider = providers[providerId];

        uint256 totalRating = 0;
        uint256 totalReviews = 0;

        uint256 serviceCount = _serviceIdCounter.current();

        for (uint256 i = 0; i < serviceCount; i++) {
            if (services[i].providerId == providerId) {
                Review[] memory reviews = serviceReviews[i];

                for (uint256 j = 0; j < reviews.length; j++) {
                    totalRating += reviews[j].rating;
                    totalReviews++;
                }
            }
        }

        if (totalReviews > 0) {
            provider.rating = (totalRating * 100) / totalReviews;
            provider.reviewCount = totalReviews;
        }
    }

    function deactivateProvider(uint256 providerId) public onlyOwner {
        providers[providerId].active = false;
        emit ProviderDeactivated(providerId);
    }

    function getProvider(uint256 providerId) public view returns (ServiceProvider memory) {
        return providers[providerId];
    }

    function getService(uint256 serviceId) public view returns (Service memory) {
        return services[serviceId];
    }

    function getServiceReviews(uint256 serviceId) public view returns (Review[] memory) {
        return serviceReviews[serviceId];
    }

    function getProviderId(address wallet) public view returns (uint256) {
        return providerIdByAddress[wallet];
    }
}
