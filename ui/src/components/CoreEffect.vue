<script setup>
import { computed, ref, watch, onUnmounted } from 'vue'

const props = defineProps({
  effect: { type: String, default: null }
})

const visible = ref(true)
let pulseInterval = null

const pulsingEffects = [
  'agitation',
  'background',
  'confusion',
  'core_background',
  'disoriented',
  'menu_background',
  'overfeed',
  'overweight',
  'sick_01',
  'sick_02',
  'snake_venom',
  'tracked',
  'underweight'
]

const shouldPulse = computed(() => pulsingEffects.includes(props.effect))
const effectPath = computed(() =>
  props.effect ? `./cores/rpg_textures/rpg_${props.effect}.png` : null
)

watch(() => props.effect, (newEffect) => {
  clearInterval(pulseInterval)
  visible.value = true

  if (pulsingEffects.includes(newEffect)) {
    pulseInterval = setInterval(() => {
      visible.value = !visible.value
    }, 500)
  }
}, { immediate: true })

onUnmounted(() => {
  clearInterval(pulseInterval)
})
</script>

<template>
  <img
    v-if="effect && visible"
    :src="effectPath"
    class="absolute z-20 w-5 h-5 left-12 top-1"
    alt="effect"
  />
</template>

<style scoped>
img {
  pointer-events: none;
}
</style>
