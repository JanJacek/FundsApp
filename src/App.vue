<template>
  <div class="min-h-screen">
    <FTopNav v-if="auth.initialized && auth.isAuthenticated" />
    <RouterView />
  </div>
</template>

<script setup lang="ts">
import FTopNav from '@/components/FTopNav.vue'
import { useAuthStore } from '@/stores/auth'
import { RouterView } from 'vue-router'

const auth = useAuthStore()
</script>

<style scoped></style>
