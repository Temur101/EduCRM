import { createRouter, createWebHistory } from 'vue-router';
import Dashboard from '../views/Dashboard.vue';

const routes = [
  {
    path: '/login',
    name: 'Login',
    component: () => import('../views/Login.vue'),
    meta: { layout: 'blank' }
  },
  {
    path: '/',
    name: 'Dashboard',
    component: Dashboard,
  },
  {
    path: '/tasks',
    name: 'Tasks',
    component: () => import('../views/Tasks.vue')
  },
  { path: '/leads', name: 'Leads', component: () => import('../views/Leads.vue') },
  { path: '/payments', name: 'Payments', component: () => import('../views/Payments.vue') },
  { path: '/today', name: 'Today', component: () => import('../views/Today.vue') },
  { path: '/attendance', name: 'Attendance', component: () => import('../views/Placeholder.vue') },
  { path: '/archive', name: 'Archive', component: () => import('../views/Archive.vue') },
  { path: '/bot-manager', name: 'BotManager', component: () => import('../views/BotManager.vue') },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

router.beforeEach((to, from, next) => {
  const isLoggedIn = localStorage.getItem('isLoggedIn') === 'true';

  if (to.name !== 'Login' && !isLoggedIn) {
    next({ name: 'Login' });
  } else if (to.name === 'Login' && isLoggedIn) {
    next({ name: 'Dashboard' });
  } else {
    next();
  }
});

export default router;
