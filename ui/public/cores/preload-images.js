// preload-images.js using Vite's native glob import
const preload = (files) => {
  for (const path in files) {
    files[path]();
  }
};

// Preload all core icons (16 per folder)
preload(import.meta.glob('./assets/cores/rpg_core_health/*.png', { eager: true }));
preload(import.meta.glob('./assets/cores/rpg_core_stamina/*.png', { eager: true }));
preload(import.meta.glob('./assets/cores/rpg_core_horse_health/*.png', { eager: true }));
preload(import.meta.glob('./assets/cores/rpg_core_horse_stamina/*.png', { eager: true }));

// Preload rpg_meter (100 icons) and track (10 icons)
preload(import.meta.glob('./assets/cores/rpg_meter/*.png', { eager: true }));
preload(import.meta.glob('./assets/cores/rpg_meter_track/*.png', { eager: true }));

// Preload all rpg_textures (status effects)
preload(import.meta.glob('./assets/cores/rpg_textures/*.png', { eager: true }));
