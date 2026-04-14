<template>
  <div class="report-container">
    <section class="report-form-card">
      <div class="panel-header">
        <div>
          <h3>{{ reportLeftView === 'form' ? '新增物种分布记录' : '已收集的记录' }}</h3>
          <p>支持地图选点与表单录入，保存后会同步刷新记录列表。</p>
        </div>
      </div>

      <div v-if="reportLeftView === 'form'" class="form-area">
        <label class="field-label">物种名称</label>
        <select v-model="reportForm.species" class="form-input">
          <option value="">-- 选择物种 --</option>
          <option v-for="species in speciesList" :key="species" :value="species">{{ species }}</option>
        </select>

        <div class="button-row">
          <button @click="forwardGeocode" class="small-btn">详细地名转经纬</button>
          <button @click="reverseGeocode" class="small-btn">经纬转详细地名</button>
        </div>

        <label class="field-label">详细地名</label>
        <input v-model="reportForm.location_name" class="form-input" placeholder="例：江苏省南京市玄武区 XXX" />

        <div class="coords-row">
          <div>
            <label class="field-label">经度</label>
            <input v-model.number="reportForm.longitude" type="number" class="form-input" step="0.000001" min="-180" max="180" />
          </div>
          <div>
            <label class="field-label">纬度</label>
            <input v-model.number="reportForm.latitude" type="number" class="form-input" step="0.000001" min="-90" max="90" />
          </div>
        </div>

        <label class="field-label">发现日期</label>
        <input v-model="reportForm.date" type="date" class="form-input" />

        <div class="button-row">
          <button @click="saveLocation" class="save-btn" :disabled="!canSave">保存记录</button>
          <button @click="resetForm" class="small-btn">清空表单</button>
        </div>

        <div class="message-slot">
          <div v-if="reportMessage" :class="['message-box', reportMessageType]">{{ reportMessage }}</div>
          <div v-else class="message-placeholder" aria-hidden="true"></div>
        </div>
      </div>

      <div v-else class="records-area">
        <div class="toolbar">
          <select v-model="recordFilterSpeciesModel" class="form-input toolbar-species">
            <option value="">全部物种</option>
            <option v-for="species in speciesList" :key="species" :value="species">{{ species }}</option>
          </select>
          <input v-model="recordFilterDateModel" type="date" class="form-input date-input toolbar-date" />
          <select v-model="recordSortFieldModel" class="form-input toolbar-sort-field">
            <option value="date">按日期</option>
            <option value="species">按物种</option>
            <option value="location_name">按地点</option>
          </select>
          <select v-model="recordSortOrderModel" class="form-input toolbar-sort-order">
            <option value="desc">降序</option>
            <option value="asc">升序</option>
          </select>
          <button class="small-btn toolbar-reset" @click="resetRecordFilters">重置</button>
        </div>

        <div v-if="filteredSortedRecords.length > 0" class="records-table">
          <table>
            <colgroup>
              <col class="records-col-species" />
              <col class="records-col-location" />
              <col class="records-col-coords" />
              <col class="records-col-date" />
            </colgroup>
            <thead>
              <tr>
                <th>物种</th>
                <th>位置</th>
                <th>坐标</th>
                <th>日期</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="(record, index) in filteredSortedRecords"
                :key="`${record.species}-${record.date}-${record.latitude}-${record.longitude}-${index}`"
                @dblclick="focusRecordOnMap(record)"
              >
                <td>{{ record.species }}</td>
                <td>{{ record.location_name }}</td>
                <td>{{ record.latitude.toFixed(4) }}, {{ record.longitude.toFixed(4) }}</td>
                <td>{{ record.date }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div v-else class="empty-state">暂无记录数据</div>
      </div>

      <button class="toggle-left-view-btn" @click="toggleReportLeftView">{{ reportLeftToggleLabel }}</button>
    </section>

    <section class="report-map-card">
      <div class="map-toolbar">
        <label>地图底图</label>
        <select v-model="reportBasemapModel" @change="changeReportBasemap" class="form-input map-select">
          <option value="gaode_satellite">高德卫星</option>
          <option value="gaode_satellite_annotated">高德卫星（带标注）</option>
        </select>
      </div>
      <div id="report-map" class="report-map-container"></div>
    </section>
  </div>
</template>

<script setup>
import { computed } from 'vue'

const props = defineProps({
  speciesList: { type: Array, required: true },
  reportForm: { type: Object, required: true },
  reportMessage: { type: String, required: true },
  reportMessageType: { type: String, required: true },
  reportLeftView: { type: String, required: true },
  recordFilterSpecies: { type: String, required: true },
  recordFilterDate: { type: String, required: true },
  recordSortField: { type: String, required: true },
  recordSortOrder: { type: String, required: true },
  reportBasemap: { type: String, required: true },
  canSave: { type: Boolean, required: true },
  reportLeftToggleLabel: { type: String, required: true },
  filteredSortedRecords: { type: Array, required: true },
  changeReportBasemap: { type: Function, required: true },
  forwardGeocode: { type: Function, required: true },
  reverseGeocode: { type: Function, required: true },
  focusRecordOnMap: { type: Function, required: true },
  saveLocation: { type: Function, required: true },
  resetForm: { type: Function, required: true },
  resetRecordFilters: { type: Function, required: true },
  toggleReportLeftView: { type: Function, required: true },
})

const emit = defineEmits([
  'update:recordFilterSpecies',
  'update:recordFilterDate',
  'update:recordSortField',
  'update:recordSortOrder',
  'update:reportBasemap',
])

const recordFilterSpeciesModel = computed({
  get: () => props.recordFilterSpecies,
  set: (value) => emit('update:recordFilterSpecies', value),
})

const recordFilterDateModel = computed({
  get: () => props.recordFilterDate,
  set: (value) => emit('update:recordFilterDate', value),
})

const recordSortFieldModel = computed({
  get: () => props.recordSortField,
  set: (value) => emit('update:recordSortField', value),
})

const recordSortOrderModel = computed({
  get: () => props.recordSortOrder,
  set: (value) => emit('update:recordSortOrder', value),
})

const reportBasemapModel = computed({
  get: () => props.reportBasemap,
  set: (value) => emit('update:reportBasemap', value),
})
</script>

<style scoped>
.report-container {
  display: grid;
  grid-template-columns: 420px minmax(0, 1fr);
  min-height: 680px;
}

.report-form-card {
  padding: 22px;
  border-right: 1px solid #edf2f7;
  background: linear-gradient(180deg, #f9fbfe 0%, #eff5fb 100%);
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.panel-header {
  display: flex;
  gap: 12px;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 18px;
}

.panel-header h3 {
  margin: 0 0 8px;
}

.panel-header p {
  margin: 0;
  color: #637487;
  line-height: 1.6;
}

.form-area,
.records-area {
  display: grid;
  gap: 12px;
  min-height: 0;
  flex: 1 1 auto;
}

.field-label {
  font-size: 0.92rem;
  font-weight: 600;
  color: #344556;
}

.form-input {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid #ccd8e4;
  border-radius: 10px;
  background: #fff;
}

.coords-row,
.button-row,
.toolbar {
  display: grid;
  gap: 10px;
}

.coords-row {
  grid-template-columns: 1fr 1fr;
}

.button-row {
  grid-template-columns: 1fr 1fr;
}

.toolbar {
  grid-template-columns: repeat(2, minmax(0, 1fr));
  align-items: center;
}

.toolbar-species {
  grid-column: 1 / -1;
}

.toolbar-date,
.toolbar-sort-field,
.toolbar-sort-order {
  min-width: 0;
}

.toolbar-reset {
  grid-column: 1 / -1;
}

.small-btn,
.save-btn {
  border: 0;
  border-radius: 10px;
  cursor: pointer;
}

.small-btn {
  padding: 10px 12px;
  background: #e7eff8;
}

.save-btn {
  padding: 10px 12px;
  background: #155eef;
  color: #fff;
}

.message-box {
  padding: 12px 14px;
  border-radius: 10px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  line-height: 1.4;
}

.message-slot {
  height: 48px;
}

.message-placeholder {
  height: 48px;
}

.message-box.success {
  background: #eafaf1;
  color: #127447;
}

.message-box.error {
  background: #fff0ef;
  color: #b42318;
}

.records-table {
  overflow: auto;
  max-height: min(52vh, 520px);
  background: #fff;
  border: 1px solid #d9e3ee;
  border-radius: 12px;
}

table {
  width: 100%;
  border-collapse: collapse;
  table-layout: fixed;
}

th,
td {
  padding: 10px 12px;
  border-bottom: 1px solid #eef3f8;
  text-align: center;
}

thead th {
  position: sticky;
  top: 0;
  z-index: 1;
  background: #f8f9fa;
  opacity: 1;
}

.records-col-species {
  width: 18%;
}

.records-col-location {
  width: 42%;
}

.records-col-coords {
  width: 22%;
}

.records-col-date {
  width: 18%;
}

tbody tr {
  cursor: pointer;
}

.empty-state {
  padding: 18px;
  border-radius: 12px;
  background: #fff;
  color: #66788a;
}

.report-map-card {
  display: grid;
  grid-template-rows: auto minmax(0, 1fr);
}

.map-toolbar {
  display: flex;
  gap: 12px;
  align-items: center;
  padding: 18px 20px;
  border-bottom: 1px solid #edf2f7;
}

.date-input {
  letter-spacing: -0.04em;
  font-variant-numeric: tabular-nums;
}

.map-select {
  width: 220px;
}

.date-input {
  letter-spacing: 0;
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}

.report-map-container {
  min-height: 680px;
}

.toggle-left-view-btn {
  margin-top: 14px;
  width: 100%;
  border: 1px solid #155eef;
  background: #eaf0ff;
  color: #1549b5;
  border-radius: 8px;
  padding: 10px 12px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.toggle-left-view-btn:hover {
  background: #155eef;
  color: #fff;
}

@media (max-width: 1180px) {
  .report-container {
    grid-template-columns: 1fr;
  }

  .report-form-card {
    border-right: 0;
    border-bottom: 1px solid #edf2f7;
  }
}

@media (max-width: 760px) {
  .coords-row,
  .button-row,
  .toolbar {
    grid-template-columns: 1fr;
  }
}
</style>
