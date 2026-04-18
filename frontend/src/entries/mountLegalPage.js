import { createApp } from 'vue'
import LegacyLegalPage from '@/legacy/LegacyLegalPage.vue'

export function mountLegalPage(rawHtml, page) {
    createApp(LegacyLegalPage, { rawHtml, page }).mount('#app')
}
