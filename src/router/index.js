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
  { path: '/students', name: 'Students', component: () => import('../views/Students.vue') },
  { path: '/payments', name: 'Payments', component: () => import('../views/Payments.vue') },
  { path: '/reminders', name: 'Reminders', component: () => import('../views/Reminders.vue') },
  { path: '/today', name: 'Today', component: () => import('../views/Today.vue') },
  { path: '/attendance', name: 'Attendance', component: () => import('../views/Placeholder.vue') },
  { path: '/archive', name: 'Archive', component: () => import('../views/Archive.vue'), meta: { requiresAdmin: true } },
  { path: '/teachers', name: 'Teachers', component: () => import('../views/Teachers.vue') },
  { path: '/courses', name: 'Courses', component: () => import('../views/Courses.vue') },
  { path: '/groups', name: 'Groups', component: () => import('../views/Groups.vue') },
  { path: '/teacher/groups', name: 'TeacherGroups', component: () => import('../views/Groups.vue') },
  { path: '/teacher/students', name: 'TeacherStudents', component: () => import('../views/Students.vue') },
  { path: '/rooms', name: 'Rooms', component: () => import('../views/Rooms.vue') },
  { path: '/groups/:id', name: 'GroupDetails', component: () => import('../views/GroupDetails.vue') },
  { path: '/students/:id', name: 'StudentDetails', component: () => import('../views/StudentDetails.vue') },
  { path: '/staff', name: 'Staff', component: () => import('../views/Staff.vue'), meta: { requiresAdmin: true } },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

router.beforeEach((to, from, next) => {
  const isLoggedIn = localStorage.getItem('isLoggedIn') === 'true';
  const userRole = localStorage.getItem('userRole') || 'regular';
  
  const publicPages = ['Login', 'Register'];
  const authRequired = !publicPages.includes(to.name);

  if (authRequired && !isLoggedIn) {
    next({ name: 'Login' });
  } else if (publicPages.includes(to.name) && isLoggedIn) {
    next({ name: 'Dashboard' });
  } else if (userRole === 'teacher') {
    // Teachers can access their specific views and any detail views
    const allowedPatterns = [
      /^\/teacher\/groups/,
      /^\/teacher\/students/,
      /^\/groups\/[^\/]+$/,
      /^\/students\/[^\/]+$/
    ];
    const isAllowed = allowedPatterns.some(pattern => pattern.test(to.path));
    
    if (isAllowed) {
      next();
    } else {
      next({ path: '/teacher/groups' });
    }
  } else if (to.meta.requiresAdmin && userRole !== 'admin') {
    next({ name: 'Dashboard' }); // Redirect non-admins to dashboard
  } else {
    next();
  }
});

export default router;
