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
  <main class="auth-page">
    <form class="auth-card" @submit.prevent="onSubmit">
      <h1>Rejestracja</h1>

      <label>
        Email
        <input v-model="email" type="email" autocomplete="email" required />
      </label>

      <label>
        Hasło
        <input v-model="password" type="password" autocomplete="new-password" minlength="6" required />
      </label>

      <p v-if="errorMsg" class="error">{{ errorMsg }}</p>
      <p v-if="successMsg" class="success">{{ successMsg }}</p>

      <button :disabled="loading" type="submit">
        {{ loading ? 'Tworzenie konta...' : 'Utwórz konto' }}
      </button>

      <router-link to="/login">Masz już konto? Zaloguj się</router-link>
    </form>
  </main>
</template>

<style scoped>
.auth-page {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px;
  background: #f5f7fb;
}

.auth-card {
  width: min(420px, 100%);
  display: grid;
  gap: 12px;
  padding: 24px;
  border-radius: 14px;
  background: #fff;
  box-shadow: 0 10px 30px rgb(17 24 39 / 12%);
}

h1 {
  margin: 0 0 6px;
}

label {
  display: grid;
  gap: 6px;
  font-weight: 600;
}

input {
  border: 1px solid #d1d5db;
  border-radius: 10px;
  padding: 10px 12px;
  font: inherit;
}

button {
  border: 0;
  border-radius: 10px;
  padding: 10px 14px;
  font: inherit;
  font-weight: 700;
  color: #fff;
  background: #0f172a;
  cursor: pointer;
}

button:disabled {
  opacity: 0.7;
  cursor: not-allowed;
}

.error {
  margin: 0;
  color: #b42318;
}

.success {
  margin: 0;
  color: #067647;
}
</style>
