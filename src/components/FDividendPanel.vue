<template>
  <section class="mx-auto w-full max-w-[69rem] space-y-4">
    <p class="m-0 text-sm text-muted">Pick a month to filter dividends by payment date.</p>

    <FMonthCalendar v-model="selectedPeriodMonth" />

    <section class="rounded-[12px] border border-border bg-surface p-4">
      <div class="mb-3 flex flex-wrap items-center justify-between gap-3">
        <h2 class="m-0 text-lg font-bold text-text">{{ selectedMonthLabel }} - Dividends</h2>
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

      <p v-if="loading" class="m-0 text-sm text-muted">Loading dividends...</p>
      <p v-else-if="errorMsg" class="m-0 text-sm text-error">{{ errorMsg }}</p>

      <template v-if="!loading && !errorMsg">
        <p v-if="editableRows.length === 0" class="m-0 text-sm text-muted">
          No dividend entries yet.
        </p>

        <FTable v-else :headers="dividendTableHeaders" :rows="editableRows" row-key="localId">
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
              v-else-if="header.key === 'value'"
              v-model.number="row.value"
              type="number"
              min="0"
              step="0.01"
              class="w-32 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
              @keydown.enter.prevent="void onCommit(row.localId)"
              @blur="void onCommit(row.localId)"
            />
            <input
              v-else-if="header.key === 'paidAt'"
              v-model="row.paidAt"
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
import { supabase } from '@/lib/supabase'
import { computed, ref, watch } from 'vue'

type DividendRow = {
  id: string
  name: string
  currency: string
  value: number | string
  paid_at: string
}

type EditableDividendRow = {
  localId: string
  id: string | null
  name: string
  currency: string
  value: number
  paidAt: string
  error: string
  isSaving: boolean
  persistedSignature: string
}

const loading = ref(false)
const errorMsg = ref('')
const editableRows = ref<EditableDividendRow[]>([])
const allowedCurrencies = ['PLN', 'EUR', 'USD'] as const
const dividendTableHeaders: FTableHeader[] = [
  { key: 'name', label: 'Name' },
  { key: 'currency', label: 'Currency' },
  { key: 'value', label: 'Value', numeric: true, align: 'left' },
  { key: 'paidAt', label: 'Date' },
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

const getRowSignature = (row: EditableDividendRow) =>
  JSON.stringify({
    name: row.name.trim(),
    currency: row.currency,
    value: Number.isFinite(row.value) ? Number(row.value.toFixed(2)) : row.value,
    paidAt: row.paidAt,
  })

const loadRows = async () => {
  loading.value = true
  errorMsg.value = ''

  try {
    const { monthStart, monthEnd } = getMonthBounds(selectedPeriodMonth.value)
    const { data, error } = await supabase
      .from('dividends_entries')
      .select('id, name, currency, value, paid_at')
      .gte('paid_at', monthStart)
      .lte('paid_at', monthEnd)
      .order('paid_at', { ascending: false })
      .order('name', { ascending: true })

    if (error) throw error

    editableRows.value = ((data ?? []) as DividendRow[]).map((row) => {
      const editableRow: EditableDividendRow = {
        localId: row.id,
        id: row.id,
        name: row.name,
        currency: row.currency,
        value: Number(row.value),
        paidAt: row.paid_at,
        error: '',
        isSaving: false,
        persistedSignature: '',
      }

      editableRow.persistedSignature = getRowSignature(editableRow)
      return editableRow
    })
  } catch (error) {
    errorMsg.value = error instanceof Error ? error.message : 'Failed to load dividend rows.'
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

const addRow = () => {
  const editableRow: EditableDividendRow = {
    localId: `new-${Date.now()}-${Math.random()}`,
    id: null,
    name: '',
    currency: 'PLN',
    value: 0,
    paidAt: selectedPeriodMonth.value,
    error: '',
    isSaving: false,
    persistedSignature: '',
  }

  editableRow.persistedSignature = getRowSignature(editableRow)
  editableRows.value.unshift(editableRow)
}

const validateRow = (row: EditableDividendRow) => {
  if (row.name.trim().length < 1) return 'Name is required.'
  if (!allowedCurrencies.includes(row.currency as (typeof allowedCurrencies)[number])) {
    return 'Currency must be one of: PLN, EUR, USD.'
  }
  if (!Number.isFinite(row.value) || row.value < 0) return 'Value must be >= 0.'
  if (!row.paidAt) return 'Date is required.'
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
    value: Number(row.value.toFixed(2)),
    paid_at: row.paidAt,
  }

  try {
    if (row.id) {
      const { error } = await supabase.from('dividends_entries').update(payload).eq('id', row.id)
      if (error) throw error
    } else {
      const { data, error } = await supabase.from('dividends_entries').insert(payload).select('id').single()
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
      const { error } = await supabase.from('dividends_entries').delete().eq('id', row.id)
      if (error) throw error
    }

    editableRows.value.splice(rowIndex, 1)
  } catch (error) {
    row.error = error instanceof Error ? error.message : 'Failed to delete row.'
  } finally {
    row.isSaving = false
  }
}
</script>

<style scoped></style>
