<template>
  <section class="mx-auto w-full max-w-[980px]">
    <div class="rounded-[12px] border border-border bg-surface p-4">
      <h2 class="m-0 text-xl font-bold text-text">Portfel - aktualny vs docelowy</h2>

      <div class="mt-5 space-y-5">
        <article
          v-for="row in rows"
          :key="row.key"
          class="border-b border-border/70 pb-4 last:border-b-0 last:pb-0"
        >
          <div class="mb-2 flex items-center justify-between text-sm">
            <strong class="text-text">{{ row.label }}</strong>
            <span class="text-muted">{{ formatCurrency(row.value) }}</span>
          </div>

          <div class="relative h-10 bg-border/60">
            <span
              v-for="pos in minorTickPositions"
              :key="`${row.key}-minor-grid-${pos}`"
              class="absolute top-0 h-full w-[1px] bg-text/10"
              :style="{ left: `${pos}%` }"
            />
            <span
              v-for="pos in majorTickPositions"
              :key="`${row.key}-major-grid-${pos}`"
              class="absolute top-0 h-full w-[1px] bg-text/20"
              :style="{ left: `${pos}%` }"
            />
            <div
              class="relative z-[1] flex h-full items-center px-3 font-bold text-text"
              :style="{ width: `${row.currentWidthPct}%`, backgroundColor: row.color }"
            >
              {{ formatPercent(row.currentPct) }}
            </div>
            <span
              class="absolute top-[-6px] z-[2] h-[52px] w-[2px] bg-primary"
              :style="{ left: `${row.targetWidthPct}%` }"
              title="Poziom docelowy"
            />
          </div>
        </article>
      </div>

      <div class="mt-4">
        <p class="mb-1 text-xs font-semibold uppercase tracking-wide text-text">Skala</p>
        <div class="relative h-5">
          <div class="absolute left-0 right-0 top-0 h-[2px] bg-text" />

          <span
            v-for="pos in minorTickPositions"
            :key="`minor-${pos}`"
            class="absolute top-0 w-[1px] bg-text/70"
            :style="{ left: `${pos}%`, height: '9px' }"
          />

          <span
            v-for="pos in majorTickPositions"
            :key="`major-${pos}`"
            class="absolute top-0 w-[2px] bg-text"
            :style="{ left: `${pos}%`, height: '14px' }"
          />
        </div>

        <div class="relative h-6 text-sm text-text">
          <span
            v-for="(tick, idx) in axisTicks"
            :key="`axis-${tick}`"
            class="absolute top-0"
            :style="axisLabelStyle(idx)"
          >
            {{ formatShortCurrency(tick) }}
          </span>
        </div>
      </div>
    </div>

    <p v-if="missingCurrencies.length" class="mt-2 text-xs text-error">
      Brak kursu PLN dla walut: {{ missingCurrencies.join(', ') }}. Nie zostały doliczone do sumy.
    </p>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import type { PortfolioAllocation } from '@/stores/settings'

const props = withDefaults(
  defineProps<{
    cashPln: number
    stocksPln?: number
    etfsPln?: number
    bondsPln?: number
    currency?: string
    target?: PortfolioAllocation
    missingCurrencies?: string[]
  }>(),
  {
    stocksPln: 0,
    etfsPln: 0,
    bondsPln: 0,
    currency: 'PLN',
    target: () => ({
      cashPct: 4.6,
      stocksPct: 10,
      etfsPct: 67.4,
      bondsPct: 18,
    }),
    missingCurrencies: () => [],
  },
)

const totalPln = computed(() => props.cashPln + props.stocksPln + props.etfsPln + props.bondsPln)
const maxAxisValue = computed(() => {
  const maxCurrent = Math.max(props.cashPln, props.stocksPln, props.etfsPln, props.bondsPln, 1)
  const rounded = Math.ceil(maxCurrent / 5000) * 5000
  return Math.max(rounded, 5000)
})

const safeTotal = computed(() => (totalPln.value > 0 ? totalPln.value : 1))

const rows = computed(() => [
  {
    key: 'cash',
    label: 'Gotówka',
    value: props.cashPln,
    color: '#f43f5e',
    currentPct: (props.cashPln / safeTotal.value) * 100,
    currentWidthPct: (props.cashPln / maxAxisValue.value) * 100,
    targetWidthPct: ((safeTotal.value * (props.target.cashPct / 100)) / maxAxisValue.value) * 100,
  },
  {
    key: 'stocks',
    label: 'Akcje',
    value: props.stocksPln,
    color: '#22c55e',
    currentPct: (props.stocksPln / safeTotal.value) * 100,
    currentWidthPct: (props.stocksPln / maxAxisValue.value) * 100,
    targetWidthPct: ((safeTotal.value * (props.target.stocksPct / 100)) / maxAxisValue.value) * 100,
  },
  {
    key: 'etfs',
    label: 'ETF-y',
    value: props.etfsPln,
    color: '#eab308',
    currentPct: (props.etfsPln / safeTotal.value) * 100,
    currentWidthPct: (props.etfsPln / maxAxisValue.value) * 100,
    targetWidthPct: ((safeTotal.value * (props.target.etfsPct / 100)) / maxAxisValue.value) * 100,
  },
  {
    key: 'bonds',
    label: 'Obligacje',
    value: props.bondsPln,
    color: '#60a5fa',
    currentPct: (props.bondsPln / safeTotal.value) * 100,
    currentWidthPct: (props.bondsPln / maxAxisValue.value) * 100,
    targetWidthPct: ((safeTotal.value * (props.target.bondsPct / 100)) / maxAxisValue.value) * 100,
  },
].map((row) => ({
  ...row,
  currentWidthPct: Math.max(0, Math.min(100, row.currentWidthPct)),
  targetWidthPct: Math.max(0, Math.min(100, row.targetWidthPct)),
})))

const axisTicks = computed(() => {
  const max = maxAxisValue.value
  return [0, 1, 2, 3, 4, 5].map((step) => (max / 5) * step)
})

const majorTickPositions = [0, 20, 40, 60, 80, 100]
const minorTickPositions = Array.from({ length: 26 }, (_, idx) => idx * 4).filter(
  (pos) => !majorTickPositions.includes(pos),
)

const axisLabelStyle = (idx: number) => {
  if (idx === 0) return { left: '0%', transform: 'translateX(0)' }
  if (idx === axisTicks.value.length - 1) return { left: '100%', transform: 'translateX(-100%)' }
  return { left: `${majorTickPositions[idx]}%`, transform: 'translateX(-50%)' }
}

const formatCurrency = (value: number) =>
  new Intl.NumberFormat('pl-PL', {
    style: 'currency',
    currency: props.currency,
    maximumFractionDigits: 2,
  }).format(value)

const formatShortCurrency = (value: number) => {
  if (value >= 1000) return `${Math.round(value / 1000)}K`
  return `${Math.round(value)}`
}

const formatPercent = (value: number) => `${value.toFixed(1)}%`
</script>

<style scoped></style>
