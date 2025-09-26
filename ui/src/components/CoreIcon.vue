<script setup>
import { computed, ref, watch, onUnmounted } from 'vue'

const props = defineProps({
  type: { type: String, required: true },
  value: { type: Number, default: 100 },
  effect: { type: String, default: null },
  effectPosition: { type: String, default: 'inside' } // 'inside' or 'next'
})

// Define pulsing effects
const pulsingEffects = [
  'agitation', 'background', 'confusion', 'core_background',
  'disoriented', 'menu_background',
  'overfeed', 'overweight', 'sick_01', 'sick_02', 'snake_venom',
  'tracked', 'underweight'
]

const usePulse = computed(() => props.effect && pulsingEffects.includes(props.effect))
const showEffectIcon = ref(false)
let pulseInterval = null

const typeToFolder = {
  health: 'rpg_core_health',
  stamina: 'rpg_core_stamina',
  temperature: 'rpg_core_stamina',
  horse_health: 'rpg_core_horse_health',
  horse_stamina: 'rpg_core_horse_stamina',
  horse_dirt: 'rpg_core_horse_health'
}

const stateIndex = computed(() => {
  if (typeof props.value !== 'number' || Number.isNaN(props.value)) {
    return 0
  }

  const raw = props.value > 15 ? (props.value * 15) / 100 : props.value
  const clamped = Math.max(0, Math.min(15, raw))
  return Math.floor(clamped + 0.0001)
})

const baseIconPath = computed(() =>
  `./cores/${typeToFolder[props.type] || 'rpg_core_default'}/core_state_${stateIndex.value}.png`
)

const effectIconPath = computed(() =>
  props.effect ? `./cores/rpg_textures/rpg_${props.effect}.png` : null
)

const currentIcon = computed(() => {
  if (!props.effect || props.effectPosition !== 'inside') {
    return baseIconPath.value
  }

  if (usePulse.value) {
    return showEffectIcon.value ? effectIconPath.value : baseIconPath.value
  }

  return effectIconPath.value || baseIconPath.value
})

// Start/stop pulsing
watch(
  () => props.effect,
  (newEffect) => {
    if (pulseInterval) {
      clearInterval(pulseInterval)
      pulseInterval = null
    }

    showEffectIcon.value = !!newEffect

    if (props.effectPosition === 'inside' && pulsingEffects.includes(newEffect)) {
      showEffectIcon.value = true
      pulseInterval = setInterval(() => {
        showEffectIcon.value = !showEffectIcon.value
      }, 500)
    }
  },
  { immediate: true }
)

onUnmounted(() => {
  clearInterval(pulseInterval)
})
</script>

<template>
  <img
    :src="currentIcon"
    class="w-full h-full absolute z-10 pointer-events-none"
    :alt="type"
  />
</template>
