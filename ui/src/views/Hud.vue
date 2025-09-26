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
  horse_health: null,
  horse_stamina: null,
  horse_dirt: null,
  temperature: null
})

const cores = ref(createDefaultCores())
const visible = ref(true)
const devmode = ref(false)

provide('cores', readonly(cores))

const clamp = (value, min, max, fallback) => {
  if (typeof value !== 'number' || Number.isNaN(value)) {
    return fallback
  }
  return Math.min(Math.max(value, min), max)
}

const normalizeCore = (payload, mapping) => {
  const inner = payload?.[mapping.inner]
  const outer = payload?.[mapping.outer]
  const effectInside = payload?.[mapping.effectInside]
  const effectNext = payload?.[mapping.effectNext]

  const hasData =
    typeof inner === 'number' ||
    typeof outer === 'number' ||
    typeof effectInside === 'string' ||
    typeof effectNext === 'string'

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
    effectNext: 'effect_horse_dirt_next'
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
  for (const key of Object.keys(CORE_MAP)) {
    next[key] = normalizeCore(corePayload, CORE_MAP[key])
      || (key === 'health' || key === 'stamina' ? { ...DEFAULT_SLOT } : null)
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
