<template>
  <section class="mx-auto w-full max-w-[69rem] space-y-4">
    <section class="rounded-[12px] border border-border bg-surface p-4">
      <div class="mb-3 flex flex-wrap items-end justify-between gap-3">
        <h2 class="m-0 text-lg font-bold text-text">Progress - Monthly Portfolio Value</h2>
        <span class="text-sm text-muted">Last 12 months</span>
      </div>

      <p v-if="loading" class="m-0 text-sm text-muted">Loading progress data...</p>
      <p v-else-if="errorMsg" class="m-0 text-sm text-error">{{ errorMsg }}</p>

      <template v-if="!loading && !errorMsg">
        <p v-if="points.length === 0" class="m-0 text-sm text-muted">No data to render.</p>

        <div v-else class="space-y-3">
          <div class="grid gap-2 text-sm text-muted sm:grid-cols-3">
            <p class="m-0">
              Latest:
              <strong class="text-text">{{ formatCurrency(points[points.length - 1]?.value ?? 0) }}</strong>
            </p>
            <p class="m-0">
              First:
              <strong class="text-text">{{ formatCurrency(points[0]?.value ?? 0) }}</strong>
            </p>
            <p class="m-0">
              Change:
              <strong :class="changeValue >= 0 ? 'text-success' : 'text-error'">
                {{ formatSignedCurrency(changeValue) }}
              </strong>
            </p>
          </div>

          <div class="rounded-[10px] border border-border bg-background p-3">
            <svg viewBox="0 0 1000 320" class="h-[280px] w-full">
              <line
                v-for="y in yGrid"
                :key="`grid-${y.value}`"
                x1="60"
                :y1="y.y"
                x2="970"
                :y2="y.y"
                class="stroke-border"
                stroke-width="1"
              />

              <text
                v-for="y in yGrid"
                :key="`label-${y.value}`"
                x="8"
                :y="y.y + 4"
                class="fill-muted text-[11px]"
              >
                {{ formatShort(y.value) }}
              </text>

              <polyline
                :points="linePoints"
                fill="none"
                class="stroke-primary"
                stroke-width="3"
                stroke-linecap="round"
                stroke-linejoin="round"
              />

              <circle
                v-for="point in points"
                :key="point.label"
                :cx="point.x"
                :cy="point.y"
                r="4"
                class="fill-primary"
              />

              <text
                v-for="point in points"
                :key="`x-${point.label}`"
                :x="point.x"
                y="304"
                text-anchor="middle"
                class="fill-muted text-[11px]"
              >
                {{ point.label }}
              </text>
            </svg>
          </div>
        </div>
      </template>
    </section>
  </section>
</template>

<script setup lang="ts">
import { supabase } from '@/lib/supabase'
import { useSettingsStore } from '@/stores/settings'
import { computed, onMounted, ref } from 'vue'

type CashBalanceRow = {
  period_month: string
  currency: string
  amount: number | string
}

type PriceRow = {
  current_price: number | string
  opened_at: string
  closed_at: string | null
}

type BondRow = {
  current_value: number | string
  currency: string
  purchase_date: string
  maturity_date: string
}

const FX_TO_PLN: Record<string, number> = {
  PLN: 1,
  EUR: 4.3,
  USD: 4.0,
  GBP: 5.0,
}

const settings = useSettingsStore()
const loading = ref(true)
const errorMsg = ref('')
const monthlyTotals = ref<{ month: string; valuePln: number }[]>([])

const months = (() => {
  const now = new Date()
  const arr: string[] = []
  for (let i = 11; i >= 0; i -= 1) {
    const date = new Date(now.getFullYear(), now.getMonth() - i, 1)
    const y = date.getFullYear()
    const m = String(date.getMonth() + 1).padStart(2, '0')
    arr.push(`${y}-${m}-01`)
  }
  return arr
})()

const toDisplayCurrency = (valuePln: number) => {
  const rate = FX_TO_PLN[settings.displayCurrency]
  if (!rate) return valuePln
  return Number((valuePln / rate).toFixed(2))
}

const values = computed(() => monthlyTotals.value.map((item) => toDisplayCurrency(item.valuePln)))
const minValue = computed(() => Math.min(...values.value, 0))
const maxValue = computed(() => Math.max(...values.value, 1))
const valueSpan = computed(() => Math.max(maxValue.value - minValue.value, 1))

const points = computed(() => {
  if (values.value.length === 0) return []

  return values.value.map((value, idx) => {
    const x = 60 + (idx * (910 / Math.max(values.value.length - 1, 1)))
    const y = 260 - ((value - minValue.value) / valueSpan.value) * 220
    const labelDate = new Date(months[idx] ?? months[0] ?? new Date().toISOString().slice(0, 10))
    const label = new Intl.DateTimeFormat('en-US', { month: 'short' }).format(labelDate)
    return { x, y, label, value }
  })
})

const linePoints = computed(() => points.value.map((point) => `${point.x},${point.y}`).join(' '))

const yGrid = computed(() => {
  const steps = 4
  return Array.from({ length: steps + 1 }, (_, idx) => {
    const ratio = idx / steps
    const value = maxValue.value - (maxValue.value - minValue.value) * ratio
    return { y: 40 + ratio * 220, value }
  })
})

const changeValue = computed(() => {
  if (values.value.length < 2) return 0
  return (values.value[values.value.length - 1] ?? 0) - (values.value[0] ?? 0)
})

const formatCurrency = (value: number) =>
  new Intl.NumberFormat('pl-PL', {
    style: 'currency',
    currency: settings.displayCurrency,
    maximumFractionDigits: 2,
  }).format(value)

const formatSignedCurrency = (value: number) => (value >= 0 ? `+${formatCurrency(value)}` : `-${formatCurrency(Math.abs(value))}`)
const formatShort = (value: number) => {
  if (Math.abs(value) >= 1000) return `${Math.round(value / 1000)}k`
  return `${Math.round(value)}`
}

const loadProgress = async () => {
  loading.value = true
  errorMsg.value = ''

  try {
    const monthStart = months[0]
    const lastMonth = months[months.length - 1]
    if (!monthStart || !lastMonth) {
      monthlyTotals.value = []
      return
    }

    const monthEndDate = new Date(lastMonth)
    const monthEnd = `${monthEndDate.getFullYear()}-${String(monthEndDate.getMonth() + 1).padStart(2, '0')}-${String(new Date(monthEndDate.getFullYear(), monthEndDate.getMonth() + 1, 0).getDate()).padStart(2, '0')}`

    const [cashResult, stocksResult, etfsResult, bondsResult] = await Promise.all([
      supabase
        .from('cash_balances')
        .select('period_month, currency, amount')
        .gte('period_month', monthStart)
        .lte('period_month', lastMonth),
      supabase
        .from('stocks_positions')
        .select('current_price, opened_at, closed_at')
        .lte('opened_at', monthEnd),
      supabase
        .from('etfs_positions')
        .select('current_price, opened_at, closed_at')
        .lte('opened_at', monthEnd),
      supabase
        .from('bonds_positions')
        .select('current_value, currency, purchase_date, maturity_date')
        .lte('purchase_date', monthEnd),
    ])

    if (cashResult.error) throw cashResult.error
    if (stocksResult.error) throw stocksResult.error
    if (etfsResult.error) throw etfsResult.error
    if (bondsResult.error) throw bondsResult.error

    const cashRows = (cashResult.data ?? []) as CashBalanceRow[]
    const stockRows = (stocksResult.data ?? []) as PriceRow[]
    const etfRows = (etfsResult.data ?? []) as PriceRow[]
    const bondRows = (bondsResult.data ?? []) as BondRow[]

    const totals: { month: string; valuePln: number }[] = months.map((month) => ({ month, valuePln: 0 }))
    const byMonth = new Map<string, number>()

    for (const month of months) byMonth.set(month, 0)

    for (const row of cashRows) {
      const month = row.period_month
      if (!byMonth.has(month)) continue
      const rate = FX_TO_PLN[row.currency.toUpperCase()]
      if (!rate) continue
      byMonth.set(month, (byMonth.get(month) ?? 0) + Number(row.amount) * rate)
    }

    for (const month of months) {
      const monthEndLocal = `${month.slice(0, 7)}-${String(new Date(Number(month.slice(0, 4)), Number(month.slice(5, 7)), 0).getDate()).padStart(2, '0')}`
      const monthStartLocal = month
      let dynamicTotal = byMonth.get(month) ?? 0

      for (const row of stockRows) {
        if (row.opened_at <= monthEndLocal && (!row.closed_at || row.closed_at >= monthStartLocal)) {
          dynamicTotal += Number(row.current_price)
        }
      }

      for (const row of etfRows) {
        if (row.opened_at <= monthEndLocal && (!row.closed_at || row.closed_at >= monthStartLocal)) {
          dynamicTotal += Number(row.current_price)
        }
      }

      for (const row of bondRows) {
        const rate = FX_TO_PLN[row.currency.toUpperCase()]
        if (!rate) continue
        if (row.purchase_date <= monthEndLocal && row.maturity_date >= monthStartLocal) {
          dynamicTotal += Number(row.current_value) * rate
        }
      }

      byMonth.set(month, Number(dynamicTotal.toFixed(2)))
    }

    for (const item of totals) {
      item.valuePln = byMonth.get(item.month) ?? 0
    }

    monthlyTotals.value = totals
  } catch (error) {
    errorMsg.value = error instanceof Error ? error.message : 'Failed to load progress data.'
  } finally {
    loading.value = false
  }
}

onMounted(() => {
  void loadProgress()
})
</script>

<style scoped></style>
