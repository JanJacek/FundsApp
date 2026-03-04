<template>
  <main class="min-h-[calc(100vh-4rem)] bg-dashboard p-6">
    <section class="mx-auto w-full max-w-[980px]">
      <h1 class="m-0 text-2xl font-bold text-text">Ustawienia</h1>
      <p class="mt-2 text-sm text-muted">Waluta prezentacji wszystkich wartości w aplikacji.</p>

      <div class="mt-4 flex items-center gap-3">
        <span class="text-sm text-text">Waluta:</span>
        <FSelect
          :model-value="settings.displayCurrency"
          :options="currencyOptions"
          @update:model-value="settings.setDisplayCurrency"
        />
      </div>
    </section>
  </main>
</template>

<script setup lang="ts">
import FSelect from '@/components/FSelect.vue'
import { useSettingsStore } from '@/stores/settings'
import { computed } from 'vue'

const settings = useSettingsStore()

const currencyOptions = computed(() =>
  settings.availableCurrencies.map((currency) => ({ label: currency, value: currency })),
)
</script>

<style scoped></style>
