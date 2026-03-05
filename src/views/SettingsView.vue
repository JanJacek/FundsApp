<template>
  <main class="min-h-[calc(100vh-4rem)] bg-dashboard p-6">
    <section class="mx-auto flex h-[calc(100vh-4rem-3rem)] w-full max-w-[69rem] flex-col gap-6">
      <h1 class="m-0 text-2xl font-bold text-text">Ustawienia</h1>

      <div class="min-h-0 flex-1 grid gap-6 md:grid-cols-[220px_minmax(0,1fr)]">
        <aside class="h-full rounded-[12px] border border-border bg-surface p-2">
          <nav class="space-y-1">
            <button
              v-for="section in sections"
              :key="section.id"
              type="button"
              class="flex w-full items-center rounded-[8px] px-3 py-2 text-left text-sm text-text hover:bg-primary/5"
              :class="activeSection === section.id ? 'bg-primary text-white hover:bg-primary' : ''"
              @click="activeSection = section.id"
            >
              {{ section.label }}
            </button>
          </nav>
        </aside>

        <section class="h-full rounded-[12px] border border-border bg-surface p-5">
          <FMessage v-if="saveError" variant="error">{{ saveError }}</FMessage>
          <FMessage v-if="saveSuccess" variant="success">{{ saveSuccess }}</FMessage>

          <div v-if="activeSection === 'presentation'" class="space-y-4">
            <h2 class="m-0 text-lg font-bold text-text">Waluta prezentacji</h2>
            <p class="m-0 text-sm text-muted">Waluta prezentacji wszystkich wartości w aplikacji.</p>

            <div class="flex items-center gap-3">
              <span class="text-sm text-text">Waluta:</span>
              <FSelect
                :model-value="settings.displayCurrency"
                :options="currencyOptions"
                @update:model-value="settings.setDisplayCurrency"
              />
            </div>
          </div>

          <div v-else-if="activeSection === 'avatar'" class="space-y-4">
            <h2 class="m-0 text-lg font-bold text-text">Avatar</h2>
            <p class="m-0 text-sm text-muted">Wpisz swoje inicjały (maksymalnie 2 litery).</p>

            <div class="flex flex-wrap items-end gap-3">
              <label class="grid gap-1 text-sm text-text">
                Inicjały
                <input
                  v-model="avatarForm"
                  type="text"
                  maxlength="2"
                  class="w-24 rounded-[10px] border border-border bg-surface px-3 py-2 text-sm uppercase text-text outline-none"
                />
              </label>

              <FButton type="button" :disabled="avatarSaving" @click="saveAvatar">
                {{ avatarSaving ? 'Zapisywanie...' : 'Zapisz inicjały' }}
              </FButton>
            </div>
          </div>

          <div v-else-if="activeSection === 'notifications'" class="space-y-4">
            <h2 class="m-0 text-lg font-bold text-text">Powiadomienia miesięczne</h2>
            <p class="m-0 text-sm text-muted">
              Możesz zrezygnować z automatycznych powiadomień tworzonych raz w miesiącu.
            </p>

            <div class="flex flex-wrap items-end gap-3">
              <label class="flex items-center gap-2 text-sm text-text">
                <input
                  v-model="notificationsForm"
                  type="checkbox"
                  class="h-4 w-4 rounded border-border"
                />
                Otrzymuj miesięczne powiadomienia in-app
              </label>

              <FButton type="button" :disabled="notificationsSaving" @click="saveNotifications">
                {{ notificationsSaving ? 'Zapisywanie...' : 'Zapisz powiadomienia' }}
              </FButton>
            </div>
          </div>

          <div v-else-if="activeSection === 'portfolio'" class="space-y-4">
            <h2 class="m-0 text-lg font-bold text-text">Struktura portfela</h2>
            <p class="m-0 text-sm text-muted">
              Domyślnie: gotówka 4.6%, akcje 10%, ETF-y 67.4%, obligacje 18% (razem 100%).
            </p>

            <div class="grid gap-3 sm:grid-cols-2">
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

            <p class="text-sm" :class="isTotalValid ? 'text-muted' : 'text-error'">
              Suma: {{ totalPct.toFixed(2) }}%
            </p>

            <div class="flex flex-wrap gap-3">
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

          <div v-else-if="activeSection === 'account'" class="space-y-4">
            <h2 class="m-0 text-lg font-bold text-text">Usuwanie konta</h2>
            <p class="m-0 text-sm text-muted">
              Ta operacja jest nieodwracalna. Konto oraz wszystkie Twoje dane w bazie zostaną usunięte.
            </p>

            <label class="grid gap-1 text-sm text-text">
              Aby potwierdzić, wpisz <strong>USUN</strong>
              <input
                v-model="deleteConfirmText"
                type="text"
                maxlength="4"
                class="w-28 rounded-[10px] border border-border bg-surface px-3 py-2 text-sm uppercase text-text outline-none"
              />
            </label>

            <FButton
              type="button"
              :disabled="deletingAccount || deleteConfirmText !== 'USUN'"
              @click="removeAccount"
            >
              {{ deletingAccount ? 'Usuwanie...' : 'Usuń konto' }}
            </FButton>
          </div>
        </section>
      </div>
    </section>
  </main>
</template>

<script setup lang="ts">
import FButton from '@/components/FButton.vue'
import FMessage from '@/components/FMessage.vue'
import FSelect from '@/components/FSelect.vue'
import { useAuthStore } from '@/stores/auth'
import type { PortfolioAllocation } from '@/stores/settings'
import { DEFAULT_PORTFOLIO_ALLOCATION } from '@/stores/settings'
import { useSettingsStore } from '@/stores/settings'
import { computed, onMounted, ref } from 'vue'
import { useRouter } from 'vue-router'

const router = useRouter()
const auth = useAuthStore()
const settings = useSettingsStore()
const saving = ref(false)
const saveError = ref('')
const saveSuccess = ref('')
const portfolioForm = ref<PortfolioAllocation>({ ...DEFAULT_PORTFOLIO_ALLOCATION })
const avatarSaving = ref(false)
const avatarForm = ref('')
const notificationsSaving = ref(false)
const notificationsForm = ref(true)
const deletingAccount = ref(false)
const deleteConfirmText = ref('')
const activeSection = ref<'presentation' | 'avatar' | 'notifications' | 'portfolio' | 'account'>(
  'presentation',
)
const sections = [
  { id: 'presentation', label: 'Waluta' },
  { id: 'avatar', label: 'Avatar' },
  { id: 'notifications', label: 'Powiadomienia' },
  { id: 'portfolio', label: 'Portfel' },
  { id: 'account', label: 'Konto' },
] as const

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

const removeAccount = async () => {
  if (deleteConfirmText.value !== 'USUN') return

  saveError.value = ''
  saveSuccess.value = ''
  deletingAccount.value = true

  try {
    await auth.deleteAccount()
    await router.replace('/login')
  } catch (error) {
    saveError.value = error instanceof Error ? error.message : 'Nie udało się usunąć konta.'
  } finally {
    deletingAccount.value = false
  }
}

onMounted(() => {
  void loadSettings()
})
</script>

<style scoped></style>
