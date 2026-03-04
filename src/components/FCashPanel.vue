<template>
  <section class="mx-auto w-full max-w-[980px] space-y-4">
    <p class="m-0 text-sm text-muted">Pick a month to see all cash positions for that period.</p>

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
                <th class="px-3 py-2 font-semibold">As of date</th>
                <th class="px-3 py-2 font-semibold">Note</th>
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
                    v-model="row.currency"
                    type="text"
                    maxlength="3"
                    class="w-20 rounded-[8px] border border-border px-2 py-1 uppercase text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
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
                <td class="px-3 py-2">
                  <input
                    v-model="row.asOfDate"
                    type="date"
                    class="rounded-[8px] border border-border px-2 py-1 text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
                <td class="px-3 py-2">
                  <input
                    v-model="row.note"
                    type="text"
                    maxlength="300"
                    placeholder="Optional note"
                    class="w-full min-w-[180px] rounded-[8px] border border-border px-2 py-1 text-text outline-none"
                    @keydown.enter.prevent="void onCommit(row.localId)"
                    @blur="void onCommit(row.localId)"
                  />
                </td>
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
          </table>
        </div>
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
  as_of_date: string
  note: string | null
}

type EditableCashRow = {
  localId: string
  id: string | null
  currency: string
  amount: number
  asOfDate: string
  note: string
  error: string
  isSaving: boolean
  persistedSignature: string
}

const now = new Date()
const initialMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-01`

const selectedPeriodMonth = ref(initialMonth)
const rows = ref<CashRow[]>([])
const editableRows = ref<EditableCashRow[]>([])
const loading = ref(false)
const errorMsg = ref('')

const getRowSignature = (row: EditableCashRow) =>
  JSON.stringify({
    currency: row.currency.toUpperCase(),
    amount: Number.isFinite(row.amount) ? Number(row.amount.toFixed(2)) : row.amount,
    asOfDate: row.asOfDate,
    note: row.note || '',
  })

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
    editableRows.value = rows.value.map((row) => {
      const editableRow: EditableCashRow = {
        localId: row.id,
        id: row.id,
        currency: row.currency,
        amount: Number(row.amount),
        asOfDate: row.as_of_date,
        note: row.note ?? '',
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

watch(selectedPeriodMonth, () => {
  void loadCashRows()
}, { immediate: true })

const addRow = () => {
  const [yearRaw, monthRaw] = selectedPeriodMonth.value.split('-')
  const year = Number(yearRaw)
  const month = Number(monthRaw)
  const lastDay = new Date(year, month, 0).getDate()
  const asOfDate = `${yearRaw}-${monthRaw}-${String(lastDay).padStart(2, '0')}`

  const editableRow: EditableCashRow = {
    localId: `new-${Date.now()}-${Math.random()}`,
    id: null,
    currency: 'PLN',
    amount: 0,
    asOfDate,
    note: '',
    error: '',
    isSaving: false,
    persistedSignature: '',
  }

  editableRow.persistedSignature = getRowSignature(editableRow)
  editableRows.value.unshift(editableRow)
}

const isSameMonth = (dateValue: string, periodMonth: string) =>
  dateValue.slice(0, 7) === periodMonth.slice(0, 7)

const validateRow = (row: EditableCashRow) => {
  if (!/^[A-Za-z]{3}$/.test(row.currency)) {
    return 'Currency must be a 3-letter ISO code.'
  }
  if (!Number.isFinite(row.amount) || row.amount < 0) {
    return 'Amount must be a non-negative number.'
  }
  if (!row.asOfDate) {
    return 'As of date is required.'
  }
  if (!isSameMonth(row.asOfDate, selectedPeriodMonth.value)) {
    return 'As of date must be in selected month.'
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
    currency: row.currency.toUpperCase(),
    amount: Number(row.amount.toFixed(2)),
    as_of_date: row.asOfDate,
    note: row.note || null,
  }

  try {
    if (row.id) {
      const { error } = await supabase
        .from('cash_balances')
        .update(payload)
        .eq('id', row.id)
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

    row.currency = row.currency.toUpperCase()
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
      const { error } = await supabase
        .from('cash_balances')
        .delete()
        .eq('id', row.id)
      if (error) throw error
    }

    editableRows.value.splice(rowIndex, 1)
  } catch (error) {
    row.error = error instanceof Error ? error.message : 'Failed to delete row.'
  }
}
</script>

<style scoped></style>
