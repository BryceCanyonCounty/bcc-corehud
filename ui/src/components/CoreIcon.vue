<script setup>
import { computed, inject } from 'vue'

const OUTER_RADIUS = 17
const OUTER_CIRCUMFERENCE = 2 * Math.PI * OUTER_RADIUS

const props = defineProps({
  type: { type: String, required: true },
  inner: { type: Number, default: 0 },
  outer: { type: Number, default: 0 },
  effectInside: { type: String, default: null },
  effectNext: { type: String, default: null },
  meta: { type: Object, default: null }
})

const ICON_CLASS_MAP = {
  health: 'fa-solid fa-heart',
  stamina: 'fa-solid fa-bolt',
  hunger: 'fa-solid fa-apple-whole',
  thirst: 'fa-solid fa-bottle-water',
  stress: 'fa-solid fa-face-tired',
  messages: 'fa-solid fa-envelope',
  clean_stats: 'fa-solid fa-soap',
  money: null,
  gold: null,
  exp: 'fa-solid fa-star',
  tokens: null,
  player_id: 'fa-solid fa-id-badge',
  logo: null,
  horse_health: 'fa-solid fa-horse',
  horse_stamina: 'fa-solid fa-horse-head',
  horse_dirt: null,
  voice: 'fa-solid fa-microphone-lines',
  temperature_value: null,
  default: 'fa-solid fa-circle'
}

const STAT_TYPES = new Set(['money', 'gold', 'exp', 'tokens', 'player_id'])
const ICONLESS_TYPES = new Set(['messages', 'clean_stats', 'logo'])

const ICON_IMAGE_MAP = {
  money: {
    default: 'cores/rpg_textures/money.png'
  },
  gold: {
    default: 'cores/rpg_textures/gold.png'
  },
  tokens: {
    default: 'cores/rpg_textures/token.png'
  },
  shield: {
    default: 'cores/rpg_textures/shield.png'
  },
  messages: {
    default: 'cores/rpg_textures/letter.png'
  },
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
  if (props.type === 'logo') {
    const logoSrc = props.meta && typeof props.meta.logo === 'string' ? props.meta.logo : null
    if (!logoSrc || logoSrc.length === 0) {
      return null
    }
    if (logoSrc.startsWith('http://') || logoSrc.startsWith('https://') || logoSrc.startsWith('nui://') || logoSrc.startsWith('data:')) {
      return logoSrc
    }
    return toAssetPath(logoSrc)
  }
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
  if (ICONLESS_TYPES.has(props.type)) {
    return null
  }

  const entry = ICON_CLASS_MAP[props.type]
  if (entry === null) {
    return null
  }
  if (typeof entry === 'string' && entry.length > 0) {
    return entry
  }

  return ICON_CLASS_MAP.default
})
const toClampedPercent = (value) => {
  const numeric = Number(value)
  if (!Number.isFinite(numeric)) {
    return null
  }
  return Math.min(Math.max(numeric, 0), 100)
}

const voiceMeta = computed(() => {
  if (props.type !== 'voice' || !props.meta || typeof props.meta !== 'object') {
    return null
  }

  const talking = props.meta.talking === true || props.meta.talking === 1 || props.meta.talking === 'true'
  const proximityPercent = toClampedPercent(props.meta.proximityPercent ?? props.meta.proximity)

  return {
    talking,
    proximityPercent
  }
})

const computeVoiceAccent = (percent) => {
  if (percent === null) {
    return null
  }

  const hue = Math.max(0, Math.min(120, 120 - (percent * 1.2)))
  return `hsl(${Math.round(hue)}, 85%, 60%)`
}

const accentColor = computed(() => {
  if (props.type === 'logo') {
    return '#ffffff'
  }
  if (props.type === 'voice') {
    const meta = voiceMeta.value
    if (meta?.talking) {
      const accent = computeVoiceAccent(meta.proximityPercent)
      if (accent) {
        return accent
      }
    }
  }
  return paletteEntry.value.accent
})

const trackColor = computed(() => {
  if (props.type === 'logo') {
    return 'transparent'
  }
  if (props.type === 'voice') {
    const meta = voiceMeta.value
    if (meta?.talking) {
      return 'rgba(30, 58, 138, 0.55)'
    }
  }
  return paletteEntry.value.track
})

const backgroundColor = computed(() => {
  if (props.type === 'logo') {
    return 'transparent'
  }
  if (props.type === 'voice') {
    const meta = voiceMeta.value
    if (meta?.talking) {
      return 'rgba(12, 18, 28, 0.9)'
    }
  }
  return paletteEntry.value.background
})

const borderColor = computed(() => paletteEntry.value.border)
const iconShadow = computed(() => {
  if (props.type === 'logo') {
    return 'none'
  }
  return paletteEntry.value.shadow
})
const iconColor = computed(() => {
  if (props.type === 'voice' && voiceMeta.value?.talking) {
    return '#f8fafc'
  }
  if (props.type === 'logo') {
    return '#ffffff'
  }
  return paletteEntry.value.icon
})

const coreSlotClasses = computed(() => {
  const classes = ['core-slot']
  if (props.type === 'voice' && voiceMeta.value?.talking) {
    classes.push('core-slot--voice-talking')
  }
  if (props.type === 'logo') {
    classes.push('core-slot--logo')
    if (props.meta && typeof props.meta.logo === 'string' && props.meta.logo.length > 0) {
      classes.push('core-slot--logo-image')
    }
  }
  if (STAT_TYPES.has(props.type)) {
    classes.push('core-slot--stat', `core-slot--stat-${props.type}`)
  }
  return classes
})

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
  if (props.type === 'logo') {
    return {
      backgroundColor: 'transparent',
      boxShadow: 'none',
      color: iconColor.value
    }
  }
  return {
    backgroundColor: backgroundColor.value,
    boxShadow: `inset 0 0 0 1.4px ${borderColor.value}`,
    color: iconColor.value
  }
})

const centerLabel = computed(() => {
  if (['temperature_value', 'messages', 'clean_stats', 'logo'].includes(props.type) && typeof props.effectNext === 'string' && props.effectNext.length > 0) {
    return props.effectNext
  }
  return null
})

const sideLabel = computed(() => {
  if (STAT_TYPES.has(props.type) && typeof props.effectNext === 'string' && props.effectNext.length > 0) {
    return props.effectNext
  }
  return null
})

const isStatType = computed(() => STAT_TYPES.has(props.type))

const statValue = computed(() => {
  if (!isStatType.value) {
    return null
  }
  const label = sideLabel.value
  if (!label) {
    return '--'
  }
  return label.trim() || '--'
})
</script>

<template>
  <div :class="coreSlotClasses" :style="{
    '--accent-color': accentColor,
    '--icon-color': iconColor,
    '--track-color': trackColor,
    '--inner-bg': backgroundColor,
    '--icon-shadow': iconShadow,
    '--inner-border': borderColor
  }">
    <template v-if="isStatType">
      <span class="stat-icon-wrapper">
        <img v-if="iconImage" class="stat-icon-img" :src="iconImage" :alt="`${type} icon`" draggable="false" />
        <i v-else-if="iconClass" class="stat-icon" :class="iconClass" aria-hidden="true"></i>
      </span>
      <span class="stat-value">{{ statValue }}</span>
    </template>
    <template v-else>
      <svg class="core-gauge" viewBox="0 0 40 40" aria-hidden="true">
        <circle class="ring ring--outer-track" cx="20" cy="20" :r="OUTER_RADIUS" />
        <circle class="ring ring--outer-fill" cx="20" cy="20" :r="OUTER_RADIUS" :stroke-dasharray="OUTER_CIRCUMFERENCE"
          :stroke-dashoffset="outerDashOffset" />
      </svg>

      <div class="core-fill" :style="coreFillStyle"></div>
      <img v-if="iconImage" class="core-icon-img" :src="iconImage" :alt="`${type} icon`" draggable="false" />
      <i v-else-if="iconClass" class="core-icon" :class="iconClass" aria-hidden="true"></i>
      <span v-if="centerLabel" class="core-icon-label">{{ centerLabel }}</span>
      <span v-if="sideLabel" class="core-side-label">{{ sideLabel }}</span>
    </template>
  </div>
</template>

<style scoped>
.core-slot {
  position: relative;
  width: 2.65rem;
  height: 2.65rem;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 9999px;
  filter: drop-shadow(0 8px 16px rgba(15, 23, 42, 0.35));
  transform-origin: center;
  will-change: transform;
  --accent-color: #ffffff;
  --icon-color: #ffffff;
  --track-color: rgba(17, 24, 39, 0.85);
  --inner-bg: #0c1018;
  --icon-shadow: 0 4px 8px rgba(8, 13, 23, 0.6);
  --inner-border: #1f2937;
}

.core-slot--voice-talking {
  animation: voicePulse 1.05s ease-in-out infinite;
}

@keyframes voicePulse {

  0%,
  100% {
    transform: scale(1);
  }

  50% {
    transform: scale(1.08);
  }
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
  font-size: 1.65rem;
  color: var(--icon-color);
  text-shadow: var(--icon-shadow);
}

.core-icon-img {
  position: relative;
  z-index: 1;
  width: 2.65rem;
  height: 2.65rem;
  object-fit: contain;
  box-shadow: var(--icon-shadow);
  border-radius: 50%;
  user-select: none;
  pointer-events: none;
}

.core-icon-label {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.58rem;
  font-weight: 600;
  letter-spacing: 0.03em;
  color: #e2e8f0;
  text-shadow: 0 1px 2px rgba(15, 23, 42, 0.7);
  pointer-events: none;
}

.core-side-label {
  position: absolute;
  top: 50%;
  left: calc(100% + 0.45rem);
  transform: translateY(-50%);
  font-size: 0.62rem;
  font-weight: 600;
  letter-spacing: 0.02em;
  color: #e2e8f0;
  text-shadow: 0 1px 2px rgba(15, 23, 42, 0.7);
  pointer-events: none;
  white-space: nowrap;
}

.core-slot--logo {
  padding: 0;
  background: transparent;
  filter: none;
  box-shadow: none;
  border-radius: 0.75rem;
  min-width: 4.25rem;
  min-height: 4.25rem;
}

.core-slot--logo .core-gauge,
.core-slot--logo .core-fill,
.core-slot--logo .ring {
  display: none;
}

.core-slot--logo-image .core-icon-img {
  width: 4.25rem;
  height: 4.25rem;
  border-radius: 0.75rem;
  box-shadow: none;
}

.core-slot--logo-image .core-icon-label {
  display: none;
}

.core-slot--stat {
  width: auto;
  height: auto;
  min-height: 1.9rem;
  padding: 0;
  border-radius: 0;
  display: inline-flex;
  align-items: center;
  justify-content: flex-start;
  gap: 0.45rem;
  background: transparent;
  border: none;
  box-shadow: none;
  filter: none;
}

.core-slot--stat .core-gauge,
.core-slot--stat .core-fill,
.core-slot--stat .core-icon-img,
.core-slot--stat .core-icon,
.core-slot--stat .core-icon-label,
.core-slot--stat .core-side-label {
  display: none;
}

.stat-icon-wrapper {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1.4rem;
  height: 1.4rem;
}

.stat-icon-img {
  width: 100%;
  height: 100%;
  object-fit: contain;
  user-select: none;
  pointer-events: none;
}

.stat-icon {
  font-size: 1.1rem;
  color: #f1f5f9;
}

.stat-value {
  font-family: 'Chineserok', 'Chineserok', 'Noto Sans', sans-serif;
  font-size: 1.05rem;
  font-weight: 700;
  letter-spacing: 0.015em;
  color: #f1f5f9;
  text-shadow: 0 1px 2px rgba(15, 23, 42, 0.65);
  white-space: nowrap;
  font-variant-numeric: tabular-nums;
}
</style>
