<script setup lang="ts">
const props = withDefaults(
  defineProps<{
    modelValue: string
    type?: string
    autocomplete?: string
    required?: boolean
    minlength?: number
    placeholder?: string
  }>(),
  {
    type: 'text',
    autocomplete: undefined,
    required: false,
    minlength: undefined,
    placeholder: undefined,
  },
)

const emit = defineEmits<{
  (e: 'update:modelValue', value: string): void
}>()

const onInput = (event: Event) => {
  const target = event.target as HTMLInputElement
  emit('update:modelValue', target.value)
}
</script>

<template>
  <input
    :value="props.modelValue"
    :type="props.type"
    :autocomplete="props.autocomplete"
    :required="props.required"
    :minlength="props.minlength"
    :placeholder="props.placeholder"
    class="rounded-[10px] border border-border px-3 py-2.5 text-base text-text outline-none"
    @input="onInput"
  />
</template>
