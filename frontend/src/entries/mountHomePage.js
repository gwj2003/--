import { createApp } from 'vue'
import LegacyPage from '@/legacy/LegacyPage.vue'

export function mountHomePage(rawHtml) {
    createApp(LegacyPage, { rawHtml }).mount('#app')
}
