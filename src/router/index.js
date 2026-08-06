import { createRouter, createWebHistory } from 'vue-router'
import { supabase } from '../lib/supabase'
import { useAuthStore } from '../stores/auth'

const routes = [
  {
    path: '/login',
    name: 'login',
    component: () => import('../views/Login.vue'),
    meta: { public: true },
  },
  {
    path: '/',
    component: () => import('../components/AppLayout.vue'),
    children: [
      {
        path: '',
        name: 'new-order',
        component: () => import('../views/NewOrder.vue'),
      },
      {
        path: 'dashboard',
        name: 'dashboard',
        component: () => import('../views/Dashboard.vue'),
      },
      {
        path: 'orders',
        name: 'orders',
        component: () => import('../views/Orders.vue'),
      },
      {
        path: 'orders/new',
        redirect: { name: 'new-order' },
      },
      {
        path: 'orders/:id',
        name: 'order-detail',
        component: () => import('../views/OrderDetail.vue'),
      },
      {
        path: 'orders/:id/edit',
        name: 'edit-order',
        component: () => import('../views/NewOrder.vue'),
        meta: { admin: true },
      },
      {
        path: 'products',
        name: 'products',
        component: () => import('../views/Products.vue'),
        meta: { admin: true },
      },
      {
        path: 'earnings',
        redirect: { name: 'orders' },
      },
    ],
  },
]

const router = createRouter({
  history: createWebHistory(),
  routes,
})

router.beforeEach(async (to) => {
  const auth = useAuthStore()

  if (auth.loading) {
    await auth.init()
  }

  const {
    data: { session },
  } = await supabase.auth.getSession()

  if (!to.meta.public && !session) {
    return { name: 'login', query: { redirect: to.fullPath } }
  }

  if (to.name === 'login' && session) {
    return { name: 'new-order' }
  }

  if (session && !auth.partner && to.name !== 'login') {
    // Still allow dashboard so we can show the "not linked" message
    if (to.meta.admin || to.name === 'new-order') {
      return { name: 'dashboard' }
    }
  }

  if (to.meta.admin && !auth.isAdmin) {
    return { name: 'dashboard' }
  }
})

export default router
