import { getJson } from './client'

export const geocodeAddress = (address) => getJson('/geocode', { address })

export const reverseGeocodeCoords = (lat, lon) =>
    getJson('/reverse-geocode', { lat, lon })
