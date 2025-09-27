<script setup>
import { inject, computed } from 'vue'
import CoreIcon from './CoreIcon.vue'

const props = defineProps({
  type: { type: String, required: true }
})

const cores = inject('cores')

const slotData = computed(() => {
  const source = cores?.value?.[props.type]
  if (!source) {
    return null
  }

  const effectInside = typeof source.effectInside === 'string' ? source.effectInside : null

  if (props.type === 'temperature') {
    const lowered = effectInside ? effectInside.toLowerCase() : null
    if (lowered !== 'hot' && lowered !== 'cold') {
      return null
    }
  }

  return {
    inner: typeof source.inner === 'number' ? source.inner : 15,
    outer: typeof source.outer === 'number' ? source.outer : 99,
    effectInside,
    effectNext: typeof source.effectNext === 'string' ? source.effectNext : null
  }
})
</script>

<template>
  <CoreIcon
    v-if="slotData"
    :type="type"
    :inner="slotData.inner"
    :outer="slotData.outer"
    :effect-inside="slotData.effectInside"
    :effect-next="slotData.effectNext"
  />
</template>
