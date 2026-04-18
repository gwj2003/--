import { createApp } from 'vue'
import LegacyCaseFeaturePage from '@/legacy/LegacyCaseFeaturePage.vue'

export function mountCaseFeaturePage(props) {
    createApp(LegacyCaseFeaturePage, props).mount('#app')
}
