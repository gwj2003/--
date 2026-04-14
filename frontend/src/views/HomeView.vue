<template>
  <div class="home-container">
    <header class="app-header">
      <h1>水生入侵动物综合平台</h1>
      <p>分布识别、知识问答与数据协作</p>
    </header>

    <main class="tabs-shell">
      <nav class="tabs-header">
        <button
          v-for="(tab, index) in tabs"
          :key="tab.key"
          :class="['tab-btn', { active: activeTab === index }]"
          @click="activeTab = index"
        >
          {{ tab.label }}
        </button>
      </nav>

      <section v-show="activeTab === 0" class="tab-content">
        <SpeciesMapPanel
          :species-list="speciesList"
          v-model:selected-species="selectedSpecies"
          v-model:selected-basemap="selectedBasemap"
          v-model:selected-layer="selectedLayer"
          :current-locations="currentLocations"
          :change-basemap="changeBasemap"
          :change-layer="changeLayer"
          :on-species-change="onSpeciesChange"
        />
      </section>

      <section v-show="activeTab === 1" class="tab-content">
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
      </section>

      <section v-show="activeTab === 2" class="tab-content">
        <ReportPanel
          :species-list="speciesList"
          :report-form="reportForm"
          :report-message="reportMessage"
          :report-message-type="reportMessageType"
          :report-left-view="reportLeftView"
          v-model:record-filter-species="recordFilterSpecies"
          v-model:record-filter-date="recordFilterDate"
          v-model:record-sort-field="recordSortField"
          v-model:record-sort-order="recordSortOrder"
          v-model:report-basemap="reportBasemap"
          :can-save="canSave"
          :report-left-toggle-label="reportLeftToggleLabel"
          :filtered-sorted-records="filteredSortedRecords"
          :change-report-basemap="changeReportBasemap"
          :forward-geocode="forwardGeocode"
          :reverse-geocode="reverseGeocode"
          :focus-record-on-map="focusRecordOnMap"
          :save-location="saveLocation"
          :reset-form="resetForm"
          :reset-record-filters="resetRecordFilters"
          :toggle-report-left-view="toggleReportLeftView"
        />
      </section>
    </main>
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import 'leaflet/dist/leaflet.css'

import { getJson } from '@/api/client'
import ChatPanel from '@/components/chat/ChatPanel.vue'
import ReportPanel from '@/components/report/ReportPanel.vue'
import SpeciesMapPanel from '@/components/species/SpeciesMapPanel.vue'
import { useChatQa } from '@/composables/useChatQa'
import { useReportMap } from '@/composables/useReportMap'
import { useSpeciesMap } from '@/composables/useSpeciesMap'


const activeTab = ref(0)
const speciesList = ref([])

const tabs = [
  { key: 'species', label: '分布识别分析' },
  { key: 'chat', label: '智能知识问答' },
  { key: 'report', label: '数据上报与更新' },
]

const {
  selectedSpecies,
  selectedBasemap,
  selectedLayer,
  currentLocations,
  changeBasemap,
  changeLayer,
  onSpeciesChange,
} = useSpeciesMap(activeTab)

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

const {
  reportForm,
  reportMessage,
  reportMessageType,
  reportLeftView,
  recordFilterSpecies,
  recordFilterDate,
  recordSortField,
  recordSortOrder,
  reportBasemap,
  canSave,
  reportLeftToggleLabel,
  filteredSortedRecords,
  loadAllRecords,
  changeReportBasemap,
  forwardGeocode,
  reverseGeocode,
  focusRecordOnMap,
  saveLocation,
  resetForm,
  resetRecordFilters,
  toggleReportLeftView,
} = useReportMap(activeTab)

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
  await loadAllRecords()
})
</script>

<style scoped>
:global(html),
:global(body),
:global(#app) {
  width: 100%;
  min-height: 100%;
}

:global(body) {
  overflow-y: scroll;
  scrollbar-gutter: stable both-edges;
}

.home-container {
  min-height: 100vh;
  background: #f4f7fb;
  overflow-x: hidden;
}

.app-header {
  padding: 44px 24px 34px;
  color: #fff;
  text-align: center;
  background: linear-gradient(135deg, #124e78 0%, #1f7a8c 50%, #4ba3c3 100%);
}

.app-header h1 {
  margin: 0;
  font-size: clamp(2rem, 4vw, 2.8rem);
}

.app-header p {
  margin: 12px 0 0;
  opacity: 0.92;
  font-size: 1.05rem;
}

.tabs-shell {
  max-width: 1440px;
  margin: 0 auto;
  padding: 22px;
}

.tabs-header {
  display: flex;
  gap: 10px;
  margin-bottom: 16px;
}

.tab-btn {
  padding: 12px 18px;
  border: 0;
  border-radius: 12px;
  background: #e5edf6;
  color: #425466;
  cursor: pointer;
  transition: 0.2s ease;
}

.tab-btn.active {
  background: #124e78;
  color: #fff;
}

.tab-content {
  overflow: hidden;
  border-radius: 18px;
  background: #fff;
  box-shadow: 0 18px 45px rgba(15, 35, 52, 0.08);
}

@media (max-width: 760px) {
  .tabs-header {
    flex-direction: column;
  }
}
</style>
