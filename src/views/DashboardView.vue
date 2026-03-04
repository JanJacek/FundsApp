<template>
  <main class="grid min-h-screen place-items-center bg-dashboard p-6">
    <FCard as="section" custom-class="max-w-[560px]">
      <h1 class="mt-0 text-[2em] font-bold leading-tight text-text">Panel</h1>
      <p class="mt-4 text-base text-text">
        Zalogowano jako:
        <strong class="text-text">{{ auth.user?.email }}</strong>
      </p>
      <FButton type="button" custom-class="mt-6" @click="logout">
        Wyloguj
      </FButton>
    </FCard>
  </main>
</template>

<script setup lang="ts">
import FButton from '@/components/FButton.vue'
import FCard from '@/components/FCard.vue'
import { useAuthStore } from '@/stores/auth'
import { useRouter } from 'vue-router'

const router = useRouter()
const auth = useAuthStore()

const logout = async () => {
  await auth.signOut()
  await router.push('/login')
}
</script>

<style scoped></style>
