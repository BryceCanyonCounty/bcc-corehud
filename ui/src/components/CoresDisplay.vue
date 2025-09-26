<script setup>
import CoreSlot from './CoreSlot.vue'
</script>

<template>
  <div class="core-display">
    <CoreSlot type="health" />
    <CoreSlot type="stamina" />
    <CoreSlot type="horse_health" />
    <CoreSlot type="horse_stamina" />
    <CoreSlot type="horse_dirt" />
    <CoreSlot type="temperature" />

    <!-- Optional debug output (dev only!) -->
    <pre
      v-if="false"
      class="text-white text-xs absolute top-0 left-0 bg-black bg-opacity-50 p-2"
    >
      DEBUG PLACEHOLDER
    </pre>
  </div>
</template>

<style scoped>
.core-display {
  display: flex;
  gap: 1rem;
}
</style>
