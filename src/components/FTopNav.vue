<template>
  <header class="border-b border-border bg-surface">
    <nav class="mx-auto flex h-16 w-full max-w-6xl items-center justify-between px-6">
      <router-link to="/" class="font-serif text-xl font-bold text-text">FundsApp</router-link>

      <div class="flex items-center gap-3">
        <span class="hidden text-sm text-muted sm:inline">{{ auth.user?.email }}</span>
        <FButton
          type="button"
          variant="ghost"
          :icon="mdiLogoutVariant"
          icon-only
          aria-label="Wyloguj"
          @click="logout"
        />
      </div>
    </nav>
  </header>
</template>

<script setup lang="ts">
import { mdiLogoutVariant } from '@mdi/js'
import FButton from '@/components/FButton.vue'
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
