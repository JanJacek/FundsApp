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

        <FTable v-else :headers="bondsTableHeaders" :rows="editableRows" row-key="localId">
          <template #cell="{ row, header }">
            <select
              v-if="header.key === 'bondType'"
              v-model="row.bondType"
              class="rounded-[8px] border border-border px-2 py-1 text-text outline-none"
              @change="onRowInput(row.localId); void onCommit(row.localId)"
              @blur="void onCommit(row.localId)"
            >
              <option value="OTS">OTS</option>
              <option value="TOS">TOS</option>
            </select>
            <input
              v-else-if="header.key === 'purchaseDate'"
              v-model="row.purchaseDate"
              type="date"
              class="rounded-[8px] border border-border px-2 py-1 text-text outline-none"
              @input="onRowInput(row.localId)"
              @keydown.enter.prevent="void onCommit(row.localId)"
              @blur="void onCommit(row.localId)"
            />
            <span v-else-if="header.key === 'maturityDate'" class="text-text">{{ row.maturityDate }}</span>
            <input
              v-else-if="header.key === 'quantity'"
              v-model.number="row.quantity"
              type="number"
              min="1"
              step="1"
              class="w-24 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
              @input="onRowInput(row.localId)"
              @keydown.enter.prevent="void onCommit(row.localId)"
              @blur="void onCommit(row.localId)"
            />
            <input
              v-else-if="header.key === 'nominalPerBond'"
              v-model.number="row.nominalPerBond"
              type="number"
              min="0.01"
              step="0.01"
              class="w-24 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
              @input="onRowInput(row.localId)"
              @keydown.enter.prevent="void onCommit(row.localId)"
              @blur="void onCommit(row.localId)"
            />
            <input
              v-else-if="header.key === 'interestRate'"
              v-model.number="row.interestRate"
              type="number"
              min="0"
              step="0.0001"
              class="w-28 rounded-[8px] border border-border px-2 py-1 text-text outline-none"
              @input="onRowInput(row.localId)"
              @keydown.enter.prevent="void onCommit(row.localId)"
              @blur="void onCommit(row.localId)"
            />
            <span v-else-if="header.key === 'purchaseValue'" class="text-text">
              {{ formatCurrency(row.calc.purchaseValue) }}
            </span>
            <span v-else-if="header.key === 'interest'" class="text-text">
              {{ formatCurrency(row.calc.interest) }}
            </span>
            <span v-else-if="header.key === 'finalValue'" class="text-text">
              {{ formatCurrency(row.calc.finalValue) }}
            </span>
            <span
              v-else-if="header.key === 'roi'"
              class="font-semibold"
              :class="row.calc.roi >= 0 ? 'text-success' : 'text-error'"
            >
              {{ formatPercent(row.calc.roi) }}
            </span>
            <span
              v-else-if="header.key === 'status'"
              class="rounded-full px-2 py-0.5 text-xs font-semibold"
              :class="row.calc.status === 'OPEN' ? 'bg-success/15 text-success' : 'bg-muted/20 text-muted'"
            >
              {{ row.calc.status }}
            </span>
            <div v-else-if="header.key === 'actions'">
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
            </div>
          </template>
        </FTable>
      </template>
    </section>
  </section>
</template>

<script setup lang="ts">
import { mdiDeleteOutline } from '@mdi/js'
import { calculateBondPosition, getBondMaturityDate, type BondCalculation, type BondPosition, type BondType } from '@/lib/bonds'
import FMonthCalendar from '@/components/FMonthCalendar.vue'
import FTable from '@/components/FTable.vue'
import type { FTableHeader } from '@/components/FTable.vue'
import { supabase } from '@/lib/supabase'
import { computed, ref, watch } from 'vue'

type BondRow = {
  id: string
  bond_type: BondType
  purchase_date: string
  maturity_date: string
  quantity: number
  nominal_per_bond: number | string
  interest_rate: number | string
}

type EditableBondRow = {
  localId: string
  id: string | null
  bondType: BondType
  purchaseDate: string
  maturityDate: string
  quantity: number
  nominalPerBond: number
  interestRate: number
  calc: BondCalculation
  error: string
  isSaving: boolean
  persistedSignature: string
}

const loading = ref(false)
const errorMsg = ref('')
const editableRows = ref<EditableBondRow[]>([])
const bondsTableHeaders: FTableHeader[] = [
  { key: 'bondType', label: 'Type' },
  { key: 'purchaseDate', label: 'Purchase Date' },
  { key: 'maturityDate', label: 'Maturity Date' },
  { key: 'quantity', label: 'Quantity' },
  { key: 'nominalPerBond', label: 'Nominal' },
  { key: 'interestRate', label: 'Rate (decimal)' },
  { key: 'purchaseValue', label: 'Purchase Value' },
  { key: 'interest', label: 'Interest' },
  { key: 'finalValue', label: 'Final Value' },
  { key: 'roi', label: 'ROI' },
  { key: 'status', label: 'Status' },
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

const toPosition = (row: Pick<EditableBondRow, 'id' | 'bondType' | 'purchaseDate' | 'maturityDate' | 'quantity' | 'nominalPerBond' | 'interestRate'>): BondPosition => ({
  id: row.id ?? 'new',
  bondType: row.bondType,
  purchaseDate: row.purchaseDate,
  maturityDate: row.maturityDate,
  quantity: row.quantity,
  nominalPerBond: row.nominalPerBond,
  interestRate: row.interestRate,
})

const recalcRow = (row: EditableBondRow) => {
  row.maturityDate = getBondMaturityDate(row.bondType, row.purchaseDate)
  row.calc = calculateBondPosition(toPosition(row))
}

const getRowSignature = (row: EditableBondRow) =>
  JSON.stringify({
    bondType: row.bondType,
    purchaseDate: row.purchaseDate,
    quantity: row.quantity,
    nominalPerBond: Number.isFinite(row.nominalPerBond) ? Number(row.nominalPerBond.toFixed(2)) : row.nominalPerBond,
    interestRate: Number.isFinite(row.interestRate) ? Number(row.interestRate.toFixed(6)) : row.interestRate,
  })

const createEditableRow = (row: {
  localId: string
  id: string | null
  bondType: BondType
  purchaseDate: string
  quantity: number
  nominalPerBond: number
  interestRate: number
}) => {
  const editableRow: EditableBondRow = {
    localId: row.localId,
    id: row.id,
    bondType: row.bondType,
    purchaseDate: row.purchaseDate,
    maturityDate: getBondMaturityDate(row.bondType, row.purchaseDate),
    quantity: row.quantity,
    nominalPerBond: row.nominalPerBond,
    interestRate: row.interestRate,
    calc: {
      purchaseValue: 0,
      interest: 0,
      finalValue: 0,
      roi: 0,
      status: 'OPEN',
    },
    error: '',
    isSaving: false,
    persistedSignature: '',
  }

  recalcRow(editableRow)
  editableRow.persistedSignature = getRowSignature(editableRow)
  return editableRow
}

const loadRows = async () => {
  loading.value = true
  errorMsg.value = ''

  try {
    const { monthStart, monthEnd } = getMonthBounds(selectedPeriodMonth.value)
    const { data, error } = await supabase
      .from('bonds_positions')
      .select('id, bond_type, purchase_date, maturity_date, quantity, nominal_per_bond, interest_rate')
      .lte('purchase_date', monthEnd)
      .gte('maturity_date', monthStart)
      .order('purchase_date', { ascending: false })

    if (error) throw error

    const selectedYm = selectedPeriodMonth.value.slice(0, 7)
    const monthFilteredRows = ((data ?? []) as BondRow[]).filter((row) => {
      const purchaseYm = row.purchase_date.slice(0, 7)
      const maturityYm = row.maturity_date.slice(0, 7)
      return purchaseYm <= selectedYm && maturityYm >= selectedYm
    })

    editableRows.value = monthFilteredRows.map((row) => {
      const editableRow = createEditableRow({
        localId: row.id,
        id: row.id,
        bondType: row.bond_type,
        purchaseDate: row.purchase_date,
        quantity: Number(row.quantity),
        nominalPerBond: Number(row.nominal_per_bond),
        interestRate: Number(row.interest_rate),
      })
      editableRow.maturityDate = row.maturity_date
      recalcRow(editableRow)
      editableRow.persistedSignature = getRowSignature(editableRow)
      return editableRow
    })
  } catch (error) {
    errorMsg.value = error instanceof Error ? error.message : 'Failed to load bond rows.'
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
  const newRow = createEditableRow({
    localId: `new-${Date.now()}-${Math.random()}`,
    id: null,
    bondType: 'OTS',
    purchaseDate: selectedPeriodMonth.value,
    quantity: 1,
    nominalPerBond: 100,
    interestRate: 0,
  })

  editableRows.value.unshift(newRow)
}

const validateRow = (row: EditableBondRow) => {
  if (!['OTS', 'TOS'].includes(row.bondType)) return 'Bond type must be OTS or TOS.'
  if (!row.purchaseDate) return 'Purchase date is required.'
  if (!Number.isInteger(row.quantity) || row.quantity <= 0) return 'Quantity must be a positive integer.'
  if (!Number.isFinite(row.nominalPerBond) || row.nominalPerBond <= 0) return 'Nominal must be > 0.'
  if (!Number.isFinite(row.interestRate) || row.interestRate < 0) return 'Rate must be >= 0.'
  return ''
}

const saveRow = async (localId: string) => {
  const row = editableRows.value.find((item) => item.localId === localId)
  if (!row || row.isSaving) return

  recalcRow(row)
  row.error = validateRow(row)
  if (row.error) return

  row.isSaving = true

  const payload = {
    bond_type: row.bondType,
    purchase_date: row.purchaseDate,
    maturity_date: row.maturityDate,
    quantity: row.quantity,
    nominal_per_bond: Number(row.nominalPerBond.toFixed(2)),
    interest_rate: Number(row.interestRate.toFixed(6)),
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

    recalcRow(row)
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

  recalcRow(row)
  if (getRowSignature(row) === row.persistedSignature) return
  await saveRow(localId)
}

const onRowInput = (localId: string) => {
  const row = editableRows.value.find((item) => item.localId === localId)
  if (!row) return
  recalcRow(row)
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

const formatCurrency = (value: number) =>
  new Intl.NumberFormat('pl-PL', {
    style: 'currency',
    currency: 'PLN',
    maximumFractionDigits: 2,
  }).format(value)

const formatPercent = (value: number) => `${(value * 100).toFixed(2)}%`
</script>

<style scoped></style>
