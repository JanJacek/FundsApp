<template>
  <section class="mx-auto w-full max-w-[69rem] space-y-4">
    <p class="m-0 text-sm text-muted">Pick a month to filter active bonds.</p>

    <FMonthCalendar v-model="selectedPeriodMonth" />

    <section class="rounded-[12px] border border-border bg-surface p-4">
      <div class="mb-3 flex flex-wrap items-center justify-between gap-3">
        <h2 class="m-0 text-lg font-bold text-text">{{ selectedMonthLabel }} - Bonds</h2>
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

      <p v-if="loading" class="m-0 text-sm text-muted">Loading bonds...</p>
      <p v-else-if="errorMsg" class="m-0 text-sm text-error">{{ errorMsg }}</p>

      <template v-if="!loading && !errorMsg">
        <p v-if="editableRows.length === 0" class="m-0 text-sm text-muted">
          No bonds for this month.
        </p>

        <div v-else class="overflow-x-auto">
          <table class="w-full border-collapse text-sm">
            <thead>
              <tr class="border-b border-border text-left text-muted">
                <th class="px-3 py-2 font-semibold">Name</th>
                <th class="px-3 py-2 font-semibold">Currency</th>
                <th class="px-3 py-2 font-semibold">Purchase Date</th>
                <th class="px-3 py-2 font-semibold">Term (months)</th>
                <th class="px-3 py-2 font-semibold">Maturity Date</th>
                <th class="px-3 py-2 font-semibold">Opening Value</th>
                <th class="px-3 py-2 font-semibold">Current Value</th>
                <th class="px-3 py-2 font-semibold">Interest %</th>
                <th class="px-3 py-2 font-semibold">P/L</th>
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
                    class="w-40 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
                <td class="px-3 py-2">
                  <input
                    v-model="row.currency"
                    type="text"
                    maxlength="3"
                    class="w-16 rounded-[8px] border border-border px-2 py-1 uppercase text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
                <td class="px-3 py-2">
                  <input
                    v-model="row.purchaseDate"
                    type="date"
                    class="rounded-[8px] border border-border px-2 py-1 text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
                <td class="px-3 py-2">
                  <input
                    v-model.number="row.termMonths"
                    type="number"
                    min="1"
                    step="1"
                    class="w-24 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
                <td class="px-3 py-2 text-text">
                  {{ row.maturityDate || '-' }}
                </td>
                <td class="px-3 py-2">
                  <input
                    v-model.number="row.openingValue"
                    type="number"
                    min="0"
                    step="0.01"
                    class="w-28 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
                <td class="px-3 py-2">
                  <input
                    v-model.number="row.currentValue"
                    type="number"
                    min="0"
                    step="0.01"
                    class="w-28 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
                <td class="px-3 py-2">
                  <input
                    v-model.number="row.interestRatePct"
                    type="number"
                    min="0"
                    step="0.01"
                    class="w-24 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
                <td class="px-3 py-2">
                  <span
                    class="font-semibold"
                    :class="rowProfitLoss(row) >= 0 ? 'text-success' : 'text-error'"
                  >
                    {{ formatSignedCurrency(rowProfitLoss(row), row.currency) }}
                  </span>
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

type BondRow = {
  id: string
  name: string
  currency: string
  purchase_date: string
  term_months: number
  maturity_date: string
  opening_value: number | string
  current_value: number | string
  interest_rate_pct: number | string
}

type EditableBondRow = {
  localId: string
  id: string | null
  name: string
  currency: string
  purchaseDate: string
  termMonths: number
  maturityDate: string
  openingValue: number
  currentValue: number
  interestRatePct: number
  error: string
  isSaving: boolean
  persistedSignature: string
}

const loading = ref(false)
const errorMsg = ref('')
const editableRows = ref<EditableBondRow[]>([])

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

const getRowSignature = (row: EditableBondRow) =>
  JSON.stringify({
    name: row.name.trim(),
    currency: row.currency.toUpperCase(),
    purchaseDate: row.purchaseDate,
    termMonths: row.termMonths,
    openingValue: Number.isFinite(row.openingValue) ? Number(row.openingValue.toFixed(2)) : row.openingValue,
    currentValue: Number.isFinite(row.currentValue) ? Number(row.currentValue.toFixed(2)) : row.currentValue,
    interestRatePct: Number.isFinite(row.interestRatePct)
      ? Number(row.interestRatePct.toFixed(2))
      : row.interestRatePct,
  })

const loadRows = async () => {
  loading.value = true
  errorMsg.value = ''

  try {
    const { monthStart, monthEnd } = getMonthBounds(selectedPeriodMonth.value)
    const { data, error } = await supabase
      .from('bonds_positions')
      .select(`
        id,
        name,
        currency,
        purchase_date,
        term_months,
        maturity_date,
        opening_value,
        current_value,
        interest_rate_pct
      `)
      .lte('purchase_date', monthEnd)
      .or(`maturity_date.is.null,maturity_date.gte.${monthStart}`)
      .order('purchase_date', { ascending: false })
      .order('name', { ascending: true })

    if (error) throw error

    editableRows.value = ((data ?? []) as BondRow[]).map((row) => {
      const editableRow: EditableBondRow = {
        localId: row.id,
        id: row.id,
        name: row.name,
        currency: row.currency,
        purchaseDate: row.purchase_date,
        termMonths: row.term_months,
        maturityDate: row.maturity_date,
        openingValue: Number(row.opening_value),
        currentValue: Number(row.current_value),
        interestRatePct: Number(row.interest_rate_pct),
        error: '',
        isSaving: false,
        persistedSignature: '',
      }

      editableRow.persistedSignature = getRowSignature(editableRow)
      return editableRow
    })
  } catch (error) {
    errorMsg.value = error instanceof Error ? error.message : 'Failed to load bond rows.'
  } finally {
    loading.value = false
  }
}

watch(selectedPeriodMonth, () => {
  void loadRows()
}, { immediate: true })

const addRow = () => {
  const editableRow: EditableBondRow = {
    localId: `new-${Date.now()}-${Math.random()}`,
    id: null,
    name: '',
    currency: 'PLN',
    purchaseDate: selectedPeriodMonth.value,
    termMonths: 12,
    maturityDate: '',
    openingValue: 0,
    currentValue: 0,
    interestRatePct: 0,
    error: '',
    isSaving: false,
    persistedSignature: '',
  }

  editableRow.persistedSignature = getRowSignature(editableRow)
  editableRows.value.unshift(editableRow)
}

const validateRow = (row: EditableBondRow) => {
  if (row.name.trim().length < 1) return 'Name is required.'
  if (!/^[A-Za-z]{3}$/.test(row.currency)) return 'Currency must be a 3-letter ISO code.'
  if (!row.purchaseDate) return 'Purchase date is required.'
  if (!Number.isInteger(row.termMonths) || row.termMonths <= 0) return 'Term must be a positive integer (months).'
  if (!Number.isFinite(row.openingValue) || row.openingValue < 0) return 'Opening value must be >= 0.'
  if (!Number.isFinite(row.currentValue) || row.currentValue < 0) return 'Current value must be >= 0.'
  if (!Number.isFinite(row.interestRatePct) || row.interestRatePct < 0) return 'Interest % must be >= 0.'
  return ''
}

const rowProfitLoss = (row: EditableBondRow) => row.currentValue - row.openingValue

const saveRow = async (localId: string) => {
  const row = editableRows.value.find((item) => item.localId === localId)
  if (!row || row.isSaving) return

  row.error = validateRow(row)
  if (row.error) return
  row.isSaving = true

  const payload = {
    name: row.name.trim(),
    currency: row.currency.toUpperCase(),
    purchase_date: row.purchaseDate,
    term_months: row.termMonths,
    opening_value: Number(row.openingValue.toFixed(2)),
    current_value: Number(row.currentValue.toFixed(2)),
    interest_rate_pct: Number(row.interestRatePct.toFixed(2)),
  }

  try {
    if (row.id) {
      const { error } = await supabase
        .from('bonds_positions')
        .update(payload)
        .eq('id', row.id)
      if (error) throw error
    } else {
      const { data, error } = await supabase
        .from('bonds_positions')
        .insert(payload)
        .select('id, maturity_date')
        .single()
      if (error) throw error
      row.id = data.id
      row.localId = data.id
      row.maturityDate = data.maturity_date
    }

    row.currency = row.currency.toUpperCase()

    if (row.id) {
      const { data, error } = await supabase
        .from('bonds_positions')
        .select('maturity_date')
        .eq('id', row.id)
        .single()
      if (error) throw error
      row.maturityDate = data.maturity_date
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
        .from('bonds_positions')
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

const formatSignedCurrency = (value: number, currency: string) => {
  const absFormatted = new Intl.NumberFormat('pl-PL', {
    style: 'currency',
    currency: /^[A-Za-z]{3}$/.test(currency) ? currency.toUpperCase() : 'PLN',
    maximumFractionDigits: 2,
  }).format(Math.abs(value))

  return value >= 0 ? `+${absFormatted}` : `-${absFormatted}`
}
</script>

<style scoped></style>
