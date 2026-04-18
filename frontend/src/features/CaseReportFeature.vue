<template>
  <div class="case-feature-wrap">
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
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'

import { getJson } from '@/api/client'
import ReportPanel from '@/shared/report/ReportPanel.vue'
import { useReportMap } from '@/shared/composables/useReportMap'

const activeTab = ref(2)
const speciesList = ref([])

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
.case-feature-wrap {
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 12px 34px rgba(15, 35, 52, 0.08);
}
</style>
