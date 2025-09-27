<script setup>
import { computed, inject } from 'vue'

const OUTER_RADIUS = 17
const OUTER_CIRCUMFERENCE = 2 * Math.PI * OUTER_RADIUS

const props = defineProps({
  type: { type: String, required: true },
  inner: { type: Number, default: 0 },
  outer: { type: Number, default: 0 },
  effectInside: { type: String, default: null },
  effectNext: { type: String, default: null }
})

const ICON_CLASS_MAP = {
  health: 'fa-solid fa-heart',
  stamina: 'fa-solid fa-bolt',
  hunger: 'fa-solid fa-apple-whole',
  thirst: 'fa-solid fa-bottle-water',
  stress: 'fa-solid fa-face-tired',
  horse_health: 'fa-solid fa-horse',
  horse_stamina: 'fa-solid fa-horse-head',
  horse_dirt: 'fa-solid fa-broom',
  voice: 'fa-solid fa-microphone-lines',
  default: 'fa-solid fa-circle'
}

const ICON_IMAGE_MAP = {
  health: {
    wounded: 'cores/rpg_textures/rpg_wounded.png',
    sick_01: 'cores/rpg_textures/rpg_sick_01.png',
    sick_02: 'cores/rpg_textures/rpg_sick_02.png',
    snake_venom: 'cores/rpg_textures/rpg_snake_venom.png'
  },
  stamina: {
    drained: 'cores/rpg_textures/rpg_drained.png'
  },
  hunger: {
    default: 'cores/rpg_textures/rpg_consumable_apple.png',
    starving: 'cores/rpg_textures/rpg_underweight.png',
    overfed: 'cores/rpg_textures/rpg_overfed.png'
  },
  thirst: {
    default: 'cores/rpg_textures/rpg_generic_bottle.png',
    parched: 'cores/rpg_textures/rpg_drained.png'
  },
  temperature: {
    cold: 'cores/rpg_textures/rpg_cold.png',
    hot: 'cores/rpg_textures/rpg_hot.png'
  },
  horse_dirt: {
    horse_dirty: 'cores/rpg_textures/rpg_horse_dirty.png'
  }
}

const CORE_SPRITE_FOLDERS = {
  health: 'rpg_core_health',
  stamina: 'rpg_core_stamina',
  horse_health: 'rpg_core_horse_health',
  horse_stamina: 'rpg_core_horse_stamina'
}

let rawBaseUrl = '/'
if (typeof import.meta !== 'undefined' && import.meta.env && typeof import.meta.env.BASE_URL === 'string' && import.meta.env.BASE_URL !== '') {
  rawBaseUrl = import.meta.env.BASE_URL
}

const BASE_URL = rawBaseUrl.endsWith('/') ? rawBaseUrl : `${rawBaseUrl}/`

const toAssetPath = (relativePath) => {
  if (typeof relativePath !== 'string' || relativePath.length === 0) {
    return null
  }
  return `${BASE_URL}${relativePath.replace(/^\/+/, '')}`
}

const paletteInjection = inject('palette', null)

const fallbackEntry = Object.freeze({
  accent: '#ffffff',
  icon: '#ffffff',
  background: '#0c1018',
  track: 'rgba(17, 24, 39, 0.85)',
  border: '#1f2937',
  shadow: '0 18px 28px rgba(8, 13, 23, 0.45)'
})

const paletteEntry = computed(() => {
  const source = paletteInjection?.value?.[props.type] || paletteInjection?.value?.default
  if (source && typeof source === 'object') {
    return {
      accent: source.accent ?? fallbackEntry.accent,
      icon: source.icon ?? fallbackEntry.icon,
      background: source.background ?? fallbackEntry.background,
      track: source.track ?? fallbackEntry.track,
      border: source.border ?? fallbackEntry.border,
      shadow: source.shadow ?? fallbackEntry.shadow
    }
  }
  return fallbackEntry
})

const normaliseEffectKey = (value) => {
  if (typeof value !== 'string') {
    return null
  }
  return value.toLowerCase()
}

const resolveIconImage = () => {
  const entry = ICON_IMAGE_MAP[props.type]
  if (entry) {
    const insideKey = normaliseEffectKey(props.effectInside)
    if (insideKey && entry[insideKey]) {
      const asset = toAssetPath(entry[insideKey])
      if (asset) {
        return asset
      }
    }

    const nextKey = normaliseEffectKey(props.effectNext)
    if (nextKey && entry[nextKey]) {
      const asset = toAssetPath(entry[nextKey])
      if (asset) {
        return asset
      }
    }

    if (entry.default) {
      const asset = toAssetPath(entry.default)
      if (asset) {
        return asset
      }
    }
  }

  const folder = CORE_SPRITE_FOLDERS[props.type]
  if (!folder) {
    return null
  }

  const numericInner = Number(props.inner)
  const safeInner = Number.isFinite(numericInner) ? numericInner : 0
  const index = Math.max(0, Math.min(15, Math.round(safeInner)))
  return toAssetPath(`cores/${folder}/core_state_${index}.png`)
}

const iconImage = computed(resolveIconImage)
const iconClass = computed(() => {
  if (iconImage.value) {
    return null
  }

  if (props.type === 'temperature') {
    return null
  }

  const entry = ICON_CLASS_MAP[props.type]
  if (entry) {
    return entry
  }

  return ICON_CLASS_MAP.default
})
const accentColor = computed(() => paletteEntry.value.accent)
const iconColor = computed(() => paletteEntry.value.icon)
const backgroundColor = computed(() => paletteEntry.value.background)
const trackColor = computed(() => paletteEntry.value.track)
const borderColor = computed(() => paletteEntry.value.border)
const iconShadow = computed(() => paletteEntry.value.shadow)

const clampPercent = (value, max) => {
  const numeric = typeof value === 'number' ? value : 0
  const clamped = Math.max(0, Math.min(numeric, max))
  return (clamped / max) * 100
}

const outerPercent = computed(() => clampPercent(props.outer, 99))
const innerPercent = computed(() => clampPercent(props.inner, 15))

const outerDashOffset = computed(
  () => ((100 - outerPercent.value) / 100) * OUTER_CIRCUMFERENCE
)

const coreFillStyle = computed(() => {
  return {
    backgroundColor: '#0c1018',              // dark background
    boxShadow: `inset 0 0 0 1.4px #1f2937`, // dark border
    color: '#ffffff'                        // white icon/text if needed
  }
})

const effectLabel = computed(() => props.effectInside || props.effectNext || '')
</script>

<template>
  <div
    class="core-slot"
    :style="{
      '--accent-color': accentColor,
      '--icon-color': iconColor,
      '--track-color': trackColor,
      '--inner-bg': backgroundColor,
      '--icon-shadow': iconShadow,
      '--inner-border': borderColor
    }"
  >
    <svg class="core-gauge" viewBox="0 0 40 40" aria-hidden="true">
      <circle
        class="ring ring--outer-track"
        cx="20"
        cy="20"
        :r="OUTER_RADIUS"
      />
      <circle
        class="ring ring--outer-fill"
        cx="20"
        cy="20"
        :r="OUTER_RADIUS"
        :stroke-dasharray="OUTER_CIRCUMFERENCE"
        :stroke-dashoffset="outerDashOffset"
      />
    </svg>

    <div class="core-fill" :style="coreFillStyle"></div>
    <img
      v-if="iconImage"
      class="core-icon-img"
      :src="iconImage"
      :alt="`${type} icon`"
      draggable="false"
    />
    <i v-else-if="iconClass" class="core-icon" :class="iconClass" aria-hidden="true"></i>

    <span v-if="effectLabel" class="core-effect">{{ effectLabel }}</span>
  </div>
</template>

<style scoped>
.core-slot {
  position: relative;
  width: 3.65rem;
  height: 3.65rem;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 9999px;
  filter: drop-shadow(0 8px 16px rgba(15, 23, 42, 0.35));
  --accent-color: #ffffff;
  --icon-color: #ffffff;
  --track-color: rgba(17, 24, 39, 0.85);
  --inner-bg: #0c1018;
  --icon-shadow: 0 4px 8px rgba(8, 13, 23, 0.6);
  --inner-border: #1f2937;
}

.core-gauge {
  position: absolute;
  inset: 0;
  transform: rotate(-90deg);
}

.ring {
  fill: none;
  stroke-width: 4;
  stroke-linecap: round;
}

.ring--outer-track {
  stroke: var(--track-color);
}

.ring--outer-fill {
  stroke: var(--accent-color);
  transition: stroke-dashoffset 0.25s ease;
}

.core-fill {
  position: absolute;
  inset: 6px;
  border-radius: 50%;
  overflow: hidden;
  transition: background 0.3s ease;
}

.core-icon {
  position: relative;
  z-index: 1;
  font-size: 2.1rem;
  color: var(--icon-color);
  text-shadow: var(--icon-shadow);
}

.core-icon-img {
  position: relative;
  z-index: 1;
  width: 3.65rem;
  height:3.65rem;
  object-fit: contain;
  box-shadow: var(--icon-shadow);
  border-radius: 50%;
  user-select: none;
  pointer-events: none;
}

.core-effect {
  position: absolute;
  bottom: -0.55rem;
  font-size: 0.6rem;
  font-weight: 600;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  color: rgba(55, 65, 81, 0.75);
}
</style>
