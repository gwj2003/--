"""中国省界 GeoJSON：本地优先、网络回写磁盘；衍生几何随版本失效。"""
from __future__ import annotations

import json
import threading
from typing import Any, Optional

import geopandas as gpd
import requests
from shapely.errors import GEOSException
from shapely.geometry import Point
from shapely.ops import unary_union

from config import get_settings

_lock = threading.RLock()
_geojson: Optional[dict] = None
_source: str = "none"  # local | network | none
_version: int = 0
_gdf_cache: Optional[gpd.GeoDataFrame] = None
_land_union_cache: Any = None
_LAND_MISS = object()


def _safe_make_valid(geom):
    """Best-effort geometry repair to avoid GEOS topology errors."""
    if geom is None:
        return None
    try:
        if getattr(geom, "is_valid", True):
            return geom
    except Exception:
        return geom

    # Prefer make_valid when available (Shapely 2), fallback to buffer(0).
    try:
        from shapely.validation import make_valid  # type: ignore

        fixed = make_valid(geom)
        if fixed is not None and not getattr(fixed, "is_empty", False):
            return fixed
    except Exception:
        pass

    try:
        fixed = geom.buffer(0)
        if fixed is not None and not getattr(fixed, "is_empty", False):
            return fixed
    except Exception:
        pass
    return geom


def _invalidate_derived():
    global _gdf_cache, _land_union_cache
    _gdf_cache = None
    _land_union_cache = None


def load_china_geojson(force_reload: bool = False) -> Optional[dict]:
    """加载 GeoJSON；优先本地文件，失败再请求 URL，成功则写入本地。"""
    global _geojson, _source, _version
    s = get_settings()
    with _lock:
        if not force_reload and _geojson is not None:
            return _geojson

        local_path = s.china_geojson_local
        local_path.parent.mkdir(parents=True, exist_ok=True)

        if local_path.is_file():
            try:
                with open(local_path, "r", encoding="utf-8") as f:
                    _geojson = json.load(f)
                _source = "local"
                _version += 1
                _invalidate_derived()
                return _geojson
            except Exception as e:
                print(f"读取本地省界 GeoJSON 失败: {e}")

        try:
            r = requests.get(s.china_geojson_url, timeout=20)
            r.raise_for_status()
            _geojson = r.json()
            _source = "network"
            _version += 1
            _invalidate_derived()
            try:
                with open(local_path, "w", encoding="utf-8") as f:
                    json.dump(_geojson, f, ensure_ascii=False)
            except Exception as e:
                print(f"省界 GeoJSON 写入本地失败（下次仍将依赖网络）: {e}")
            return _geojson
        except Exception as e:
            print(f"加载中国省界 GeoJSON 失败: {e}")
            _geojson = None
            _source = "none"
            return None


def get_china_geojson() -> Optional[dict]:
    return load_china_geojson(force_reload=False)


def invalidate_geo_cache():
    """清空内存中的省界与衍生几何（下次请求重新读或拉网）。"""
    global _geojson, _source, _version
    with _lock:
        _geojson = None
        _source = "none"
        _version += 1
        _invalidate_derived()


def geo_version() -> int:
    return _version


def geo_source() -> str:
    return _source


def get_china_gdf() -> Optional[gpd.GeoDataFrame]:
    global _gdf_cache
    gj = get_china_geojson()
    if not gj or "features" not in gj:
        return None
    with _lock:
        if _gdf_cache is None:
            _gdf_cache = gpd.GeoDataFrame.from_features(gj["features"])
            _gdf_cache.set_crs(epsg=4326, inplace=True)
            # Repair invalid geometries up front to reduce topology failures.
            if "geometry" in _gdf_cache:
                _gdf_cache = _gdf_cache[_gdf_cache.geometry.notnull()].copy()
                _gdf_cache["geometry"] = _gdf_cache["geometry"].map(_safe_make_valid)
                _gdf_cache = _gdf_cache[_gdf_cache.geometry.notnull()].copy()
                _gdf_cache = _gdf_cache[~_gdf_cache.geometry.is_empty].copy()
        return _gdf_cache


def get_china_land_union():
    global _land_union_cache
    with _lock:
        if _land_union_cache is _LAND_MISS:
            return None
        if _land_union_cache is not None:
            return _land_union_cache
    gdf = get_china_gdf()
    if gdf is None or gdf.empty:
        with _lock:
            _land_union_cache = _LAND_MISS
        return None
    try:
        u = gdf.geometry.union_all()
    except AttributeError:
        u = unary_union(gdf.geometry.values)
    u = _safe_make_valid(u)
    with _lock:
        _land_union_cache = u
    return u


def point_in_china(lon: float, lat: float) -> Optional[bool]:
    poly = get_china_land_union()
    if poly is None:
        return None
    point = Point(lon, lat)
    try:
        return bool(poly.covers(point))
    except GEOSException:
        # Retry once with repaired union geometry when GEOS throws topology errors.
        repaired = _safe_make_valid(poly)
        try:
            return bool(repaired.covers(point))
        except Exception:
            return None
