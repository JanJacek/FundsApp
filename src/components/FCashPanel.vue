<template>
  <section class="mx-auto w-full max-w-[69rem] space-y-4">
    <p class="m-0 text-sm text-muted">Pick a month to manage cash positions.</p>

    <FMonthCalendar v-model="selectedPeriodMonth" />

    <section class="rounded-[12px] border border-border bg-surface p-4">
      <div class="mb-3 flex flex-wrap items-center justify-between gap-3">
        <h2 class="m-0 text-lg font-bold text-text">{{ selectedMonthLabel }}</h2>
        <div class="flex items-center gap-3">
          <span class="text-sm text-muted">Entries: {{ editableRows.length }}</span>
          <button
            type="button"
            class="rounded-[8px] border border-border px-3 py-1.5 text-sm text-text hover:bg-primary/5"
            @click="addRow"
          >
            Add row
          </button>
        </div>
      </div>

      <p v-if="loading" class="m-0 text-sm text-muted">Loading cash entries...</p>
      <p v-else-if="errorMsg" class="m-0 text-sm text-error">{{ errorMsg }}</p>
      <template v-if="!loading && !errorMsg">
        <p v-if="editableRows.length === 0" class="m-0 text-sm text-muted">
          No cash positions for selected month.
        </p>

        <div v-else class="overflow-x-auto">
          <table class="min-w-full border-collapse text-sm">
            <thead>
              <tr class="border-b border-border text-left text-muted">
                <th class="px-3 py-2 font-semibold">Currency</th>
                <th class="px-3 py-2 font-semibold">Amount</th>
                <th class="px-3 py-2 font-semibold">Rate</th>
                <th class="px-3 py-2 font-semibold">Value in PLN</th>
                <th class="px-3 py-2 font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in editableRows" :key="row.localId" class="border-b border-border/70">
                <td class="px-3 py-2">
                  <select
                    v-model="row.currency"
                    class="w-20 rounded-[8px] border border-border px-2 py-1 uppercase text-text outline-none"
                    @change="void onCommit(row.localId)"
                  >
                    <option v-for="currency in allowedCurrencies" :key="currency" :value="currency">
                      {{ currency }}
                    </option>
                  </select>
                </td>
                <td class="px-3 py-2">
                  <input
                    v-model.number="row.amount"
                    type="number"
                    min="0"
                    step="0.01"
                    class="w-32 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
                <td class="px-3 py-2 text-text">{{ formatRate(row.currency) }}</td>
                <td class="px-3 py-2 text-text">{{ formatCurrency(valueInPln(row)) }}</td>
                <td class="px-3 py-2">
                  <div class="flex items-center gap-2">
                    <button
                      type="button"
                      class="inline-flex h-8 w-8 items-center justify-center rounded-[8px] text-error hover:bg-error/10 disabled:cursor-not-allowed disabled:opacity-60"
                      :disabled="row.isSaving"
                      @click="deleteRow(row.localId)"
                      aria-label="Delete row"
                      title="Delete row"
                    >
                      <svg viewBox="0 0 24 24" class="h-4 w-4 fill-current" aria-hidden="true">
                        <path :d="mdiDeleteOutline" />
                      </svg>
                    </button>
                  </div>
                  <p v-if="row.error" class="mt-1 text-xs text-error">{{ row.error }}</p>
                </td>
              </tr>
            </tbody>
            <tfoot>
              <tr class="border-t border-border bg-background/50">
                <td class="px-3 py-2 font-semibold text-text" colspan="3">
                  Cash na ostatni dzień miesiąca
                </td>
                <td class="px-3 py-2 font-bold text-text">{{ formatCurrency(totalPln) }}</td>
                <td class="px-3 py-2" />
              </tr>
            </tfoot>
          </table>
        </div>

        <p v-if="missingRates.length" class="mt-2 text-xs text-error">
          Missing rates up to cutoff date for: {{ missingRates.join(', ') }}.
        </p>
      </template>
    </section>
  </section>
</template>

<script setup lang="ts">
import FMonthCalendar from '@/components/FMonthCalendar.vue'
import { mdiDeleteOutline } from '@mdi/js'
import { supabase } from '@/lib/supabase'
import { computed, ref, watch } from 'vue'

type CashRow = {
  id: string
  currency: string
  amount: string | number
}

type EditableCashRow = {
  localId: string
  id: string | null
  currency: string
  amount: number
  error: string
  isSaving: boolean
  persistedSignature: string
}

type FxRateRow = {
  currency: string
  rate_to_pln: number | string
  rate_date: string
}

const now = new Date()
const initialMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
const allowedCurrencies = ['PLN', 'EUR', 'USD'] as const

const selectedPeriodMonth = ref(initialMonth)
const rows = ref<CashRow[]>([])
const editableRows = ref<EditableCashRow[]>([])
const loading = ref(false)
const errorMsg = ref('')
const fxRates = ref<Record<string, number>>({ PLN: 1 })

const getRowSignature = (row: EditableCashRow) =>
  JSON.stringify({
    currency: row.currency,
    amount: Number.isFinite(row.amount) ? Number(row.amount.toFixed(2)) : row.amount,
  })

const selectedMonthLabel = computed(() => {
  const [yearRaw, monthRaw] = selectedPeriodMonth.value.split('-')
  const year = Number(yearRaw)
  const month = Number(monthRaw)
  const date = new Date(year, month - 1, 1)
  return new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric' }).format(date)
})

const monthEndDate = computed(() => {
  const [yearRaw, monthRaw] = selectedPeriodMonth.value.split('-')
  const year = Number(yearRaw)
  const month = Number(monthRaw)
  const lastDay = new Date(year, month, 0).getDate()
  return `${yearRaw}-${monthRaw}-${String(lastDay).padStart(2, '0')}`
})

const currentMonthStart = computed(() => {
  const date = new Date()
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-01`
})

const todayDate = computed(() => new Date().toISOString().slice(0, 10))

const rateCutoffDate = computed(() => {
  if (selectedPeriodMonth.value === currentMonthStart.value) return todayDate.value
  return monthEndDate.value
})

const valueInPln = (row: EditableCashRow) => {
  const rate = fxRates.value[row.currency] ?? 0
  return Number((row.amount * rate).toFixed(2))
}

const totalPln = computed(() =>
  Number(editableRows.value.reduce((sum, row) => sum + valueInPln(row), 0).toFixed(2)),
)

const missingRates = computed(() =>
  Array.from(new Set(editableRows.value.map((row) => row.currency))).filter(
    (currency) => !fxRates.value[currency],
  ),
)

const loadCashRows = async () => {
  loading.value = true
  errorMsg.value = ''

  try {
    const { data, error } = await supabase
      .from('cash_balances')
      .select('id, currency, amount')
      .eq('period_month', selectedPeriodMonth.value)
      .order('currency', { ascending: true })

    if (error) throw error
    rows.value = (data ?? []) as CashRow[]
    editableRows.value = rows.value.map((row) => {
      const editableRow: EditableCashRow = {
        localId: row.id,
        id: row.id,
        currency: row.currency,
        amount: Number(row.amount),
        error: '',
        isSaving: false,
        persistedSignature: '',
      }

      editableRow.persistedSignature = getRowSignature(editableRow)
      return editableRow
    })
  } catch (error) {
    errorMsg.value = error instanceof Error ? error.message : 'Failed to load cash entries.'
  } finally {
    loading.value = false
  }
}

const loadFxRates = async () => {
  const currencies = allowedCurrencies.filter((currency) => currency !== 'PLN')
  const { data, error } = await supabase
    .from('fx_rates')
    .select('currency, rate_to_pln, rate_date')
    .in('currency', currencies)
    .lte('rate_date', rateCutoffDate.value)
    .order('currency', { ascending: true })
    .order('rate_date', { ascending: false })

  if (error) {
    fxRates.value = { PLN: 1 }
    return
  }

  const map: Record<string, number> = { PLN: 1 }
  for (const row of (data ?? []) as FxRateRow[]) {
    const currency = row.currency.toUpperCase()
    if (map[currency]) continue
    map[currency] = Number(row.rate_to_pln)
  }

  const missingFromDb = currencies.filter((currency) => !map[currency])
  if (missingFromDb.length > 0) {
    const fetchedRates = await Promise.all(
      missingFromDb.map(async (currency) => {
        const rate = await fetchNbpRate(currency, rateCutoffDate.value)
        return { currency, rate }
      }),
    )

    for (const item of fetchedRates) {
      if (!item.rate) continue
      map[item.currency] = item.rate
    }
  }

  fxRates.value = map
}

const formatDate = (date: Date) => {
  const y = date.getFullYear()
  const m = String(date.getMonth() + 1).padStart(2, '0')
  const d = String(date.getDate()).padStart(2, '0')
  return `${y}-${m}-${d}`
}

const fetchNbpRate = async (currency: string, cutoff: string) => {
  try {
    const cutoffDate = new Date(`${cutoff}T00:00:00`)
    const startDate = new Date(cutoffDate)
    startDate.setDate(startDate.getDate() - 7)

    const url =
      `https://api.nbp.pl/api/exchangerates/rates/A/${currency}/` +
      `${formatDate(startDate)}/${formatDate(cutoffDate)}/?format=json`

    const response = await fetch(url)
    if (!response.ok) return null

    const json = (await response.json()) as { rates?: Array<{ mid?: number }> }
    const lastRate = json.rates?.[json.rates.length - 1]?.mid
    if (typeof lastRate !== 'number') return null
    return Number(lastRate)
  } catch {
    return null
  }
}

watch(
  selectedPeriodMonth,
  () => {
    void Promise.all([loadCashRows(), loadFxRates()])
  },
  { immediate: true },
)

const addRow = () => {
  const editableRow: EditableCashRow = {
    localId: `new-${Date.now()}-${Math.random()}`,
    id: null,
    currency: 'PLN',
    amount: 0,
    error: '',
    isSaving: false,
    persistedSignature: '',
  }

  editableRow.persistedSignature = getRowSignature(editableRow)
  editableRows.value.unshift(editableRow)
}

const validateRow = (row: EditableCashRow) => {
  if (!allowedCurrencies.includes(row.currency as (typeof allowedCurrencies)[number])) {
    return 'Currency must be one of: PLN, EUR, USD.'
  }
  if (!Number.isFinite(row.amount) || row.amount < 0) {
    return 'Amount must be a non-negative number.'
  }
  return ''
}

const saveRow = async (localId: string) => {
  const row = editableRows.value.find((item) => item.localId === localId)
  if (!row) return
  if (row.isSaving) return

  row.error = validateRow(row)
  if (row.error) return
  row.isSaving = true

  const payload = {
    period_month: selectedPeriodMonth.value,
    currency: row.currency,
    amount: Number(row.amount.toFixed(2)),
  }

  try {
    if (row.id) {
      const { error } = await supabase.from('cash_balances').update(payload).eq('id', row.id)
      if (error) throw error
    } else {
      const { data, error } = await supabase
        .from('cash_balances')
        .insert(payload)
        .select('id')
        .single()

      if (error) throw error
      row.id = data.id
      row.localId = data.id
    }

    row.persistedSignature = getRowSignature(row)
    row.error = ''
  } catch (error) {
    row.error = error instanceof Error ? error.message : 'Failed to save row.'
  } finally {
    row.isSaving = false
  }
}

const onCommit = async (localId: string) => {
  const row = editableRows.value.find((item) => item.localId === localId)
  if (!row || row.isSaving) return

  if (getRowSignature(row) === row.persistedSignature) return
  await saveRow(localId)
}

const deleteRow = async (localId: string) => {
  const rowIndex = editableRows.value.findIndex((item) => item.localId === localId)
  if (rowIndex < 0) return

  const row = editableRows.value[rowIndex]
  if (!row) return

  try {
    if (row.id) {
      const { error } = await supabase.from('cash_balances').delete().eq('id', row.id)
      if (error) throw error
    }

    editableRows.value.splice(rowIndex, 1)
  } catch (error) {
    row.error = error instanceof Error ? error.message : 'Failed to delete row.'
  }
}

const formatCurrency = (value: number) =>
  new Intl.NumberFormat('pl-PL', {
    style: 'currency',
    currency: 'PLN',
    maximumFractionDigits: 2,
  }).format(value)

const formatRate = (currency: string) => {
  if (currency === 'PLN') return '1.000000'
  const rate = fxRates.value[currency]
  if (!rate) return 'n/a'
  return rate.toFixed(6)
}
</script>

<style scoped></style>
