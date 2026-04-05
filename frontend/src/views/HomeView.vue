<template>
  <div class="home-container">
    <header class="app-header">
      <h1>🌊 水生入侵生物综合平台</h1>
      <p>分布识别 · 知识问答 · 数据协作</p>
    </header>

    <div class="tabs-wrapper">
      <div class="tabs-header">
        <button 
          v-for="(tab, idx) in tabs" 
          :key="idx"
          :class="['tab-btn', { active: activeTab === idx }]"
          @click="activeTab = idx"
        >
          {{ tab.label }}
        </button>
      </div>

      <!-- Tab 1: 分布识别分析（v-show 保留 #map DOM，避免 Leaflet 在 0 尺寸下初始化或实例挂在已销毁节点上） -->
      <div v-show="activeTab === 0" class="tab-content">
        <div class="map-analysis">
          <div class="sidebar">
            <div class="control-panel">
              <h3>🌍 分布识别分析</h3>
              <div class="basemap-selector">
                <label>选择底图：</label>
                <select v-model="selectedBasemap" @change="changeBasemap" class="basemap-select">
                  <option value="osm">OpenStreetMap</option>
                  <option value="esri">ESRI 卫星</option>
                  <option value="gaode_satellite">高德卫星影像</option>
                  <option value="gaode_satellite_annotated">高德卫星影像(带标注)</option>
                </select>
              </div>
              <div class="layer-selector">
                <label>选择图层：</label>
                <select v-model="selectedLayer" @change="changeLayer" class="layer-select">
                  <option value="points">散点图</option>
                  <option value="heatmap">空间热力图</option>
                  <option value="province">省级填色图</option>
                  <option value="maxent">MaxEnt 适生区预测</option>
                </select>
              </div>
              <div class="species-selector">
                <label>选择物种：</label>
                <select v-model="selectedSpecies" @change="onSpeciesChange" class="species-select">
                  <option value="">-- 请选择物种 --</option>
                  <option v-for="sp in speciesList" :key="sp" :value="sp">{{ sp }}</option>
                </select>
              </div>
              
              <div v-if="selectedSpecies" class="info-panel">
                <h4>📍 分布统计</h4>
                <div class="stats">
                  <div class="stat-item">
                    <span class="label">已记录点位：</span>
                    <span class="value">{{ currentLocations.length }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div id="map" class="map-container"></div>
        </div>
      </div>

      <!-- Tab 2: 智能知识问答 -->
      <div v-show="activeTab === 1" class="tab-content">
        <div class="qa-container">
          <div class="chat-wrapper">
            <div class="chat-header">
              <h3>🤖 知识问答</h3>
              <button @click="clearChat" class="clear-btn">清空对话</button>
            </div>
            
            <div class="messages-container">
              <div v-for="msg in chatMessages" :key="msg.id" :class="['message', msg.role]">
                <div class="message-content">
                  <span class="role-label">{{ msg.role === 'user' ? '你' : '助手' }}：</span>
                  <div v-if="msg.role === 'assistant'" class="message-text markdown-body" v-html="renderMarkdown(msg.content)"></div>
                  <span v-else class="message-text">{{ msg.content }}</span>
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
                <span class="suggest-label">💡 关于 <strong>{{ chatSpecies }}</strong>，试试：</span>
                <div class="suggestion-buttons">
                  <button 
                    v-for="(q, idx) in randomQuestions" 
                    :key="idx"
                    @click="sendPresetQuestion(q)"
                    :disabled="isLoading"
                    class="sugg-btn"
                  >
                    {{ q }}
                  </button>
                </div>
              </div>
              
              <div class="input-group">
                <input 
                  v-model="userInput" 
                  @keyup.enter="sendMessage"
                  placeholder="输入你的问题..."
                  class="qa-input"
                />
                <button @click="sendMessage" :disabled="!userInput.trim() || isLoading" class="send-btn">
                  {{ isLoading ? '思考中...' : '发送' }}
                </button>
              </div>
            </div>
          </div>

          <div class="species-panel">
            <h3>📚 选择物种或快速提问</h3>
            <div class="species-buttons-scroll">
              <div class="species-buttons">
                <button 
                  v-for="sp in speciesList" 
                  :key="sp"
                  @click="selectChatSpecies(sp)"
                  :class="['species-btn', { active: chatSpecies === sp }]"
                >
                  {{ sp }}
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Tab 3: 数据上报与更新 -->
      <div v-show="activeTab === 2" class="tab-content">
        <div class="report-container">
          <div class="report-section">
            <div v-if="reportLeftView === 'form'" class="report-left-view">
              <h3>📝 新增物种分布记录</h3>
              <p class="guide-text">支持两种方式：在地图上选点或填写表单。确认无误后点击保存。</p>
              <div class="form-area">
                <div class="form-group">
                  <label>物种名称 *</label>
                  <select v-model="reportForm.species" class="form-input">
                    <option value="">-- 选择物种 --</option>
                    <option v-for="sp in speciesList" :key="sp" :value="sp">{{ sp }}</option>
                  </select>
                </div>

                <div class="form-row">
                  <button @click="forwardGeocode" class="small-btn">详细地名转经纬</button>
                  <button @click="reverseGeocode" class="small-btn">经纬转详细地名</button>
                </div>
                <p class="small-text">地图点选会自动填入三框。</p>

                <div class="form-group">
                  <label>详细地名 *</label>
                  <input v-model="reportForm.location_name" class="form-input" placeholder="例：江苏省南京市玄武区XXX"/>
                </div>

                <div class="coords-row">
                  <div class="form-group">
                    <label>经度 (Longitude) *</label>
                    <input 
                      v-model.number="reportForm.longitude" 
                      type="number" 
                      class="form-input" 
                      placeholder="经度"
                      step="0.000001"
                      min="-180"
                      max="180"
                    />
                  </div>
                  <div class="form-group">
                    <label>纬度 (Latitude) *</label>
                    <input 
                      v-model.number="reportForm.latitude" 
                      type="number" 
                      class="form-input" 
                      placeholder="纬度"
                      step="0.000001"
                      min="-90"
                      max="90"
                    />
                  </div>
                </div>

                <div class="form-group">
                  <label>发现日期</label>
                  <input v-model="reportForm.date" type="date" class="form-input"/>
                </div>

                <div class="button-group">
                  <button @click="saveLocation" class="save-btn" :disabled="!canSave">
                    💾 保存记录
                  </button>
                  <button @click="resetForm" class="reset-btn">
                    🔄 清空表单
                  </button>
                </div>

                <div v-if="reportMessage" :class="['message-box', reportMessageType]">
                  {{ reportMessage }}
                </div>
              </div>
            </div>

            <div v-else class="report-left-view">
              <div class="collected-data records-only">
                <h3>📊 已收集的记录</h3>
                <div class="records-toolbar">
                  <select v-model="recordFilterSpecies" class="form-input toolbar-input">
                    <option value="">全部物种</option>
                    <option v-for="sp in speciesList" :key="`filter-${sp}`" :value="sp">{{ sp }}</option>
                  </select>
                  <input v-model="recordFilterDate" type="date" class="form-input toolbar-input" />
                  <select v-model="recordSortField" class="form-input toolbar-input">
                    <option value="date">按日期排序</option>
                    <option value="species">按物种排序</option>
                    <option value="location_name">按地点排序</option>
                  </select>
                  <select v-model="recordSortOrder" class="form-input toolbar-input toolbar-order">
                    <option value="desc">降序</option>
                    <option value="asc">升序</option>
                  </select>
                  <button class="small-btn" @click="resetRecordFilters">重置</button>
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
                        v-for="(record, idx) in filteredSortedRecords"
                        :key="`${record.species}-${record.date}-${record.latitude}-${record.longitude}-${idx}`"
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
                <div v-else class="empty-state">
                  暂无记录数据
                </div>
              </div>
            </div>

            <button class="toggle-left-view-btn" @click="toggleReportLeftView">
              {{ reportLeftToggleLabel }}
            </button>
          </div>

          <div class="map-and-records">
            <div class="report-basemap-wrapper" style="margin-bottom: 10px;">
              <label style="font-weight: 500; color: #333; margin-right: 8px;">地图底图：</label>
              <select v-model="reportBasemap" @change="changeReportBasemap" class="form-input" style="width: auto; display: inline-block; padding: 6px 12px;">
                <option value="osm">OpenStreetMap</option>
                <option value="esri">ESRI 卫星影像</option>
                <option value="gaode_satellite">高德纯卫星影像</option>
                <option value="gaode_satellite_annotated">高德卫星影像 (带标注)</option>
              </select>
            </div>
            <div id="report-map" class="report-map-container"></div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, watch, nextTick } from 'vue'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import 'leaflet.heat' // 需要安装 leaflet.heat 插件
import { marked } from 'marked'

const API_BASE = '/api'

const normalizeZhSpacing = (text) => {
  return String(text || '')
    .replace(/\s+/g, ' ')
    .replace(/([\u4e00-\u9fff])\s+([\u4e00-\u9fff])/g, '$1$2')
    .replace(/([\u4e00-\u9fff])\s+([，。！？；：、])/g, '$1$2')
    .replace(/([，。！？；：、])\s+([\u4e00-\u9fff])/g, '$1$2')
    .trim()
}

const cleanInvisibleCharacters = (text) => {
  return String(text || '')
    .replace(/\uFEFF/g, '')
    .replace(/[\u200B-\u200D\u2060\u180E]/g, '')
    .replace(/\u00A0/g, ' ')
    .replace(/\u2028|\u2029/g, '\n')
    .replace(/\r\n?/g, '\n')
}

const normalizeMarkdownForChat = (text) => {
  const lines = cleanInvisibleCharacters(text).split('\n')

  const mapped = lines.map((rawLine) => {
    const line = rawLine.replace(/[ \t]+$/g, '')
    const trimmed = line.trim()

    if (!trimmed) return ''

    // 标题前缀归一化：处理全角 #、转义 #、以及没有空格的 ###标题
    const headingCandidate = trimmed.replace(/^\\+([#＃])/, '$1')
    const headingPrefix = headingCandidate.match(/^[#＃]{1,6}\s*(.+)$/)
    if (headingPrefix) {
      const title = headingPrefix[1].trim().replace(/[：:]$/, '')
      return title ? `### ${title}` : ''
    }

    // 识别类似“补充背景信息：”这类短标题行为章节标题
    const shortTitleMatch = trimmed.match(/^([^，。；;！？!?]{2,18})[：:]$/)
    if (shortTitleMatch && !/^[0-9一二三四五六七八九十]+[\.、]/.test(trimmed)) {
      return `### ${shortTitleMatch[1]}`
    }

    // 识别“1. 入侵性：”并归一化为同一种标题组件
    const numberedTitle = trimmed.match(/^([0-9一二三四五六七八九十]+)[\.、]\s*([^：:，。；;！？!?]{1,18})[：:]?$/)
    if (numberedTitle) {
      return `### ${numberedTitle[1]}. ${numberedTitle[2]}`
    }

    // 把常见符号列表统一为 Markdown 列表，并保留层级
    const bulletMatch = line.match(/^(\s*)[•●▪▫◦○·\-]\s+(.*)$/)
    if (bulletMatch) {
      const leading = bulletMatch[1].replace(/\t/g, '  ').length
      const content = bulletMatch[2].trim()
      const level = Math.min(2, Math.floor(leading / 2))
      return `${'  '.repeat(level)}- ${content}`
    }

    // 数字列表统一转为同一符号列表（避免数字/实心点混用）
    const orderedMatch = line.match(/^(\s*)(\d+)[\.、]\s*(.+)$/)
    if (orderedMatch) {
      const leading = orderedMatch[1].replace(/\t/g, '  ').length
      const content = orderedMatch[3].trim()
      const level = Math.min(2, Math.floor(leading / 2))
      return `${'  '.repeat(level)}- ${content}`
    }

    return line
  })

  // 将独立的短编号标题转为标题组件（例如："1. 生态危害"）
  const sectionized = mapped.map((line, idx, arr) => {
    const m = line.match(/^\s*([0-9一二三四五六七八九十]+)[\.、]\s*([^：:。；;，,]{2,22})\s*$/)
    if (!m) return line

    const prev = idx > 0 ? arr[idx - 1].trim() : ''
    const next = idx < arr.length - 1 ? arr[idx + 1].trim() : ''
    const hasContext = prev !== '' || next !== ''
    if (!hasContext) return line

    return `### ${m[1]}. ${m[2]}`
  })

  // 标题块强制换段：确保标题前后独立成段，避免 ### 明文
  const withHeadingSpacing = []
  sectionized.forEach((line, idx) => {
    const trimmed = line.trim()
    const isHeading = /^#{3}\s+/.test(trimmed)

    if (isHeading) {
      const prev = withHeadingSpacing.length > 0 ? withHeadingSpacing[withHeadingSpacing.length - 1] : ''
      if (prev.trim() !== '') {
        withHeadingSpacing.push('')
      }
      withHeadingSpacing.push(trimmed)

      const next = idx < sectionized.length - 1 ? sectionized[idx + 1].trim() : ''
      if (next !== '') {
        withHeadingSpacing.push('')
      }
      return
    }

    withHeadingSpacing.push(line)
  })

  return withHeadingSpacing
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim()
}

/**
 * 渲染Markdown为HTML，支持安全的HTML渲染
 */
const renderMarkdown = (content) => {
  if (!content) return ''
  try {
    const normalized = normalizeMarkdownForChat(content)

    // 配置marked选项
    marked.setOptions({
      breaks: true,
      gfm: true,
    })
    return marked(normalized)
  } catch (e) {
    console.error('Markdown渲染错误:', e)
    return content.replace(/</g, '&lt;').replace(/>/g, '&gt;')
  }
}

/**
 * 解析API错误信息，兼容多种错误格式
 */
const apiErrorMessage = (data) => {
  if (data?.error?.message != null) {
    const m = data.error.message
    return Array.isArray(m) ? JSON.stringify(m) : String(m)
  }
  if (data?.detail != null) return String(data.detail)
  return ''
}

/**
 * 安全解析响应体：优先JSON，失败时回退为文本
 */
const parseResponseBody = async (response) => {
  const raw = await response.text()
  if (!raw) return { json: null, text: '' }
  try {
    return { json: JSON.parse(raw), text: raw }
  } catch {
    return { json: null, text: raw }
  }
}

/**
 * 获取底图配置
 * @param {string} basemap - 底图类型: 'osm', 'esri', 'gaode_satellite', 'gaode_satellite_annotated'
 * @returns {Array} Leaflet 图层数组
 */
const getBasemapLayers = (basemap) => {
  const layers = []

  switch(basemap) {
    case 'osm':
      layers.push(L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
        attribution: '© OpenStreetMap contributors',
        maxZoom: 18
      }))
      break
    case 'esri':
      layers.push(L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
        attribution: 'Tiles &copy; Esri &mdash; Source: Esri...',
        maxZoom: 18
      }))
      break
    case 'gaode_satellite':
      layers.push(L.tileLayer('https://webst02.is.autonavi.com/appmaptile?style=6&x={x}&y={y}&z={z}', {
        attribution: 'Tiles &copy; 高德地图 AMap',
        maxZoom: 18
      }))
      break
    case 'gaode_satellite_annotated':
      // 先铺底图再叠加标注
      layers.push(L.tileLayer('https://webst02.is.autonavi.com/appmaptile?style=6&x={x}&y={y}&z={z}', {
        attribution: 'Tiles &copy; 高德地图 AMap',
        maxZoom: 18
      }))
      layers.push(L.tileLayer('https://webst02.is.autonavi.com/appmaptile?style=8&x={x}&y={y}&z={z}', {
        maxZoom: 18
      }))
      break
  }

  return layers
}

// =============== 全局状态 ===============
const activeTab = ref(0)
const speciesList = ref([])
const isLoading = ref(false)

// =============== Tab 1: 分布分析 ===============
const selectedSpecies = ref('')
const selectedBasemap = ref('osm')
const selectedLayer = ref('points')
const currentLocations = ref([])
let map = null
let markersLayer = null
let tileLayer = null
let heatLayer = null
let provinceLayer = null
let maxentLayer = null

// =============== Tab 2: 知识问答 ===============
const chatMessages = ref([
  {
    id: 0,
    role: 'assistant',
    content: '你好！我是水生入侵生物科普助手，可以为您介绍各类入侵生物的分类、危害和防治方法。请问您想了解哪个物种？'
  }
])
let msgId = 1
const userInput = ref('')
const chatSpecies = ref('')
const allSuggestions = ref([])  // 后端返回的所有建议
const randomQuestions = ref([])  // 当前显示的 2 个随机问题
const lastSuggestedLabels = ref([])  // 上次推荐过的问题标签
const lastMsgCountForRefresh = ref(-1)  // 上次刷新时的消息数
const lastSpeciesForRefresh = ref('')  // 上次刷新时的物种

// =============== Tab 3: 数据上报 ===============
const reportForm = ref({
  species: '',
  location_name: '',
  latitude: null,
  longitude: null,
  date: new Date().toISOString().split('T')[0]
})
const reportMessage = ref('')
const reportMessageType = ref('success')
const reportLeftView = ref('form')
const allRecords = ref([])
const recordFilterSpecies = ref('')
const recordFilterDate = ref('')
const recordSortField = ref('date')
const recordSortOrder = ref('desc')
let reportMap = null
let reportMapMarker = null
let reportTileLayer = null  // Tab3的底图图层
let reportRecordsLayer = null
let reportReverseGeocodeTimer = null
let reportRecordMarkerMap = new Map()
const reportBasemap = ref('osm')  // Tab3的底图选择

const tabs = ref([
  { label: '🌍 分布识别分析', icon: '🌍' },
  { label: '🤖 智能知识问答', icon: '🤖' },
  { label: '📝 数据上报与更新', icon: '📝' }
])

const canSave = computed(() => {
  return reportForm.value.species && 
         reportForm.value.location_name && 
         reportForm.value.latitude !== null && 
         reportForm.value.longitude !== null
})

const reportLeftToggleLabel = computed(() => {
  return reportLeftView.value === 'form'
    ? '切换为📊 已收集的记录'
    : '切换为📝 新增物种分布记录'
})

const filteredSortedRecords = computed(() => {
  const rows = allRecords.value.filter((r) => {
    const bySpecies = !recordFilterSpecies.value || r.species === recordFilterSpecies.value
    const byDate = !recordFilterDate.value || String(r.date || '').startsWith(recordFilterDate.value)
    return bySpecies && byDate
  })

  rows.sort((a, b) => {
    const field = recordSortField.value
    let result = 0

    if (field === 'date') {
      const aTime = new Date(a.date || '1970-01-01').getTime()
      const bTime = new Date(b.date || '1970-01-01').getTime()
      result = aTime - bTime
    } else {
      result = String(a[field] || '').localeCompare(String(b[field] || ''), 'zh-CN')
    }

    return recordSortOrder.value === 'asc' ? result : -result
  })

  return rows
})

// =============== 初始化和加载数据 ===============
onMounted(async () => {
  await loadSpeciesList()
  await loadAllRecords()
})

watch(
  () => activeTab.value,
  (newTab) => {
    if (newTab === 0) {
      nextTick(() => {
        setTimeout(() => {
          if (activeTab.value !== 0) return
          if (!map) initMap()
          else map.invalidateSize(true)
        }, 100)
      })
    }
    if (newTab === 2) {
      nextTick(() => {
        setTimeout(() => {
          if (activeTab.value !== 2) return
          if (!reportMap) {
            initReportMap()
          } else {
            reportMap.invalidateSize(true)
            renderReportPointsOnMap(filteredSortedRecords.value)
          }
        }, 100)
      })
    }
  },
  { immediate: true }
)

watch(
  () => filteredSortedRecords.value,
  (records) => {
    if (!reportMap) return
    renderReportPointsOnMap(records)
  }
)

watch(
  () => reportLeftView.value,
  (view) => {
    if (view !== 'form' && reportReverseGeocodeTimer) {
      clearTimeout(reportReverseGeocodeTimer)
      reportReverseGeocodeTimer = null
    }
    updateReportMapByView()
  }
)

const loadSpeciesList = async () => {
  try {
    const response = await fetch(`${API_BASE}/species`)
    const data = await response.json()
    speciesList.value = data.species || []
  } catch (error) {
    console.error('加载物种列表失败:', error)
  }
}

const loadAllRecords = async () => {
  try {
    const response = await fetch(`${API_BASE}/records`)
    const data = await response.json()
    allRecords.value = (data.records || []).map(r => ({
      ...r,
      latitude: parseFloat(r.latitude),
      longitude: parseFloat(r.longitude)
    }))
  } catch (error) {
    console.error('加载记录失败:', error)
    allRecords.value = []
  }
}

// =============== Tab 1: 地图相关 ===============
const initMap = () => {
  if (map) return
  
  map = L.map('map').setView([35, 105], 4)
  markersLayer = L.layerGroup().addTo(map)
  changeBasemap()
  changeLayer()
}

const changeBasemap = () => {
  if (tileLayer) {
    map.removeLayer(tileLayer)
  }

  // 使用 LayerGroup 方便整体管理
  tileLayer = L.layerGroup().addTo(map)

  // 获取对应底图的所有图层并添加
  const layers = getBasemapLayers(selectedBasemap.value)
  layers.forEach(layer => layer.addTo(tileLayer))
}

const changeLayer = async () => {
  // 移除现有图层
  if (markersLayer && map.hasLayer(markersLayer)) map.removeLayer(markersLayer)
  if (heatLayer && map.hasLayer(heatLayer)) map.removeLayer(heatLayer)
  if (provinceLayer && map.hasLayer(provinceLayer)) map.removeLayer(provinceLayer)
  if (maxentLayer && map.hasLayer(maxentLayer)) map.removeLayer(maxentLayer)

  if (selectedLayer.value === 'points') {
    markersLayer = L.layerGroup().addTo(map)
    updatePoints()
  } else if (selectedLayer.value === 'heatmap') {
    await loadHeatmapData()
  } else if (selectedLayer.value === 'province') {
    await loadProvinceData()
  } else if (selectedLayer.value === 'maxent') {
    await loadMaxentData()
  }
}

const updatePoints = () => {
  if (!markersLayer) return
  markersLayer.clearLayers()
  currentLocations.value.forEach(loc => {
    if (loc.latitude && loc.longitude) {
      L.circleMarker([loc.latitude, loc.longitude], {
        radius: 5,
        fillColor: '#ff6b6b',
        color: '#d63031',
        weight: 2,
        opacity: 0.7,
        fillOpacity: 0.6
      }).addTo(markersLayer).bindPopup(loc.location_name || `${loc.latitude.toFixed(4)}, ${loc.longitude.toFixed(4)}`)
    }
  })
}

const loadHeatmapData = async () => {
  if (!selectedSpecies.value) {
    console.warn('请先在下拉框中选择物种后再查看热力图')
    return
  }
  try {
    const response = await fetch(`${API_BASE}/heatmap/${encodeURIComponent(selectedSpecies.value)}`)
    const data = await response.json()
    const points = data.points || []
    if (points.length === 0) {
      console.warn('热力图数据为空')
      return
    }
    heatLayer = L.heatLayer(points, { 
      radius: 20,       // 稍微缩小影响半径，让热力中心更聚拢
      blur: 15,         // 降低模糊度（默认15），让边缘更清晰锐利
      maxZoom: 10,      // 根据地图缩放自动调整热力，数值越大越容易变红
      max: 1.0,         // 设置最高热力值为1.0
      gradient: {       // 自定义高对比度色带
        0.2: '#0000ff', // 蓝 (低密度)
        0.4: '#00ffff', // 青
        0.6: '#00ff00', // 绿
        0.8: '#ffff00', // 黄
        1.0: '#ff0000'  // 红 (高密度中心)
      }
    }).addTo(map)
    const latLngs = points.map((p) => [p[0], p[1]])
    map.fitBounds(L.latLngBounds(latLngs))
  } catch (error) {
    console.error('加载热力图数据失败:', error)
  }
}

const loadProvinceData = async () => {
  if (!selectedSpecies.value) {
    console.warn('请先在下拉框中选择物种后再查看省级填色图')
    return
  }
  try {
    const response = await fetch(`${API_BASE}/province-data/${encodeURIComponent(selectedSpecies.value)}`)
    const data = await response.json()
    const geojson = data.geojson
    provinceLayer = L.geoJSON(geojson, {
      style: (feature) => {
        const count = feature.properties.count;
        return {
          // 核心视觉优化：有数据的用鲜艳渐变色，没数据的用极浅的灰色
          fillColor: count > 0 ? getColor(count) : '#f4f4f4',
          weight: 1,
          opacity: 1,
          color: count > 0 ? 'white' : '#ddd', // 没数据的边界线变淡
          dashArray: '3',
          // 有数据的加深不透明度，无数据的变半透明
          fillOpacity: count > 0 ? 0.8 : 0.3
        }
      },
      onEachFeature: (feature, layer) => {
        layer.bindPopup(`${feature.properties.name}: ${feature.properties.count} 记录`)
      }
    }).addTo(map)
    if (provinceLayer && provinceLayer.getBounds && provinceLayer.getBounds().isValid()) {
      map.fitBounds(provinceLayer.getBounds())
    }
  } catch (error) {
    console.error('加载省级数据失败:', error)
  }
}

const loadMaxentData = async () => {
  if (!selectedSpecies.value) {
    console.warn('请先在下拉框中选择物种后再查看 MaxEnt 图层')
    return
  }
  try {
    const response = await fetch(`${API_BASE}/maxent-image/${encodeURIComponent(selectedSpecies.value)}`)
    const data = await response.json()
    if (!data.imageUrl || !data.bounds) {
      console.warn('未返回有效的 MaxEnt 图像数据', data)
      return
    }
    maxentLayer = L.imageOverlay(data.imageUrl, data.bounds, { opacity: 0.6 }).addTo(map)
    if (maxentLayer && data.bounds) {
      map.fitBounds(data.bounds)
    }
  } catch (error) {
    console.error('加载MaxEnt数据失败:', error)
  }
}

const initReportMap = () => {
  if (reportMap) return
  reportMap = L.map('report-map').setView([35.0, 105.0], 4)
  reportRecordsLayer = L.layerGroup().addTo(reportMap)

  changeReportBasemap()
  updateReportMapByView()

  reportMap.on('click', async (e) => {
    if (reportLeftView.value !== 'form') return

    const { lat, lng } = e.latlng
    // 1. 立即更新界面的经纬度并打点（无需等待）
    reportForm.value.latitude = parseFloat(lat.toFixed(6))
    reportForm.value.longitude = parseFloat(lng.toFixed(6))
    reportForm.value.location_name = `经纬度解析中... (${reportForm.value.longitude}, ${reportForm.value.latitude})`
    setReportMarker(reportForm.value.latitude, reportForm.value.longitude)

    // 2. 清除之前的定时器，防止连续点击产生多个请求
    if (reportReverseGeocodeTimer) {
      clearTimeout(reportReverseGeocodeTimer)
    }

    // 3. 设置新的定时器，延迟 1 秒触发请求
    reportReverseGeocodeTimer = setTimeout(async () => {
      try {
        const r = await fetch(`${API_BASE}/reverse-geocode?lat=${reportForm.value.latitude}&lon=${reportForm.value.longitude}`)
        const json = await r.json()
        if (json.address) {
          reportForm.value.location_name = json.address
        } else {
          reportForm.value.location_name = `经纬度：${reportForm.value.longitude}, ${reportForm.value.latitude}`
        }
      } catch (err) {
        console.error('逆向地理编码失败', err)
        // 失败时恢复显示基础经纬度
        reportForm.value.location_name = `经纬度：${reportForm.value.longitude}, ${reportForm.value.latitude}`
      }
    }, 1000) // 延迟 1000 毫秒 (1秒)
  })
}

const changeReportBasemap = () => {
  if (reportTileLayer) {
    reportMap.removeLayer(reportTileLayer)
  }

  reportTileLayer = L.layerGroup().addTo(reportMap)

  // 复用底图配置函数
  const layers = getBasemapLayers(reportBasemap.value)
  layers.forEach(layer => layer.addTo(reportTileLayer))
}

const setReportMarker = (lat, lng) => {
  if (!reportMap) return

  if (reportLeftView.value !== 'form') return

  if (reportMapMarker) {
    reportMap.removeLayer(reportMapMarker)
  }
  reportMapMarker = L.marker([lat, lng]).addTo(reportMap)
  reportMap.setView([lat, lng], 10)
}

const renderReportPointsOnMap = (records) => {
  if (!reportMap || !reportRecordsLayer) return

  if (reportLeftView.value !== 'records') {
    reportRecordsLayer.clearLayers()
    reportRecordMarkerMap = new Map()
    return
  }

  reportRecordsLayer.clearLayers()
  reportRecordMarkerMap = new Map()

  const validRows = (records || []).filter(r => Number.isFinite(r.latitude) && Number.isFinite(r.longitude))
  validRows.forEach((r) => {
    const marker = L.circleMarker([r.latitude, r.longitude], {
      radius: 6,
      fillColor: '#1f7ae0',
      color: '#0e4f99',
      weight: 1,
      opacity: 0.95,
      fillOpacity: 0.82
    })

    marker.bindPopup(`
      <div style="min-width: 180px; line-height: 1.5;">
        <div><strong>物种：</strong>${r.species || '-'}</div>
        <div><strong>位置：</strong>${r.location_name || '-'}</div>
        <div><strong>坐标：</strong>${Number(r.latitude).toFixed(6)}, ${Number(r.longitude).toFixed(6)}</div>
        <div><strong>日期：</strong>${r.date || '-'}</div>
      </div>
    `)

    marker.addTo(reportRecordsLayer)
    reportRecordMarkerMap.set(getRecordMarkerKey(r), marker)
  })
}

const getRecordMarkerKey = (record) => {
  return `${record.species || ''}|${record.date || ''}|${Number(record.latitude).toFixed(6)}|${Number(record.longitude).toFixed(6)}`
}

const focusRecordOnMap = (record) => {
  if (reportLeftView.value !== 'records') return

  const lat = Number(record?.latitude)
  const lng = Number(record?.longitude)
  if (!reportMap || !Number.isFinite(lat) || !Number.isFinite(lng)) return

  reportMap.flyTo([lat, lng], Math.max(reportMap.getZoom(), 9), { duration: 0.6 })

  const marker = reportRecordMarkerMap.get(getRecordMarkerKey(record))
  if (marker) {
    marker.openPopup()
  }
}

const updateReportMapByView = () => {
  if (!reportMap || !reportRecordsLayer) return

  if (reportLeftView.value === 'records') {
    if (reportMapMarker && reportMap.hasLayer(reportMapMarker)) {
      reportMap.removeLayer(reportMapMarker)
    }
    renderReportPointsOnMap(filteredSortedRecords.value)
    return
  }

  reportRecordsLayer.clearLayers()
  reportRecordMarkerMap = new Map()
}

const forwardGeocode = async () => {
  if (!reportForm.value.location_name || !reportForm.value.location_name.trim()) return
  try {
    const response = await fetch(`${API_BASE}/geocode?address=${encodeURIComponent(reportForm.value.location_name)}`)
    const data = await response.json()
    if (data.lat && data.lon) {
      reportForm.value.latitude = data.lat
      reportForm.value.longitude = data.lon
      reportForm.value.location_name = data.display_name || reportForm.value.location_name
      setReportMarker(data.lat, data.lon)
    }
  } catch (error) {
    console.error('详细地名转经纬失败:', error)
  }
}

const reverseGeocode = async () => {
  if (reportForm.value.latitude == null || reportForm.value.longitude == null) return
  try {
    const response = await fetch(`${API_BASE}/reverse-geocode?lat=${reportForm.value.latitude}&lon=${reportForm.value.longitude}`)
    const data = await response.json()
    if (data.address) {
      reportForm.value.location_name = data.address
    }
  } catch (error) {
    console.error('逆向地理编码失败:', error)
  }
}

const getColor = (d) => {
  return d > 50 ? '#800026' :
         d > 20 ? '#BD0026' :
         d > 10 ? '#E31A1C' :
         d > 5  ? '#FC4E2A' :
         d > 2  ? '#FD8D3C' :
                  '#FEB24C'; // 只要大于0，最起码是一个亮橙色
}

const onSpeciesChange = async () => {
  if (!selectedSpecies.value) {
    currentLocations.value = []
    changeLayer()
    return
  }

  try {
    const response = await fetch(`${API_BASE}/locations/${encodeURIComponent(selectedSpecies.value)}`)
    const data = await response.json()
    currentLocations.value = data.locations || []
    changeLayer()
  } catch (error) {
    console.error('加载位置失败:', error)
  }
}

// =============== Tab 2: 知识问答 ===============
const loadSuggestions = async (species) => {
  try {
    const response = await fetch(`${API_BASE}/qa/suggestions/${encodeURIComponent(species)}`)
    const data = await response.json()
    allSuggestions.value = (data.suggestions || []).map((q) => normalizeZhSpacing(q))
  } catch (error) {
    console.error('加载建议失败:', error)
    allSuggestions.value = []
  }
}

const refreshRandomQuestions = () => {
  if (allSuggestions.value.length === 0) return
  
  // 过滤掉上次推荐过的问题
  const availablePool = allSuggestions.value.filter(q => !lastSuggestedLabels.value.includes(q))
  // 如果过滤后不足 2 个，就用全量池
  const finalPool = availablePool.length >= 2 ? availablePool : allSuggestions.value
  
  // 从池中随机选 2 个
  const shuffled = [...finalPool].sort(() => Math.random() - 0.5)
  randomQuestions.value = shuffled.slice(0, 2)
  lastSuggestedLabels.value = [...randomQuestions.value]
}

const selectChatSpecies = async (species) => {
  const normalizedSpecies = String(species || '').trim()
  chatSpecies.value = normalizedSpecies
  lastSpeciesForRefresh.value = normalizedSpecies
  await loadSuggestions(normalizedSpecies)
  refreshRandomQuestions()
  // 选择新物种后滚动到顶部以显示欢迎信息
  scrollToBottom()
}

/**
 * 自动滚动到消息底部
 */
const scrollToBottom = () => {
  nextTick(() => {
    const container = document.querySelector('.messages-container')
    if (container) {
      container.scrollTop = container.scrollHeight
    }
  })
}

const sendMessage = () => {
  if (!userInput.value.trim()) return
  
  const question = normalizeZhSpacing(userInput.value)
  userInput.value = ''
  
  chatMessages.value.push({
    id: msgId++,
    role: 'user',
    content: question
  })
  
  // 确保用户消息立即显示
  scrollToBottom()
  
  askQuestion(question)
}

const sendPresetQuestion = (question) => {
  const normalizedQuestion = normalizeZhSpacing(question)
  if (!normalizedQuestion || isLoading.value) return

  chatMessages.value.push({
    id: msgId++,
    role: 'user',
    content: normalizedQuestion
  })

  scrollToBottom()
  askQuestion(normalizedQuestion)
}

const askQuestion = async (question) => {
  const normalizedQuestion = normalizeZhSpacing(question)
  if (!normalizedQuestion) return

  isLoading.value = true
  
  try {
    const response = await fetch(`${API_BASE}/qa`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ question: normalizedQuestion })
    })
    const data = await response.json()
    if (!response.ok) {
      chatMessages.value.push({
        id: msgId++,
        role: 'assistant',
        content: apiErrorMessage(data) || '请求失败'
      })
      scrollToBottom()
      return
    }
    chatMessages.value.push({
      id: msgId++,
      role: 'assistant',
      content: data.answer || '无法获取回答，请检查后端连接'
    })
    scrollToBottom()
  } catch (error) {
    chatMessages.value.push({
      id: msgId++,
      role: 'assistant',
      content: '连接失败，请检查后端服务是否运行'
    })
    scrollToBottom()
  } finally {
    isLoading.value = false
    
    // 消息完成后，刷新建议问题（保证多样性）
    const currentMsgCount = chatMessages.value.length
    if (currentMsgCount !== lastMsgCountForRefresh.value || lastSpeciesForRefresh.value !== chatSpecies.value) {
      lastMsgCountForRefresh.value = currentMsgCount
      if (chatSpecies.value && allSuggestions.value.length > 0) {
        refreshRandomQuestions()
      }
    }
  }
}

const clearChat = () => {
  chatMessages.value = [chatMessages.value[0]]
  msgId = 1
  scrollToBottom()
}

// =============== Tab 3: 数据上报 ===============
const saveLocation = async () => {
  if (!canSave.value) {
    reportMessage.value = '请填写所有必填项'
    reportMessageType.value = 'error'
    return
  }

  try {
    const response = await fetch(`${API_BASE}/record/location`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(reportForm.value)
    })

    const { json: data, text } = await parseResponseBody(response)

    if (!response.ok) {
      const backendMsg = apiErrorMessage(data)
      reportMessage.value = '❌ 保存失败：' + (backendMsg || text || `HTTP ${response.status}`)
      reportMessageType.value = 'error'
      return
    }

    if (data?.status === 'success') {
      reportMessage.value = '✅ 记录保存成功！感谢您的贡献'
      reportMessageType.value = 'success'
      if (reportForm.value.latitude !== null && reportForm.value.longitude !== null) {
        setReportMarker(reportForm.value.latitude, reportForm.value.longitude)
      }
      resetForm()
      await loadAllRecords()
      
      setTimeout(() => {
        reportMessage.value = ''
      }, 3000)
    } else {
      reportMessage.value = '❌ 保存失败：' + (data?.message || text || '未知错误')
      reportMessageType.value = 'error'
    }
  } catch (error) {
    reportMessage.value = '❌ 网络错误：' + error.message
    reportMessageType.value = 'error'
  }
}

const resetForm = () => {
  reportForm.value = {
    species: '',
    location_name: '',
    latitude: null,
    longitude: null,
    date: new Date().toISOString().split('T')[0]
  }
}

const resetRecordFilters = () => {
  recordFilterSpecies.value = ''
  recordFilterDate.value = ''
  recordSortField.value = 'date'
  recordSortOrder.value = 'desc'
}

const toggleReportLeftView = () => {
  reportLeftView.value = reportLeftView.value === 'form' ? 'records' : 'form'
}
</script>

<style scoped>
* {
  box-sizing: border-box;
}

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
  background: #f5f7fa;
  overflow-x: hidden;
}

.app-header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 40px 20px;
  text-align: center;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
}

.app-header h1 {
  margin: 0;
  font-size: 2.5em;
  font-weight: 700;
}

.app-header p {
  margin: 10px 0 0 0;
  font-size: 1.1em;
  opacity: 0.9;
}

.tabs-wrapper {
  max-width: 1400px;
  margin: 0 auto;
  padding: 20px;
}

.tabs-header {
  display: flex;
  gap: 10px;
  margin-bottom: 20px;
  border-bottom: 2px solid #ddd;
  padding-inline: 4px;
}

.tab-btn {
  padding: 12px 24px;
  font-size: 1em;
  border: none;
  background: none;
  cursor: pointer;
  border-bottom: 3px solid transparent;
  transition: all 0.3s ease;
  color: #666;
  font-weight: 500;
}

.tab-btn:hover {
  color: #667eea;
}

.tab-btn.active {
  color: #667eea;
  border-bottom-color: #667eea;
}

.tab-content {
  animation: fadeIn 0.3s ease;
  background: white;
  border-radius: 12px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  overflow: hidden;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* ============ Tab 1: 地图 ============ */
.map-analysis {
  display: flex;
  height: 750px;
}

.sidebar {
  width: 320px;
  border-right: 1px solid #eee;
  overflow-y: auto;
  background: #fafbfc;
}

.control-panel {
  padding: 20px;
}

.control-panel h3 {
  margin: 0 0 20px 0;
  color: #333;
  font-size: 1.2em;
}

.basemap-selector label {
  display: block;
  margin-bottom: 8px;
  font-weight: 500;
  color: #666;
}

.basemap-select {
  width: 100%;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 6px;
  font-size: 0.95em;
}

.layer-selector label {
  display: block;
  margin-bottom: 8px;
  font-weight: 500;
  color: #666;
}

.layer-select {
  width: 100%;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 6px;
  font-size: 0.95em;
}

.species-selector label {
  display: block;
  margin-bottom: 8px;
  font-weight: 500;
  color: #666;
}

.species-select {
  width: 100%;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 6px;
  font-size: 0.95em;
}

.info-panel {
  background: white;
  padding: 15px;
  border-radius: 8px;
  margin-top: 20px;
}

.info-panel h4 {
  margin: 0 0 12px 0;
  color: #333;
}

.stats {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.stat-item {
  display: flex;
  justify-content: space-between;
  padding: 8px 0;
  border-bottom: 1px solid #eee;
}

.stat-item .label {
  color: #666;
}

.stat-item .value {
  font-weight: 600;
  color: #667eea;
}

.map-container {
  flex: 1;
}

#map {
  width: 100%;
  height: 100%;
  z-index: 1;
}

/* ============ Tab 2: 问答 ============ */
.qa-container {
  display: grid;
  grid-template-columns: 1fr 280px;
  gap: 20px;
  padding: 20px;
  min-height: 700px;
  height: calc(100vh - 280px);
}

.chat-wrapper {
  display: flex;
  flex-direction: column;
  background: white;
  border-radius: 8px;
  border: 1px solid #eee;
  overflow: hidden;
  height: 100%;
  max-height: 700px;
}

.chat-header {
  padding: 15px 20px;
  border-bottom: 1px solid #eee;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.chat-header h3 {
  margin: 0;
  color: #333;
}

.clear-btn {
  padding: 6px 12px;
  background: #f0f0f0;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.9em;
  transition: background 0.2s;
}

.clear-btn:hover {
  background: #e0e0e0;
}

.messages-container {
  flex: 1;
  overflow-y: auto;
  padding: 20px 18px;
  display: flex;
  flex-direction: column;
  gap: 14px;
  background: #fafbfc;
  min-height: 400px;
  max-height: 600px;
}

/* 自定义滚动条 */
.messages-container::-webkit-scrollbar {
  width: 8px;
}

.messages-container::-webkit-scrollbar-track {
  background: #f1f1f1;
  border-radius: 4px;
}

.messages-container::-webkit-scrollbar-thumb {
  background: #c0c0c0;
  border-radius: 4px;
}

.messages-container::-webkit-scrollbar-thumb:hover {
  background: #a0a0a0;
}

.message {
  display: flex;
  margin: 0;
  animation: slideIn 0.3s ease-out;
  width: 100%;
}

@keyframes slideIn {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.message.user {
  justify-content: flex-end;
}

.message.assistant {
  justify-content: flex-start;
  padding-left: 4px;
}

.message-content {
  max-width: min(78%, 780px);
  padding: 13px 17px;
  border-radius: 12px;
  line-height: 1.62;
  word-wrap: break-word;
  word-break: break-word;
  overflow-wrap: break-word;
  white-space: normal;
  display: block;
}

.message.user .message-content {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border-bottom-right-radius: 4px;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.3);
  margin-left: auto;
}

.message.assistant .message-content {
  background: linear-gradient(180deg, #ffffff 0%, #fbfcff 100%);
  color: #1f2937;
  border: 1px solid #e5eaf2;
  border-bottom-left-radius: 6px;
  box-shadow: 0 4px 16px rgba(16, 24, 40, 0.065);
  margin-right: auto;
}

.message-text {
  display: block;
  word-wrap: break-word;
  word-break: break-word;
  overflow-wrap: break-word;
  white-space: normal;
}

.role-label {
  font-weight: 600;
  display: none;
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
  max-width: 68ch;
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
}

.markdown-body pre code {
  background: none;
  padding: 0;
  color: #e5e7eb;
  border: none;
  font-size: 0.87em;
  line-height: 1.6;
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
}

.markdown-body th,
.markdown-body td {
  border-bottom: 1px solid #edf1f5;
  padding: 9px 11px;
  text-align: left;
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

.loading {
  display: inline-flex;
  align-items: center;
  gap: 4px;
}

.loading::after {
  content: "";
  display: inline-block;
  width: 4px;
  height: 4px;
  animation: ellipsis 1.4s infinite;
  background: currentColor;
  border-radius: 50%;
}

@keyframes ellipsis {
  0%, 20%, 50%, 80%, 100% {
    opacity: 1;
  }
  40% {
    opacity: 0.5;
  }
  60% {
    opacity: 0.7;
  }
}

.input-area {
  border-top: 1px solid #e0e0e0;
  padding: 15px;
  background: white;
}

.input-group {
  display: flex;
  gap: 10px;
  align-items: flex-end;
}

.qa-input {
  flex: 1;
  padding: 10px 14px;
  border: 1px solid #ddd;
  border-radius: 6px;
  font-size: 0.95em;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  resize: none;
  max-height: 100px;
  outline: none;
  transition: border-color 0.2s;
}

.qa-input:focus {
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.send-btn {
  padding: 10px 20px;
  background: #667eea;
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 500;
  transition: all 0.2s;
  white-space: nowrap;
}

.send-btn:hover:not(:disabled) {
  background: #5568d3;
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
}

.send-btn:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.suggestions {
  margin-bottom: 12px;
  font-size: 0.9em;
  padding: 10px 12px;
  background: #f5f7ff;
  border-left: 3px solid #667eea;
  border-radius: 4px;
}

.suggest-label {
  color: #333;
  display: block;
  margin-bottom: 10px;
  font-weight: 500;
}

.suggest-label strong {
  color: #667eea;
}

.suggestion-buttons {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.sugg-btn {
  padding: 8px 12px;
  background: white;
  border: 1px solid #667eea;
  border-radius: 6px;
  cursor: pointer;
  font-size: 0.85em;
  transition: all 0.2s;
  color: #667eea;
  font-weight: 500;
}

.sugg-btn:hover {
  background: #667eea;
  color: white;
  box-shadow: 0 2px 8px rgba(102, 126, 234, 0.2);
}

.sugg-btn:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.species-panel {
  background: white;
  border: 1px solid #eee;
  border-radius: 8px;
  padding: 15px;
  height: fit-content;
}

.species-panel h3 {
  margin: 0 0 12px 0;
  font-size: 1em;
  color: #333;
}

.species-buttons-scroll {
  max-height: min(50vh, 380px);
  overflow-y: auto;
  padding-right: 4px;
  margin-right: -4px;
}

.species-buttons-scroll::-webkit-scrollbar {
  width: 6px;
}

.species-buttons-scroll::-webkit-scrollbar-thumb {
  background: #ccc;
  border-radius: 3px;
}

.species-buttons {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.species-btn {
  padding: 8px 10px;
  background: white;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.85em;
  transition: all 0.2s;
  text-align: left;
}

.species-btn:hover {
  background: #f0f0f0;
  border-color: #667eea;
}

.species-btn.active {
  background: #667eea;
  color: white;
  border-color: #667eea;
}

/* ============ Tab 3: 数据上报 ============ */
.report-container {
  display: grid;
  grid-template-columns: 0.85fr 1.15fr;
  gap: 20px;
  padding: 20px;
  min-height: 0;
  align-items: stretch;
  height: calc(100vh - 380px);
}

.report-section {
  background: white;
  padding: 20px;
  border-radius: 8px;
  border: 1px solid #eee;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.report-left-view {
  min-height: 0;
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
}

.report-section h3 {
  margin: 0 0 10px 0;
  color: #333;
}

.guide-text {
  margin: 0 0 20px 0;
  color: #666;
  font-size: 0.9em;
}

.form-area {
  display: flex;
  flex-direction: column;
  gap: 15px;
}

.geo-tools {
  display: flex;
  flex-direction: column;
  gap: 10px;
  margin-bottom: 12px;
}

.form-row {
  display: flex;
  gap: 10px;
  align-items: center;
}

.small-btn {
  padding: 8px 12px;
  border: 1px solid #ddd;
  border-radius: 6px;
  background: #fff;
  cursor: pointer;
  transition: background 0.2s;
}

.small-btn:hover {
  background: #f0f0f0;
}

.small-text {
  color: #666;
  font-size: 0.9em;
}

.map-and-records {
  display: flex;
  flex-direction: column;
  gap: 14px;
  height: 100%;
}

.report-map-container {
  width: 100%;
  height: 100%;
  flex: 1 1 auto;
  border: 1px solid #ddd;
  border-radius: 8px;
}

.form-group {
  display: flex;
  flex-direction: column;
}

.form-group label {
  margin-bottom: 6px;
  font-weight: 500;
  color: #333;
  font-size: 0.95em;
}

.form-input {
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 6px;
  font-size: 0.95em;
  font-family: inherit;
}

.form-input:focus {
  outline: none;
  border-color: #667eea;
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.coords-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}

.button-group {
  display: flex;
  gap: 10px;
}

.save-btn, .reset-btn {
  flex: 1;
  padding: 10px;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 500;
  transition: all 0.2s;
}

.save-btn {
  background: #667eea;
  color: white;
}

.save-btn:hover:not(:disabled) {
  background: #5568d3;
}

.save-btn:disabled {
  background: #ccc;
  cursor: not-allowed;
}

.reset-btn {
  background: #f0f0f0;
  color: #333;
}

.reset-btn:hover {
  background: #e0e0e0;
}

.message-box {
  padding: 12px;
  border-radius: 6px;
  text-align: center;
  font-size: 0.95em;
  animation: slideDown 0.3s ease;
}

@keyframes slideDown {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.message-box.success {
  background: #d4edda;
  color: #155724;
  border: 1px solid #c3e6cb;
}

.message-box.error {
  background: #f8d7da;
  color: #721c24;
  border: 1px solid #f5c6cb;
}

.collected-data {
  background: white;
  padding: 20px;
  border-radius: 8px;
  border: 1px solid #eee;
  margin-top: 0;
  min-height: 0;
  flex: 1 1 auto;
  display: flex;
  flex-direction: column;
}

.records-only {
  padding: 16px;
}

.toggle-left-view-btn {
  margin-top: 14px;
  width: 100%;
  border: 1px solid #667eea;
  background: #f4f6ff;
  color: #4a5ed0;
  border-radius: 8px;
  padding: 10px 12px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.toggle-left-view-btn:hover {
  background: #667eea;
  color: white;
}

.collected-data h3 {
  margin: 0 0 15px 0;
  color: #333;
}

.records-toolbar {
  display: grid;
  grid-template-columns: 1.1fr 1fr 1fr 0.8fr auto;
  gap: 8px;
  margin-bottom: 12px;
}

.toolbar-input {
  padding: 8px 10px;
}

.toolbar-order {
  min-width: 82px;
}

.records-table {
  overflow: auto;
  max-height: min(52vh, 520px);
  border: 1px solid #eee;
  border-radius: 6px;
}

.records-table::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

.records-table::-webkit-scrollbar-thumb {
  background: #c0c0c0;
  border-radius: 4px;
}

.records-table::-webkit-scrollbar-thumb:hover {
  background: #a7a7a7;
}

.records-table table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.9em;
  table-layout: fixed;
}

/* 在这里调整每一列默认宽度 */
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

.records-table thead {
  background: #f8f9fa;
}

.records-table thead th {
  position: sticky;
  top: 0;
  z-index: 1;
  background: #f8f9fa;
  opacity: 1;
}

.records-table th {
  padding: 10px;
  text-align: center;
  font-weight: 600;
  color: #333;
  border-bottom: 2px solid #ddd;
  background: #f8f9fa;
}

.records-table td {
  padding: 10px;
  border-bottom: 1px solid #eee;
  color: #666;
  vertical-align: top;
  word-break: break-word;
}

.records-table tbody tr:hover {
  background: #f8f9fa;
}

.records-table tbody tr {
  cursor: pointer;
}

.record-value {
  color: #666;
  word-break: break-word;
}

.empty-state {
  padding: 40px;
  text-align: center;
  color: #999;
  background: #f8f9fa;
  border-radius: 6px;
}

@media (max-width: 768px) {
  .map-analysis {
    flex-direction: column;
    height: auto;
  }

  .sidebar {
    width: 100%;
    border-right: none;
    border-bottom: 1px solid #eee;
    min-height: auto;
  }

  .qa-container {
    grid-template-columns: 1fr;
    min-height: auto;
    height: auto;
  }

  .report-container {
    grid-template-columns: 1fr;
    min-height: auto;
    height: auto;
  }

  .records-toolbar {
    grid-template-columns: 1fr 1fr;
  }

  .toggle-left-view-btn {
    margin-top: 12px;
  }

  .chat-wrapper {
    max-height: none;
  }

  .messages-container {
    max-height: 56vh;
    min-height: 42vh;
  }

  .records-table {
    max-height: 300px;
  }

  .coords-row {
    grid-template-columns: 1fr;
  }

  .app-header h1 {
    font-size: 1.8em;
  }

  .tabs-header {
    flex-wrap: wrap;
  }
}
</style>