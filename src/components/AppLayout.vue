<script setup>
import { computed, onMounted } from 'vue'
import { useRoute, useRouter, RouterLink, RouterView } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useTheme } from '../composables/useTheme'
import BaseButton from './BaseButton.vue'
import BankDetails from './BankDetails.vue'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const { isDark, toggleTheme } = useTheme()

const nav = computed(() => {
  if (auth.isAdmin) {
    return [
      { name: 'New', to: '/', icon: 'new' },
      { name: 'Home', to: '/dashboard', icon: 'home' },
      { name: 'Orders', to: '/orders', icon: 'orders' },
      { name: 'Products', to: '/products', icon: 'products' },
    ]
  }
  return [
    { name: 'New', to: '/', icon: 'new' },
    { name: 'Home', to: '/dashboard', icon: 'home' },
    { name: 'Orders', to: '/orders', icon: 'orders' },
  ]
})

function isActive(path) {
  if (path === '/') {
    return route.name === 'new-order'
  }
  if (path === '/dashboard') {
    return route.path === '/dashboard'
  }
  if (path === '/orders') {
    return (
      route.path === '/orders' ||
      /^\/orders\/[^/]+/.test(route.path)
    )
  }
  return route.path === path || route.path.startsWith(path + '/')
}

async function logout() {
  await auth.logout()
  router.push({ name: 'login' })
}

onMounted(() => {
  if (auth.loading) auth.init()
})
</script>

<template>
  <div class="min-h-screen md:flex">
    <!-- Desktop sidebar -->
    <aside
      class="hidden md:flex md:w-56 md:shrink-0 md:flex-col md:border-r md:border-border md:bg-surface"
    >
      <div class="border-b border-border p-4">
        <p class="text-xl font-extrabold tracking-tight text-accent">Biscuits</p>
        <p class="text-sm text-muted">
          {{ auth.isAdmin ? 'Admin' : auth.partner?.name || 'Partner' }}
        </p>
      </div>
      <nav class="flex flex-1 flex-col gap-1 p-3">
        <RouterLink
          v-for="item in nav"
          :key="item.to"
          :to="item.to"
          :class="[
            'rounded-xl px-3 py-2.5 text-sm font-bold',
            isActive(item.to)
              ? 'bg-accent text-white'
              : 'text-text hover:bg-page',
          ]"
        >
          {{ item.name === 'Home' ? 'Dashboard' : item.name === 'New' ? 'New order' : item.name }}
        </RouterLink>
      </nav>
      <div class="border-t border-border p-4">
        <p class="mb-1 truncate text-sm font-bold">
          {{ auth.partner?.name || 'Not linked' }}
        </p>
        <p class="mb-3 truncate text-sm text-muted">
          {{ auth.user?.email }}
        </p>
        <BaseButton variant="secondary" block class="mb-2" @click="toggleTheme">
          {{ isDark ? 'Light mode' : 'Dark mode' }}
        </BaseButton>
        <BaseButton variant="secondary" block @click="logout">
          Log out
        </BaseButton>
      </div>
    </aside>

    <div class="flex min-w-0 flex-1 flex-col">
      <!-- Mobile top bar -->
      <header
        class="sticky top-0 z-30 flex items-center justify-between border-b border-border bg-surface/95 px-4 py-2.5 backdrop-blur-md md:hidden"
      >
        <div class="min-w-0">
          <p class="truncate text-lg font-extrabold tracking-tight text-accent">
            Biscuits
          </p>
          <p class="truncate text-xs font-semibold text-muted">
            {{ auth.partner?.name || 'Partner' }}
            <span v-if="auth.isAdmin"> · Admin</span>
          </p>
        </div>
        <div class="flex shrink-0 items-center gap-2">
          <button
            type="button"
            class="icon-btn"
            :aria-label="isDark ? 'Switch to light mode' : 'Switch to dark mode'"
            @click="toggleTheme"
          >
            <svg
              v-if="isDark"
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <circle cx="12" cy="12" r="4" />
              <path d="M12 2v2" />
              <path d="M12 20v2" />
              <path d="m4.93 4.93 1.41 1.41" />
              <path d="m17.66 17.66 1.41 1.41" />
              <path d="M2 12h2" />
              <path d="M20 12h2" />
              <path d="m6.34 17.66-1.41 1.41" />
              <path d="m19.07 4.93-1.41 1.41" />
            </svg>
            <svg
              v-else
              width="18"
              height="18"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
              aria-hidden="true"
            >
              <path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z" />
            </svg>
          </button>
          <BaseButton variant="secondary" class="!min-h-10 !px-3 !text-xs" @click="logout">
            Log out
          </BaseButton>
        </div>
      </header>

      <main class="page-pad-mobile flex-1 p-4 md:p-6">
        <RouterView />
      </main>
    </div>

    <!-- Mobile bottom nav -->
    <nav class="bottom-nav md:hidden" aria-label="Main">
      <RouterLink
        v-for="item in nav"
        :key="item.to"
        :to="item.to"
        class="bottom-nav__link"
        :class="{ 'bottom-nav__link--active': isActive(item.to) }"
      >
        <svg
          class="bottom-nav__icon"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <template v-if="item.icon === 'home'">
            <path d="M3 10.5 12 3l9 7.5" />
            <path d="M5 9.5V21h14V9.5" />
          </template>
          <template v-else-if="item.icon === 'orders'">
            <path d="M8 6h13" />
            <path d="M8 12h13" />
            <path d="M8 18h13" />
            <path d="M3 6h.01" />
            <path d="M3 12h.01" />
            <path d="M3 18h.01" />
          </template>
          <template v-else-if="item.icon === 'new'">
            <circle cx="12" cy="12" r="9" />
            <path d="M12 8v8" />
            <path d="M8 12h8" />
          </template>
          <template v-else-if="item.icon === 'products'">
            <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z" />
            <path d="M3.3 7 12 12l8.7-5" />
            <path d="M12 22V12" />
          </template>
        </svg>
        {{ item.name }}
      </RouterLink>
    </nav>

    <BankDetails v-if="auth.isLinked" />
  </div>
</template>
