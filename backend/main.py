import re

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from api.errors import register_exception_handlers
from api.router import api_router
from config import get_settings
from database import ensure_seed_data
from geo_data import load_china_geojson


def _wildcard_origin_to_regex(origin: str) -> str:
    """Convert wildcard origins (e.g. https://*.ngrok.io) to anchored regex."""
    escaped = re.escape(origin)
    return f"^{escaped.replace(r'\\*', '.*')}$"


def create_app() -> FastAPI:
    settings = get_settings()
    settings.data_dir.mkdir(parents=True, exist_ok=True)
    app = FastAPI(title="Aquatic Species Analysis API")

    register_exception_handlers(app)

    # 处理 CORS 配置：支持正则表达式模式和通配符
    cors_kwargs = {
        "allow_credentials": True,
        "allow_methods": ["*"],
        "allow_headers": ["*"],
    }
    
    # 检查是否有正则表达式或通配符模式
    allow_origins_list = settings.allow_origins if isinstance(settings.allow_origins, list) else [settings.allow_origins]
    regex_patterns = [origin for origin in allow_origins_list if origin.startswith("https://*.")]
    simple_origins = [origin for origin in allow_origins_list if not origin.startswith("https://*.")]
    
    if regex_patterns:
        # 转换 https://*.ngrok.io 为正则表达式
        regex_pattern = "|".join(_wildcard_origin_to_regex(pattern) for pattern in regex_patterns)
        cors_kwargs["allow_origin_regex"] = regex_pattern
    
    if simple_origins:
        cors_kwargs["allow_origins"] = simple_origins
    
    app.add_middleware(CORSMiddleware, **cors_kwargs)

    app.mount("/static", StaticFiles(directory=str(settings.data_dir)), name="static")
    app.include_router(api_router)

    @app.on_event("startup")
    async def _startup() -> None:
        settings.runtime_dir.mkdir(parents=True, exist_ok=True)
        load_china_geojson(force_reload=False)
        ensure_seed_data()

    @app.get("/")
    def read_root():
        return {"message": "后端服务已启动，可以开始查询水生外来入侵物种了。"}

    return app


app = create_app()
