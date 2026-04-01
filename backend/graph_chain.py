import os
from langchain_community.graphs import Neo4jGraph
from langchain_community.chains.graph_qa.cypher import GraphCypherQAChain
from langchain_openai import ChatOpenAI
from langchain_core.prompts import PromptTemplate
from functools import lru_cache

@lru_cache(maxsize=1)
def get_chain():
    os.environ["OPENAI_API_KEY"] = os.getenv("OPENAI_API_KEY", "sk-123456789abcdef1234567890abcdef123")
    os.environ["OPENAI_API_BASE"] = os.getenv("OPENAI_API_BASE", "https://api.deepseek.com")

    graph = Neo4jGraph(
        url="bolt://localhost:7687",
        username="neo4j",
        password=os.getenv("NEO4J_PASSWORD", "12345sss"),
        refresh_schema=False
    )
    graph.structured_schema = {
        "node_props": {
            "Species": [{"property": "name", "type": "STRING"}],
            "Taxonomy": [{"property": "name", "type": "STRING"}],
            "Location": [{"property": "name", "type": "STRING"}, {"property": "lat", "type": "FLOAT"}, {"property": "lng", "type": "FLOAT"}],
            "Impact": [{"property": "name", "type": "STRING"}],
            "Control": [{"property": "name", "type": "STRING"}]
        },
        "relationships": [
            {"start": "Species", "type": "HAS_ALIAS", "end": "Species"},
            {"start": "Species", "type": "BELONGS_TO", "end": "Taxonomy"},
            {"start": "Species", "type": "NATIVE_TO", "end": "Location"},
            {"start": "Species", "type": "INVADES", "end": "Location"},
            {"start": "Species", "type": "CAUSES", "end": "Impact"},
            {"start": "Species", "type": "SUPPRESSED_BY", "end": "Control"}
        ],
        "metadata": {}
    }

    llm = ChatOpenAI(model="deepseek-chat", temperature=0)

    CYPHER_GENERATION_TEMPLATE = """
    任务：将用户问题转换为 Cypher 查询。
    Schema：{schema}
    说明：
    1. 模糊匹配使用 CONTAINS。
    2. 仅使用 Schema 中的关系。
    3. 只输出 Cypher。
    用户问题：{question}
    Cypher："""

    CYPHER_PROMPT = PromptTemplate(input_variables=["schema", "question"], template=CYPHER_GENERATION_TEMPLATE)

    qa_prompt = PromptTemplate(
        input_variables=["context", "question"],
        template="""你是一个生物入侵领域的专家。基于以下数据库信息回答问题：\n{context}\n问题：{question}\n回答："""
    )

    chain = GraphCypherQAChain.from_llm(
        llm=llm,
        graph=graph,
        verbose=True,
        allow_dangerous_requests=True,
        cypher_prompt=CYPHER_PROMPT,
        qa_prompt=qa_prompt
    )
    return chain