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

      <!-- Tab 1: 分布识别分析 -->
      <div v-if="activeTab === 0" class="tab-content">
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
      <div v-if="activeTab === 1" class="tab-content">
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
                  <span>{{ msg.content }}</span>
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
                    @click="askQuestion(q)"
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
            <div class="species-buttons">
              <button 
                v-for="sp in speciesList.slice(0, 8)" 
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

      <!-- Tab 3: 数据上报与更新 -->
      <div v-if="activeTab === 2" class="tab-content">
        <div class="report-container">
          <div class="report-section">
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

            <div class="collected-data">
              <h3>📊 已收集的记录</h3>
              <div v-if="allRecords.length > 0" class="records-table">
                <table>
                  <thead>
                    <tr>
                      <th>物种</th>
                      <th>位置</th>
                      <th>坐标</th>
                      <th>日期</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr v-for="(record, idx) in allRecords" :key="idx">
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
import { ref, computed, onMounted, watch } from 'vue'
import L from 'leaflet'
import 'leaflet/dist/leaflet.css'
import 'leaflet.heat' // 需要安装 leaflet.heat 插件

const API_BASE = 'http://localhost:8000/api'

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
const allRecords = ref([])
let reportMap = null
let reportMapMarker = null
let reportTileLayer = null  // Tab3的底图图层
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

// =============== 初始化和加载数据 ===============
onMounted(async () => {
  await loadSpeciesList()
  await loadAllRecords()
})

watch(() => activeTab.value, (newTab) => {
  if (newTab === 0 && !map) {
    // 延迟初始化以确保 DOM 已渲染
    setTimeout(initMap, 100)
  }
  if (newTab === 2 && !reportMap) {
    setTimeout(initReportMap, 100)
  }
})

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
  if (selectedBasemap.value === 'osm') {
    tileLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors',
      maxZoom: 18
    }).addTo(map)
  } else if (selectedBasemap.value === 'esri') {
    tileLayer = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
      attribution: 'Tiles &copy; Esri &mdash; Source: Esri, i-cubed, USDA, USGS, AEX, GeoEye, Getmapping, Aerogrid, IGN, IGP, UPR-EGP, and the GIS User Community',
      maxZoom: 18
    }).addTo(map)
  } else if (selectedBasemap.value === 'gaode_satellite') {
    tileLayer = L.tileLayer('https://webst02.is.autonavi.com/appmaptile?style=6&x={x}&y={y}&z={z}', {
      attribution: 'Tiles &copy; 高德地图 AMap',
      maxZoom: 18
    }).addTo(map)
  } else if (selectedBasemap.value === 'gaode_satellite_annotated') {
    tileLayer = L.tileLayer('https://webst02.is.autonavi.com/appmaptile?style=8&x={x}&y={y}&z={z}', {
      attribution: 'Tiles &copy; 高德地图 AMap',
      maxZoom: 18
    }).addTo(map)
  }
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
  try {
    const response = await fetch(`${API_BASE}/heatmap/${encodeURIComponent(selectedSpecies.value || 'all')}`)
    const data = await response.json()
    const points = data.points || []
    if (points.length === 0) {
      console.warn('热力图数据为空')
      return
    }
    heatLayer = L.heatLayer(points, { radius: 25 }).addTo(map)
    const latLngs = points.map((p) => [p[0], p[1]])
    map.fitBounds(L.latLngBounds(latLngs))
  } catch (error) {
    console.error('加载热力图数据失败:', error)
  }
}

const loadProvinceData = async () => {
  try {
    const response = await fetch(`${API_BASE}/province-data/${encodeURIComponent(selectedSpecies.value || 'all')}`)
    const data = await response.json()
    const geojson = data.geojson
    provinceLayer = L.geoJSON(geojson, {
      style: (feature) => ({
        fillColor: getColor(feature.properties.count),
        weight: 2,
        opacity: 1,
        color: 'white',
        dashArray: '3',
        fillOpacity: 0.7
      }),
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
  reportMap = L.map('report-map').setView([31.2304, 121.4737], 5)

  changeReportBasemap()

  reportMap.on('click', async (e) => {
    const { lat, lng } = e.latlng
    reportForm.value.latitude = parseFloat(lat.toFixed(6))
    reportForm.value.longitude = parseFloat(lng.toFixed(6))
    reportForm.value.location_name = `经纬度：${reportForm.value.longitude}, ${reportForm.value.latitude}`
    setReportMarker(reportForm.value.latitude, reportForm.value.longitude)

    try {
      const r = await fetch(`${API_BASE}/reverse-geocode?lat=${reportForm.value.latitude}&lon=${reportForm.value.longitude}`)
      const json = await r.json()
      if (json.address) {
        reportForm.value.location_name = json.address
      }
    } catch (err) {
      console.error('逆向地理编码失败', err)
      // 保持经纬度显示，可视为无地址情况
      reportForm.value.location_name = `经纬度：${reportForm.value.longitude}, ${reportForm.value.latitude}`
    }
  })
}

const changeReportBasemap = () => {
  if (reportTileLayer) {
    reportMap.removeLayer(reportTileLayer)
  }
  if (reportBasemap.value === 'osm') {
    reportTileLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap contributors',
      maxZoom: 18
    }).addTo(reportMap)
  } else if (reportBasemap.value === 'esri') {
    reportTileLayer = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
      attribution: 'Tiles &copy; Esri',
      maxZoom: 18
    }).addTo(reportMap)
  } else if (reportBasemap.value === 'gaode_satellite') {
    reportTileLayer = L.tileLayer('https://webst02.is.autonavi.com/appmaptile?style=6&x={x}&y={y}&z={z}', {
      attribution: 'Tiles &copy; 高德地图 AMap',
      maxZoom: 18
    }).addTo(reportMap)
  } else if (reportBasemap.value === 'gaode_satellite_annotated') {
    reportTileLayer = L.tileLayer('https://webst02.is.autonavi.com/appmaptile?style=8&x={x}&y={y}&z={z}', {
      attribution: 'Tiles &copy; 高德地图 AMap',
      maxZoom: 18
    }).addTo(reportMap)
  }
}

const setReportMarker = (lat, lng) => {
  if (!reportMap) return
  if (reportMapMarker) {
    reportMap.removeLayer(reportMapMarker)
  }
  reportMapMarker = L.marker([lat, lng]).addTo(reportMap)
  reportMap.setView([lat, lng], 10)
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
  return d > 100 ? '#800026' :
         d > 50  ? '#BD0026' :
         d > 20  ? '#E31A1C' :
         d > 10  ? '#FC4E2A' :
         d > 5   ? '#FD8D3C' :
         d > 0   ? '#FEB24C' :
                   '#FFEDA0'
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
    allSuggestions.value = data.suggestions || []
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
  chatSpecies.value = species
  lastSpeciesForRefresh.value = species
  await loadSuggestions(species)
  refreshRandomQuestions()
}

const sendMessage = () => {
  if (!userInput.value.trim()) return
  
  const question = userInput.value
  userInput.value = ''
  
  chatMessages.value.push({
    id: msgId++,
    role: 'user',
    content: question
  })
  
  askQuestion(question)
}

const askQuestion = async (question) => {
  isLoading.value = true
  
  try {
    const response = await fetch(`${API_BASE}/qa`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ question })
    })
    const data = await response.json()
    
    chatMessages.value.push({
      id: msgId++,
      role: 'assistant',
      content: data.answer || '无法获取回答，请检查后端连接'
    })
  } catch (error) {
    chatMessages.value.push({
      id: msgId++,
      role: 'assistant',
      content: '连接失败，请检查后端服务是否运行'
    })
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
    const data = await response.json()
    
    if (data.status === 'success') {
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
      reportMessage.value = '❌ 保存失败：' + (data.message || '未知错误')
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
</script>

<style scoped>
* {
  box-sizing: border-box;
}

.home-container {
  min-height: 100vh;
  background: #f5f7fa;
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
  min-height: 600px;
}

.chat-wrapper {
  display: flex;
  flex-direction: column;
  background: white;
  border-radius: 8px;
  border: 1px solid #eee;
  overflow: hidden;
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
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.message {
  display: flex;
  margin: 0;
}

.message.user {
  justify-content: flex-end;
}

.message.assistant {
  justify-content: flex-start;
}

.message-content {
  max-width: 80%;
  padding: 10px 14px;
  border-radius: 8px;
  display: flex;
  gap: 8px;
}

.message.user .message-content {
  background: #667eea;
  color: white;
}

.message.assistant .message-content {
  background: #f0f0f0;
  color: #333;
}

.role-label {
  font-weight: 600;
  white-space: nowrap;
}

.loading {
  animation: blink 1.4s infinite;
}

@keyframes blink {
  0%, 20%, 50%, 80%, 100% { opacity: 1; }
  40% { opacity: 0.5; }
  60% { opacity: 0.7; }
}

.input-area {
  border-top: 1px solid #eee;
  padding: 15px;
  background: #fafbfc;
}

.suggestions {
  margin-bottom: 12px;
  font-size: 0.9em;
}

.suggest-label {
  color: #666;
  display: block;
  margin-bottom: 8px;
}

.suggestion-buttons {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.sugg-btn {
  padding: 6px 12px;
  background: white;
  border: 1px solid #ddd;
  border-radius: 4px;
  cursor: pointer;
  font-size: 0.85em;
  transition: all 0.2s;
}

.sugg-btn:hover {
  background: #667eea;
  color: white;
  border-color: #667eea;
}

.input-group {
  display: flex;
  gap: 10px;
}

.qa-input {
  flex: 1;
  padding: 10px;
  border: 1px solid #ddd;
  border-radius: 6px;
  font-size: 0.95em;
}

.send-btn {
  padding: 10px 20px;
  background: #667eea;
  color: white;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-weight: 500;
  transition: background 0.2s;
}

.send-btn:hover:not(:disabled) {
  background: #5568d3;
}

.send-btn:disabled {
  background: #ccc;
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
  min-height: 00px;
  align-items: stretch;
  height: calc(100vh - 380px);
}

.report-section {
  background: white;
  padding: 20px;
  border-radius: 8px;
  border: 1px solid #eee;
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
}

.collected-data h3 {
  margin: 0 0 15px 0;
  color: #333;
}

.records-table {
  overflow-x: auto;
}

.records-table table {
  width: 100%;
  border-collapse: collapse;
  font-size: 0.9em;
}

.records-table thead {
  background: #f8f9fa;
}

.records-table th {
  padding: 10px;
  text-align: left;
  font-weight: 600;
  color: #333;
  border-bottom: 2px solid #ddd;
}

.records-table td {
  padding: 10px;
  border-bottom: 1px solid #eee;
  color: #666;
}

.records-table tbody tr:hover {
  background: #f8f9fa;
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
  }

  .report-container {
    grid-template-columns: 1fr;
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