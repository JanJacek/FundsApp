<script setup lang="ts">
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth'

const router = useRouter()
const auth = useAuthStore()

const logout = async () => {
  await auth.signOut()
  await router.push('/login')
}
</script>

<template>
  <main class="dashboard">
    <section class="card">
      <h1>Panel</h1>
      <p>Zalogowano jako: <strong>{{ auth.user?.email }}</strong></p>
      <button type="button" @click="logout">Wyloguj</button>
    </section>
  </main>
</template>

<style scoped>
.dashboard {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px;
  background: #eef2ff;
}

.card {
  width: min(560px, 100%);
  background: #fff;
  padding: 24px;
  border-radius: 14px;
  box-shadow: 0 10px 30px rgb(17 24 39 / 12%);
}

h1 {
  margin-top: 0;
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
</style>
