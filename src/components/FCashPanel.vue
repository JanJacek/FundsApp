<template>
  <section class="mx-auto w-full max-w-[980px] space-y-4">
    <p class="m-0 text-sm text-muted">Pick a month to see all cash positions for that period.</p>

    <FMonthCalendar v-model="selectedPeriodMonth" />

    <section class="rounded-[12px] border border-border bg-surface p-4">
      <div class="mb-3 flex items-center justify-between">
        <h2 class="m-0 text-lg font-bold text-text">{{ selectedMonthLabel }}</h2>
        <span class="text-sm text-muted">Entries: {{ rows.length }}</span>
      </div>

      <p v-if="loading" class="m-0 text-sm text-muted">Loading cash entries...</p>
      <p v-else-if="errorMsg" class="m-0 text-sm text-error">{{ errorMsg }}</p>

      <template v-else>
        <p v-if="rows.length === 0" class="m-0 text-sm text-muted">
          No cash positions for selected month.
        </p>

        <div v-else class="overflow-x-auto">
          <table class="min-w-full border-collapse text-sm">
            <thead>
              <tr class="border-b border-border text-left text-muted">
                <th class="px-3 py-2 font-semibold">Currency</th>
                <th class="px-3 py-2 font-semibold">Amount</th>
                <th class="px-3 py-2 font-semibold">As of date</th>
                <th class="px-3 py-2 font-semibold">Note</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in rows"
                :key="row.id"
                class="border-b border-border/70"
              >
                <td class="px-3 py-2 font-semibold text-text">{{ row.currency }}</td>
                <td class="px-3 py-2 text-text">{{ formatCurrency(Number(row.amount), row.currency) }}</td>
                <td class="px-3 py-2 text-text">{{ row.as_of_date }}</td>
                <td class="px-3 py-2 text-muted">{{ row.note || '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </template>
    </section>
  </section>
</template>

<script setup lang="ts">
import FMonthCalendar from '@/components/FMonthCalendar.vue'
import { supabase } from '@/lib/supabase'
import { computed, ref, watch } from 'vue'

type CashRow = {
  id: string
  currency: string
  amount: string | number
  as_of_date: string
  note: string | null
}

const now = new Date()
const initialMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`

const selectedPeriodMonth = ref(initialMonth)
const rows = ref<CashRow[]>([])
const loading = ref(false)
const errorMsg = ref('')

const selectedMonthLabel = computed(() => {
  const [yearRaw, monthRaw] = selectedPeriodMonth.value.split('-')
  const year = Number(yearRaw)
  const month = Number(monthRaw)
  const date = new Date(year, month - 1, 1)
  return new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric' }).format(date)
})

const loadCashRows = async () => {
  loading.value = true
  errorMsg.value = ''

  try {
    const { data, error } = await supabase
      .from('cash_balances')
      .select('id, currency, amount, as_of_date, note')
      .eq('period_month', selectedPeriodMonth.value)
      .order('currency', { ascending: true })

    if (error) throw error
    rows.value = (data ?? []) as CashRow[]
  } catch (error) {
    errorMsg.value = error instanceof Error ? error.message : 'Failed to load cash entries.'
  } finally {
    loading.value = false
  }
}

watch(selectedPeriodMonth, () => {
  void loadCashRows()
}, { immediate: true })

const formatCurrency = (value: number, currency: string) =>
  new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
    maximumFractionDigits: 2,
  }).format(value)
</script>

<style scoped></style>
