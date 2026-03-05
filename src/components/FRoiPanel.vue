<template>
  <section class="mx-auto w-full max-w-[69rem] space-y-4">
    <section class="rounded-[12px] border border-border bg-surface p-4">
      <div class="mb-3 flex flex-wrap items-end justify-between gap-3">
        <h2 class="m-0 text-lg font-bold text-text">ROI - Return on Investment</h2>
        <span class="text-sm text-muted">All investments (open + closed)</span>
      </div>

      <p v-if="loading" class="m-0 text-sm text-muted">Loading ROI...</p>
      <p v-else-if="errorMsg" class="m-0 text-sm text-error">{{ errorMsg }}</p>

      <template v-if="!loading && !errorMsg">
        <div class="grid gap-3 md:grid-cols-3">
          <article class="rounded-[10px] border border-border bg-background p-3">
            <p class="m-0 text-xs uppercase tracking-wide text-muted">Invested</p>
            <p class="m-0 text-xl font-bold text-text">{{ formatCurrency(totalOpenDisplay) }}</p>
          </article>
          <article class="rounded-[10px] border border-border bg-background p-3">
            <p class="m-0 text-xs uppercase tracking-wide text-muted">Current Value</p>
            <p class="m-0 text-xl font-bold text-text">{{ formatCurrency(totalCurrentDisplay) }}</p>
          </article>
          <article class="rounded-[10px] border border-border bg-background p-3">
            <p class="m-0 text-xs uppercase tracking-wide text-muted">Total ROI</p>
            <p class="m-0 text-xl font-bold" :class="roiClass(totalRoiValueDisplay)">
              {{ formatSignedCurrency(totalRoiValueDisplay) }}
            </p>
            <p class="m-0 text-sm" :class="roiClass(totalRoiValueDisplay)">
              {{ formatPercent(totalRoiPct) }}
            </p>
          </article>
        </div>

        <div class="mt-4 overflow-x-auto">
          <table class="w-full border-collapse text-sm">
            <thead>
              <tr class="border-b border-border text-left text-muted">
                <th class="px-3 py-2 font-semibold">Asset Class</th>
                <th class="px-3 py-2 font-semibold">Invested</th>
                <th class="px-3 py-2 font-semibold">Current</th>
                <th class="px-3 py-2 font-semibold">ROI Value</th>
                <th class="px-3 py-2 font-semibold">ROI %</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in rows" :key="row.key" class="border-b border-border/70">
                <td class="px-3 py-2 text-text">{{ row.label }}</td>
                <td class="px-3 py-2 text-text">{{ formatCurrency(row.openDisplay) }}</td>
                <td class="px-3 py-2 text-text">{{ formatCurrency(row.currentDisplay) }}</td>
                <td class="px-3 py-2 font-semibold" :class="roiClass(row.roiValueDisplay)">
                  {{ formatSignedCurrency(row.roiValueDisplay) }}
                </td>
                <td class="px-3 py-2 font-semibold" :class="roiClass(row.roiValueDisplay)">
                  {{ formatPercent(row.roiPct) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </section>
  </section>
</template>

<script setup lang="ts">
import { useSettingsStore } from '@/stores/settings'
import { supabase } from '@/lib/supabase'
import { computed, onMounted, ref } from 'vue'

type PositionRow = {
  opening_price: number | string
  current_price: number | string
  closed_at: string | null
}

type BondRow = {
  opening_value: number | string
  current_value: number | string
  currency: string
  maturity_date: string
}

const FX_TO_PLN: Record<string, number> = {
  PLN: 1,
  EUR: 4.3,
  USD: 4.0,
  GBP: 5.0,
}

const settings = useSettingsStore()
const loading = ref(false)
const errorMsg = ref('')

const stocksOpenPln = ref(0)
const stocksCurrentPln = ref(0)
const etfsOpenPln = ref(0)
const etfsCurrentPln = ref(0)
const bondsOpenPln = ref(0)
const bondsCurrentPln = ref(0)

const convertFromPln = (valuePln: number) => {
  const rate = FX_TO_PLN[settings.displayCurrency]
  if (!rate) return valuePln
  return Number((valuePln / rate).toFixed(2))
}

const totalOpenDisplay = computed(() => convertFromPln(stocksOpenPln.value + etfsOpenPln.value + bondsOpenPln.value))
const totalCurrentDisplay = computed(() => convertFromPln(stocksCurrentPln.value + etfsCurrentPln.value + bondsCurrentPln.value))
const totalRoiValueDisplay = computed(() => Number((totalCurrentDisplay.value - totalOpenDisplay.value).toFixed(2)))
const totalRoiPct = computed(() => (totalOpenDisplay.value > 0 ? (totalRoiValueDisplay.value / totalOpenDisplay.value) * 100 : 0))

const rows = computed(() => {
  const mapRow = (key: string, label: string, openPln: number, currentPln: number) => {
    const openDisplay = convertFromPln(openPln)
    const currentDisplay = convertFromPln(currentPln)
    const roiValueDisplay = Number((currentDisplay - openDisplay).toFixed(2))
    const roiPct = openDisplay > 0 ? (roiValueDisplay / openDisplay) * 100 : 0
    return { key, label, openDisplay, currentDisplay, roiValueDisplay, roiPct }
  }

  return [
    mapRow('stocks', 'Stocks', stocksOpenPln.value, stocksCurrentPln.value),
    mapRow('etfs', 'ETFs', etfsOpenPln.value, etfsCurrentPln.value),
    mapRow('bonds', 'Bonds', bondsOpenPln.value, bondsCurrentPln.value),
  ]
})

const loadRoiData = async () => {
  loading.value = true
  errorMsg.value = ''
  stocksOpenPln.value = 0
  stocksCurrentPln.value = 0
  etfsOpenPln.value = 0
  etfsCurrentPln.value = 0
  bondsOpenPln.value = 0
  bondsCurrentPln.value = 0

  try {
    const [stocksRes, etfsRes, bondsRes] = await Promise.all([
      supabase
        .from('stocks_positions')
        .select('opening_price, current_price, closed_at'),
      supabase
        .from('etfs_positions')
        .select('opening_price, current_price, closed_at'),
      supabase
        .from('bonds_positions')
        .select('opening_value, current_value, currency, maturity_date'),
    ])

    if (stocksRes.error) throw stocksRes.error
    if (etfsRes.error) throw etfsRes.error
    if (bondsRes.error) throw bondsRes.error

    for (const row of (stocksRes.data ?? []) as PositionRow[]) {
      stocksOpenPln.value += Number(row.opening_price)
      stocksCurrentPln.value += Number(row.current_price)
    }

    for (const row of (etfsRes.data ?? []) as PositionRow[]) {
      etfsOpenPln.value += Number(row.opening_price)
      etfsCurrentPln.value += Number(row.current_price)
    }

    for (const row of (bondsRes.data ?? []) as BondRow[]) {
      const rate = FX_TO_PLN[row.currency.toUpperCase()] || 1
      bondsOpenPln.value += Number(row.opening_value) * rate
      bondsCurrentPln.value += Number(row.current_value) * rate
    }

    stocksOpenPln.value = Number(stocksOpenPln.value.toFixed(2))
    stocksCurrentPln.value = Number(stocksCurrentPln.value.toFixed(2))
    etfsOpenPln.value = Number(etfsOpenPln.value.toFixed(2))
    etfsCurrentPln.value = Number(etfsCurrentPln.value.toFixed(2))
    bondsOpenPln.value = Number(bondsOpenPln.value.toFixed(2))
    bondsCurrentPln.value = Number(bondsCurrentPln.value.toFixed(2))
  } catch (error) {
    errorMsg.value = error instanceof Error ? error.message : 'Failed to load ROI.'
  } finally {
    loading.value = false
  }
}

const formatCurrency = (value: number) =>
  new Intl.NumberFormat('pl-PL', {
    style: 'currency',
    currency: settings.displayCurrency,
    maximumFractionDigits: 2,
  }).format(value)

const formatSignedCurrency = (value: number) => {
  const formatted = formatCurrency(Math.abs(value))
  return value >= 0 ? `+${formatted}` : `-${formatted}`
}

const formatPercent = (value: number) => `${value.toFixed(2)}%`
const roiClass = (value: number) => (value >= 0 ? 'text-success' : 'text-error')

onMounted(() => {
  void loadRoiData()
})
</script>

<style scoped></style>
