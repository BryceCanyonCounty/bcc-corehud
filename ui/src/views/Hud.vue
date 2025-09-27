<script setup>
import { ref, onMounted, onBeforeUnmount, provide, readonly } from 'vue'
import CoresDisplay from '@/components/CoresDisplay.vue'

const DEFAULT_SLOT = Object.freeze({
  inner: 15,
  outer: 99,
  effectInside: null,
  effectNext: null
})

const createDefaultCores = () => ({
  health: { ...DEFAULT_SLOT },
  stamina: { ...DEFAULT_SLOT },
  hunger: null,
  thirst: null,
  stress: null,
  voice: null,
  horse_health: null,
  horse_stamina: null,
  horse_dirt: null,
  temperature: null
})

const cores = ref(createDefaultCores())
const visible = ref(false)
const devmode = ref(false)

provide('cores', readonly(cores))

const DEFAULT_PALETTE_ENTRY = Object.freeze({
  accent: '#ffffff',
  icon: '#ffffff',
  background: '#0c1018',
  track: 'rgba(17, 24, 39, 0.85)',
  border: '#1f2937',
  shadow: '0 18px 28px rgba(8, 13, 23, 0.45)'
})

const createDefaultPalette = () => ({
  default: { ...DEFAULT_PALETTE_ENTRY },
  health: { ...DEFAULT_PALETTE_ENTRY },
  stamina: { ...DEFAULT_PALETTE_ENTRY },
  hunger: { ...DEFAULT_PALETTE_ENTRY },
  thirst: { ...DEFAULT_PALETTE_ENTRY },
  stress: { ...DEFAULT_PALETTE_ENTRY },
  temperature: { ...DEFAULT_PALETTE_ENTRY },
  horse_health: { ...DEFAULT_PALETTE_ENTRY },
  horse_stamina: { ...DEFAULT_PALETTE_ENTRY },
  horse_dirt: { ...DEFAULT_PALETTE_ENTRY },
  voice: { ...DEFAULT_PALETTE_ENTRY }
})

const palette = ref(createDefaultPalette())

provide('palette', readonly(palette))

const clamp = (value, min, max, fallback) => {
  if (typeof value !== 'number' || Number.isNaN(value)) {
    return fallback
  }
  return Math.min(Math.max(value, min), max)
}

const normalizeCore = (payload, mapping) => {
  const inner = payload?.[mapping.inner]
  const outer = payload?.[mapping.outer]

  const effectInsideKey = typeof mapping.effectInside === 'string' ? mapping.effectInside : null
  const effectNextKey = typeof mapping.effectNext === 'string' ? mapping.effectNext : null

  const effectInside = effectInsideKey ? payload?.[effectInsideKey] : null
  const effectNext = effectNextKey ? payload?.[effectNextKey] : null

  const hasNumbers =
    typeof inner === 'number' ||
    typeof outer === 'number'

  const hasEffect =
    typeof effectInside === 'string' ||
    typeof effectNext === 'string'

  const requireEffect = mapping.requireEffect === true
  const hasData = requireEffect ? hasEffect : (hasNumbers || hasEffect)

  if (!hasData) {
    return null
  }

  return {
    inner: clamp(inner, 0, 15, DEFAULT_SLOT.inner),
    outer: clamp(outer, 0, 99, DEFAULT_SLOT.outer),
    effectInside: typeof effectInside === 'string' ? effectInside : null,
    effectNext: typeof effectNext === 'string' ? effectNext : null
  }
}

const CORE_MAP = {
  health: {
    inner: 'innerhealth',
    outer: 'outerhealth',
    effectInside: 'effect_health_inside',
    effectNext: 'effect_health_next'
  },
  stamina: {
    inner: 'innerstamina',
    outer: 'outerstamina',
    effectInside: 'effect_stamina_inside',
    effectNext: 'effect_stamina_next'
  },
  hunger: {
    inner: 'innerhunger',
    outer: 'outerhunger',
    effectInside: 'effect_hunger_inside',
    effectNext: 'effect_hunger_next'
  },
  thirst: {
    inner: 'innerthirst',
    outer: 'outerthirst',
    effectInside: 'effect_thirst_inside',
    effectNext: 'effect_thirst_next'
  },
  stress: {
    inner: 'innerstress',
    outer: 'outerstress',
    effectInside: 'effect_stress_inside',
    effectNext: 'effect_stress_next'
  },
  voice: {
    inner: 'innervoice',
    outer: 'outervoice',
    effectInside: 'effect_voice_inside',
    effectNext: 'effect_voice_next'
  },
  horse_health: {
    inner: 'innerhorse_health',
    outer: 'outerhorse_health',
    effectInside: 'effect_horse_health_inside',
    effectNext: 'effect_horse_health_next'
  },
  horse_stamina: {
    inner: 'innerhorse_stamina',
    outer: 'outerhorse_stamina',
    effectInside: 'effect_horse_stamina_inside',
    effectNext: 'effect_horse_stamina_next'
  },
  horse_dirt: {
    inner: 'innerhorse_dirt',
    outer: 'outerhorse_dirt',
    effectInside: 'effect_horse_dirt_inside',
    effectNext: 'effect_horse_dirt_next',
    requireEffect: true
  },
  temperature: {
    inner: 'innertemperature',
    outer: 'outertemperature',
    effectInside: 'effect_temperature_inside',
    effectNext: 'effect_temperature_next'
  }
}

const setCores = (corePayload) => {
  const next = {}
  const alwaysVisible = ['health', 'stamina', 'hunger', 'thirst', 'stress']

  for (const key of Object.keys(CORE_MAP)) {
    next[key] = normalizeCore(corePayload, CORE_MAP[key])
      || (alwaysVisible.includes(key) ? { ...DEFAULT_SLOT } : null)
  }
  cores.value = next
}

const handleMessage = (event) => {
  const { data } = event
  if (!data || typeof data.type !== 'string') {
    return
  }

  switch (data.type) {
    case 'hud':
      if (data.cores) {
        setCores(data.cores)
      }
      break

    case 'toggle':
      if (typeof data.visible === 'boolean') {
        visible.value = data.visible
      }
      break

    case 'palette':
      if (data.palette && typeof data.palette === 'object') {
        const next = createDefaultPalette()
        for (const [key, value] of Object.entries(data.palette)) {
          if (!value || typeof value !== 'object') {
            continue
          }

          if (!next[key]) {
            next[key] = { ...DEFAULT_PALETTE_ENTRY }
          }

          next[key] = { ...next[key], ...value }
        }

        palette.value = next
      }
      break

    case 'devmode':
      devmode.value = true
      break

    default:
      break
  }
}

onMounted(() => {
  window.addEventListener('message', handleMessage)
})

onBeforeUnmount(() => {
  window.removeEventListener('message', handleMessage)
})
</script>

<template>
  <div class="core-layout" v-if="visible || devmode">
    <CoresDisplay />
  </div>
</template>

<style scoped>
.core-layout {
  position: absolute;
  bottom: 4vh;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  justify-content: center;
  z-index: 10;
  pointer-events: none;
  width: max-content;
}
</style>
