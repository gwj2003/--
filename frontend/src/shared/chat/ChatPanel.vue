<template>
  <div class="qa-container">
    <section class="chat-wrapper">
      <div class="chat-header">
        <h3>智能知识问答</h3>
        <div class="header-actions">
          <button @click="showRawMarkdown = !showRawMarkdown" class="clear-btn">
            {{ showRawMarkdown ? '查看渲染' : '查看原文' }}
          </button>
          <button @click="clearChat" class="clear-btn">清空对话</button>
        </div>
      </div>

      <div class="messages-container">
        <div v-for="message in chatMessages" :key="message.id" :class="['message', message.role]">
          <div class="message-content">
            <span class="role-label">{{ message.role === 'user' ? '你' : '助手' }}：</span>
            <template v-if="message.role === 'assistant'">
              <pre v-if="showRawMarkdown" class="message-text raw-text">{{ message.content }}</pre>
              <div v-else class="message-text markdown-body" v-html="renderMarkdown(message.content)"></div>
            </template>
            <span v-else class="message-text">{{ message.content }}</span>
          </div>
        </div>

        <div v-if="isLoading" class="message assistant">
          <div class="message-content">
            <span class="role-label">助手：</span>
            <span class="loading">思考中...</span>
          </div>
        </div>
      </div>

      <div class="input-area">
        <div v-if="chatSpecies && randomQuestions.length > 0" class="suggestions">
          <span class="suggest-label">关于 <strong>{{ chatSpecies }}</strong>，可以试试：</span>
          <div class="suggestion-buttons">
            <button
              v-for="(question, index) in randomQuestions"
              :key="index"
              :disabled="isLoading"
              class="sugg-btn"
              @click="sendPresetQuestion(question)"
            >
              {{ question }}
            </button>
          </div>
        </div>

        <div class="input-group">
          <input
            v-model="userInputModel"
            class="qa-input"
            placeholder="输入你的问题..."
            @keyup.enter="sendMessage"
          />
          <button @click="sendMessage" :disabled="!userInput.trim() || isLoading" class="send-btn">
            {{ isLoading ? '思考中...' : '发送' }}
          </button>
        </div>
      </div>
    </section>

    <aside class="species-panel">
      <h3>快速选择物种</h3>
      <div class="species-buttons">
        <button
          v-for="species in speciesList"
          :key="species"
          :class="['species-btn', { active: chatSpecies === species }]"
          @click="selectChatSpecies(species)"
        >
          {{ species }}
        </button>
      </div>
    </aside>
  </div>
</template>

<script setup>
import { computed, ref } from 'vue'

const props = defineProps({
  speciesList: { type: Array, required: true },
  chatMessages: { type: Array, required: true },
  isLoading: { type: Boolean, required: true },
  userInput: { type: String, required: true },
  chatSpecies: { type: String, required: true },
  randomQuestions: { type: Array, required: true },
  renderMarkdown: { type: Function, required: true },
  selectChatSpecies: { type: Function, required: true },
  sendMessage: { type: Function, required: true },
  sendPresetQuestion: { type: Function, required: true },
  clearChat: { type: Function, required: true },
})

const emit = defineEmits(['update:userInput'])

const userInputModel = computed({
  get: () => props.userInput,
  set: (value) => emit('update:userInput', value),
})

const showRawMarkdown = ref(false)
</script>

<style scoped>
.qa-container {
  display: grid;
  grid-template-columns: minmax(0, 1fr) 280px;
  min-height: 680px;
}

.chat-wrapper {
  display: grid;
  grid-template-rows: auto minmax(0, 1fr) auto;
  min-height: 680px;
}

.chat-header,
.species-panel {
  padding: 22px 24px;
}

.chat-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid #edf2f7;
}

.header-actions {
  display: flex;
  gap: 8px;
}

.messages-container {
  padding: 20px 24px;
  overflow: auto;
  overflow-x: hidden;
  background: #fbfdff;
}

.message {
  margin-bottom: 14px;
}

.message-content {
  max-width: 90%;
  padding: 12px 14px;
  border-radius: 14px;
  background: #eef5fb;
  line-height: 1.65;
  word-wrap: break-word;
  word-break: break-word;
  overflow-wrap: anywhere;
  overflow-x: hidden;
}

.message.user .message-content {
  margin-left: auto;
  background: #d9ecff;
}

.message-text {
  display: block;
  word-wrap: break-word;
  word-break: break-word;
  overflow-wrap: anywhere;
}

.raw-text {
  margin: 0;
  padding: 0;
  white-space: pre-wrap;
  font-family: 'Cascadia Code', 'Consolas', monospace;
  font-size: 0.92rem;
  line-height: 1.6;
}

.role-label {
  font-weight: 700;
  display: none;
}

.input-area {
  padding: 18px 24px 24px;
  border-top: 1px solid #edf2f7;
  background: #fff;
}

.suggestions {
  margin-bottom: 14px;
}

.suggestion-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 10px;
}

.sugg-btn,
.species-btn,
.clear-btn,
.send-btn {
  border: 0;
  border-radius: 10px;
  cursor: pointer;
}

.sugg-btn,
.species-btn,
.clear-btn {
  padding: 8px 12px;
  background: #eef4fa;
}

.input-group {
  display: flex;
  gap: 10px;
}

.qa-input {
  flex: 1;
  padding: 12px 14px;
  border: 1px solid #cbd8e6;
  border-radius: 12px;
}

.send-btn {
  min-width: 110px;
  padding: 12px 16px;
  background: #155eef;
  color: #fff;
}

.species-panel {
  border-left: 1px solid #edf2f7;
  background: linear-gradient(180deg, #f8fbff 0%, #eef5fb 100%);
}

.species-panel h3 {
  margin: 0 0 16px;
}

.species-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 10px;
}

.species-btn.active {
  background: #155eef;
  color: #fff;
}

.markdown-body {
  --md-indent-1: 1.36em;
  --md-indent-2: 1.18em;
  --md-indent-3: 1.04em;
  font-size: 0.95rem;
  line-height: 1.76;
  color: #1f2937;
  font-family: 'Segoe UI', 'PingFang SC', 'Noto Sans SC', sans-serif;
  letter-spacing: 0.01em;
  padding-left: 0;
  max-width: 100%;
}

.markdown-body > :first-child {
  margin-top: 0;
}

.markdown-body > :last-child {
  margin-bottom: 0;
}

.markdown-body h1,
.markdown-body h2,
.markdown-body h3,
.markdown-body h4,
.markdown-body h5,
.markdown-body h6 {
  margin-top: 1.04em;
  margin-bottom: 0.5em;
  font-size: 1.02em;
  font-weight: 700;
  line-height: 1.38;
  color: #1e3a5f;
  background: #f3f6fb;
  border: 1px solid #d9e3f2;
  border-left: 4px solid #8ea5ce;
  border-radius: 10px;
  padding: 6px 10px;
}

.markdown-body p {
  margin: 0.66em 0;
}

.markdown-body :deep(ul),
.markdown-body :deep(ol) {
  margin: 0.62em 0 0.7em;
  padding-left: var(--md-indent-1);
  margin-left: 0.18em;
  list-style-position: outside;
}

.markdown-body :deep(ul) {
  list-style-type: disc;
}

.markdown-body :deep(ol) {
  list-style-type: decimal;
}

.markdown-body :deep(li) {
  margin: 0.3em 0;
  line-height: 1.64;
  padding-left: 0.12em;
}

.markdown-body :deep(li > p) {
  margin: 0.24em 0 0.42em;
}

.markdown-body :deep(li > ul),
.markdown-body :deep(li > ol) {
  margin-top: 0.26em;
  margin-bottom: 0.18em;
}

.markdown-body :deep(ul li::marker),
.markdown-body :deep(ol li::marker) {
  color: #4b5563;
  font-size: 0.96em;
  font-weight: 600;
}

.markdown-body :deep(ol li::marker) {
  font-variant-numeric: tabular-nums;
}

.markdown-body :deep(ul ul),
.markdown-body :deep(ol ul),
.markdown-body :deep(ul ol),
.markdown-body :deep(ol ol) {
  margin: 0.26em 0;
  padding-left: var(--md-indent-2);
  font-size: 0.96em;
  list-style-position: outside;
}

.markdown-body :deep(ul ul),
.markdown-body :deep(ol ul) {
  list-style-type: circle;
}

.markdown-body :deep(ul ol),
.markdown-body :deep(ol ol) {
  list-style-type: decimal;
}

.markdown-body :deep(ul ul ul),
.markdown-body :deep(ol ul ul),
.markdown-body :deep(ul ol ul),
.markdown-body :deep(ol ol ul),
.markdown-body :deep(ul ul ol),
.markdown-body :deep(ol ul ol),
.markdown-body :deep(ul ol ol),
.markdown-body :deep(ol ol ol) {
  padding-left: var(--md-indent-3);
  font-size: 0.94em;
  list-style-position: outside;
}

.markdown-body :deep(ul ul ul),
.markdown-body :deep(ol ul ul),
.markdown-body :deep(ul ol ul),
.markdown-body :deep(ol ol ul) {
  list-style-type: square;
}

.markdown-body :deep(ul ul ol),
.markdown-body :deep(ol ul ol),
.markdown-body :deep(ul ol ol),
.markdown-body :deep(ol ol ol) {
  list-style-type: lower-alpha;
}

.markdown-body :deep(ul ul li::marker),
.markdown-body :deep(ol ul li::marker),
.markdown-body :deep(ul ol li::marker),
.markdown-body :deep(ol ol li::marker) {
  color: #99a4b3;
  font-size: 0.9em;
  font-weight: 500;
}

.markdown-body code {
  background: #f3f4f6;
  border-radius: 6px;
  padding: 0.16em 0.44em;
  font-family: 'Cascadia Code', 'Consolas', monospace;
  color: #b42318;
  font-size: 0.88em;
  border: 1px solid #e5e7eb;
}

.markdown-body pre {
  background: #0f172a;
  border-radius: 10px;
  padding: 12px 14px;
  overflow-x: auto;
  margin: 0.75em 0;
  border: 1px solid #111827;
  max-width: 100%;
}

.markdown-body pre code {
  background: none;
  padding: 0;
  color: #e5e7eb;
  border: none;
  font-size: 0.87em;
  line-height: 1.6;
  white-space: pre;
}

.markdown-body blockquote {
  border-left: 3px solid #94a3b8;
  margin: 0.75em 0;
  color: #475467;
  background: #f8fafc;
  padding: 10px 12px;
  border-radius: 8px;
}

.markdown-body strong {
  font-weight: 700;
  color: #101828;
}

.markdown-body em {
  font-style: italic;
  color: #475467;
}

.markdown-body hr {
  border: none;
  border-top: 1px solid #e7edf5;
  margin: 1.1em 0 0.95em;
}

.markdown-body table {
  border-collapse: separate;
  border-spacing: 0;
  width: 100%;
  margin: 0.75em 0;
  border: 1px solid #e5e7eb;
  border-radius: 10px;
  overflow: hidden;
  display: block;
  overflow-x: auto;
  max-width: 100%;
}

.markdown-body th,
.markdown-body td {
  border-bottom: 1px solid #edf1f5;
  padding: 9px 11px;
  text-align: left;
  word-break: break-word;
  overflow-wrap: anywhere;
}

.markdown-body th {
  background: #f8fafc;
  color: #1f2937;
  font-weight: 700;
}

.markdown-body tr:last-child td {
  border-bottom: none;
}

.markdown-body tr:hover {
  background: #f8fafc;
}

@media (max-width: 980px) {
  .qa-container {
    grid-template-columns: 1fr;
  }

  .species-panel {
    border-left: 0;
    border-top: 1px solid #edf2f7;
  }
}
</style>
