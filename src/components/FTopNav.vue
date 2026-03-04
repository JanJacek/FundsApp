<template>
  <header class="border-b border-border bg-surface">
    <nav class="mx-auto flex h-16 w-full max-w-6xl items-center justify-between px-6">
      <router-link to="/" class="font-serif text-xl font-bold text-text">FundsApp</router-link>
      <FUserMenu />
    </nav>
  </header>
</template>

<script setup lang="ts">
import FUserMenu from '@/components/FUserMenu.vue'
</script>

<style scoped></style>
