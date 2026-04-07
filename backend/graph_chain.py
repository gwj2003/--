import os
import re
from typing import Any, Optional

from langchain_community.graphs import Neo4jGraph
from langchain_community.chains.graph_qa.cypher import GraphCypherQAChain
from langchain_openai import ChatOpenAI
from langchain_core.prompts import PromptTemplate

from config import get_settings


def _normalize_cypher_query(query: Any) -> str:
    """Normalize LLM-generated Cypher text for safer execution."""
    if hasattr(query, "text"):
        query = getattr(query, "text")
    q = str(query or "").strip()
    q = re.sub(r"^```(?:cypher)?\s*", "", q, flags=re.IGNORECASE)
    q = re.sub(r"\s*```$", "", q)
    q = re.sub(r"^cypher\s+", "", q, flags=re.IGNORECASE)
    return q.strip()


def _strip_cypher_string_literals(cypher: str) -> str:
    s = re.sub(r"'(?:[^'\\]|\\.)*'", " ", cypher)
    s = re.sub(r'"(?:[^"\\]|\\.)*"', " ", s)
    s = re.sub(r"`(?:[^`\\]|\\.)*`", " ", s)
    return s


_WRITE_CYPHER = re.compile(
    r"(?<![.\w])("
    r"CREATE|MERGE|DELETE|DETACH|SET|REMOVE|FOREACH|LOAD\s+CSV|"
    r"GRANT|REVOKE|ALTER|"
    r"DROP\s+(CONSTRAINT|INDEX|DATABASE)|STOP\s+DATABASE"
    r")(?![\w])",
    re.IGNORECASE | re.DOTALL,
)

_CALL_CYPHER = re.compile(r"(?<![.\w])CALL(?![\w])", re.IGNORECASE)


MANUAL_STRUCTURED_SCHEMA = {
    "node_props": {
        "Species": [{"property": "name", "type": "STRING"}],
        "Taxonomy": [{"property": "name", "type": "STRING"}],
        "Location": [
            {"property": "name", "type": "STRING"},
            {"property": "lat", "type": "FLOAT"},
            {"property": "lng", "type": "FLOAT"},
        ],
        "Impact": [{"property": "name", "type": "STRING"}],
        "Control": [{"property": "name", "type": "STRING"}],
    },
    "relationships": [
        {"start": "Species", "type": "HAS_ALIAS", "end": "Species"},
        {"start": "Species", "type": "BELONGS_TO", "end": "Taxonomy"},
        {"start": "Species", "type": "NATIVE_TO", "end": "Location"},
        {"start": "Species", "type": "INVADES", "end": "Location"},
        {"start": "Species", "type": "CAUSES", "end": "Impact"},
        {"start": "Species", "type": "SUPPRESSED_BY", "end": "Control"},
    ],
    "metadata": {},
}


def assert_read_only_cypher(cypher: str) -> None:
    if not (cypher or "").strip():
        return
    body = _strip_cypher_string_literals(cypher)
    if _WRITE_CYPHER.search(body):
        raise ValueError("生成的 Cypher 含写操作或受限关键字，已拒绝执行")
    core = body.rstrip().rstrip(";").strip()
    if ";" in core:
        raise ValueError("拒绝执行包含多条语句的 Cypher")
    if get_settings().cypher_block_call and _CALL_CYPHER.search(body):
        raise ValueError("当前策略禁止 CALL 语句")


class ReadOnlyNeo4jGraph(Neo4jGraph):
    def query(self, query: str, params: Optional[dict] = None):
        normalized_query = _normalize_cypher_query(query)
        assert_read_only_cypher(normalized_query)
        try:
            return super().query(normalized_query, params or {})
        except Exception as exc:
            # Compatibility fallback for driver/library mismatch around Query objects.
            if "Query object is only supported for session.run" in str(exc):
                with self._driver.session(database=self._database) as session:  # type: ignore[attr-defined]
                    result = session.run(normalized_query, params or {})
                    return [record.data() for record in result]
            raise


_chain: Any = None
_neo4j_graph_instance: Optional[ReadOnlyNeo4jGraph] = None
_llm: Optional[ChatOpenAI] = None


def get_llm() -> ChatOpenAI:
    global _llm
    if _llm is None:
        s = get_settings()
        key = s.openai_api_key or os.getenv("OPENAI_API_KEY", "")
        os.environ["OPENAI_API_KEY"] = key
        os.environ["OPENAI_API_BASE"] = s.openai_api_base or os.getenv("OPENAI_API_BASE", "")
        _llm = ChatOpenAI(model=s.llm_model, temperature=0, timeout=120)
    return _llm


def get_neo4j_graph() -> Optional[ReadOnlyNeo4jGraph]:
    get_chain()
    return _neo4j_graph_instance


def invalidate_chain():
    global _chain, _neo4j_graph_instance, _llm
    _chain = None
    _neo4j_graph_instance = None
    _llm = None


def _build_chain():
    global _chain, _neo4j_graph_instance
    s = get_settings()
    graph = None
    try:
        graph = ReadOnlyNeo4jGraph(
            url=s.neo4j_uri,
            username=s.neo4j_username,
            password=s.neo4j_password,
            database=s.neo4j_database,
            timeout=s.neo4j_query_timeout,
            refresh_schema=False,
        )
        if s.neo4j_refresh_schema:
            try:
                graph.refresh_schema()
            except Exception as e:
                print(f"Neo4j refresh_schema 失败，使用手工 schema: {e}")
                graph.structured_schema = MANUAL_STRUCTURED_SCHEMA
        else:
            graph.structured_schema = MANUAL_STRUCTURED_SCHEMA
    except Exception as e:
        print(f"警告：Neo4j 连接失败 ({e})，使用离线模式")
        graph = None

    llm = get_llm()

    CYPHER_GENERATION_TEMPLATE = """
    任务：将用户问题转换为 Cypher 查询。
    Schema：{schema}
    说明：
    1. 物种名称在图中可能与平台列表不完全一致，对 Species.name 优先用 toLower(s.name) CONTAINS toLower('关键词') 或 CONTAINS 做模糊匹配，必要时 OR 多个别名。
    2. 仅使用 Schema 中的关系与标签；禁止 CREATE、MERGE、DELETE、SET、REMOVE、LOAD CSV 等写操作。
    3. 只输出单条只读查询（MATCH/OPTIONAL MATCH/RETURN/WITH/WHERE 等），不要分号连接多条。
    4. 只输出 Cypher，不要解释。
    用户问题：{question}
    Cypher："""

    CYPHER_PROMPT = PromptTemplate(
        input_variables=["schema", "question"], template=CYPHER_GENERATION_TEMPLATE
    )

    qa_prompt = PromptTemplate(
        input_variables=["context", "question"],
        template="""你是一个生物入侵领域的专家。基于以下数据库信息回答问题：\n{context}\n问题：{question}\n回答：""",
    )

    if graph:
        _neo4j_graph_instance = graph
        _chain = GraphCypherQAChain.from_llm(
            llm=llm,
            graph=graph,
            verbose=True,
            allow_dangerous_requests=True,
            validate_cypher=True,
            cypher_prompt=CYPHER_PROMPT,
            qa_prompt=qa_prompt,
        )
    else:
        _neo4j_graph_instance = None

        class SimpleChain:
            def __init__(self, llm_):
                self.llm = llm_

            def invoke(self, input_dict):
                question = input_dict.get("query", "")
                prompt = f"""你是一个水生入侵生物的专家。请回答以下问题：

问题：{question}

基于你的知识库，请提供一个详细的回答。"""
                result = self.llm.invoke(prompt)
                return {
                    "result": result.content if hasattr(result, "content") else str(result),
                    "generated_cypher": "",
                }

        _chain = SimpleChain(llm)

    return _chain


def get_chain(force_refresh: bool = False):
    global _chain
    if force_refresh:
        invalidate_chain()
    if _chain is None:
        _build_chain()
    return _chain


SIMPLE_TEMPLATE_CYPHER = """
MATCH (s:Species)
WHERE toLower(s.name) CONTAINS toLower($needle)
OPTIONAL MATCH (s)-[r]->(n)
RETURN s.name AS species, type(r) AS rel_type, labels(n) AS nlabels, coalesce(n.name, '') AS related
LIMIT 40
"""


def _extract_species_needle(question: str, gbif_names: list) -> Optional[str]:
    q = (question or "").strip()
    if len(q) > 200:
        return None
    if not re.search(r"(介绍|危害|防治|分类|原产地|是什么|哪种|如何|怎样|请问|查询|说说|讲讲)", q):
        return None
    names_sorted = sorted((n for n in gbif_names if n), key=len, reverse=True)
    for n in names_sorted:
        if n in q:
            return n
    return None


def try_simple_template_qa(question: str, gbif_names: list) -> Optional[dict]:
    """命中简单模板时：1 次参数化 Cypher + 1 次 LLM 总结，跳过 Cypher 生成 LLM。"""
    if not get_settings().qa_use_simple_template:
        return None
    needle = _extract_species_needle(question, gbif_names)
    if not needle:
        return None
    g = get_neo4j_graph()
    if g is None:
        return None
    try:
        rows = g.query(SIMPLE_TEMPLATE_CYPHER.strip(), params={"needle": needle})
    except Exception as e:
        print(f"simple template Cypher 失败: {e}")
        return None
    if not rows:
        return None
    llm = get_llm()
    ctx = str(rows)[:8000]
    prompt = (
        "你是水生入侵生物专家。根据下列图谱查询结果回答用户问题；若信息不足请说明。\n"
        f"图谱数据：\n{ctx}\n\n用户问题：{question}\n回答："
    )
    result = llm.invoke(prompt)
    text = result.content if hasattr(result, "content") else str(result)
    return {
        "result": text,
        "generated_cypher": SIMPLE_TEMPLATE_CYPHER.strip(),
        "from_template": True,
    }


def invoke_qa(question: str, gbif_names: list) -> dict:
    t = try_simple_template_qa(question, gbif_names)
    if t:
        return t
    chain = get_chain()
    return chain.invoke({"query": question})
