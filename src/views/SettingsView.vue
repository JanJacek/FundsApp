<template>
  <main class="min-h-[calc(100vh-4rem)] bg-dashboard p-6">
    <section class="mx-auto w-full max-w-[980px] space-y-8">
      <div>
        <h1 class="m-0 text-2xl font-bold text-text">Ustawienia</h1>
      </div>

      <div>
        <h2 class="m-0 text-lg font-bold text-text">Waluta prezentacji</h2>
        <p class="mt-2 text-sm text-muted">Waluta prezentacji wszystkich wartości w aplikacji.</p>

        <div class="mt-4 flex items-center gap-3">
          <span class="text-sm text-text">Waluta:</span>
          <FSelect
            :model-value="settings.displayCurrency"
            :options="currencyOptions"
            @update:model-value="settings.setDisplayCurrency"
          />
        </div>
      </div>

      <div>
        <h2 class="m-0 text-lg font-bold text-text">Avatar</h2>
        <p class="mt-2 text-sm text-muted">Wpisz swoje inicjały (maksymalnie 2 litery).</p>

        <div class="mt-4 flex flex-wrap items-end gap-3">
          <label class="grid gap-1 text-sm text-text">
            Inicjały
            <input
              v-model="avatarForm"
              type="text"
              maxlength="2"
              class="w-24 rounded-[10px] border border-border bg-surface px-3 py-2 text-sm uppercase text-text outline-none"
            />
          </label>

          <FButton
            type="button"
            :disabled="avatarSaving"
            @click="saveAvatar"
          >
            {{ avatarSaving ? 'Zapisywanie...' : 'Zapisz inicjały' }}
          </FButton>
        </div>
      </div>

      <div>
        <h2 class="m-0 text-lg font-bold text-text">Powiadomienia miesięczne</h2>
        <p class="mt-2 text-sm text-muted">
          Możesz zrezygnować z automatycznych powiadomień tworzonych raz w miesiącu.
        </p>

        <div class="mt-4 flex flex-wrap items-end gap-3">
          <label class="flex items-center gap-2 text-sm text-text">
            <input
              v-model="notificationsForm"
              type="checkbox"
              class="h-4 w-4 rounded border-border"
            />
            Otrzymuj miesięczne powiadomienia in-app
          </label>

          <FButton
            type="button"
            :disabled="notificationsSaving"
            @click="saveNotifications"
          >
            {{ notificationsSaving ? 'Zapisywanie...' : 'Zapisz powiadomienia' }}
          </FButton>
        </div>
      </div>

      <div>
        <h2 class="m-0 text-lg font-bold text-text">Struktura portfela</h2>
        <p class="mt-2 text-sm text-muted">
          Domyślnie: gotówka 4.6%, akcje 10%, ETF-y 67.4%, obligacje 18% (razem 100%).
        </p>

        <div class="mt-4 grid gap-3 sm:grid-cols-2">
          <label class="grid gap-1 text-sm text-text">
            Gotówka (%)
            <input
              v-model.number="portfolioForm.cashPct"
              type="number"
              min="0"
              max="100"
              step="0.1"
              class="rounded-[10px] border border-border bg-surface px-3 py-2 text-sm text-text outline-none"
            />
          </label>

          <label class="grid gap-1 text-sm text-text">
            Akcje (%)
            <input
              v-model.number="portfolioForm.stocksPct"
              type="number"
              min="0"
              max="100"
              step="0.1"
              class="rounded-[10px] border border-border bg-surface px-3 py-2 text-sm text-text outline-none"
            />
          </label>

          <label class="grid gap-1 text-sm text-text">
            ETF-y (%)
            <input
              v-model.number="portfolioForm.etfsPct"
              type="number"
              min="0"
              max="100"
              step="0.1"
              class="rounded-[10px] border border-border bg-surface px-3 py-2 text-sm text-text outline-none"
            />
          </label>

          <label class="grid gap-1 text-sm text-text">
            Obligacje (%)
            <input
              v-model.number="portfolioForm.bondsPct"
              type="number"
              min="0"
              max="100"
              step="0.1"
              class="rounded-[10px] border border-border bg-surface px-3 py-2 text-sm text-text outline-none"
            />
          </label>
        </div>

        <p class="mt-3 text-sm" :class="isTotalValid ? 'text-muted' : 'text-error'">
          Suma: {{ totalPct.toFixed(2) }}%
        </p>

        <FMessage v-if="saveError" variant="error">{{ saveError }}</FMessage>
        <FMessage v-if="saveSuccess" variant="success">{{ saveSuccess }}</FMessage>

        <div class="mt-4 flex flex-wrap gap-3">
          <FButton
            type="button"
            :disabled="saving || !isTotalValid"
            @click="savePortfolio"
          >
            {{ saving ? 'Zapisywanie...' : 'Zapisz strukturę' }}
          </FButton>

          <FButton
            type="button"
            variant="ghost"
            bordered
            :disabled="saving"
            @click="restoreDefaults"
          >
            Przywróć domyślne
          </FButton>
        </div>
      </div>
    </section>
  </main>
</template>

<script setup lang="ts">
import FButton from '@/components/FButton.vue'
import FMessage from '@/components/FMessage.vue'
import FSelect from '@/components/FSelect.vue'
import type { PortfolioAllocation } from '@/stores/settings'
import { DEFAULT_PORTFOLIO_ALLOCATION } from '@/stores/settings'
import { useSettingsStore } from '@/stores/settings'
import { computed, onMounted, ref } from 'vue'

const settings = useSettingsStore()
const saving = ref(false)
const saveError = ref('')
const saveSuccess = ref('')
const portfolioForm = ref<PortfolioAllocation>({ ...DEFAULT_PORTFOLIO_ALLOCATION })
const avatarSaving = ref(false)
const avatarForm = ref('')
const notificationsSaving = ref(false)
const notificationsForm = ref(true)

const currencyOptions = computed(() =>
  settings.availableCurrencies.map((currency) => ({ label: currency, value: currency })),
)

const totalPct = computed(
  () =>
    Number(portfolioForm.value.cashPct || 0) +
    Number(portfolioForm.value.stocksPct || 0) +
    Number(portfolioForm.value.etfsPct || 0) +
    Number(portfolioForm.value.bondsPct || 0),
)

const isTotalValid = computed(() => settings.isPortfolioAllocationValid(portfolioForm.value))

const loadSettings = async () => {
  saveError.value = ''
  await Promise.all([
    settings.loadPortfolioAllocation(),
    settings.loadAvatarInitials(),
    settings.loadMonthlyNotifications(),
  ])
  portfolioForm.value = { ...settings.portfolioAllocation }
  avatarForm.value = settings.avatarInitials
  notificationsForm.value = settings.monthlyNotificationsEnabled
}

const savePortfolio = async () => {
  saveError.value = ''
  saveSuccess.value = ''
  saving.value = true

  try {
    await settings.savePortfolioAllocation(portfolioForm.value)
    saveSuccess.value = 'Zapisano ustawienia struktury portfela.'
  } catch (error) {
    saveError.value = error instanceof Error ? error.message : 'Nie udało się zapisać ustawień.'
  } finally {
    saving.value = false
  }
}

const restoreDefaults = () => {
  saveError.value = ''
  saveSuccess.value = ''
  settings.resetPortfolioAllocation()
  portfolioForm.value = { ...settings.portfolioAllocation }
}

const saveAvatar = async () => {
  saveError.value = ''
  saveSuccess.value = ''
  avatarSaving.value = true

  try {
    await settings.saveAvatarInitials(avatarForm.value)
    avatarForm.value = settings.avatarInitials
    saveSuccess.value = 'Zapisano inicjały avatara.'
  } catch (error) {
    saveError.value = error instanceof Error ? error.message : 'Nie udało się zapisać inicjałów.'
  } finally {
    avatarSaving.value = false
  }
}

const saveNotifications = async () => {
  saveError.value = ''
  saveSuccess.value = ''
  notificationsSaving.value = true

  try {
    await settings.saveMonthlyNotifications(notificationsForm.value)
    saveSuccess.value = notificationsForm.value
      ? 'Powiadomienia miesięczne zostały włączone.'
      : 'Powiadomienia miesięczne zostały wyłączone.'
  } catch (error) {
    saveError.value =
      error instanceof Error ? error.message : 'Nie udało się zapisać ustawienia powiadomień.'
  } finally {
    notificationsSaving.value = false
  }
}

onMounted(() => {
  void loadSettings()
})
</script>

<style scoped></style>
