<template>
  <section class="rounded-[12px] border border-border bg-surface p-4">
    <div class="mb-4 flex items-center justify-between">
      <button
        type="button"
        class="rounded-[8px] p-2 text-text hover:bg-primary/5"
        aria-label="Previous year"
        @click="displayedYear -= 1"
      >
        <svg class="h-4 w-4" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
          <path :d="mdiChevronLeft" />
        </svg>
      </button>

      <strong class="text-base text-text">{{ displayedYear }}</strong>

      <button
        type="button"
        class="rounded-[8px] p-2 text-text hover:bg-primary/5"
        aria-label="Next year"
        @click="displayedYear += 1"
      >
        <svg class="h-4 w-4" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
          <path :d="mdiChevronRight" />
        </svg>
      </button>
    </div>

    <div class="grid grid-cols-3 gap-2 sm:grid-cols-4">
      <button
        v-for="month in months"
        :key="month.value"
        type="button"
        class="rounded-[8px] border px-3 py-2 text-sm transition"
        :class="isSelected(month.value)
          ? 'border-primary bg-primary text-surface'
          : 'border-border bg-surface text-text hover:bg-primary/5'"
        @click="selectMonth(month.value)"
      >
        {{ month.label }}
      </button>
    </div>
  </section>
</template>

<script setup lang="ts">
import { mdiChevronLeft, mdiChevronRight } from '@mdi/js'
import { ref, watch } from 'vue'

const props = defineProps<{
  modelValue: string
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: string): void
}>()

const parseYearMonth = (value: string) => {
  const [yearRaw, monthRaw] = value.split('-')
  const year = Number(yearRaw)
  const month = Number(monthRaw)
  return { year, month }
}

const monthLabels = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']

const months = monthLabels.map((label, index) => ({
  label,
  value: index + 1,
}))

const { year } = parseYearMonth(props.modelValue)
const displayedYear = ref(Number.isFinite(year) ? year : new Date().getFullYear())

watch(
  () => props.modelValue,
  (value) => {
    const parsed = parseYearMonth(value)
    if (Number.isFinite(parsed.year)) {
      displayedYear.value = parsed.year
    }
  },
)

const selectMonth = (month: number) => {
  const monthString = String(month).padStart(2, '0')
  emit('update:modelValue', `${displayedYear.value}-${monthString}-01`)
}

const isSelected = (month: number) => {
  const parsed = parseYearMonth(props.modelValue)
  return parsed.year === displayedYear.value && parsed.month === month
}
</script>

<style scoped></style>
