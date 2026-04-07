from __future__ import annotations

import os

from fastapi import HTTPException
from sqlalchemy.orm import Session

from config import get_settings
from graph_chain import invoke_qa
from qa_cache import qa_cache
from repositories.species_repository import list_species_names


def _is_llm_auth_or_connection_error(exc: Exception) -> bool:
    name = type(exc).__name__.lower()
    msg = str(exc).lower()
    keywords = [
        "authenticationerror",
        "apiconnectionerror",
        "api connection",
        "unauthorized",
        "401",
        "403",
        "timed out",
        "timeout",
        "connection",
        "dns",
    ]
    return any(k in name or k in msg for k in keywords)


def ask_question(question: str, db: Session) -> dict:
    value = (question or "").strip()
    if not value:
        raise HTTPException(status_code=400, detail="问题不能为空")

    settings = get_settings()
    if not (settings.openai_api_key or os.getenv("OPENAI_API_KEY", "")).strip():
        return {
            "answer": "问答服务尚未配置模型密钥。请在 backend/.env 中设置 OPENAI_API_KEY 后重启后端服务。",
            "cypher": "",
            "from_template": False,
        }

    cached = qa_cache.get(value)
    if cached:
        return cached

    try:
        response = invoke_qa(value, list_species_names(db))
        payload = {
            "answer": response.get("result", "无法获取回答"),
            "cypher": response.get("generated_cypher", ""),
            "from_template": bool(response.get("from_template", False)),
        }
        qa_cache.set(value, payload)
        return payload
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        print(f"QA Error: {exc}")
        if _is_llm_auth_or_connection_error(exc):
            # Degrade gracefully instead of surfacing raw provider errors to users.
            return {
                "answer": "当前问答服务连接异常（模型接口鉴权或网络不稳定）。请稍后重试；你也可以先使用分布分析和数据上报功能。",
                "cypher": "",
                "from_template": False,
            }
        raise HTTPException(status_code=503, detail=f"暂时无法回答: {type(exc).__name__}") from exc


def get_suggestions(species: str) -> dict[str, list[str]]:
    return {
        "suggestions": [
            f"介绍一下 {species}",
            f"{species} 的危害是什么？",
            f"如何防治 {species}？",
            f"{species} 属于什么分类？",
            f"{species} 的原产地在哪？",
        ]
    }
