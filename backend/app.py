import streamlit as st
import os
from langchain_community.graphs import Neo4jGraph
# 【关键修改】修正了引入路径
from langchain_community.chains.graph_qa.cypher import GraphCypherQAChain
from langchain_openai import ChatOpenAI
from langchain_core.prompts import PromptTemplate

# ================= 配置 =================
st.set_page_config(page_title="水生入侵生物知识问答", page_icon="🦀", layout="wide")

st.title("🌊 水生入侵生物知识图谱问答系统")
st.markdown("基于 **Neo4j + DeepSeek + LangChain** 构建")

# 侧边栏配置
with st.sidebar:
    st.header("⚙️ 系统配置")
    # 默认值填好，方便你直接点连接
    openai_key = st.text_input("DeepSeek API Key", value="sk-123456789abcdef1234567890abcdef123", type="password")
    neo4j_pwd = st.text_input("Neo4j 密码", value="12345sss", type="password")

    # 增加一个按钮来手动触发连接
    connect_btn = st.button("🔄 连接/刷新图数据库")


# ================= 核心逻辑 =================

@st.cache_resource
def get_chain(api_key, db_password):
    os.environ["OPENAI_API_KEY"] = api_key
    os.environ["OPENAI_API_BASE"] = "https://api.deepseek.com"

    # 连接数据库
    graph = Neo4jGraph(
        url="bolt://localhost:7687",
        username="neo4j",
        password=db_password,
        refresh_schema=False
    )

    # 【关键】手动注入 Schema (必须和 api.py 一致)
    graph.structured_schema = {
        "node_props": {
            "Species": [{"property": "name", "type": "STRING"}],
            "Taxonomy": [{"property": "name", "type": "STRING"}],
            "Location": [{"property": "name", "type": "STRING"}],
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

    # 中文提示词 (和 api.py 保持一致)
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


# ================= 界面交互 =================

if "messages" not in st.session_state:
    st.session_state.messages = [{"role": "assistant",
                                  "content": "你好！我是入侵生物科普助手。你可以问我：\n- 福寿螺有什么危害？\n- 怎么防治鳄雀鳝？"}]

# 显示历史消息
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.write(msg["content"])

# 处理用户输入
if prompt := st.chat_input("请输入你的问题..."):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.write(prompt)

    with st.chat_message("assistant"):
        with st.spinner("🔍 正在查询知识图谱..."):
            try:
                # 获取 Chain
                chain = get_chain(openai_key, neo4j_pwd)

                # 调用
                response = chain.invoke({"query": prompt})
                answer = response['result']

                st.write(answer)

                # 侧边栏显示 Cypher 语句，增加科技感
                with st.sidebar:
                    st.success("✅ 查询成功")
                    st.code(response.get('generated_cypher'), language="cypher")

                st.session_state.messages.append({"role": "assistant", "content": answer})

            except Exception as e:
                st.error(f"出错啦: {e}")