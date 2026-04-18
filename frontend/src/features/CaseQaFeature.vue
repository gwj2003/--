<template>
  <div class="case-feature-wrap">
    <ChatPanel
      :species-list="speciesList"
      :chat-messages="chatMessages"
      :is-loading="isLoading"
      v-model:user-input="userInput"
      :chat-species="chatSpecies"
      :random-questions="randomQuestions"
      :render-markdown="renderMarkdown"
      :select-chat-species="selectChatSpecies"
      :send-message="sendMessage"
      :send-preset-question="sendPresetQuestion"
      :clear-chat="clearChat"
    />
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'

import { getJson } from '@/api/client'
import ChatPanel from '@/shared/chat/ChatPanel.vue'
import { useChatQa } from '@/shared/composables/useChatQa'

const speciesList = ref([])

const {
  chatMessages,
  isLoading,
  userInput,
  chatSpecies,
  randomQuestions,
  renderMarkdown,
  selectChatSpecies,
  sendMessage,
  sendPresetQuestion,
  clearChat,
} = useChatQa()

const loadSpeciesList = async () => {
  try {
    const data = await getJson('/species')
    speciesList.value = data.species || []
  } catch (error) {
    console.error('加载物种列表失败:', error)
    speciesList.value = []
  }
}

onMounted(async () => {
  await loadSpeciesList()
  if (speciesList.value.length > 0) {
    await selectChatSpecies(speciesList.value[0])
  }
})
</script>

<style scoped>
.case-feature-wrap {
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 12px 34px rgba(15, 35, 52, 0.08);
}
</style>
