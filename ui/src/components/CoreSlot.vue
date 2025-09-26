<script setup>
import { inject, computed } from 'vue'
import CoreIcon from './CoreIcon.vue'
import CoreMeter from './CoreMeter.vue'
import CoreEffect from './CoreEffect.vue'

const props = defineProps({
  type: { type: String, required: true }
})

const cores = inject('cores')

const slotData = computed(() => {
  const source = cores?.value?.[props.type]
  if (!source) {
    return null
  }

  return {
    inner: typeof source.inner === 'number' ? source.inner : 15,
    outer: typeof source.outer === 'number' ? source.outer : 99,
    effectInside: typeof source.effectInside === 'string' ? source.effectInside : null,
    effectNext: typeof source.effectNext === 'string' ? source.effectNext : null
  }
})
</script>

<template>
  <div v-if="slotData" class="relative w-14 h-14">
    <CoreIcon :type="type" :value="slotData.inner" :effect="slotData.effectInside" />
    <CoreEffect :effect="slotData.effectNext" />
    <CoreMeter :value="slotData.outer" />
  </div>
</template>
