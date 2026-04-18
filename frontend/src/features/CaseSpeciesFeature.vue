<template>
  <div class="case-feature-wrap">
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
  </div>
</template>

<script setup>
import { onMounted, ref } from 'vue'
import 'leaflet/dist/leaflet.css'

import { getJson } from '@/api/client'
import SpeciesMapPanel from '@/shared/species/SpeciesMapPanel.vue'
import { useSpeciesMap } from '@/shared/composables/useSpeciesMap'

const activeTab = ref(0)
const speciesList = ref([])

const {
  selectedSpecies,
  selectedBasemap,
  selectedLayer,
  currentLocations,
  changeBasemap,
  changeLayer,
  onSpeciesChange,
} = useSpeciesMap(activeTab)

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
})
</script>

<style scoped>
.case-feature-wrap {
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 12px 34px rgba(15, 35, 52, 0.08);
}
</style>
