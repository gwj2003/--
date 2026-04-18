const API_BASE = '/api'

export class ApiError extends Error {
    constructor(message, { status = 500, data = null, text = '' } = {}) {
        super(message)
        this.name = 'ApiError'
        this.status = status
        this.data = data
        this.text = text
    }
}

const normalizeErrorMessage = (data, fallback) => {
    if (data?.error?.message != null) {
        const message = data.error.message
        return Array.isArray(message) ? JSON.stringify(message) : String(message)
    }
    if (data?.detail != null) return String(data.detail)
    return fallback
}

const buildUrl = (path, query) => {
    const url = new URL(`${API_BASE}${path}`, window.location.origin)
    Object.entries(query || {}).forEach(([key, value]) => {
        if (value == null || value === '') return
        url.searchParams.set(key, String(value))
    })
    return `${url.pathname}${url.search}`
}

const parseBody = async (response) => {
    const text = await response.text()
    if (!text) return { data: null, text: '' }
    try {
        return { data: JSON.parse(text), text }
    } catch {
        return { data: null, text }
    }
}

export const requestJson = async (path, { method = 'GET', query, body, headers } = {}) => {
    const response = await fetch(buildUrl(path, query), {
        method,
        headers: {
            ...(body != null ? { 'Content-Type': 'application/json' } : {}),
            ...(headers || {})
        },
        body: body != null ? JSON.stringify(body) : undefined
    })

    const { data, text } = await parseBody(response)
    if (!response.ok) {
        throw new ApiError(normalizeErrorMessage(data, text || `HTTP ${response.status}`), {
            status: response.status,
            data,
            text
        })
    }

    return data
}

export const getJson = (path, query) => requestJson(path, { query })
export const postJson = (path, body) => requestJson(path, { method: 'POST', body })
