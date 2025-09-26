<script setup>
import { computed } from 'vue'

const props = defineProps({
  value: { type: Number, default: 100 }
})

const meterIndex = computed(() => Math.floor(Math.max(0, Math.min(99, props.value))))
const meterPath = computed(() => `./cores/rpg_meter/rpg_meter_${meterIndex.value}.png`)
</script>

<template>
  <img :src="meterPath" class="w-full h-full absolute z-0 pointer-events-none" alt="meter" />
</template>