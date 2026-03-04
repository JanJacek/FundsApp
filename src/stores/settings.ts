import { defineStore } from 'pinia'
import { ref } from 'vue'

const STORAGE_KEY = 'fundsapp.display_currency'
const AVAILABLE_CURRENCIES = ['PLN', 'EUR', 'USD', 'GBP'] as const

type DisplayCurrency = (typeof AVAILABLE_CURRENCIES)[number]

export const useSettingsStore = defineStore('settings', () => {
  const displayCurrency = ref<DisplayCurrency>('PLN')

  const load = () => {
    if (typeof window === 'undefined') return

    const saved = window.localStorage.getItem(STORAGE_KEY)
    if (!saved) return
    if (AVAILABLE_CURRENCIES.includes(saved as DisplayCurrency)) {
      displayCurrency.value = saved as DisplayCurrency
    }
  }

  const setDisplayCurrency = (currency: string) => {
    if (!AVAILABLE_CURRENCIES.includes(currency as DisplayCurrency)) return

    displayCurrency.value = currency as DisplayCurrency
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(STORAGE_KEY, displayCurrency.value)
    }
  }

  load()

  return {
    displayCurrency,
    availableCurrencies: AVAILABLE_CURRENCIES,
    setDisplayCurrency,
  }
})
