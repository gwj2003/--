import { ref, nextTick, watch } from 'vue'
import L from 'leaflet'
import 'leaflet.heat'

import { getJson } from '@/api/client'
import { applyBasemap } from '@/utils/maps'


export const useSpeciesMap = (activeTab) => {
  const selectedSpecies = ref('')
  const selectedBasemap = ref('gaode_satellite')
  const selectedLayer = ref('points')
  const currentLocations = ref([])

  let map = null
  let markersLayer = null
  let tileLayer = null
  let heatLayer = null
  let provinceLayer = null
  let maxentLayer = null

  const initMap = () => {
    if (map) return

    map = L.map('map').setView([35, 105], 4)
    markersLayer = L.layerGroup().addTo(map)
    changeBasemap()
    changeLayer()
  }

  const changeBasemap = () => {
    tileLayer = applyBasemap(map, tileLayer, selectedBasemap.value)
  }

  const clearDataLayers = () => {
    if (markersLayer && map?.hasLayer(markersLayer)) map.removeLayer(markersLayer)
    if (heatLayer && map?.hasLayer(heatLayer)) map.removeLayer(heatLayer)
    if (provinceLayer && map?.hasLayer(provinceLayer)) map.removeLayer(provinceLayer)
    if (maxentLayer && map?.hasLayer(maxentLayer)) map.removeLayer(maxentLayer)
  }

  const CHINA_BOUNDS = L.latLngBounds([
    [18.0, 73.0],
    [54.0, 135.0]
  ])

  const fitToCurrentSpeciesBounds = () => {
    if (!map) return
    const valid = (currentLocations.value || []).filter(
      (point) => Number.isFinite(point.latitude) && Number.isFinite(point.longitude)
    )
    if (!valid.length) return
    const bounds = L.latLngBounds(valid.map((point) => [point.latitude, point.longitude]))
    if (bounds.isValid()) {
      map.fitBounds(bounds)
    }
  }

  const fitToChinaBounds = () => {
    if (!map) return
    if (!CHINA_BOUNDS.isValid()) return
    map.fitBounds(CHINA_BOUNDS)
  }

  const updatePoints = () => {
    if (!markersLayer) return
    markersLayer.clearLayers()

    currentLocations.value.forEach((loc) => {
      if (loc.latitude && loc.longitude) {
        L.circleMarker([loc.latitude, loc.longitude], {
          radius: 5,
          fillColor: '#ff6b6b',
          color: '#d63031',
          weight: 2,
          opacity: 0.7,
          fillOpacity: 0.6
        })
          .addTo(markersLayer)
          .bindPopup(loc.location_name || `${loc.latitude.toFixed(4)}, ${loc.longitude.toFixed(4)}`)
      }
    })
  }

  const loadHeatmapData = async () => {
    if (!selectedSpecies.value) return
    try {
      const data = await getJson(`/heatmap/${encodeURIComponent(selectedSpecies.value)}`)
      const points = data.points || []
      if (points.length === 0) return
      heatLayer = L.heatLayer(points, {
        radius: 20,
        blur: 15,
        maxZoom: 10,
        max: 1.0,
        gradient: {
          0.2: '#0000ff',
          0.4: '#00ffff',
          0.6: '#00ff00',
          0.8: '#ffff00',
          1.0: '#ff0000'
        }
      }).addTo(map)
    } catch (error) {
      console.error('加载热力图数据失败:', error)
    }
  }

  const getColor = (d) => {
    return d > 50 ? '#800026' :
      d > 20 ? '#BD0026' :
        d > 10 ? '#E31A1C' :
          d > 5 ? '#FC4E2A' :
            d > 2 ? '#FD8D3C' :
              '#FEB24C'
  }

  const loadProvinceData = async () => {
    if (!selectedSpecies.value) return
    try {
      const data = await getJson(`/province-data/${encodeURIComponent(selectedSpecies.value)}`)
      provinceLayer = L.geoJSON(data.geojson, {
        style: (feature) => {
          const count = feature.properties.count
          return {
            fillColor: count > 0 ? getColor(count) : '#f4f4f4',
            weight: 1,
            opacity: 1,
            color: count > 0 ? 'white' : '#ddd',
            dashArray: '3',
            fillOpacity: count > 0 ? 0.8 : 0.3
          }
        },
        onEachFeature: (feature, layer) => {
          layer.bindPopup(`${feature.properties.name}: ${feature.properties.count} 记录`)
        }
      }).addTo(map)
    } catch (error) {
      console.error('加载省级数据失败:', error)
    }
  }

  const loadMaxentData = async () => {
    if (!selectedSpecies.value) return
    try {
      const data = await getJson(`/maxent-image/${encodeURIComponent(selectedSpecies.value)}`)
      if (!data.imageUrl || !data.bounds) return
      maxentLayer = L.imageOverlay(data.imageUrl, data.bounds, { opacity: 0.6 }).addTo(map)
    } catch (error) {
      console.error('加载MaxEnt数据失败:', error)
    }
  }

  const changeLayer = async () => {
    if (!map) return
    clearDataLayers()

    if (selectedLayer.value === 'points') {
      markersLayer = L.layerGroup().addTo(map)
      updatePoints()
      fitToCurrentSpeciesBounds()
    } else if (selectedLayer.value === 'heatmap') {
      await loadHeatmapData()
      fitToCurrentSpeciesBounds()
    } else if (selectedLayer.value === 'province') {
      await loadProvinceData()
      fitToChinaBounds()
    } else if (selectedLayer.value === 'maxent') {
      await loadMaxentData()
      fitToCurrentSpeciesBounds()
    }
  }

  const onSpeciesChange = async () => {
    if (!selectedSpecies.value) {
      currentLocations.value = []
      changeLayer()
      return
    }

    try {
      const data = await getJson(`/locations/${encodeURIComponent(selectedSpecies.value)}`)
      currentLocations.value = data.locations || []
      changeLayer()
    } catch (error) {
      console.error('加载位置失败:', error)
    }
  }

  watch(
    () => activeTab.value,
    (newTab) => {
      if (newTab !== 0) return
      nextTick(() => {
        setTimeout(() => {
          if (activeTab.value !== 0) return
          if (!map) initMap()
          else map.invalidateSize(true)
        }, 100)
      })
    },
    { immediate: true }
  )

  return {
    selectedSpecies,
    selectedBasemap,
    selectedLayer,
    currentLocations,
    changeBasemap,
    changeLayer,
    onSpeciesChange,
  }
}
