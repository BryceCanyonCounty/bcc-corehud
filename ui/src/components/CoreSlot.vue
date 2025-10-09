<script setup>
import { inject, computed } from 'vue'
import CoreIcon from './CoreIcon.vue'

const props = defineProps({
  type: { type: String, required: true }
})

const cores = inject('cores')
const layoutEditingInjection = inject('layoutEditing', null)

const isLayoutEditing = computed(() => layoutEditingInjection?.value === true)

const PERMANENT_PLACEHOLDERS = new Set([
  'voice',
  'messages',
  'clean_stats',
  'bleed',
  'money',
  'gold',
  'exp',
  'tokens',
  'player_id',
  'logo',
  'temperature',
  'temperature_value',
  'horse_health',
  'horse_stamina',
  'horse_dirt'
])

const buildPlaceholderSlot = () => {
  switch (props.type) {
    case 'temperature':
      return {
        inner: 15,
        outer: 99,
        effectInside: 'cold',
        effectNext: null,
        meta: null
      }
    case 'temperature_value':
      return {
        inner: 15,
        outer: 99,
        effectInside: null,
        effectNext: '--°',
        meta: null
      }
    case 'horse_health':
    case 'horse_stamina':
      return {
        inner: 15,
        outer: 99,
        effectInside: null,
        effectNext: null,
        meta: null
      }
    case 'horse_dirt':
      return {
        inner: 15,
        outer: 99,
        effectInside: 'horse_dirty',
        effectNext: null,
        meta: null
      }
    case 'messages':
      return {
        inner: 15,
        outer: 99,
        effectInside: null,
        effectNext: '0',
        meta: null
      }
    case 'clean_stats':
      return {
        inner: 15,
        outer: 99,
        effectInside: null,
        effectNext: '100%',
        meta: null
      }
    case 'bleed':
      return {
        inner: 15,
        outer: 99,
        effectInside: 'bandaged',
        effectNext: null,
        meta: null
      }
    case 'money':
      return {
        inner: 15,
        outer: 99,
        effectInside: null,
        effectNext: '$0',
        meta: null
      }
    case 'gold':
      return {
        inner: 15,
        outer: 99,
        effectInside: null,
        effectNext: 'G 0',
        meta: null
      }
    case 'exp':
      return {
        inner: 15,
        outer: 99,
        effectInside: null,
        effectNext: 'XP 0',
        meta: null
      }
    case 'tokens':
      return {
        inner: 15,
        outer: 99,
        effectInside: null,
        effectNext: 'T 0',
        meta: null
      }
    case 'player_id':
      return {
        inner: 15,
        outer: 99,
        effectInside: null,
        effectNext: 'ID 0',
        meta: null
      }
    case 'logo':
      return {
        inner: 15,
        outer: 99,
        effectInside: null,
        effectNext: 'LOGO',
        meta: { logo: null }
      }
    default:
      return {
        inner: 15,
        outer: 99,
        effectInside: null,
        effectNext: null,
        meta: null
      }
  }
}

const slotData = computed(() => {
  const editing = isLayoutEditing.value
  const source = cores?.value?.[props.type]
  if (!source) {
    if (editing && PERMANENT_PLACEHOLDERS.has(props.type)) {
      return buildPlaceholderSlot()
    }
    return null
  }

  const effectInside = typeof source.effectInside === 'string' ? source.effectInside : null
  const effectNext = typeof source.effectNext === 'string' ? source.effectNext : null

  const result = {
    inner: typeof source.inner === 'number' ? source.inner : 15,
    outer: typeof source.outer === 'number' ? source.outer : 99,
    effectInside,
    effectNext,
    meta: null
  }

  const meta = {}
  if (typeof source.talking !== 'undefined') {
    meta.talking = source.talking === true || source.talking === 1 || source.talking === 'true'
  }

  if (typeof source.pulseThreshold === 'number' && Number.isFinite(source.pulseThreshold)) {
    meta.pulseThreshold = source.pulseThreshold
  }

  if (props.type === 'logo') {
    const logoSrc = typeof source.image === 'string' ? source.image : null
    if (logoSrc && logoSrc.length > 0) {
      meta.logo = logoSrc
    }
  }

  const proximityPercentRaw = source.proximityPercent ?? source.proximity
  const proximityPercent = typeof proximityPercentRaw === 'number' && Number.isFinite(proximityPercentRaw)
    ? Math.min(Math.max(proximityPercentRaw, 0), 100)
    : null
  if (proximityPercent !== null) {
    meta.proximityPercent = proximityPercent
  }

  if (Object.keys(meta).length > 0) {
    result.meta = meta
  }

  if (props.type === 'temperature') {
    const lowered = effectInside ? effectInside.toLowerCase() : null
    const hasExtreme = lowered === 'hot' || lowered === 'cold'
    if (hasExtreme) {
      result.effectInside = lowered
    } else {
      if (editing) {
        return buildPlaceholderSlot()
      }
      return null
    }
  }

  if (props.type === 'temperature_value') {
    if (!result.effectNext) {
      if (editing) {
        return buildPlaceholderSlot()
      }
      return null
    }
  }

  return result
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
    :meta="slotData.meta"
  />
</template>
