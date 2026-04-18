import { ref, nextTick } from 'vue'
import DOMPurify from 'dompurify'
import { marked } from 'marked'

import { getJson, postJson } from '@/api/client'


marked.setOptions({
    breaks: true,
    gfm: true,
})

const normalizeZhSpacing = (text) => {
    return String(text || '')
        .replace(/\s+/g, ' ')
        .replace(/([\u4e00-\u9fff])\s+([\u4e00-\u9fff])/g, '$1$2')
        .replace(/([\u4e00-\u9fff])\s+([，。！；：、])/g, '$1$2')
        .replace(/([，。！；：、])\s+([\u4e00-\u9fff])/g, '$1$2')
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
    let inCodeFence = false

    const normalized = lines.map((rawLine) => {
        let line = rawLine
            .replace(/^[\u200E\u200F\u202A-\u202E\u2066-\u2069]+/g, '')
            .replace(/\u3000/g, ' ')
            .replace(/[ \t]+$/g, '')
        const trimmed = line.trim()

        if (!trimmed) return ''

        if (/^```/.test(trimmed)) {
            inCodeFence = !inCodeFence
            return line
        }

        if (inCodeFence) return line

        line = line
            .replace(/^(\s*)\\+([*+\-])(?=\s+)/, '$1$2')
            .replace(/^(\s*)\\+([#＃]{1,6})(?=\s|$)/, '$1$2')
            .replace(/^(\s*)[－—–﹣−](?=\s+)/, '$1-')
            .replace(/^(\s*)[•◆■□▪◦·](?=\s+)/, '$1-')
            .replace(/\\\*\\\*([^\n]+?)\\\*\\\*/g, '**$1**')
            .replace(/\\_([^\n]+?)\\_/g, '_$1_')
            .replace(/^[\t ]+([#＃]{1,6}\s+)/, '$1')
            .replace(/^\s{4,}([#＃]{1,6})(?=\s)/, '$1')
            .replace(/^(\s*)([#＃]{1,6})(?=\S)/, (_, lead, marks) => `${lead}${String(marks).replace(/＃/g, '#')} `)
            .replace(/^(\s*)([#＃]{1,6})(?=\s)/, (_, lead, marks) => `${lead}${String(marks).replace(/＃/g, '#')}`)

        return line
    })

    return normalized.join('\n').replace(/\n{3,}/g, '\n\n').trim()
}

const logMarkdownDiagnostics = (text) => {
    const value = String(text || '')
    const lines = value.split('\n')
    const suspects = []

    lines.forEach((line, idx) => {
        if (!/[#＃]/.test(line)) return
        if (/^\s*[#＃]{1,6}\s/.test(line)) return

        const head = line.slice(0, 10)
        const codepoints = [...head].map((ch) => `U+${ch.codePointAt(0).toString(16).toUpperCase().padStart(4, '0')}`)
        suspects.push({ line: idx + 1, preview: head, codepoints })
    })

    if (suspects.length > 0) {
        console.debug('[QA Markdown Diagnostics] 可疑标题行:', suspects)
    }
}

const shuffleInPlace = (items) => {
    const arr = [...items]
    for (let i = arr.length - 1; i > 0; i -= 1) {
        const j = Math.floor(Math.random() * (i + 1))
            ;[arr[i], arr[j]] = [arr[j], arr[i]]
    }
    return arr
}

export const useChatQa = () => {
    const chatMessages = ref([
        {
            id: 0,
            role: 'assistant',
            content: '你好！我是水生入侵生物科普助手，可以为您介绍各类入侵生物的分类、危害和防治方法。请问您想了解哪个物种？'
        }
    ])
    const isLoading = ref(false)
    const userInput = ref('')
    const chatSpecies = ref('')
    const allSuggestions = ref([])
    const randomQuestions = ref([])
    const lastSuggestedLabels = ref([])
    const lastMsgCountForRefresh = ref(-1)
    const lastSpeciesForRefresh = ref('')
    let msgId = 1

    const scrollToBottom = () => {
        nextTick(() => {
            const container = document.querySelector('.messages-container')
            if (container) {
                container.scrollTop = container.scrollHeight
            }
        })
    }

    const renderMarkdown = (content) => {
        if (!content) return ''
        try {
            const normalized = normalizeMarkdownForChat(content)
            return DOMPurify.sanitize(marked.parse(normalized))
        } catch (error) {
            console.error('Markdown渲染错误:', error)
            return DOMPurify.sanitize(String(content || ''))
        }
    }

    const loadSuggestions = async (species) => {
        try {
            const data = await getJson(`/qa/suggestions/${encodeURIComponent(species)}`)
            allSuggestions.value = (data.suggestions || []).map((q) => normalizeZhSpacing(q))
        } catch (error) {
            console.error('加载建议失败:', error)
            allSuggestions.value = []
        }
    }

    const refreshRandomQuestions = () => {
        if (allSuggestions.value.length === 0) return

        const availablePool = allSuggestions.value.filter((q) => !lastSuggestedLabels.value.includes(q))
        const finalPool = availablePool.length >= 2 ? availablePool : allSuggestions.value
        randomQuestions.value = shuffleInPlace(finalPool).slice(0, 2)
        lastSuggestedLabels.value = [...randomQuestions.value]
    }

    const selectChatSpecies = async (species) => {
        const normalizedSpecies = String(species || '').trim()
        chatSpecies.value = normalizedSpecies
        lastSpeciesForRefresh.value = normalizedSpecies
        await loadSuggestions(normalizedSpecies)
        refreshRandomQuestions()
        scrollToBottom()
    }

    const askQuestion = async (question) => {
        const normalizedQuestion = normalizeZhSpacing(question)
        if (!normalizedQuestion) return

        isLoading.value = true
        try {
            const data = await postJson('/qa', { question: normalizedQuestion })
            logMarkdownDiagnostics(data.answer)
            chatMessages.value.push({
                id: msgId++,
                role: 'assistant',
                content: data.answer || '无法获取回答，请检查后端连接。'
            })
            scrollToBottom()
        } catch (error) {
            chatMessages.value.push({
                id: msgId++,
                role: 'assistant',
                content: error?.message || '连接失败，请检查后端服务是否运行。'
            })
            scrollToBottom()
        } finally {
            isLoading.value = false
            const currentMsgCount = chatMessages.value.length
            if (currentMsgCount !== lastMsgCountForRefresh.value || lastSpeciesForRefresh.value !== chatSpecies.value) {
                lastMsgCountForRefresh.value = currentMsgCount
                if (chatSpecies.value && allSuggestions.value.length > 0) {
                    refreshRandomQuestions()
                }
            }
        }
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

    const clearChat = () => {
        chatMessages.value = [chatMessages.value[0]]
        msgId = 1
        scrollToBottom()
    }

    return {
        chatMessages,
        isLoading,
        userInput,
        chatSpecies,
        randomQuestions,
        renderMarkdown,
        refreshRandomQuestions,
        selectChatSpecies,
        sendMessage,
        sendPresetQuestion,
        clearChat,
    }
}
