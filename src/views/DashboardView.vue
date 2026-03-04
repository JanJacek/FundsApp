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
  <main class="grid min-h-screen place-items-center bg-dashboard p-6">
    <section class="w-full max-w-[560px] rounded-[14px] bg-surface p-6 shadow-card">
      <h1 class="mt-0 text-[2em] font-bold leading-tight text-text">Panel</h1>
      <p class="mt-4 text-base text-text">
        Zalogowano jako:
        <strong class="text-text">{{ auth.user?.email }}</strong>
      </p>
      <button
        type="button"
        @click="logout"
        class="mt-6 cursor-pointer rounded-[10px] bg-primary px-[14px] py-[10px] font-bold text-surface"
      >
        Wyloguj
      </button>
    </section>
  </main>
</template>
