<template>
  <button
    :type="props.type"
    :disabled="props.disabled"
    :class="[
      'cursor-pointer rounded-[10px] px-[14px] py-[10px] font-bold transition disabled:cursor-not-allowed disabled:opacity-70',
      variantClass,
      props.customClass,
    ]"
  >
    <slot />
  </button>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = withDefaults(
  defineProps<{
    type?: 'button' | 'submit' | 'reset'
    disabled?: boolean
    variant?: 'primary' | 'ghost'
    customClass?: string
  }>(),
  {
    type: 'button',
    disabled: false,
    variant: 'primary',
    customClass: '',
  },
)

const variantClass = computed(() => {
  if (props.variant === 'ghost') return 'bg-transparent text-primary'
  return 'bg-primary text-surface'
})
</script>

<style scoped></style>
