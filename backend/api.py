#!/usr/bin/env python3
"""
CarLife 后端 API 示例
演示 Go 后端的 Python 实现（用于快速测试）
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import uvicorn
import json
from datetime import datetime

app = FastAPI(title="CarLife API")

# CORS 中间件
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# 数据模型

class Provider(BaseModel):
    id: Optional[int] = None
    name: str
    service_type: str  # MAINTENANCE, INSURANCE, WASH, GAS, PARKING, RENTAL
    location: str
    rating: float = 0.0
    review_count: int = 0
    active: bool = True


class Service(BaseModel):
    id: Optional[int] = None
    provider_id: int
    title: str
    description: str
    price: float
    currency: str = "CNY"
    available: bool = True


class Review(BaseModel):
    id: Optional[int] = None
    service_id: int
    rating: int  # 1-5
    comment: str


class CarNFT(BaseModel):
    id: Optional[int] = None
    vin: str
    brand: str
    model: str
    year: int
    color: str
    mileage: int
    owner: str


# 内存数据库

providers_db = []
services_db = []
reviews_db = {}
cars_db = []


# API 端点

@app.get("/")
def read_root():
    return {"message": "CarLife API", "version": "1.0.0"}


@app.get("/health")
def health_check():
    return {"status": "ok", "timestamp": datetime.now().isoformat()}


@app.get("/providers", response_model=List[Provider])
def get_providers():
    """获取所有服务商"""
    return providers_db


@app.post("/providers", response_model=Provider)
def create_provider(provider: Provider):
    """注册服务商"""
    provider.id = len(providers_db) + 1
    providers_db.append(provider)
    return provider


@app.get("/providers/{provider_id}", response_model=Provider)
def get_provider(provider_id: int):
    """获取服务商详情"""
    for p in providers_db:
        if p.id == provider_id:
            return p
    return {"error": "Provider not found"}


@app.get("/services", response_model=List[Service])
def get_services():
    """获取所有服务"""
    return services_db


@app.post("/services", response_model=Service)
def create_service(service: Service):
    """添加服务"""
    service.id = len(services_db) + 1
    services_db.append(service)
    return service


@app.get("/services/{service_id}/reviews", response_model=List[Review])
def get_service_reviews(service_id: int):
    """获取服务评价"""
    return reviews_db.get(service_id, [])


@app.post("/services/{service_id}/reviews", response_model=Review)
def add_review(service_id: int, review: Review):
    """添加评价"""
    review.id = len(reviews_db.get(service_id, [])) + 1
    if service_id not in reviews_db:
        reviews_db[service_id] = []
    reviews_db[service_id].append(review)

    # 更新服务商评分
    total = sum(r.rating for r in reviews_db[service_id])
    count = len(reviews_db[service_id])
    avg = total / count if count > 0 else 0

    for p in providers_db:
        if p.id == services_db[service_id - 1].provider_id:
            p.rating = avg
            p.review_count = count
            break

    return review


@app.get("/cars", response_model=List[CarNFT])
def get_cars():
    """获取所有车辆 NFT"""
    return cars_db


@app.post("/cars", response_model=CarNFT)
def mint_car(car: CarNFT):
    """铸造车辆 NFT"""
    car.id = len(cars_db) + 1
    car.owner = "demo"  # 从钱包地址获取
    cars_db.append(car)
    return car


@app.get("/cars/{car_id}", response_model=CarNFT)
def get_car(car_id: int):
    """获取车辆详情"""
    for car in cars_db:
        if car.id == car_id:
            return car
    return {"error": "Car not found"}


@app.put("/cars/{car_id}/mileage")
def update_car_mileage(car_id: int, mileage: int):
    """更新车辆里程"""
    for car in cars_db:
        if car.id == car_id:
            car.mileage = mileage
            return {"success": True}
    return {"error": "Car not found"}


if __name__ == "__main__":
    print("🚗 CarLife API 启动中...")
    print("访问 http://localhost:8000/docs 查看 API 文档")

    uvicorn.run(app, host="0.0.0.0", port=8000)
