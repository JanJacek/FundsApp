<template>
  <span
    :class="[
      'grid place-items-center rounded-full bg-primary/10 text-xs font-bold text-primary',
      sizeClass,
    ]"
  >
    {{ initial }}
  </span>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    text?: string
    size?: 'sm' | 'md' | 'lg'
  }>(),
  {
    text: '',
    size: 'md',
  },
)

const initial = computed(() => {
  const source = props.text.trim()
  if (!source) return 'U'
  return source.charAt(0).toUpperCase()
})

const sizeClass = computed(() => {
  if (props.size === 'sm') return 'h-7 w-7'
  if (props.size === 'lg') return 'h-10 w-10'
  return 'h-8 w-8'
})
</script>

<style scoped></style>
