<template>
  <section class="mx-auto w-full max-w-[69rem] space-y-4">
    <section class="rounded-[12px] border border-border bg-surface p-4">
      <div class="mb-3 flex flex-wrap items-end justify-between gap-3">
        <h2 class="m-0 text-lg font-bold text-text">ROI - Return on Investment</h2>
        <span class="text-sm text-muted">All investments (open + closed)</span>
      </div>

      <p v-if="loading" class="m-0 text-sm text-muted">Loading ROI...</p>
      <p v-else-if="errorMsg" class="m-0 text-sm text-error">{{ errorMsg }}</p>
      <p v-else-if="fxWarning" class="m-0 text-sm text-error">{{ fxWarning }}</p>

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
            <div class="mt-2 grid gap-3 sm:grid-cols-2">
              <div>
                <p class="m-0 text-sm text-muted">Gross</p>
                <p class="m-0 text-lg font-bold" :class="roiClass(totalRoiGrossValueDisplay)">
                  {{ formatSignedCurrency(totalRoiGrossValueDisplay) }}
                </p>
                <p class="m-0 text-xs" :class="roiClass(totalRoiGrossValueDisplay)">
                  {{ formatPercent(totalRoiGrossPct) }}
                </p>
              </div>
              <div>
                <p class="m-0 text-sm text-muted">Net (Belka 19%)</p>
                <p class="m-0 text-lg font-bold" :class="roiClass(totalRoiNetValueDisplay)">
                  {{ formatSignedCurrency(totalRoiNetValueDisplay) }}
                </p>
                <p class="m-0 text-xs" :class="roiClass(totalRoiNetValueDisplay)">
                  {{ formatPercent(totalRoiNetPct) }}
                </p>
              </div>
            </div>
          </article>
        </div>

        <div class="mt-4">
          <FTable :headers="roiTableHeaders" :rows="rows" row-key="key">
            <template #cell="{ row, header }">
              <span v-if="header.key === 'label'" class="text-text">{{ row.label }}</span>
              <span v-else-if="header.key === 'openDisplay'" class="text-text">
                {{ formatCurrency(row.openDisplay) }}
              </span>
              <span v-else-if="header.key === 'currentDisplay'" class="text-text">
                {{ formatCurrency(row.currentDisplay) }}
              </span>
              <span
                v-else-if="header.key === 'roiGrossValueDisplay'"
                class="font-semibold"
                :class="roiClass(row.roiGrossValueDisplay)"
              >
                {{ formatSignedCurrency(row.roiGrossValueDisplay) }}
              </span>
              <span
                v-else-if="header.key === 'roiGrossPct'"
                class="font-semibold"
                :class="roiClass(row.roiGrossValueDisplay)"
              >
                {{ formatPercent(row.roiGrossPct) }}
              </span>
              <span
                v-else-if="header.key === 'roiNetValueDisplay'"
                class="font-semibold"
                :class="roiClass(row.roiNetValueDisplay)"
              >
                {{ formatSignedCurrency(row.roiNetValueDisplay) }}
              </span>
              <span
                v-else-if="header.key === 'roiNetPct'"
                class="font-semibold"
                :class="roiClass(row.roiNetValueDisplay)"
              >
                {{ formatPercent(row.roiNetPct) }}
              </span>
            </template>
          </FTable>
        </div>
      </template>
    </section>
  </section>
</template>

<script setup lang="ts">
import FTable from '@/components/FTable.vue'
import type { FTableHeader } from '@/components/FTable.vue'
import { calculateBondPosition, type BondPosition, type BondType } from '@/lib/bonds'
import { fxRequestKey, resolveFxRatesToPln } from '@/lib/fx'
import { useSettingsStore } from '@/stores/settings'
import { supabase } from '@/lib/supabase'
import { computed, onMounted, ref } from 'vue'

type PositionRow = {
  currency: string
  quantity: number
  opening_price: number | string
  current_price: number | string
  closed_at: string | null
}

type BondRow = {
  id: string
  bond_type: BondType
  purchase_date: string
  maturity_date: string
  quantity: number
  nominal_per_bond: number | string
  interest_rate: number | string
}

type DividendRow = {
  currency: string
  value: number | string
  paid_at: string
}

const FX_TO_PLN: Record<string, number> = {
  PLN: 1,
  EUR: 4.3,
  USD: 4.0,
  GBP: 5.0,
}
const BELKA_TAX_RATE = 0.19

const settings = useSettingsStore()
const loading = ref(false)
const errorMsg = ref('')
const fxWarning = ref('')
const roiTableHeaders: FTableHeader[] = [
  { key: 'label', label: 'Asset Class' },
  { key: 'openDisplay', label: 'Invested', numeric: true },
  { key: 'currentDisplay', label: 'Current', numeric: true },
  { key: 'roiGrossValueDisplay', label: 'ROI Gross', numeric: true },
  { key: 'roiGrossPct', label: 'ROI Gross %', numeric: true },
  { key: 'roiNetValueDisplay', label: 'ROI Net', numeric: true },
  { key: 'roiNetPct', label: 'ROI Net %', numeric: true },
]

const stocksOpenPln = ref(0)
const stocksCurrentPln = ref(0)
const etfsOpenPln = ref(0)
const etfsCurrentPln = ref(0)
const bondsOpenPln = ref(0)
const bondsCurrentPln = ref(0)
const dividendsCurrentPln = ref(0)

const convertFromPln = (valuePln: number) => {
  const rate = FX_TO_PLN[settings.displayCurrency]
  if (!rate) return valuePln
  return Number((valuePln / rate).toFixed(2))
}

const totalOpenDisplay = computed(() =>
  convertFromPln(stocksOpenPln.value + etfsOpenPln.value + bondsOpenPln.value),
)
const totalCurrentDisplay = computed(() =>
  convertFromPln(
    stocksCurrentPln.value + etfsCurrentPln.value + bondsCurrentPln.value + dividendsCurrentPln.value,
  ),
)
const totalRoiGrossValueDisplay = computed(() => Number((totalCurrentDisplay.value - totalOpenDisplay.value).toFixed(2)))
const totalBelkaTaxDisplay = computed(() => Number((Math.max(totalRoiGrossValueDisplay.value, 0) * BELKA_TAX_RATE).toFixed(2)))
const totalRoiNetValueDisplay = computed(() => Number((totalRoiGrossValueDisplay.value - totalBelkaTaxDisplay.value).toFixed(2)))
const totalRoiGrossPct = computed(() =>
  totalOpenDisplay.value > 0 ? (totalRoiGrossValueDisplay.value / totalOpenDisplay.value) * 100 : 0,
)
const totalRoiNetPct = computed(() =>
  totalOpenDisplay.value > 0 ? (totalRoiNetValueDisplay.value / totalOpenDisplay.value) * 100 : 0,
)

const rows = computed(() => {
  const mapRow = (key: string, label: string, openPln: number, currentPln: number) => {
    const openDisplay = convertFromPln(openPln)
    const currentDisplay = convertFromPln(currentPln)
    const roiGrossValueDisplay = Number((currentDisplay - openDisplay).toFixed(2))
    const belkaTaxDisplay = Number((Math.max(roiGrossValueDisplay, 0) * BELKA_TAX_RATE).toFixed(2))
    const roiNetValueDisplay = Number((roiGrossValueDisplay - belkaTaxDisplay).toFixed(2))
    const roiGrossPct = openDisplay > 0 ? (roiGrossValueDisplay / openDisplay) * 100 : 0
    const roiNetPct = openDisplay > 0 ? (roiNetValueDisplay / openDisplay) * 100 : 0
    return { key, label, openDisplay, currentDisplay, roiGrossValueDisplay, roiNetValueDisplay, roiGrossPct, roiNetPct }
  }

  return [
    mapRow('stocks', 'Stocks', stocksOpenPln.value, stocksCurrentPln.value),
    mapRow('etfs', 'ETFs', etfsOpenPln.value, etfsCurrentPln.value),
    mapRow('bonds', 'Bonds', bondsOpenPln.value, bondsCurrentPln.value),
    mapRow('dividends', 'Dividends', 0, dividendsCurrentPln.value),
  ]
})

const loadRoiData = async () => {
  loading.value = true
  errorMsg.value = ''
  fxWarning.value = ''
  stocksOpenPln.value = 0
  stocksCurrentPln.value = 0
  etfsOpenPln.value = 0
  etfsCurrentPln.value = 0
  bondsOpenPln.value = 0
  bondsCurrentPln.value = 0
  dividendsCurrentPln.value = 0

  try {
    const [stocksRes, etfsRes, bondsRes, dividendsRes] = await Promise.all([
      supabase
        .from('stocks_positions')
        .select('currency, quantity, opening_price, current_price, closed_at'),
      supabase
        .from('etfs_positions')
        .select('currency, quantity, opening_price, current_price, closed_at'),
      supabase
        .from('bonds_positions')
        .select('id, bond_type, purchase_date, maturity_date, quantity, nominal_per_bond, interest_rate'),
      supabase
        .from('dividends_entries')
        .select('currency, value, paid_at'),
    ])

    if (stocksRes.error) throw stocksRes.error
    if (etfsRes.error) throw etfsRes.error
    if (bondsRes.error) throw bondsRes.error
    if (dividendsRes.error) throw dividendsRes.error

    const today = new Date().toISOString().slice(0, 10)
    const stocksRows = (stocksRes.data ?? []) as PositionRow[]
    const etfsRows = (etfsRes.data ?? []) as PositionRow[]
    const dividendsRows = (dividendsRes.data ?? []) as DividendRow[]

    const fxRequests = [
      ...stocksRows.map((row) => ({ currency: row.currency, date: row.closed_at || today })),
      ...etfsRows.map((row) => ({ currency: row.currency, date: row.closed_at || today })),
      ...dividendsRows.map((row) => ({ currency: row.currency, date: row.paid_at })),
    ]

    const { rates, missing } = await resolveFxRatesToPln(fxRequests)
    if (missing.length > 0) {
      fxWarning.value = `Missing FX rates for: ${missing.join(', ')}`
    }

    for (const row of stocksRows) {
      const rateDate = row.closed_at || today
      const rate = rates[fxRequestKey(row.currency, rateDate)]
      if (!rate) continue
      stocksOpenPln.value += Number(row.opening_price) * Number(row.quantity) * rate
      stocksCurrentPln.value += Number(row.current_price) * Number(row.quantity) * rate
    }

    for (const row of etfsRows) {
      const rateDate = row.closed_at || today
      const rate = rates[fxRequestKey(row.currency, rateDate)]
      if (!rate) continue
      etfsOpenPln.value += Number(row.opening_price) * Number(row.quantity) * rate
      etfsCurrentPln.value += Number(row.current_price) * Number(row.quantity) * rate
    }

    for (const row of dividendsRows) {
      const rate = rates[fxRequestKey(row.currency, row.paid_at)]
      if (!rate) continue
      dividendsCurrentPln.value += Number(row.value) * rate
    }

    for (const row of (bondsRes.data ?? []) as BondRow[]) {
      const position: BondPosition = {
        id: row.id,
        bondType: row.bond_type,
        purchaseDate: row.purchase_date,
        maturityDate: row.maturity_date,
        quantity: Number(row.quantity),
        nominalPerBond: Number(row.nominal_per_bond),
        interestRate: Number(row.interest_rate),
      }

      const calc = calculateBondPosition(position)
      bondsOpenPln.value += calc.purchaseValue
      bondsCurrentPln.value += calc.finalValue
    }

    stocksOpenPln.value = Number(stocksOpenPln.value.toFixed(2))
    stocksCurrentPln.value = Number(stocksCurrentPln.value.toFixed(2))
    etfsOpenPln.value = Number(etfsOpenPln.value.toFixed(2))
    etfsCurrentPln.value = Number(etfsCurrentPln.value.toFixed(2))
    bondsOpenPln.value = Number(bondsOpenPln.value.toFixed(2))
    bondsCurrentPln.value = Number(bondsCurrentPln.value.toFixed(2))
    dividendsCurrentPln.value = Number(dividendsCurrentPln.value.toFixed(2))
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
