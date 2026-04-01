<template>
  <div class="map-page">
    <h2>🌊 水生入侵生物分布图与问答</h2>
    
    <div class="qa-panel">
      <h3>🤖 知识问答</h3>
      <div class="chat-box">
        <div v-for="msg in messages" :key="msg.id" class="message" :class="msg.role">
          <strong>{{ msg.role === 'user' ? '你' : '助手' }}:</strong> {{ msg.content }}
        </div>
      </div>
      <input v-model="userQuestion" @keyup.enter="askQuestion" placeholder="输入问题..." class="qa-input">
      <button @click="askQuestion" class="qa-button">提问</button>
    </div>
    
    <div class="control-panel">
      <select v-model="selectedSpecies" @change="onSpeciesChange" class="species-select">
        <option value="">选择物种</option>
        <option v-for="species in speciesList" :key="species" :value="species">{{ species }}</option>
      </select>
      <span class="status-text">{{ selectedSpecies ? `已选择: ${selectedSpecies}` : '请选择物种查看分布' }}</span>
    </div>
    <div id="map"></div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

const speciesList = ref([]);
const selectedSpecies = ref("");
let map = null;
let markersLayer = null;

const messages = ref([{ role: 'assistant', content: '你好！我是入侵生物科普助手。你可以问我：福寿螺有什么危害？怎么防治鳄雀鳝？', id: 0 }]);
const userQuestion = ref('');
let msgId = 1;

const fetchSpeciesList = async () => {
  try {
    const response = await fetch('http://127.0.0.1:8000/api/species');
    const result = await response.json();
    if (response.ok) {
      speciesList.value = result.species;
    } else {
      console.error('获取物种列表失败:', result);
    }
  } catch (error) {
    console.error('网络错误:', error);
  }
};

const onSpeciesChange = async () => {
  if (!selectedSpecies.value) return;
  try {
    const response = await fetch(`http://127.0.0.1:8000/api/locations?species=${encodeURIComponent(selectedSpecies.value)}`);
    const result = await response.json();
    if (response.ok && result.locations) {
      markersLayer.clearLayers();
      result.locations.forEach(loc => {
        if (loc.lat && loc.lng) {
          L.marker([loc.lat, loc.lng]).addTo(markersLayer).bindPopup(loc.location);
        }
      });
    } else {
      console.error('获取位置失败:', result);
    }
  } catch (error) {
    console.error('网络错误:', error);
  }
};

const askQuestion = async () => {
  if (!userQuestion.value.trim()) return;
  const question = userQuestion.value;
  userQuestion.value = '';
  messages.value.push({ role: 'user', content: question, id: msgId++ });
  
  try {
    const response = await fetch('http://127.0.0.1:8000/api/qa', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ question })
    });
    const result = await response.json();
    if (response.ok) {
      messages.value.push({ role: 'assistant', content: result.answer, id: msgId++ });
    } else {
      messages.value.push({ role: 'assistant', content: `错误: ${result.detail || '未知错误'}`, id: msgId++ });
    }
  } catch (error) {
    messages.value.push({ role: 'assistant', content: '连接失败，请检查后端。', id: msgId++ });
  }
};

onMounted(() => {
  map = L.map('map').setView([35.0, 105.0], 4);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap contributors'
  }).addTo(map);
  markersLayer = L.layerGroup().addTo(map);
  fetchSpeciesList();
});
</script>

<style scoped>
.map-page {
  padding: 20px;
  max-width: 1200px;
  margin: 0 auto;
}

.control-panel {
  background-color: #f8f9fa;
  padding: 15px 20px;
  border-radius: 8px;
  margin-bottom: 20px;
  box-shadow: 0 2px 4px rgba(0,0,0,0.05);
  display: flex;
  align-items: center;
  gap: 15px;
}

.species-select {
  padding: 8px 12px;
  border-radius: 4px;
  border: 1px solid #ccc;
  font-size: 16px;
  min-width: 200px;
}

.status-text {
  color: #666;
  font-size: 14px;
}

#map {
  height: 700px;
  width: 100%;
  border-radius: 12px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
  z-index: 1;
}

.qa-panel {
  background-color: #f8f9fa;
  padding: 15px;
  border-radius: 8px;
  margin-bottom: 20px;
}

.chat-box {
  max-height: 200px;
  overflow-y: auto;
  margin-bottom: 10px;
}

.message {
  margin: 5px 0;
  padding: 8px;
  border-radius: 4px;
}

.message.user { background-color: #e3f2fd; }
.message.assistant { background-color: #f1f8e9; }

.qa-input {
  width: 70%;
  padding: 8px;
  margin-right: 10px;
}

.qa-button {
  padding: 8px 16px;
  background-color: #007bff;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
}
</style>