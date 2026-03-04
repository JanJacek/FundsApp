<template>
  <section class="mx-auto w-full max-w-[980px]">
    <div class="mb-2 flex items-center justify-between">
      <h2 class="m-0 text-base font-bold text-text">Walet</h2>
    </div>

    <div class="flex flex-col gap-1 text-sm">
      <p class="m-0 text-muted">
        Gotówka: <strong class="text-text">{{ formatCurrency(cashPln) }}</strong>
      </p>
      <p class="m-0 text-muted">
        Akcje: <strong class="text-text">{{ formatCurrency(stocksPln) }}</strong>
      </p>
      <p class="m-0 text-muted">
        ETF-y: <strong class="text-text">{{ formatCurrency(etfsPln) }}</strong>
      </p>
      <p class="m-0 text-muted">
        Obligacje: <strong class="text-text">{{ formatCurrency(bondsPln) }}</strong>
      </p>
      <p class="m-0 text-muted">
        Suma: <strong class="text-text">{{ formatCurrency(totalPln) }}</strong>
      </p>
    </div>

    <p v-if="missingCurrencies.length" class="mt-1 text-xs text-error">
      Brak kursu PLN dla walut: {{ missingCurrencies.join(', ') }}. Nie zostały doliczone do sumy.
    </p>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    cashPln: number
    stocksPln?: number
    etfsPln?: number
    bondsPln?: number
    currency?: string
    missingCurrencies?: string[]
  }>(),
  {
    stocksPln: 0,
    etfsPln: 0,
    bondsPln: 0,
    currency: 'PLN',
    missingCurrencies: () => [],
  },
)

const totalPln = computed(() => props.cashPln + props.stocksPln + props.etfsPln + props.bondsPln)

const formatCurrency = (value: number) =>
  new Intl.NumberFormat('pl-PL', {
    style: 'currency',
    currency: props.currency,
    maximumFractionDigits: 2,
  }).format(value)
</script>

<style scoped></style>
