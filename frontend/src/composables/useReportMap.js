import { computed, nextTick, ref, watch } from 'vue'
import L from 'leaflet'

import { getJson, postJson } from '@/api/client'
import { geocodeAddress, reverseGeocodeCoords } from '@/api/geocoding'
import { applyBasemap } from '@/utils/maps'


const today = () => new Date().toISOString().split('T')[0]

const defaultReportForm = () => ({
  species: '',
  location_name: '',
  latitude: null,
  longitude: null,
  date: today()
})

const getRecordMarkerKey = (record) =>
  `${record.species || ''}|${record.date || ''}|${Number(record.latitude).toFixed(6)}|${Number(record.longitude).toFixed(6)}`

export const useReportMap = (activeTab) => {
  const reportForm = ref(defaultReportForm())
  const reportMessage = ref('')
  const reportMessageType = ref('success')
  const reportLeftView = ref('form')
  const allRecords = ref([])
  const recordFilterSpecies = ref('')
  const recordFilterDate = ref('')
  const recordSortField = ref('date')
  const recordSortOrder = ref('desc')
  const reportBasemap = ref('gaode_satellite')

  const canSave = computed(() =>
    reportForm.value.species &&
    reportForm.value.location_name &&
    reportForm.value.latitude !== null &&
    reportForm.value.longitude !== null
  )

  const reportLeftToggleLabel = computed(() =>
    reportLeftView.value === 'form' ? '切换为 已收集的记录' : '切换为 新增物种分布记录'
  )

  const filteredSortedRecords = computed(() => {
    const rows = allRecords.value.filter((row) => {
      const bySpecies = !recordFilterSpecies.value || row.species === recordFilterSpecies.value
      const byDate = !recordFilterDate.value || String(row.date || '').startsWith(recordFilterDate.value)
      return bySpecies && byDate
    })

    rows.sort((a, b) => {
      const field = recordSortField.value
      let result = 0

      if (field === 'date') {
        result = new Date(a.date || '1970-01-01').getTime() - new Date(b.date || '1970-01-01').getTime()
      } else {
        result = String(a[field] || '').localeCompare(String(b[field] || ''), 'zh-CN')
      }

      return recordSortOrder.value === 'asc' ? result : -result
    })

    return rows
  })

  let reportMap = null
  let reportMapMarker = null
  let reportTileLayer = null
  let reportRecordsLayer = null
  let reportReverseGeocodeTimer = null
  let reportRecordMarkerMap = new Map()

  const setReportMarker = (lat, lng) => {
    if (!reportMap || reportLeftView.value !== 'form') return

    if (reportMapMarker) {
      reportMap.removeLayer(reportMapMarker)
    }

    reportMapMarker = L.marker([lat, lng]).addTo(reportMap)
    reportMap.setView([lat, lng], 10)
  }

  const changeReportBasemap = () => {
    reportTileLayer = applyBasemap(reportMap, reportTileLayer, reportBasemap.value)
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

    const validRows = (records || []).filter((row) => Number.isFinite(row.latitude) && Number.isFinite(row.longitude))
    validRows.forEach((row) => {
      const marker = L.circleMarker([row.latitude, row.longitude], {
        radius: 6,
        fillColor: '#1f7ae0',
        color: '#0e4f99',
        weight: 1,
        opacity: 0.95,
        fillOpacity: 0.82
      })

      marker.bindPopup(`
        <div style="min-width: 180px; line-height: 1.5;">
          <div><strong>物种：</strong>${row.species || '-'}</div>
          <div><strong>位置：</strong>${row.location_name || '-'}</div>
          <div><strong>坐标：</strong>${Number(row.latitude).toFixed(6)}, ${Number(row.longitude).toFixed(6)}</div>
          <div><strong>日期：</strong>${row.date || '-'}</div>
        </div>
      `)

      marker.addTo(reportRecordsLayer)
      reportRecordMarkerMap.set(getRecordMarkerKey(row), marker)
    })

    fitReportBounds(validRows)
  }

  const fitReportBounds = (records) => {
    if (!reportMap) return
    const validRows = (records || []).filter((row) => Number.isFinite(row.latitude) && Number.isFinite(row.longitude))
    if (!validRows.length) return
    const bounds = L.latLngBounds(validRows.map((row) => [row.latitude, row.longitude]))
    if (bounds.isValid()) {
      reportMap.fitBounds(bounds, { padding: [20, 20] })
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
    if (!reportForm.value.location_name?.trim()) return
    try {
      const data = await geocodeAddress(reportForm.value.location_name)
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
      const data = await reverseGeocodeCoords(reportForm.value.latitude, reportForm.value.longitude)
      if (data.address) {
        reportForm.value.location_name = data.address
      }
    } catch (error) {
      console.error('逆向地理编码失败:', error)
    }
  }

  const loadAllRecords = async () => {
    try {
      const data = await getJson('/records')
      allRecords.value = (data.records || []).map((row) => ({
        ...row,
        latitude: parseFloat(row.latitude),
        longitude: parseFloat(row.longitude)
      }))
    } catch (error) {
      console.error('加载记录失败:', error)
      allRecords.value = []
    }
  }

  const initReportMap = () => {
    if (reportMap) return

    reportMap = L.map('report-map').setView([35.0, 105.0], 4)
    reportRecordsLayer = L.layerGroup().addTo(reportMap)
    changeReportBasemap()
    updateReportMapByView()

    reportMap.on('click', (event) => {
      if (reportLeftView.value !== 'form') return

      const { lat, lng } = event.latlng
      reportForm.value.latitude = parseFloat(lat.toFixed(6))
      reportForm.value.longitude = parseFloat(lng.toFixed(6))
      reportForm.value.location_name = `经纬度解析中... (${reportForm.value.longitude}, ${reportForm.value.latitude})`
      setReportMarker(reportForm.value.latitude, reportForm.value.longitude)

      if (reportReverseGeocodeTimer) {
        clearTimeout(reportReverseGeocodeTimer)
      }

      reportReverseGeocodeTimer = setTimeout(async () => {
        try {
          const data = await reverseGeocodeCoords(reportForm.value.latitude, reportForm.value.longitude)
          reportForm.value.location_name =
            data.address || `经纬度：${reportForm.value.longitude}, ${reportForm.value.latitude}`
        } catch (error) {
          console.error('逆向地理编码失败', error)
          reportForm.value.location_name = `经纬度：${reportForm.value.longitude}, ${reportForm.value.latitude}`
        }
      }, 1000)
    })
  }

  const focusRecordOnMap = (record) => {
    if (reportLeftView.value !== 'records') return

    const lat = Number(record?.latitude)
    const lng = Number(record?.longitude)
    if (!reportMap || !Number.isFinite(lat) || !Number.isFinite(lng)) return

    reportMap.flyTo([lat, lng], Math.max(reportMap.getZoom(), 9), { duration: 0.6 })
    reportRecordMarkerMap.get(getRecordMarkerKey(record))?.openPopup()
  }

  const saveLocation = async () => {
    if (!canSave.value) {
      reportMessage.value = '请填写所有必填项'
      reportMessageType.value = 'error'
      return
    }

    try {
      const data = await postJson('/record/location', reportForm.value)
      if (data?.status === 'success') {
        reportMessage.value = '记录保存成功，感谢您的贡献。'
        reportMessageType.value = 'success'
        if (reportForm.value.latitude !== null && reportForm.value.longitude !== null) {
          setReportMarker(reportForm.value.latitude, reportForm.value.longitude)
        }
        resetForm()
        await loadAllRecords()
        setTimeout(() => {
          reportMessage.value = ''
        }, 3000)
        return
      }

      reportMessage.value = data?.message || '保存失败'
      reportMessageType.value = 'error'
    } catch (error) {
      reportMessage.value = `保存失败: ${error.message}`
      reportMessageType.value = 'error'
    }
  }

  const resetForm = () => {
    reportForm.value = defaultReportForm()
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

  watch(
    () => activeTab.value,
    (newTab) => {
      if (newTab !== 2) return
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

  return {
    reportForm,
    reportMessage,
    reportMessageType,
    reportLeftView,
    allRecords,
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
  }
}
