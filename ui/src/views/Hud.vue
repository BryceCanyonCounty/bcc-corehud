<script setup>
import { ref, onMounted, onBeforeUnmount, provide, readonly, computed, watch, nextTick } from 'vue'
import CoreSlot from '@/components/CoreSlot.vue'
import api from '@/api'

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
  messages: null,
  clean_stats: null,
  money: null,
  gold: null,
  exp: null,
  tokens: null,
  logo: null,
  voice: null,
  horse_health: null,
  horse_stamina: null,
  horse_dirt: null,
  temperature: null,
  temperature_value: null
})

const cores = ref(createDefaultCores())
const visible = ref(false)
const devmode = ref(false)
const layoutEditing = ref(false)
const layoutDirty = ref(false)
const dragState = ref(null)

provide('cores', readonly(cores))
provide('layoutEditing', readonly(layoutEditing))

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
  messages: { ...DEFAULT_PALETTE_ENTRY },
  clean_stats: { ...DEFAULT_PALETTE_ENTRY },
  money: { ...DEFAULT_PALETTE_ENTRY },
  gold: { ...DEFAULT_PALETTE_ENTRY },
  exp: { ...DEFAULT_PALETTE_ENTRY },
  tokens: { ...DEFAULT_PALETTE_ENTRY },
  logo: { ...DEFAULT_PALETTE_ENTRY },
  temperature: { ...DEFAULT_PALETTE_ENTRY },
  temperature_value: { ...DEFAULT_PALETTE_ENTRY },
  horse_health: { ...DEFAULT_PALETTE_ENTRY },
  horse_stamina: { ...DEFAULT_PALETTE_ENTRY },
  horse_dirt: { ...DEFAULT_PALETTE_ENTRY },
  voice: { ...DEFAULT_PALETTE_ENTRY }
})

const palette = ref(createDefaultPalette())

provide('palette', readonly(palette))

const SLOT_ORDER = Object.freeze([
  'health',
  'stamina',
  'hunger',
  'thirst',
  'stress',
  'messages',
  'clean_stats',
  'money',
  'gold',
  'exp',
  'tokens',
  'player_id',
  'logo',
  'voice',
  'horse_health',
  'horse_stamina',
  'horse_dirt',
  'temperature',
  'temperature_value'
])

const SLOT_LABELS = Object.freeze({
  health: 'Health',
  stamina: 'Stamina',
  hunger: 'Hunger',
  thirst: 'Thirst',
  stress: 'Stress',
  messages: 'Messages',
  clean_stats: 'Cleanliness',
  money: 'Money',
  gold: 'Gold',
  exp: 'Experience',
  tokens: 'Tokens',
  player_id: 'Player ID',
  logo: 'Logo',
  voice: 'Voice',
  horse_health: 'Horse Health',
  horse_stamina: 'Horse Stamina',
  horse_dirt: 'Horse Cleanliness',
  temperature: 'Temperature',
  temperature_value: 'Temperature (°)'
})

const roundToThree = (value) => Math.round(value * 1000) / 1000
const clampPercentValue = (value) => {
  if (!Number.isFinite(value)) {
    return 0
  }
  if (value < 0) {
    return 0
  }
  if (value > 100) {
    return 100
  }
  return value
}

const createFallbackLayout = () => {
  const spacing = 7.0
  const baseX = 12
  const baseY = 50
  const start = baseY - ((SLOT_ORDER.length - 1) * spacing) / 2
  const result = {}
  SLOT_ORDER.forEach((slot, index) => {
    const percentY = clampPercentValue(start + index * spacing)
    result[slot] = {
      x: roundToThree(clampPercentValue(baseX)),
      y: roundToThree(percentY)
    }
  })
  return result
}

const fallbackLayout = Object.freeze(createFallbackLayout())

const layoutPositions = ref({})
const defaultLayout = ref({})
const layoutExitPending = ref(false)
const DEFAULT_SAVE_LABEL = 'Save Layout'
const saveLayoutLabel = ref(DEFAULT_SAVE_LABEL)

const layoutHasEntries = computed(() => Object.keys(layoutPositions.value).length > 0)
const useAbsoluteLayout = computed(() => layoutEditing.value || layoutHasEntries.value)
const draggingType = computed(() => dragState.value?.type ?? null)
const canSaveLayout = computed(() => layoutEditing.value && layoutDirty.value)

const slotRefs = new Map()
const setSlotRef = (type, el) => {
  if (el) {
    slotRefs.set(type, el)
  } else {
    slotRefs.delete(type)
  }
}

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

  const result = {
    inner: clamp(inner, 0, 15, DEFAULT_SLOT.inner),
    outer: clamp(outer, 0, 99, DEFAULT_SLOT.outer),
    effectInside: typeof effectInside === 'string' ? effectInside : null,
    effectNext: typeof effectNext === 'string' ? effectNext : null
  }

  if (mapping.meta && typeof mapping.meta === 'object') {
    for (const [targetKey, sourceKey] of Object.entries(mapping.meta)) {
      if (typeof targetKey !== 'string' || typeof sourceKey !== 'string') {
        continue
      }

      const value = payload?.[sourceKey]
      if (value !== undefined) {
        result[targetKey] = value
      }
    }
  }

  return result
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
    effectNext: 'effect_stamina_next',
    meta: {
      pulseThreshold: 'stamina_threshold'
    }
  },
  hunger: {
    inner: 'innerhunger',
    outer: 'outerhunger',
    effectInside: 'effect_hunger_inside',
    effectNext: 'effect_hunger_next',
    meta: {
      pulseThreshold: 'hunger_threshold'
    }
  },
  thirst: {
    inner: 'innerthirst',
    outer: 'outerthirst',
    effectInside: 'effect_thirst_inside',
    effectNext: 'effect_thirst_next',
    meta: {
      pulseThreshold: 'thirst_threshold'
    }
  },
  stress: {
    inner: 'innerstress',
    outer: 'outerstress',
    effectInside: 'effect_stress_inside',
    effectNext: 'effect_stress_next',
    meta: {
      pulseThreshold: 'stress_threshold'
    }
  },
  messages: {
    inner: 'innermessages',
    outer: 'outermessages',
    effectInside: 'effect_messages_inside',
    effectNext: 'effect_messages_next'
  },
  clean_stats: {
    inner: 'innerclean_stats',
    outer: 'outerclean_stats',
    effectInside: 'effect_clean_stats_inside',
    effectNext: 'effect_clean_stats_next',
    meta: {
      pulseThreshold: 'clean_stats_threshold'
    }
  },
  money: {
    inner: 'innermoney',
    outer: 'outermoney',
    effectInside: 'effect_money_inside',
    effectNext: 'effect_money_next'
  },
  gold: {
    inner: 'innergold',
    outer: 'outergold',
    effectInside: 'effect_gold_inside',
    effectNext: 'effect_gold_next'
  },
  exp: {
    inner: 'innerexp',
    outer: 'outerexp',
    effectInside: 'effect_exp_inside',
    effectNext: 'effect_exp_next'
  },
  tokens: {
    inner: 'innertokens',
    outer: 'outertokens',
    effectInside: 'effect_tokens_inside',
    effectNext: 'effect_tokens_next'
  },
  player_id: {
    inner: 'innerplayer_id',
    outer: 'outerplayer_id',
    effectInside: 'effect_player_id_inside',
    effectNext: 'effect_player_id_next'
  },
  logo: {
    inner: 'innerlogo',
    outer: 'outerlogo',
    effectInside: 'effect_logo_inside',
    effectNext: 'effect_logo_next',
    meta: {
      logo: 'logo_image'
    }
  },
  voice: {
    inner: 'innervoice',
    outer: 'outervoice',
    effectInside: 'effect_voice_inside',
    effectNext: 'effect_voice_next',
    meta: {
      talking: 'voice_talking',
      proximity: 'voice_proximity',
      proximityPercent: 'voice_proximity_percent'
    }
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
  },
  temperature_value: {
    inner: 'innertemperature_value',
    outer: 'outertemperature_value',
    effectInside: null,
    effectNext: 'effect_temperature_value_next'
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

const sanitizeLayoutPayload = (payload) => {
  if (!payload || typeof payload !== 'object') {
    return {}
  }

  const sanitized = {}
  for (const [key, value] of Object.entries(payload)) {
    if (!value || typeof value !== 'object') {
      continue
    }

    const x = Number(value.x)
    const y = Number(value.y)
    if (!Number.isFinite(x) || !Number.isFinite(y)) {
      continue
    }

    sanitized[key] = {
      x: roundToThree(clampPercentValue(x)),
      y: roundToThree(clampPercentValue(y))
    }
  }

  return sanitized
}

const buildLayoutPayload = () => {
  const payload = {}
  for (const [key, value] of Object.entries(layoutPositions.value)) {
    if (!value || typeof value !== 'object') {
      continue
    }

    const x = Number(value.x)
    const y = Number(value.y)
    if (!Number.isFinite(x) || !Number.isFinite(y)) {
      continue
    }

    payload[key] = {
      x: roundToThree(clampPercentValue(x)),
      y: roundToThree(clampPercentValue(y))
    }
  }
  return payload
}

const getSlotPosition = (type) => {
  const layoutEntry = layoutPositions.value[type]
  if (layoutEntry) {
    return layoutEntry
  }

  const defaultEntry = defaultLayout.value[type]
  if (defaultEntry) {
    return defaultEntry
  }

  const fallbackEntry = fallbackLayout[type]
  if (fallbackEntry) {
    return fallbackEntry
  }

  return { x: 50, y: 80 }
}

const getSlotStyle = (type) => {
  const position = getSlotPosition(type)
  return {
    left: `${position.x}vw`,
    top: `${position.y}vh`
  }
}

const updateLayoutPosition = (type, xPercent, yPercent) => {
  const safeX = roundToThree(clampPercentValue(xPercent))
  const safeY = roundToThree(clampPercentValue(yPercent))
  const current = layoutPositions.value[type]

  if (current && current.x === safeX && current.y === safeY) {
    return
  }

  layoutPositions.value = {
    ...layoutPositions.value,
    [type]: { x: safeX, y: safeY }
  }
  layoutDirty.value = true
}

const captureDefaultLayout = async () => {
  if (useAbsoluteLayout.value) {
    return
  }

  await nextTick()
  await new Promise((resolve) => window.requestAnimationFrame(resolve))

  const viewportWidth = window.innerWidth || 1
  const viewportHeight = window.innerHeight || 1
  const captured = {}

  slotRefs.forEach((element, type) => {
    if (!element) {
      return
    }

    const rect = element.getBoundingClientRect()
    if (!rect.width && !rect.height) {
      return
    }

    const centerX = rect.left + rect.width / 2
    const centerY = rect.top + rect.height / 2
    const percentX = roundToThree(clampPercentValue((centerX / viewportWidth) * 100))
    const percentY = roundToThree(clampPercentValue((centerY / viewportHeight) * 100))
    captured[type] = { x: percentX, y: percentY }
  })

  if (Object.keys(captured).length > 0) {
    defaultLayout.value = captured
  }
}

const ensureLayoutPositionsFromInline = async () => {
  if (layoutHasEntries.value) {
    return
  }

  await captureDefaultLayout()

  if (layoutHasEntries.value) {
    return
  }

  if (Object.keys(defaultLayout.value).length > 0) {
    layoutPositions.value = { ...defaultLayout.value }
  } else {
    layoutPositions.value = { ...fallbackLayout }
  }
}

const handlePointerMove = (event) => {
  const state = dragState.value
  if (!state) {
    return
  }

  if (state.pointerId !== undefined && event.pointerId !== state.pointerId) {
    return
  }

  event.preventDefault()

  const viewportWidth = window.innerWidth || 1
  const viewportHeight = window.innerHeight || 1

  const centerX = event.clientX - state.offsetX
  const centerY = event.clientY - state.offsetY

  const percentX = (centerX / viewportWidth) * 100
  const percentY = (centerY / viewportHeight) * 100

  updateLayoutPosition(state.type, percentX, percentY)
}

const stopDrag = () => {
  if (!dragState.value) {
    return
  }

  dragState.value = null
  window.removeEventListener('pointermove', handlePointerMove)
  window.removeEventListener('pointerup', stopDrag)
  window.removeEventListener('pointercancel', stopDrag)
}

const startDrag = (type, event) => {
  if (!layoutEditing.value) {
    return
  }

  event.preventDefault()
  event.stopPropagation()

  const viewportWidth = window.innerWidth || 1
  const viewportHeight = window.innerHeight || 1
  const basis = getSlotPosition(type)

  const basisX = (basis.x / 100) * viewportWidth
  const basisY = (basis.y / 100) * viewportHeight

  dragState.value = {
    type,
    pointerId: event.pointerId,
    offsetX: event.clientX - basisX,
    offsetY: event.clientY - basisY
  }

  window.addEventListener('pointermove', handlePointerMove)
  window.addEventListener('pointerup', stopDrag)
  window.addEventListener('pointercancel', stopDrag)
}

const saveLayoutToServer = async () => {
  const payload = buildLayoutPayload()

  if (typeof GetParentResourceName === 'undefined') {
    console.info('[BCC-CoreHUD] Layout payload (dev)', payload)
    layoutDirty.value = false
    return
  }

  try {
    await api.post('saveLayout', { positions: payload })
    layoutDirty.value = false
  } catch (error) {
    console.error('[BCC-CoreHUD] Failed to save layout', error)
  }
}

const handleSaveLayoutClick = async () => {
  if (!canSaveLayout.value) {
    return
  }
  await saveLayoutToServer()
  if (!layoutDirty.value) {
    try {
      await api.post('setLayoutEditing', { editing: false, skipSave: true })
    } catch (error) {
      console.error('[BCC-CoreHUD] Failed to exit layout mode', error)
    } finally {
      await toggleLayoutEditing(false)
    }
  }
}

const toggleLayoutEditing = async (enabled) => {
  if (enabled) {
    await ensureLayoutPositionsFromInline()
  } else {
    stopDrag()
    layoutExitPending.value = false
    saveLayoutLabel.value = DEFAULT_SAVE_LABEL
  }

  layoutEditing.value = enabled
}

const handleResize = () => {
  if (!layoutEditing.value && !layoutHasEntries.value) {
    captureDefaultLayout()
  }
}

const handleMessage = async (event) => {
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

    case 'layout':
      layoutPositions.value = sanitizeLayoutPayload(data.positions)
      if (!layoutEditing.value) {
        layoutDirty.value = false
      }
      break

    case 'layoutEdit':
      if (typeof data.label === 'string' && data.label.trim() !== '') {
        saveLayoutLabel.value = data.label
      } else {
        saveLayoutLabel.value = DEFAULT_SAVE_LABEL
      }
      if (typeof data.editing === 'boolean') {
        await toggleLayoutEditing(data.editing)
      }
      break

    case 'layoutRequestSave':
      saveLayoutToServer()
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
  window.addEventListener('blur', stopDrag)
  window.addEventListener('resize', handleResize)
})

onBeforeUnmount(() => {
  window.removeEventListener('message', handleMessage)
  window.removeEventListener('blur', stopDrag)
  window.removeEventListener('resize', handleResize)
  stopDrag()
})

watch(
  [visible, devmode, useAbsoluteLayout],
  async ([isVisible, isDev, absolute]) => {
    if ((isVisible || isDev) && !absolute) {
      await captureDefaultLayout()
    }
  },
  { immediate: true }
)

watch(useAbsoluteLayout, (active) => {
  if (!active) {
    stopDrag()
  }
})

watch(layoutEditing, async (editing) => {
  if (!editing && layoutDirty.value) {
    await saveLayoutToServer()
  }
})

</script>

<template>
  <div
    v-if="visible || devmode"
    class="core-layout"
    :class="{ 'core-layout--editing': layoutEditing }"
  >
    <div
      v-if="useAbsoluteLayout"
      class="core-layout-overlay"
      :class="{ 'core-layout-overlay--editing': layoutEditing }"
    >
      <div v-if="layoutEditing" class="core-layout-toolbar">
        <button
          type="button"
          class="core-layout-save"
          :disabled="!canSaveLayout"
          @click="handleSaveLayoutClick"
        >
          {{ saveLayoutLabel }}
        </button>
      </div>
      <div v-if="layoutEditing" class="core-layout-grid"></div>
      <div
        v-for="type in SLOT_ORDER"
        :key="type"
        class="core-slot-wrapper"
        :class="{
          'core-slot-wrapper--editing': layoutEditing,
          'core-slot-wrapper--dragging': draggingType === type
        }"
        :style="getSlotStyle(type)"
        @pointerdown="(event) => startDrag(type, event)"
      >
        <CoreSlot :type="type" />
      </div>
    </div>
    <div v-else class="core-layout-row">
      <div
        v-for="type in SLOT_ORDER"
        :key="type"
        class="core-slot-inline"
        :ref="(el) => setSlotRef(type, el)"
      >
        <CoreSlot :type="type" />
      </div>
    </div>
  </div>
</template>

<style scoped>

.core-layout {
  position: fixed;
  inset: 0;
  display: flex;
  justify-content: flex-start;
  align-items: flex-start;
  pointer-events: none;
  z-index: 10;
}

.core-layout--editing {
  pointer-events: auto;
}

.core-layout-row {
  position: absolute;
  bottom: 4vh;
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
  pointer-events: none;
  align-items: flex-start;
}

.core-slot-inline {
  pointer-events: none;
}

.core-layout-overlay {
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.core-layout-overlay--editing {
  pointer-events: auto;
}

.core-layout-toolbar {
  position: absolute;
  bottom: 6vh;
  left: 6vw;
  display: flex;
  gap: 0.5rem;
  pointer-events: auto;
  z-index: 1;
}

.core-layout-save {
  pointer-events: auto;
  border: none;
  background: rgba(12, 16, 24, 0.78);
  color: #f9fafb;
  padding: 0.45rem 0.9rem;
  border-radius: 0.5rem;
  font-size: 0.9rem;
  letter-spacing: 0.02em;
  cursor: pointer;
  transition: background-color 0.18s ease, transform 0.18s ease;
}

.core-layout-save:hover:not(:disabled) {
  background: rgba(37, 99, 235, 0.9);
  transform: translateY(-1px);
}

.core-layout-save:disabled {
  opacity: 0.55;
  cursor: not-allowed;
}

.core-layout-grid {
  position: absolute;
  inset: 0;
  pointer-events: none;
  background-image:
    linear-gradient(to right, rgba(255, 255, 255, 0.12) 1px, transparent 1px),
    linear-gradient(to bottom, rgba(255, 255, 255, 0.12) 1px, transparent 1px),
    linear-gradient(to right, rgba(255, 255, 255, 0.2) 1px, transparent 1px),
    linear-gradient(to bottom, rgba(255, 255, 255, 0.2) 1px, transparent 1px);
  background-size:
    2.5vw 100%,
    100% 4vh,
    12.5vw 100%,
    100% 16vh;
  border: 1px solid rgba(255, 255, 255, 0.2);
  box-sizing: border-box;
}

.core-slot-wrapper {
  position: absolute;
  transform: translate(-50%, -50%);
  pointer-events: none;
  transition: transform 0.18s ease;
}

.core-slot-wrapper--editing {
  pointer-events: auto;
  cursor: grab;
}

.core-slot-wrapper--dragging {
  cursor: grabbing;
}

</style>
