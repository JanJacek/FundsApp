<template>
  <main class="min-h-[calc(100vh-4rem)] bg-dashboard p-6">
    <div class="w-full">
      <p v-if="loading" class="mx-auto mb-4 max-w-[980px] text-sm text-muted">
        Ładowanie danych portfela...
      </p>
      <p v-else-if="errorMsg" class="mx-auto mb-4 max-w-[980px] text-sm text-error">
        {{ errorMsg }}
      </p>

      <template v-else>
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
    </div>
  </main>
</template>

<script setup lang="ts">
import FWalet from '@/components/FWalet.vue'
import { supabase } from '@/lib/supabase'
import { useSettingsStore } from '@/stores/settings'
import { computed, onMounted, ref } from 'vue'

type CashBalanceRow = {
  currency: string
  amount: number | string
  period_month: string
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

  try {
    const { data, error } = await supabase
      .from('cash_balances')
      .select('currency, amount, period_month')
      .order('period_month', { ascending: false })

    if (error) throw error

    const latestByCurrency = new Map<string, number>()

    for (const row of (data ?? []) as CashBalanceRow[]) {
      const currency = row.currency?.toUpperCase()
      if (!currency || latestByCurrency.has(currency)) continue
      latestByCurrency.set(currency, Number(row.amount))
    }

    let cashTotal = 0
    const missing = new Set<string>()

    latestByCurrency.forEach((amount, currency) => {
      const rate = FX_TO_PLN[currency]
      if (!rate) {
        missing.add(currency)
        return
      }

      cashTotal += amount * rate
    })

    cashPln.value = Number(cashTotal.toFixed(2))
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
</script>

<style scoped></style>
