import { defineStore } from 'pinia'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'
import { ref } from 'vue'

const STORAGE_KEY = 'fundsapp.display_currency'
const AVAILABLE_CURRENCIES = ['PLN', 'EUR', 'USD', 'GBP'] as const

type DisplayCurrency = (typeof AVAILABLE_CURRENCIES)[number]
export type PortfolioAllocation = {
  cashPct: number
  stocksPct: number
  etfsPct: number
  bondsPct: number
}

export const DEFAULT_PORTFOLIO_ALLOCATION: PortfolioAllocation = {
  cashPct: 4.6,
  stocksPct: 10,
  etfsPct: 67.4,
  bondsPct: 18,
}

export const useSettingsStore = defineStore('settings', () => {
  const auth = useAuthStore()
  const displayCurrency = ref<DisplayCurrency>('PLN')
  const portfolioAllocation = ref<PortfolioAllocation>({ ...DEFAULT_PORTFOLIO_ALLOCATION })
  const avatarInitials = ref('')
  const monthlyNotificationsEnabled = ref(true)

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

  const setPortfolioAllocation = (allocation: PortfolioAllocation) => {
    portfolioAllocation.value = {
      cashPct: Number(allocation.cashPct.toFixed(2)),
      stocksPct: Number(allocation.stocksPct.toFixed(2)),
      etfsPct: Number(allocation.etfsPct.toFixed(2)),
      bondsPct: Number(allocation.bondsPct.toFixed(2)),
    }
  }

  const isPortfolioAllocationValid = (allocation: PortfolioAllocation) => {
    const allValues = [allocation.cashPct, allocation.stocksPct, allocation.etfsPct, allocation.bondsPct]
    const inRange = allValues.every((value) => value >= 0 && value <= 100)
    const total = allValues.reduce((sum, value) => sum + value, 0)

    return inRange && Math.abs(total - 100) < 0.0001
  }

  const loadPortfolioAllocation = async () => {
    const ownerId = auth.user?.id
    if (!ownerId) {
      setPortfolioAllocation(DEFAULT_PORTFOLIO_ALLOCATION)
      return
    }

    const { data, error } = await supabase
      .from('portfolio_settings')
      .select('cash_pct, stocks_pct, etfs_pct, bonds_pct')
      .eq('owner_id', ownerId)
      .maybeSingle()

    if (error) throw error

    if (!data) {
      setPortfolioAllocation(DEFAULT_PORTFOLIO_ALLOCATION)
      return
    }

    setPortfolioAllocation({
      cashPct: Number(data.cash_pct),
      stocksPct: Number(data.stocks_pct),
      etfsPct: Number(data.etfs_pct),
      bondsPct: Number(data.bonds_pct),
    })
  }

  const savePortfolioAllocation = async (allocation: PortfolioAllocation) => {
    const ownerId = auth.user?.id
    if (!ownerId) throw new Error('Brak zalogowanego użytkownika.')
    if (!isPortfolioAllocationValid(allocation)) {
      throw new Error('Struktura portfela musi sumować się do 100%.')
    }

    const payload = {
      owner_id: ownerId,
      cash_pct: Number(allocation.cashPct.toFixed(2)),
      stocks_pct: Number(allocation.stocksPct.toFixed(2)),
      etfs_pct: Number(allocation.etfsPct.toFixed(2)),
      bonds_pct: Number(allocation.bondsPct.toFixed(2)),
    }

    const { error } = await supabase
      .from('portfolio_settings')
      .upsert(payload, { onConflict: 'owner_id' })

    if (error) throw error

    setPortfolioAllocation(allocation)
  }

  const resetPortfolioAllocation = () => {
    setPortfolioAllocation(DEFAULT_PORTFOLIO_ALLOCATION)
  }

  const normalizeAvatarInitials = (value: string) =>
    value
      .toUpperCase()
      .replace(/[^A-Z]/g, '')
      .slice(0, 2)

  const setAvatarInitials = (value: string) => {
    avatarInitials.value = normalizeAvatarInitials(value)
  }

  const loadAvatarInitials = async () => {
    const ownerId = auth.user?.id
    if (!ownerId) {
      avatarInitials.value = ''
      return
    }

    const { data, error } = await supabase
      .from('user_profiles')
      .select('avatar_initials')
      .eq('owner_id', ownerId)
      .maybeSingle()

    if (error) throw error

    avatarInitials.value = normalizeAvatarInitials(data?.avatar_initials ?? '')
  }

  const saveAvatarInitials = async (value: string) => {
    const ownerId = auth.user?.id
    if (!ownerId) throw new Error('Brak zalogowanego użytkownika.')

    const initials = normalizeAvatarInitials(value)
    const { error } = await supabase
      .from('user_profiles')
      .upsert(
        {
          owner_id: ownerId,
          avatar_initials: initials || null,
        },
        { onConflict: 'owner_id' },
      )

    if (error) throw error

    avatarInitials.value = initials
  }

  const loadMonthlyNotifications = async () => {
    const ownerId = auth.user?.id
    if (!ownerId) {
      monthlyNotificationsEnabled.value = true
      return
    }

    const { data, error } = await supabase
      .from('user_profiles')
      .select('monthly_notifications_enabled')
      .eq('owner_id', ownerId)
      .maybeSingle()

    if (error) throw error

    monthlyNotificationsEnabled.value = data?.monthly_notifications_enabled ?? true
  }

  const saveMonthlyNotifications = async (enabled: boolean) => {
    const ownerId = auth.user?.id
    if (!ownerId) throw new Error('Brak zalogowanego użytkownika.')

    const { error } = await supabase
      .from('user_profiles')
      .upsert(
        {
          owner_id: ownerId,
          monthly_notifications_enabled: enabled,
        },
        { onConflict: 'owner_id' },
      )

    if (error) throw error

    monthlyNotificationsEnabled.value = enabled
  }

  load()

  return {
    displayCurrency,
    availableCurrencies: AVAILABLE_CURRENCIES,
    portfolioAllocation,
    avatarInitials,
    monthlyNotificationsEnabled,
    setDisplayCurrency,
    loadPortfolioAllocation,
    savePortfolioAllocation,
    resetPortfolioAllocation,
    isPortfolioAllocationValid,
    setAvatarInitials,
    loadAvatarInitials,
    saveAvatarInitials,
    loadMonthlyNotifications,
    saveMonthlyNotifications,
  }
})
