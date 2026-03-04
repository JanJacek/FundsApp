<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const auth = useAuthStore()

const email = ref('')
const password = ref('')
const loading = ref(false)
const errorMsg = ref('')
const successMsg = ref('')

const onSubmit = async () => {
  errorMsg.value = ''
  successMsg.value = ''
  loading.value = true

  try {
    await auth.signUp(email.value, password.value)
    successMsg.value = 'Konto utworzone. Możesz się zalogować.'
    await router.push('/login')
  } catch (error) {
    errorMsg.value = error instanceof Error ? error.message : 'Nie udało się zarejestrować.'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <main class="grid min-h-screen place-items-center bg-auth p-6">
    <form
      class="grid w-full max-w-[420px] gap-3 rounded-[14px] bg-surface p-6 shadow-card"
      @submit.prevent="onSubmit"
    >
      <h1 class="mb-[6px] mt-0 text-[2em] font-bold leading-tight text-text">Rejestracja</h1>

      <label class="grid gap-[6px] font-semibold text-text">
        Email
        <input
          v-model="email"
          type="email"
          autocomplete="email"
          required
          class="rounded-[10px] border border-border px-3 py-2.5 text-base text-text outline-none"
        />
      </label>

      <label class="grid gap-[6px] font-semibold text-text">
        Hasło
        <input
          v-model="password"
          type="password"
          autocomplete="new-password"
          minlength="6"
          required
          class="rounded-[10px] border border-border px-3 py-2.5 text-base text-text outline-none"
        />
      </label>

      <p v-if="errorMsg" class="m-0 text-error">{{ errorMsg }}</p>
      <p v-if="successMsg" class="m-0 text-success">{{ successMsg }}</p>

      <button
        :disabled="loading"
        type="submit"
        class="cursor-pointer rounded-[10px] bg-primary px-[14px] py-[10px] font-bold text-surface disabled:cursor-not-allowed disabled:opacity-70"
      >
        {{ loading ? 'Tworzenie konta...' : 'Utwórz konto' }}
      </button>

      <router-link to="/login" class="text-muted hover:text-primary">
        Masz już konto? Zaloguj się
      </router-link>
    </form>
  </main>
</template>
