import { ref, computed } from 'vue'
import gsap from 'gsap'

const theme = ref('light')
let initialized = false

function apply(next, { animate = false, persist = true } = {}) {
  const resolved = next === 'dark' ? 'dark' : 'light'
  theme.value = resolved
  document.documentElement.classList.toggle('dark', resolved === 'dark')
  document.documentElement.style.colorScheme = resolved

  if (persist) {
    try {
      localStorage.setItem('theme', resolved)
    } catch {
      /* ignore */
    }
  }

  if (animate && typeof document !== 'undefined') {
    gsap.fromTo(
      document.body,
      { opacity: 0.82 },
      { opacity: 1, duration: 0.35, ease: 'power2.out' }
    )
  }
}

export function useTheme() {
  if (!initialized && typeof document !== 'undefined') {
    initialized = true
    let saved = null
    try {
      saved = localStorage.getItem('theme')
    } catch {
      saved = null
    }
    apply(saved === 'dark' ? 'dark' : 'light')
  }

  const isDark = computed(() => theme.value === 'dark')

  function toggleTheme() {
    apply(theme.value === 'dark' ? 'light' : 'dark', { animate: true })
  }

  return {
    theme,
    isDark,
    toggleTheme,
    setTheme: apply,
  }
}
