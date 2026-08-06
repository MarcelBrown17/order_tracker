<script setup>
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useTheme } from '../composables/useTheme'
import BaseButton from '../components/BaseButton.vue'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()
const { isDark, toggleTheme } = useTheme()

const email = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)

async function onSubmit() {
  error.value = ''
  loading.value = true
  try {
    await auth.login(email.value.trim(), password.value)
    const redirect = route.query.redirect || '/'
    router.push(String(redirect))
  } catch (e) {
    error.value = e.message || 'Login failed'
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="relative flex min-h-screen items-center justify-center bg-page p-4">
    <button
      type="button"
      class="icon-btn absolute right-4 top-4"
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
        aria-hidden="true"
      >
        <circle cx="12" cy="12" r="4" />
        <path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41" />
      </svg>
      <svg
        v-else
        width="18"
        height="18"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        aria-hidden="true"
      >
        <path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z" />
      </svg>
    </button>

    <div class="surface-card w-full max-w-sm space-y-5 p-5">
      <div>
        <h1 class="text-2xl font-extrabold tracking-tight text-accent">
          Biscuits
        </h1>
        <p class="page-subtitle">Sign in to manage orders</p>
      </div>

      <form class="space-y-3.5" @submit.prevent="onSubmit">
        <div class="form-field">
          <label for="email">Email</label>
          <input
            id="email"
            v-model="email"
            type="email"
            required
            autocomplete="email"
          />
        </div>
        <div class="form-field">
          <label for="password">Password</label>
          <input
            id="password"
            v-model="password"
            type="password"
            required
            autocomplete="current-password"
          />
        </div>

        <p v-if="error" class="text-sm text-red-600 dark:text-red-400">{{ error }}</p>

        <BaseButton type="submit" variant="primary" block :disabled="loading">
          {{ loading ? 'Signing in…' : 'Sign in' }}
        </BaseButton>
      </form>
    </div>
  </div>
</template>
