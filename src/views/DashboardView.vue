<template>
  <main class="grid min-h-[calc(100vh-4rem)] place-items-center bg-dashboard p-6">
    <FCard as="section" custom-class="max-w-[560px]">
      <h1 class="mt-0 text-[2em] font-bold leading-tight text-text">Panel</h1>
      <p class="mt-4 text-base text-text">
        Zalogowano jako:
        <strong class="text-text">{{ auth.user?.email }}</strong>
      </p>
    </FCard>
  </main>
</template>

<script setup lang="ts">
import FCard from '@/components/FCard.vue'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
</script>

<style scoped></style>
