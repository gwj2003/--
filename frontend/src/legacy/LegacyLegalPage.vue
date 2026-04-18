<script setup>
import { computed, nextTick, onMounted } from 'vue'
import LegacyBreadcrumb from '@/legacy/components/LegacyBreadcrumb.vue'
import LegacyFooter from '@/legacy/components/LegacyFooter.vue'
import LegacyNavbar from '@/legacy/components/LegacyNavbar.vue'

const props = defineProps({
  rawHtml: {
    type: String,
    required: true,
  },
  page: {
    type: String,
    required: true,
    validator: (value) => ['privacy', 'terms'].includes(value),
  },
})

const pageTitleMap = {
  privacy: '隐私说明',
  terms: '服务条款',
}

const fallbackScriptSources = [
  '/js/jquery.min.js',
  '/js/popper.min.js',
  '/js/bootstrap.min.js',
  '/js/jquery.easing.min.js',
  '/js/swiper.min.js',
  '/js/jquery.magnific-popup.js',
  '/js/morphext.min.js',
  '/js/isotope.pkgd.min.js',
  '/js/validator.min.js',
  '/js/scripts.js',
]

function normalizeScriptSrc(src) {
  if (!src) {
    return ''
  }

  if (/^https?:\/\//i.test(src)) {
    return src
  }

  if (src.startsWith('/')) {
    return src
  }

  return `/${src.replace(/^\.\//, '')}`
}

const parsedPage = computed(() => {
  const parser = new DOMParser()
  const doc = parser.parseFromString(props.rawHtml, 'text/html')

  const scriptElements = Array.from(doc.querySelectorAll('script[src]'))
  const extractedScriptSources = scriptElements
    .map((script) => normalizeScriptSrc(script.getAttribute('src') || ''))
    .filter(Boolean)

  const bodyAttributes = {}
  for (const attr of Array.from(doc.body.attributes)) {
    bodyAttributes[attr.name] = attr.value
  }

  const contentSection = doc.querySelector('.ex-basic-2')
  const mainContentHtml = contentSection ? contentSection.outerHTML : ''

  return {
    title: doc.title || '',
    bodyAttributes,
    mainContentHtml,
    scriptSources: extractedScriptSources.length > 0 ? extractedScriptSources : fallbackScriptSources,
  }
})

const mainContentHtml = computed(() => parsedPage.value.mainContentHtml)

function hasScript(src) {
  const absSrc = new URL(src, window.location.origin).href
  return Array.from(document.scripts).some((script) => script.src === absSrc)
}

function loadScript(src) {
  if (hasScript(src)) {
    return Promise.resolve()
  }

  return new Promise((resolve, reject) => {
    const script = document.createElement('script')
    script.src = src
    script.async = false
    script.onload = () => resolve()
    script.onerror = () => reject(new Error(`Failed to load script: ${src}`))
    document.body.appendChild(script)
  })
}

async function loadLegacyScripts() {
  for (const src of parsedPage.value.scriptSources) {
    await loadScript(src)
  }
}

onMounted(async () => {
  const { bodyAttributes } = parsedPage.value
  document.title = `${pageTitleMap[props.page]} - 中国水生动物入侵智能化平台`

  document.body.removeAttribute('data-spy')
  document.body.removeAttribute('data-target')
  for (const [key, value] of Object.entries(bodyAttributes)) {
    document.body.setAttribute(key, value)
  }

  await nextTick()
  await loadLegacyScripts()

  const spinner = document.querySelector('.spinner-wrapper')
  if (spinner) {
    setTimeout(() => {
      spinner.style.display = 'none'
    }, 700)
  }
})
</script>

<template>
  <div class="spinner-wrapper">
    <div class="spinner">
      <div class="bounce1"></div>
      <div class="bounce2"></div>
      <div class="bounce3"></div>
    </div>
  </div>

  <LegacyNavbar />
  <LegacyBreadcrumb :page="page" />

  <div v-html="mainContentHtml"></div>

  <LegacyBreadcrumb :page="page" />
  <LegacyFooter />
</template>

<style>
html,
body,
#app {
  width: 100%;
}
</style>
