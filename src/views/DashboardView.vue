<template>
  <main class="min-h-[calc(100vh-4rem)] bg-dashboard px-6 py-4">
    <div class="w-full">
      <FDashboardNav v-model="activeTab" />

      <p v-if="loading && activeTab === 'wallet'" class="mx-auto mb-4 max-w-[69rem] text-sm text-muted">
        Ładowanie danych portfela...
      </p>
      <p v-else-if="errorMsg && activeTab === 'wallet'" class="mx-auto mb-4 max-w-[69rem] text-sm text-error">
        {{ errorMsg }}
      </p>

      <template v-if="activeTab === 'wallet' && !loading && !errorMsg">
        <FWalet
          :cash-pln="cashInDisplayCurrency"
          :stocks-pln="stocksInDisplayCurrency"
          :etfs-pln="etfsInDisplayCurrency"
          :bonds-pln="bondsInDisplayCurrency"
          :currency="settings.displayCurrency"
          :target="settings.portfolioAllocation"
          :missing-currencies="missingCurrencies"
        />
      </template>

      <FCashPanel v-else-if="activeTab === 'cash'" />
      <FStocksPanel v-else-if="activeTab === 'stocks'" />
    </div>
  </main>
</template>

<script setup lang="ts">
import FDashboardNav from '@/components/FDashboardNav.vue'
import type { DashboardTab } from '@/components/FDashboardNav.vue'
import FCashPanel from '@/components/FCashPanel.vue'
import FStocksPanel from '@/components/FStocksPanel.vue'
import FWalet from '@/components/FWalet.vue'
import { supabase } from '@/lib/supabase'
import { useSettingsStore } from '@/stores/settings'
import { computed, onMounted, ref, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'

type CashBalanceRow = {
  currency: string
  amount: number | string
}

const FX_TO_PLN: Record<string, number> = {
  PLN: 1,
  EUR: 4.3,
  USD: 4.0,
  GBP: 5.0,
}

const loading = ref(true)
const errorMsg = ref('')
const cashPln = ref(0)
const stocksPln = ref(0)
const etfsPln = ref(0)
const bondsPln = ref(0)
const missingCurrencies = ref<string[]>([])
const settings = useSettingsStore()
const route = useRoute()
const router = useRouter()
const activeTab = ref<DashboardTab>('wallet')

const convertFromPln = (amountPln: number) => {
  const rate = FX_TO_PLN[settings.displayCurrency]
  if (!rate) return amountPln
  return Number((amountPln / rate).toFixed(2))
}

const cashInDisplayCurrency = computed(() => convertFromPln(cashPln.value))
const stocksInDisplayCurrency = computed(() => convertFromPln(stocksPln.value))
const etfsInDisplayCurrency = computed(() => convertFromPln(etfsPln.value))
const bondsInDisplayCurrency = computed(() => convertFromPln(bondsPln.value))

const loadWalletData = async () => {
  loading.value = true
  errorMsg.value = ''
  cashPln.value = 0
  stocksPln.value = 0
  etfsPln.value = 0
  bondsPln.value = 0
  missingCurrencies.value = []

  try {
    const now = new Date()
    const currentPeriodMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`

    const { data, error } = await supabase
      .from('cash_balances')
      .select('currency, amount')
      .eq('period_month', currentPeriodMonth)
      .order('currency', { ascending: true })

    if (error) throw error

    let cashTotal = 0
    const missing = new Set<string>()

    for (const row of (data ?? []) as CashBalanceRow[]) {
      const currency = row.currency?.toUpperCase()
      if (!currency) continue
      const rate = FX_TO_PLN[currency]
      if (!rate) {
        missing.add(currency)
        continue
      }

      cashTotal += Number(row.amount) * rate
    }

    cashPln.value = Number(cashTotal.toFixed(2))

    const today = new Date().toISOString().slice(0, 10)
    const { data: stocksData, error: stocksError } = await supabase
      .from('stocks_positions')
      .select('current_price, closed_at')
      .order('opened_at', { ascending: false })

    if (stocksError) throw stocksError

    let stocksTotal = 0
    for (const row of (stocksData ?? []) as { current_price: number | string; closed_at: string | null }[]) {
      const isClosed = !!row.closed_at && row.closed_at < today
      if (isClosed) continue
      stocksTotal += Number(row.current_price)
    }

    stocksPln.value = Number(stocksTotal.toFixed(2))
    missingCurrencies.value = Array.from(missing).sort()
  } catch (error) {
    errorMsg.value = error instanceof Error ? error.message : 'Nie udało się pobrać danych walet.'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  void (async () => {
    await loadWalletData()

    try {
      await settings.loadPortfolioAllocation()
    } catch (error) {
      console.error('Nie udało się pobrać ustawień portfela', error)
    }
  })()
})

watch(
  () => route.query.tab,
  (tab) => {
    if (tab === 'cash') {
      activeTab.value = 'cash'
      return
    }
    if (tab === 'stocks') {
      activeTab.value = 'stocks'
      return
    }

    activeTab.value = 'wallet'
  },
  { immediate: true },
)

watch(activeTab, async (tab) => {
  const query = { ...route.query }

  if (tab === 'cash') {
    query.tab = 'cash'
  } else if (tab === 'stocks') {
    query.tab = 'stocks'
  } else {
    delete query.tab
  }

  await router.replace({ query })
})
</script>

<style scoped></style>
