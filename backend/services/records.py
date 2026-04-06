"""Record-related business logic."""

from __future__ import annotations

from fastapi import HTTPException
from sqlalchemy.orm import Session

from geo_data import point_in_china
from repositories.records_repository import (
    create_location_record as repo_create_location_record,
    list_location_records as repo_list_location_records,
)


def create_location_record(
    db: Session,
    *,
    species: str,
    latitude: float,
    longitude: float,
    location_name: str,
    date: str | None = None,
) -> dict[str, str]:
    inside = point_in_china(longitude, latitude)
    if inside is None:
        raise HTTPException(
            status_code=503,
            detail="地理边界判定暂不可用（可能为 GeoJSON 无效或数据未就绪），请稍后重试。",
        )
    if not inside:
        raise HTTPException(status_code=400, detail="坐标必须位于中国境内。")

    repo_create_location_record(
        db,
        species=species,
        latitude=latitude,
        longitude=longitude,
        location_name=location_name,
        date=date,
    )
    return {"status": "success", "message": "记录已保存"}


def list_location_records(db: Session) -> dict[str, list[dict]]:
    return {"records": repo_list_location_records(db)}
