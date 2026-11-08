<script setup>
import { ref, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute, RouterLink } from 'vue-router'
import { useAuthStore } from '../stores/auth'
import { useTheme } from '../composables/useTheme'
import { useToast } from '../composables/useToast'
import BrandLogo from '../components/BrandLogo.vue'

const auth = useAuthStore()
const router = useRouter()
const route = useRoute()
const { theme, setTheme } = useTheme()
const toast = useToast()

const email = ref('')
const password = ref('')
const loading = ref(false)
let previousTheme = 'light'

onMounted(() => {
  previousTheme = theme.value
  setTheme('light', { persist: false })
})

onUnmounted(() => {
  setTheme(previousTheme, { persist: false })
})

async function onSubmit() {
  loading.value = true
  try {
    await auth.login(email.value.trim(), password.value)
    toast.success('Signed in')
    const redirect = route.query.redirect
    router.push(redirect ? String(redirect) : { name: 'new-order' })
  } catch (e) {
    toast.error(e.message || 'Login failed')
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="login-page">
    <p class="login-announce">Baked in small batches. Packed by hand.</p>
    <div class="login-shell">
      <div class="login-topbar">
        <RouterLink to="/" class="brand-logo">
          <BrandLogo />
        </RouterLink>
        <RouterLink to="/" class="pill-btn">
          <svg
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <path d="M5 8h14l-1.2 11H6.2z" />
            <path d="M9 8V6a3 3 0 0 1 6 0v2" />
          </svg>
          Order
        </RouterLink>
      </div>

      <div class="login-hero">
        <h1>Welcome back</h1>
        <p>Sign in to manage orders, products, and partners.</p>
      </div>

      <form class="login-card" @submit.prevent="onSubmit">
        <div class="login-field">
          <label for="email">
            Email <span class="login-req" aria-hidden="true">*</span>
          </label>
          <input
            id="email"
            v-model="email"
            type="email"
            required
            autocomplete="email"
            placeholder="you@example.com"
          />
        </div>

        <div class="login-field login-field--last">
          <label for="password">
            Password <span class="login-req" aria-hidden="true">*</span>
          </label>
          <input
            id="password"
            v-model="password"
            type="password"
            required
            autocomplete="current-password"
            placeholder="Your password"
          />
        </div>

        <button type="submit" class="login-send" :disabled="loading">
          {{ loading ? 'Signing in…' : 'Sign in' }}
          <span v-if="!loading" aria-hidden="true">→</span>
        </button>

        <p class="login-footnote">
          Want biscuits?
          <RouterLink :to="{ name: 'request-biscuits' }">Request an order</RouterLink>
        </p>
      </form>
    </div>
  </div>
</template>

<style scoped>
.login-page {
  --lq-ink: #2a1a12;
  --lq-ink-soft: #5a4338;
  --lq-cream: #fff9ee;
  --lq-accent: #c2255c;
  --lq-accent-dark: #a01d4b;
  --lq-butter: #f5c84b;
  --lq-pink: #f7c9d4;

  min-height: 100dvh;
  background: var(--lq-cream);
  color: var(--lq-ink);
  font-family: var(--font-sans);
}

.login-announce {
  margin: 0;
  padding: 0.6rem 1rem;
  background: var(--lq-ink);
  color: var(--lq-cream);
  text-align: center;
  font-size: 0.8125rem;
  font-weight: 500;
}

.login-shell {
  width: min(27rem, 100%);
  margin: 0 auto;
  padding: 1rem 1.25rem 2.5rem;
}

.login-topbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.login-hero {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  margin: 1rem 0 1.25rem;
  padding: 1.75rem 1.5rem;
  border-radius: 2rem;
  background: var(--lq-butter);
}

.login-hero h1 {
  margin: 0;
  font-family: var(--font-display);
  font-size: clamp(2.25rem, 10vw, 2.75rem);
  font-weight: 800;
  line-height: 0.95;
  letter-spacing: -0.035em;
}

.login-hero p {
  margin: 0;
  font-size: 1rem;
  line-height: 1.5;
}

.login-card {
  padding: 1.25rem 1.125rem 1.375rem;
  border: 2px solid var(--lq-ink);
  border-radius: 1.75rem;
  background: #fff;
}

.login-field {
  margin-bottom: 1rem;
}

.login-field--last {
  margin-bottom: 1.25rem;
}

.login-field label {
  display: block;
  margin-bottom: 0.45rem;
  font-size: 0.875rem;
  font-weight: 700;
}

.login-req {
  color: var(--lq-accent);
}

.login-field input {
  width: 100%;
  height: auto;
  min-height: 3.25rem;
  max-height: none;
  border: 2px solid var(--lq-ink);
  border-radius: 999px;
  background: var(--lq-cream);
  color: var(--lq-ink);
  font: inherit;
  font-size: 0.9375rem;
  line-height: 1.2;
  padding: 0.75rem 1.25rem;
  outline: none;
  transition: box-shadow 0.15s ease;
}

.login-field input::placeholder {
  color: color-mix(in srgb, var(--lq-ink-soft) 60%, transparent);
}

.login-field input:focus {
  border-color: var(--lq-ink);
  box-shadow: 0 0 0 3px var(--lq-pink);
}

.login-send {
  display: inline-flex;
  width: 100%;
  min-height: 3.25rem;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  border: none;
  border-radius: 999px;
  padding: 0 1.5rem;
  background: var(--lq-accent);
  color: #fff;
  font: inherit;
  font-size: 1rem;
  font-weight: 700;
  cursor: pointer;
}

.login-send:hover:not(:disabled) {
  background: var(--lq-accent-dark);
}

.login-send:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.login-footnote {
  margin: 1rem 0 0;
  text-align: center;
  color: var(--lq-ink-soft);
  font-size: 0.875rem;
}

.login-footnote a {
  color: var(--lq-accent);
  font-weight: 700;
  text-decoration: none;
}
</style>
