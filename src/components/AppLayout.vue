<script setup>
import { computed, onMounted, ref } from 'vue'
import { useRoute, useRouter, RouterLink, RouterView } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useTheme } from '../composables/useTheme'
import BankDetails from './BankDetails.vue'
import AppLoader from './AppLoader.vue'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()
const { isDark, toggleTheme } = useTheme()
const signingOut = ref(false)

const nav = computed(() => {
  if (auth.isAdmin) {
    return [
      { name: 'New', to: '/new', icon: 'new' },
      { name: 'Dashboard', to: '/dashboard', icon: 'dashboard' },
      { name: 'Orders', to: '/orders', icon: 'orders' },
      { name: 'Products', to: '/products', icon: 'products' },
    ]
  }
  return [
    { name: 'New', to: '/new', icon: 'new' },
    { name: 'Dashboard', to: '/dashboard', icon: 'dashboard' },
    { name: 'Orders', to: '/orders', icon: 'orders' },
  ]
})

function isActive(path) {
  if (path === '/new') {
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
  if (signingOut.value) return
  signingOut.value = true
  try {
    await auth.logout()
    await router.replace({ name: 'login' })
  } catch {
    signingOut.value = false
  }
}

onMounted(() => {
  if (auth.loading) auth.init()
})
</script>

<template>
  <div class="app-shell flex min-h-dvh flex-col md:h-dvh md:flex-row md:overflow-hidden">
    <div
      v-if="signingOut"
      class="app-signout"
      aria-live="polite"
    >
      <AppLoader label="Signing out" />
    </div>

    <template v-else>
      <!-- Desktop sidebar -->
      <aside
        class="hidden md:flex md:h-full md:w-56 md:shrink-0 md:flex-col md:overflow-y-auto md:border-r md:border-border md:bg-surface"
      >
        <div class="border-b border-border p-4">
          <RouterLink
            :to="{ name: 'request-biscuits' }"
            class="brand-mark text-xl"
          >
            <span class="brand-dot" aria-hidden="true" />Biscuits
          </RouterLink>
          <p class="mt-1 text-sm text-muted">
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
                ? 'bg-accent-soft text-accent-hover'
                : 'text-text hover:bg-page',
            ]"
          >
            {{ item.name === 'New' ? 'New order' : item.name }}
          </RouterLink>
        </nav>
        <div class="border-t border-border p-4">
          <p class="mb-1 truncate text-sm font-bold">
            {{ auth.partner?.name || 'Not linked' }}
          </p>
          <p class="mb-3 truncate text-sm text-muted">
            {{ auth.user?.email }}
          </p>
          <button type="button" class="app-logout mb-2 w-full" @click="toggleTheme">
            {{ isDark ? 'Light mode' : 'Dark mode' }}
          </button>
          <button type="button" class="app-logout app-logout--solid w-full" @click="logout">
            Log out
          </button>
        </div>
      </aside>

      <div class="flex min-h-0 min-w-0 flex-1 flex-col md:overflow-hidden">
        <!-- Mobile top bar -->
        <header class="app-topbar md:hidden">
          <div class="min-w-0">
            <RouterLink
              :to="{ name: 'request-biscuits' }"
              class="brand-mark truncate text-lg"
            >
              <span class="brand-dot" aria-hidden="true" />Biscuits
            </RouterLink>
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
            <button type="button" class="app-logout app-logout--solid" @click="logout">
              Log out
            </button>
          </div>
        </header>

        <main class="page-pad-mobile main-scroll flex-1 overflow-x-hidden overflow-y-auto p-4 md:p-6">
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
            <template v-if="item.icon === 'dashboard'">
              <rect x="3" y="3" width="7" height="9" rx="1" />
              <rect x="14" y="3" width="7" height="5" rx="1" />
              <rect x="14" y="12" width="7" height="9" rx="1" />
              <rect x="3" y="16" width="7" height="5" rx="1" />
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
    </template>
  </div>
</template>

<style scoped>
.app-signout {
  display: flex;
  flex: 1;
  min-height: 100dvh;
  width: 100%;
  align-items: center;
  justify-content: center;
  background: var(--color-page);
}

.app-topbar {
  position: sticky;
  top: 0;
  z-index: 30;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  padding: 0.85rem 1rem;
  border-bottom: 1px solid var(--color-border);
  background: color-mix(in srgb, var(--color-surface) 92%, transparent);
  backdrop-filter: blur(10px);
  -webkit-backdrop-filter: blur(10px);
}

.app-logout {
  display: inline-flex;
  min-height: 2.375rem;
  align-items: center;
  justify-content: center;
  padding: 0 0.9rem;
  border: 1px solid var(--color-border);
  border-radius: 0.75rem;
  background: var(--color-surface);
  color: var(--color-text);
  font-size: 0.8125rem;
  font-weight: 700;
  cursor: pointer;
}

.app-logout--solid {
  border: none;
  background: var(--color-text);
  color: var(--color-page);
}

html.dark .app-logout--solid {
  background: var(--color-accent);
  color: #000;
}
</style>
