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

        <div v-else class="overflow-x-auto">
          <table class="w-full border-collapse text-sm">
            <thead>
              <tr class="border-b border-border text-left text-muted">
                <th class="px-3 py-2 font-semibold">Name</th>
                <th class="px-3 py-2 font-semibold">Current Price</th>
                <th class="px-3 py-2 font-semibold">Open Price</th>
                <th class="px-3 py-2 font-semibold">Profit/Loss</th>
                <th class="px-3 py-2 font-semibold">Open Date</th>
                <th class="px-3 py-2 font-semibold">Close Date</th>
                <th class="px-3 py-2 font-semibold">Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in editableRows"
                :key="row.localId"
                class="border-b border-border/70"
              >
                <td class="px-3 py-2">
                  <input
                    v-model="row.name"
                    type="text"
                    maxlength="120"
                    class="w-44 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
                <td class="px-3 py-2">
                  <input
                    v-model.number="row.currentPrice"
                    type="number"
                    min="0"
                    step="0.01"
                    class="w-32 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
                <td class="px-3 py-2">
                  <input
                    v-model.number="row.openPrice"
                    type="number"
                    min="0"
                    step="0.01"
                    class="w-32 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
                <td class="px-3 py-2">
                  <span
                    class="font-semibold"
                    :class="rowProfitLoss(row) >= 0 ? 'text-success' : 'text-error'"
                  >
                    {{ formatSignedCurrency(rowProfitLoss(row)) }}
                  </span>
                </td>
                <td class="px-3 py-2">
                  <input
                    v-model="row.openedAt"
                    type="date"
                    class="rounded-[8px] border border-border px-2 py-1 text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
                <td class="px-3 py-2">
                  <input
                    v-model="row.closedAt"
                    type="date"
                    class="rounded-[8px] border border-border px-2 py-1 text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
                <td class="px-3 py-2">
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
                  <p v-if="row.error" class="mt-1 text-xs text-error">{{ row.error }}</p>
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
import { mdiDeleteOutline } from '@mdi/js'
import FMonthCalendar from '@/components/FMonthCalendar.vue'
import { supabase } from '@/lib/supabase'
import { computed, ref, watch } from 'vue'

type StockRow = {
  id: string
  name: string
  current_price: number | string
  opening_price: number | string
  opened_at: string
  closed_at: string | null
}

type EditableStockRow = {
  localId: string
  id: string | null
  name: string
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
    currentPrice: Number.isFinite(row.currentPrice) ? Number(row.currentPrice.toFixed(2)) : row.currentPrice,
    openPrice: Number.isFinite(row.openPrice) ? Number(row.openPrice.toFixed(2)) : row.openPrice,
    openedAt: row.openedAt,
    closedAt: row.closedAt || '',
  })

const loadRows = async () => {
  loading.value = true
  errorMsg.value = ''

  try {
    const { monthStart, monthEnd } = getMonthBounds(selectedPeriodMonth.value)
    const { data, error } = await supabase
      .from('stocks_positions')
      .select('id, name, current_price, opening_price, opened_at, closed_at')
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
  } catch (error) {
    errorMsg.value = error instanceof Error ? error.message : 'Failed to load stock rows.'
  } finally {
    loading.value = false
  }
}

watch(selectedPeriodMonth, () => {
  void loadRows()
}, { immediate: true })

const addRow = () => {
  const editableRow: EditableStockRow = {
    localId: `new-${Date.now()}-${Math.random()}`,
    id: null,
    name: '',
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
}

const rowProfitLoss = (row: EditableStockRow) => row.currentPrice - row.openPrice

const validateRow = (row: EditableStockRow) => {
  if (row.name.trim().length < 1) return 'Name is required.'
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
    current_price: Number(row.currentPrice.toFixed(2)),
    opening_price: Number(row.openPrice.toFixed(2)),
    opened_at: row.openedAt,
    closed_at: row.closedAt || null,
  }

  try {
    if (row.id) {
      const { error } = await supabase
        .from('stocks_positions')
        .update(payload)
        .eq('id', row.id)
      if (error) throw error
    } else {
      const { data, error } = await supabase
        .from('stocks_positions')
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
  if (!row || row.isSaving) return

  row.isSaving = true
  try {
    if (row.id) {
      const { error } = await supabase
        .from('stocks_positions')
        .delete()
        .eq('id', row.id)
      if (error) throw error
    }
    editableRows.value.splice(rowIndex, 1)
  } catch (error) {
    row.error = error instanceof Error ? error.message : 'Failed to delete row.'
  } finally {
    row.isSaving = false
  }
}

const formatSignedCurrency = (value: number) => {
  const absFormatted = new Intl.NumberFormat('pl-PL', {
    style: 'currency',
    currency: 'PLN',
    maximumFractionDigits: 2,
  }).format(Math.abs(value))

  return value >= 0 ? `+${absFormatted}` : `-${absFormatted}`
}
</script>

<style scoped></style>
