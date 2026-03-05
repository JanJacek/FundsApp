<template>
  <nav class="mx-auto mb-4 w-full max-w-[69rem]">
    <ul class="flex flex-wrap gap-2">
      <li
        v-for="item in items"
        :key="item.value"
      >
        <button
          type="button"
          class="inline-flex rounded-[10px] border border-border px-3 py-1.5 text-sm text-text transition hover:bg-primary/5"
          :class="modelValue === item.value ? 'border-primary bg-primary text-white hover:bg-primary' : ''"
          @click="emit('update:modelValue', item.value)"
        >
          {{ item.label }}
        </button>
      </li>
    </ul>
  </nav>
</template>

<script setup lang="ts">
export type DashboardTab = 'wallet' | 'cash' | 'stocks' | 'etfs' | 'bonds' | 'dividends' | 'progress' | 'roi'

defineProps<{
  modelValue: DashboardTab
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', value: DashboardTab): void
}>()

const items: { label: string; value: DashboardTab }[] = [
  { label: 'Walet', value: 'wallet' },
  { label: 'Cash', value: 'cash' },
  { label: 'Stocks', value: 'stocks' },
  { label: 'ETFs', value: 'etfs' },
  { label: 'Bonds', value: 'bonds' },
  { label: 'Dividends', value: 'dividends' },
  { label: 'Progress', value: 'progress' },
  { label: 'ROI', value: 'roi' },
]
</script>

<style scoped></style>
