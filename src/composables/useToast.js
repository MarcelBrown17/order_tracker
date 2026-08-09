import { useToastStore } from '../stores/toast'

export function useToast() {
  const toast = useToastStore()
  return {
    success: (message, duration) => toast.success(message, duration),
    error: (message, duration) => toast.error(message, duration),
    info: (message, duration) => toast.info(message, duration),
    dismiss: (id) => toast.dismiss(id),
  }
}
