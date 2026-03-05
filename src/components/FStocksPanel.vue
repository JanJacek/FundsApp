<template>
  <section class="mx-auto w-full max-w-[69rem] space-y-4">
    <p class="m-0 text-sm text-muted">Pick a month to filter stock positions by open date.</p>

    <FMonthCalendar v-model="selectedPeriodMonth" />

    <section class="rounded-[12px] border border-border bg-surface p-4">
      <div class="mb-3 flex flex-wrap items-center justify-between gap-3">
        <h2 class="m-0 text-lg font-bold text-text">{{ selectedMonthLabel }} - Stocks</h2>
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

      <p v-if="loading" class="m-0 text-sm text-muted">Loading stocks...</p>
      <p v-else-if="errorMsg" class="m-0 text-sm text-error">{{ errorMsg }}</p>

      <template v-if="!loading && !errorMsg">
        <p v-if="editableRows.length === 0" class="m-0 text-sm text-muted">
          No stock positions yet.
        </p>

        <FTable v-else :headers="stocksTableHeaders" :rows="editableRows" row-key="localId">
          <template #cell="{ row, header }">
            <input
              v-if="header.key === 'name'"
              v-model="row.name"
              type="text"
              maxlength="120"
              class="w-44 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
              @keydown.enter.prevent="void onCommit(row.localId)"
              @blur="void onCommit(row.localId)"
            />
            <select
              v-else-if="header.key === 'currency'"
              v-model="row.currency"
              class="w-20 rounded-[8px] border border-border px-2 py-1 uppercase text-text outline-none"
              @change="void onCommit(row.localId)"
            >
              <option v-for="currency in allowedCurrencies" :key="currency" :value="currency">
                {{ currency }}
              </option>
            </select>
            <input
              v-else-if="header.key === 'quantity'"
              v-model.number="row.quantity"
              type="number"
              min="0.0001"
              step="0.0001"
              class="w-20 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
              @keydown.enter.prevent="void onCommit(row.localId)"
              @blur="void onCommit(row.localId)"
            />
            <input
              v-else-if="header.key === 'openPrice'"
              v-model.number="row.openPrice"
              type="number"
              min="0"
              step="0.01"
              class="w-32 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
              @keydown.enter.prevent="void onCommit(row.localId)"
              @blur="void onCommit(row.localId)"
            />
            <input
              v-else-if="header.key === 'currentPrice'"
              v-model.number="row.currentPrice"
              type="number"
              min="0"
              step="0.01"
              class="w-32 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
              @keydown.enter.prevent="void onCommit(row.localId)"
              @blur="void onCommit(row.localId)"
            />
            <span
              v-else-if="header.key === 'profitLoss'"
              class="font-semibold"
              :class="rowProfitLossDisplay(row) >= 0 ? 'text-success' : 'text-error'"
            >
              {{ formatSignedCurrency(rowProfitLossDisplay(row)) }}
            </span>
            <input
              v-else-if="header.key === 'openedAt'"
              v-model="row.openedAt"
              type="date"
              class="rounded-[8px] border border-border px-2 py-1 text-text outline-none"
              @keydown.enter.prevent="void onCommit(row.localId)"
              @blur="void onCommit(row.localId)"
            />
            <input
              v-else-if="header.key === 'closedAt'"
              v-model="row.closedAt"
              type="date"
              class="rounded-[8px] border border-border px-2 py-1 text-text outline-none"
              @keydown.enter.prevent="void onCommit(row.localId)"
              @blur="void onCommit(row.localId)"
            />
            <div v-else-if="header.key === 'actions'">
              <div class="flex justify-end">
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
              <p v-if="row.error" class="mt-1 text-right text-xs text-error">{{ row.error }}</p>
            </div>
          </template>
        </FTable>
      </template>
    </section>
  </section>
</template>

<script setup lang="ts">
import { mdiDeleteOutline } from '@mdi/js'
import FMonthCalendar from '@/components/FMonthCalendar.vue'
import FTable from '@/components/FTable.vue'
import type { FTableHeader } from '@/components/FTable.vue'
import { fxRequestKey, resolveFxRatesToPln } from '@/lib/fx'
import { supabase } from '@/lib/supabase'
import { useSettingsStore } from '@/stores/settings'
import { computed, ref, watch } from 'vue'

type StockRow = {
  id: string
  name: string
  currency: string
  quantity: number
  current_price: number | string
  opening_price: number | string
  opened_at: string
  closed_at: string | null
}

type EditableStockRow = {
  localId: string
  id: string | null
  name: string
  currency: string
  quantity: number
  currentPrice: number
  openPrice: number
  openedAt: string
  closedAt: string
  error: string
  isSaving: boolean
  persistedSignature: string
}

const loading = ref(false)
const errorMsg = ref('')
const editableRows = ref<EditableStockRow[]>([])
const settings = useSettingsStore()
const profitLossFxRates = ref<Record<string, number>>({})
const displayCurrencyRateToPln = ref(1)
const allowedCurrencies = ['PLN', 'EUR', 'USD'] as const
const stocksTableHeaders: FTableHeader[] = [
  { key: 'name', label: 'Name' },
  { key: 'currency', label: 'Currency' },
  { key: 'quantity', label: 'Quantity', numeric: true, align: 'left' },
  { key: 'openPrice', label: 'Open Price', numeric: true, align: 'left' },
  { key: 'currentPrice', label: 'Current Price', numeric: true, align: 'left' },
  { key: 'profitLoss', label: 'Profit/Loss', numeric: true },
  { key: 'openedAt', label: 'Open Date' },
  { key: 'closedAt', label: 'Close Date' },
  { key: 'actions', label: 'Actions' },
]

const now = new Date()
const initialMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`
const selectedPeriodMonth = ref(initialMonth)

const selectedMonthLabel = computed(() => {
  const [yearRaw, monthRaw] = selectedPeriodMonth.value.split('-')
  const year = Number(yearRaw)
  const month = Number(monthRaw)
  const date = new Date(year, month - 1, 1)
  return new Intl.DateTimeFormat('en-US', { month: 'long', year: 'numeric' }).format(date)
})

const getMonthBounds = (periodMonth: string) => {
  const [yearRaw, monthRaw] = periodMonth.split('-')
  const year = Number(yearRaw)
  const month = Number(monthRaw)
  const monthStart = `${yearRaw}-${monthRaw}-01`
  const monthEnd = `${yearRaw}-${monthRaw}-${String(new Date(year, month, 0).getDate()).padStart(2, '0')}`
  return { monthStart, monthEnd }
}

const getRowSignature = (row: EditableStockRow) =>
  JSON.stringify({
    name: row.name.trim(),
    currency: row.currency,
    quantity: row.quantity,
    currentPrice: Number.isFinite(row.currentPrice) ? Number(row.currentPrice.toFixed(2)) : row.currentPrice,
    openPrice: Number.isFinite(row.openPrice) ? Number(row.openPrice.toFixed(2)) : row.openPrice,
    openedAt: row.openedAt,
    closedAt: row.closedAt || '',
  })

const getFxDateForRow = (row: EditableStockRow) => row.closedAt || new Date().toISOString().slice(0, 10)

const rowProfitLossRaw = (row: EditableStockRow) => (row.currentPrice - row.openPrice) * row.quantity

const rowProfitLossDisplay = (row: EditableStockRow) => {
  const fromRate = profitLossFxRates.value[fxRequestKey(row.currency, getFxDateForRow(row))] ?? 0
  const toRate = displayCurrencyRateToPln.value || 1
  if (!fromRate) return 0
  return Number(((rowProfitLossRaw(row) * fromRate) / toRate).toFixed(2))
}

const loadProfitLossFxRates = async () => {
  const today = new Date().toISOString().slice(0, 10)
  const requests = editableRows.value.map((row) => ({
    currency: row.currency,
    date: getFxDateForRow(row),
  }))

  requests.push({ currency: settings.displayCurrency, date: today })

  const { rates } = await resolveFxRatesToPln(requests)
  profitLossFxRates.value = rates
  displayCurrencyRateToPln.value =
    rates[fxRequestKey(settings.displayCurrency, today)] || (settings.displayCurrency === 'PLN' ? 1 : 1)
}

const loadRows = async () => {
  loading.value = true
  errorMsg.value = ''

  try {
    const { monthStart, monthEnd } = getMonthBounds(selectedPeriodMonth.value)
    const { data, error } = await supabase
      .from('stocks_positions')
      .select('id, name, currency, quantity, current_price, opening_price, opened_at, closed_at')
      .lte('opened_at', monthEnd)
      .or(`closed_at.is.null,closed_at.gte.${monthStart}`)
      .order('opened_at', { ascending: false })
      .order('name', { ascending: true })

    if (error) throw error

    editableRows.value = ((data ?? []) as StockRow[]).map((row) => {
      const editableRow: EditableStockRow = {
        localId: row.id,
        id: row.id,
        name: row.name,
        currency: row.currency,
        quantity: Number(row.quantity),
        currentPrice: Number(row.current_price),
        openPrice: Number(row.opening_price),
        openedAt: row.opened_at,
        closedAt: row.closed_at ?? '',
        error: '',
        isSaving: false,
        persistedSignature: '',
      }

      editableRow.persistedSignature = getRowSignature(editableRow)
      return editableRow
    })

    await loadProfitLossFxRates()
  } catch (error) {
    errorMsg.value = error instanceof Error ? error.message : 'Failed to load stock rows.'
  } finally {
    loading.value = false
  }
}

watch(
  selectedPeriodMonth,
  () => {
    void loadRows()
  },
  { immediate: true },
)

watch(
  () => settings.displayCurrency,
  () => {
    void loadProfitLossFxRates()
  },
)

const addRow = () => {
  const editableRow: EditableStockRow = {
    localId: `new-${Date.now()}-${Math.random()}`,
    id: null,
    name: '',
    currency: 'PLN',
    quantity: 1,
    currentPrice: 0,
    openPrice: 0,
    openedAt: selectedPeriodMonth.value,
    closedAt: '',
    error: '',
    isSaving: false,
    persistedSignature: '',
  }

  editableRow.persistedSignature = getRowSignature(editableRow)
  editableRows.value.unshift(editableRow)
  void loadProfitLossFxRates()
}

const validateRow = (row: EditableStockRow) => {
  if (row.name.trim().length < 1) return 'Name is required.'
  if (!allowedCurrencies.includes(row.currency as (typeof allowedCurrencies)[number])) {
    return 'Currency must be one of: PLN, EUR, USD.'
  }
  if (!Number.isFinite(row.quantity) || row.quantity <= 0) return 'Quantity must be > 0.'
  if (!Number.isFinite(row.currentPrice) || row.currentPrice < 0) return 'Current price must be >= 0.'
  if (!Number.isFinite(row.openPrice) || row.openPrice < 0) return 'Open price must be >= 0.'
  if (!row.openedAt) return 'Open date is required.'
  if (row.closedAt && row.closedAt < row.openedAt) return 'Close date cannot be earlier than open date.'
  return ''
}

const saveRow = async (localId: string) => {
  const row = editableRows.value.find((item) => item.localId === localId)
  if (!row || row.isSaving) return

  row.error = validateRow(row)
  if (row.error) return
  row.isSaving = true

  const payload = {
    name: row.name.trim(),
    currency: row.currency.toUpperCase(),
    quantity: row.quantity,
    current_price: Number(row.currentPrice.toFixed(2)),
    opening_price: Number(row.openPrice.toFixed(2)),
    opened_at: row.openedAt,
    closed_at: row.closedAt || null,
  }

  try {
    if (row.id) {
      const { error } = await supabase.from('stocks_positions').update(payload).eq('id', row.id)
      if (error) throw error
    } else {
      const { data, error } = await supabase.from('stocks_positions').insert(payload).select('id').single()
      if (error) throw error
      row.id = data.id
      row.localId = data.id
    }

    row.persistedSignature = getRowSignature(row)
    row.error = ''
    await loadProfitLossFxRates()
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
  if (!row || row.isSaving) return

  row.isSaving = true
  try {
    if (row.id) {
      const { error } = await supabase.from('stocks_positions').delete().eq('id', row.id)
      if (error) throw error
    }

    editableRows.value.splice(rowIndex, 1)
    await loadProfitLossFxRates()
  } catch (error) {
    row.error = error instanceof Error ? error.message : 'Failed to delete row.'
  } finally {
    row.isSaving = false
  }
}

const formatSignedCurrency = (value: number) => {
  const absFormatted = new Intl.NumberFormat('pl-PL', {
    style: 'currency',
    currency: settings.displayCurrency,
    maximumFractionDigits: 2,
  }).format(Math.abs(value))

  return value >= 0 ? `+${absFormatted}` : `-${absFormatted}`
}
</script>

<style scoped></style>
