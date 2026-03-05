<template>
  <div class="overflow-x-auto">
    <table :class="tableClass">
      <thead>
        <tr :class="headRowClass">
          <th
            v-for="header in headers"
            :key="header.key"
            :class="header.thClass || defaultThClass"
          >
            {{ header.label }}
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="(row, rowIndex) in rows"
          :key="resolveRowKey(row, rowIndex)"
          :class="bodyRowClass"
        >
          <td
            v-for="(header, colIndex) in headers"
            :key="`${resolveRowKey(row, rowIndex)}-${header.key}`"
            :class="header.tdClass || defaultTdClass"
          >
            <slot
              name="cell"
              :row="row"
              :header="header"
              :row-index="rowIndex"
              :col-index="colIndex"
            >
              {{ stringifyCellValue(row, header.key) }}
            </slot>
          </td>
        </tr>
      </tbody>
      <tfoot v-if="$slots.footer">
        <slot name="footer" />
      </tfoot>
    </table>
  </div>
</template>

<script setup lang="ts">
export type FTableHeader = {
  key: string
  label: string
  thClass?: string
  tdClass?: string
}

const props = withDefaults(
  defineProps<{
    headers: FTableHeader[]
    rows: any[]
    rowKey?: string
    tableClass?: string
    headRowClass?: string
    bodyRowClass?: string
    defaultThClass?: string
    defaultTdClass?: string
  }>(),
  {
    rowKey: 'id',
    tableClass: 'w-full border-collapse text-sm',
    headRowClass: 'border-b border-border text-left text-muted',
    bodyRowClass: 'border-b border-border/70',
    defaultThClass: 'px-3 py-2 font-semibold',
    defaultTdClass: 'px-3 py-2',
  },
)

const resolveRowKey = (row: any, rowIndex: number) => {
  const keyField = props.rowKey || 'id'
  const value = row[keyField]
  if (typeof value === 'string' || typeof value === 'number') return value
  return rowIndex
}

const stringifyCellValue = (row: any, key: string) => {
  const value = row[key]
  if (value === null || value === undefined) return ''
  return String(value)
}
</script>

<style scoped></style>
