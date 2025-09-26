import { createRouter, createWebHashHistory } from 'vue-router'
import Hud from '@/views/Hud.vue'

const routes = [
  {
    path: '/',
    name: 'hud',
    component: Hud
  }
]

const router = createRouter({
  history: createWebHashHistory(),
  routes
})

export default router