<<<<<<< HEAD
=======
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from graph_chain import get_chain
import pandas as pd
import csv
import os
import requests
import numpy as np
import rasterio
import matplotlib.pyplot as plt
from datetime import datetime
from pathlib import Path
from typing import Optional

# 模型定义
class QuestionRequest(BaseModel):
    question: str

class LocationRecord(BaseModel):
    species: str
    latitude: float = Field(..., gt=-90, lt=90)
    longitude: float = Field(..., gt=-180, lt=180)
    location_name: str
    date: Optional[str] = None

app = FastAPI()

# 【关键配置】解决跨域问题（CORS）
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173", "http://localhost:5174"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 数据目录配置
DATA_DIR = "data"
LOCATIONS_RECORD_FILE = os.path.join(DATA_DIR, "locations_record.csv")

# 静态目录，供 MaxEnt 预测PNG等文件访问
app.mount("/static", StaticFiles(directory=DATA_DIR), name="static")

@app.get("/")
def read_root():
    return {"message": "后端服务已启动！可以开始查询水生外来入侵物种了！"}

# ========== 物种相关 API ==========
@app.get("/api/species")
def get_species_list():
    """获取所有物种列表"""
    try:
        gbif_dir = os.path.join(DATA_DIR, "gbif_results")
        if os.path.exists(gbif_dir):
            species_files = [f.replace(".csv", "") for f in os.listdir(gbif_dir) if f.endswith('.csv')]
            return {"species": sorted(species_files)}
        return {"species": []}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/species/{species}")
def get_species_info(species: str):
    """获取物种详细信息"""
    try:
        chain = get_chain()
        response = chain.invoke({"query": f"请介绍{species}的基本信息、危害和防治方法"})
        return {
            "info": response['result'],
            "cypher": response.get('generated_cypher', '')
        }
    except Exception as e:
        return {"info": "暂无知识库数据", "cypher": ""}

# ========== 地理位置相关 API ==========
@app.get("/api/locations/{species}")
def get_locations(species: str):
    """获取物种分布位置"""
    try:
        # 首先尝试从 GBIF 结果加载
        gbif_file = os.path.join(DATA_DIR, "gbif_results", f"{species}.csv")
        locations = []
        
        if os.path.exists(gbif_file):
            try:
                df = pd.read_csv(gbif_file)
                # 处理不同的列名变体
                lat_cols = ['decimalLatitude', 'latitude', 'lat']
                lon_cols = ['decimalLongitude', 'longitude', 'lon', 'lng']
                
                lat_col = next((col for col in lat_cols if col in df.columns), None)
                lon_col = next((col for col in lon_cols if col in df.columns), None)
                
                if lat_col and lon_col:
                    for _, row in df.iterrows():
                        try:
                            lat = float(row[lat_col])
                            lon = float(row[lon_col])
                            if -90 <= lat <= 90 and -180 <= lon <= 180:
                                locations.append({
                                    "latitude": lat,
                                    "longitude": lon,
                                    "location_name": str(row.get('locality', row.get('location', 'Unknown')))[:100]
                                })
                        except (ValueError, TypeError):
                            continue
            except Exception as e:
                print(f"Error reading GBIF file: {e}")
        
        # 限制返回数量
        return {"locations": locations[:1000]}
    except Exception as e:
        print(f"Get locations error: {e}")
        return {"locations": [], "error": str(e)}

@app.get("/api/distribution/{species}")
def get_distribution_by_province(species: str):
    """按地区统计分布"""
    try:
        locations_response = get_locations(species)
        locations = locations_response.get("locations", [])
        
        province_count = {}
        for loc in locations:
            location_name = loc.get("location_name", "")
            if location_name:
                # 提取第一个以逗号分隔的部分作为地区
                province = location_name.split(",")[0].strip()
                if province:
                    province_count[province] = province_count.get(province, 0) + 1
        
        return {
            "distribution": province_count,
            "total": sum(province_count.values())
        }
    except Exception as e:
        print(f"Get distribution error: {e}")
        return {"distribution": {}, "total": 0, "error": str(e)}

# ========== 图层与空间分析 API ==========

def _load_china_geojson():
    url = "https://geo.datav.aliyun.com/areas_v3/bound/100000_full.json"
    try:
        res = requests.get(url, timeout=15)
        res.raise_for_status()
        return res.json()
    except Exception as e:
        print(f"加载中国省界 GeoJSON 失败: {e}")
        return None

china_geojson = _load_china_geojson()

@app.get("/api/heatmap/{species}")
def get_heatmap(species: str):
    all_locs = get_locations(species).get("locations", [])
    points = []
    for loc in all_locs:
        lat = loc.get("latitude")
        lon = loc.get("longitude")
        if lat is not None and lon is not None:
            points.append([lat, lon, 0.5])
    return {"points": points}

@app.get("/api/province-data/{species}")
def get_province_data(species: str):
    if not china_geojson:
        raise HTTPException(status_code=500, detail="中国省界 GeoJSON 尚未加载")
    dist = get_distribution_by_province(species).get("distribution", {})
    features = []
    for feat in china_geojson.get("features", []):
        props = dict(feat.get("properties", {}))
        province_name = props.get("name") or props.get("NAME") or props.get("fullname")
        count = dist.get(province_name, 0)
        new_feat = {
            "type": "Feature",
            "geometry": feat.get("geometry"),
            "properties": {
                **props,
                "count": count,
                "name": province_name
            }
        }
        features.append(new_feat)
    return {"geojson": {"type": "FeatureCollection", "features": features}}

@app.get("/api/maxent-image/{species}")
def get_maxent_image(species: str):
    tif_path = os.path.join(DATA_DIR, "maxent_results", f"{species}.tif")
    png_path = os.path.join(DATA_DIR, "maxent_results", f"{species}.png")
    if not os.path.exists(tif_path):
        return {"error": "未找到 MaxEnt 结果文件", "imageUrl": "", "bounds": []}
    try:
        with rasterio.open(tif_path) as src:
            bounds = [[src.bounds.bottom, src.bounds.left], [src.bounds.top, src.bounds.right]]
            arr = src.read(1, masked=True).astype(np.float32)
            arr = np.ma.filled(arr, np.nan)
            vmin = np.nanmin(arr)
            vmax = np.nanmax(arr)
            if not (np.isfinite(vmin) and np.isfinite(vmax)) or vmin == vmax:
                norm = np.zeros_like(arr)
            else:
                norm = (arr - vmin) / (vmax - vmin)
            cmap = plt.get_cmap("YlOrRd")
            rgba = cmap(norm)
            rgba[..., 3] = np.where(np.isnan(arr), 0, 0.65)
            Path(os.path.dirname(png_path)).mkdir(parents=True, exist_ok=True)
            plt.imsave(png_path, rgba)
        return {
            "imageUrl": f"/static/maxent_results/{species}.png",
            "bounds": bounds
        }
    except Exception as e:
        print(f"生成MaxEnt图像失败: {e}")
        return {"error": str(e), "imageUrl": "", "bounds": []}

@app.get("/api/geocode")
def geocode(address: str):
    try:
        url = "https://nominatim.openstreetmap.org/search"
        params = {"q": address, "format": "json", "limit": 1}
        r = requests.get(url, params=params, headers={"User-Agent": "aquatic-species-platform"}, timeout=15)
        r.raise_for_status()
        arr = r.json()
        if not arr:
            raise HTTPException(status_code=404, detail="无法找到地址")
        first = arr[0]
        return {
            "lat": float(first["lat"]),
            "lon": float(first["lon"]),
            "display_name": first.get("display_name", "")
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"地理编码失败: {e}")

@app.get("/api/reverse-geocode")
def reverse_geocode(lat: float, lon: float):
    try:
        url = "https://nominatim.openstreetmap.org/reverse"
        params = {"lat": lat, "lon": lon, "format": "json"}
        r = requests.get(url, params=params, headers={"User-Agent": "aquatic-species-platform"}, timeout=15)
        r.raise_for_status()
        data = r.json()
        return {"address": data.get("display_name", "")}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"逆向地理编码失败: {e}")

# ========== 知识问答 API ==========
@app.post("/api/qa")
def qa_question(request: QuestionRequest):
    """知识图谱问答"""
    try:
        if not request.question or not request.question.strip():
            raise HTTPException(status_code=400, detail="问题不能为空")
        
        chain = get_chain()
        response = chain.invoke({"query": request.question})
        return {
            "answer": response.get('result', '无法获取回答'),
            "cypher": response.get('generated_cypher', '')
        }
    except Exception as e:
        print(f"QA Error: {e}")
        return {
            "answer": f"暂时无法回答，请稍后重试。(错误: {type(e).__name__})",
            "cypher": ""
        }

@app.get("/api/qa/suggestions/{species}")
def get_qa_suggestions(species: str):
    """获取针对该物种的建议问题"""
    suggestions = [
        f"介绍一下 {species}",
        f"{species} 的危害是什么？",
        f"如何防治 {species}？",
        f"{species} 属于什么分类？",
        f"{species} 的原产地在哪？"
    ]
    return {"suggestions": suggestions}

# ========== 数据上报 API ==========
@app.post("/api/record/location")
def record_location(record: LocationRecord):
    """上报新的物种位置记录"""
    try:
        # 初始化 CSV 文件
        if not os.path.exists(LOCATIONS_RECORD_FILE):
            Path(LOCATIONS_RECORD_FILE).parent.mkdir(parents=True, exist_ok=True)
            with open(LOCATIONS_RECORD_FILE, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow(['species', 'latitude', 'longitude', 'location_name', 'date', 'timestamp'])
        
        # 写入新记录
        with open(LOCATIONS_RECORD_FILE, 'a', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            writer.writerow([
                record.species,
                record.latitude,
                record.longitude,
                record.location_name,
                record.date or datetime.now().strftime("%Y-%m-%d"),
                datetime.now().isoformat()
            ])
        return {
            "status": "success", 
            "message": "记录已保存"
        }
    except ValueError as e:
        return {
            "status": "error",
            "message": f"数据验证失败: {str(e)}"
        }
    except Exception as e:
        print(f"Record Error: {e}")
        return {
            "status": "error",
            "message": f"保存失败: {str(e)}"
        }

@app.get("/api/records")
def get_all_records():
    """获取所有上报的记录"""
    try:
        if os.path.exists(LOCATIONS_RECORD_FILE):
            df = pd.read_csv(LOCATIONS_RECORD_FILE)
            return {"records": df.to_dict(orient='records')}
        return {"records": []}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/health")
def health_check():
    """健康检查"""
    return {"status": "ok"}
>>>>>>> 95badd0 (全部重写)
