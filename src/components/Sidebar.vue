<script setup>
import { ref, computed } from 'vue';
import { useRouter } from 'vue-router';
import { 
  LayoutDashboard, 
  CheckSquare, 
  Users, 
  CreditCard, 
  Calendar, 
  UserCheck, 
  Archive, 
  MessageSquare,
  BookOpen,
  ChevronRight,
  LogOut,
  GraduationCap,
  DoorOpen,
  ShieldCheck,
  Bell
} from 'lucide-vue-next';

const router = useRouter();
const showLogout = ref(false);
const userRole = ref(localStorage.getItem('userRole') || 'regular');
const userName = ref(localStorage.getItem('userName') || 'User');

const menuItems = [
  { key: 'sidebar.dashboard', path: '/', icon: LayoutDashboard },
  { key: 'sidebar.tasks', path: '/tasks', icon: CheckSquare },
  { key: 'sidebar.today', path: '/today', icon: Calendar },
  { key: 'sidebar.leads', path: '/leads', icon: Users },
  { key: 'sidebar.students', path: '/students', icon: GraduationCap },
  { key: 'sidebar.payments', path: '/payments', icon: CreditCard },
  { key: 'sidebar.reminders', path: '/reminders', icon: Bell },
  { key: 'sidebar.archive', path: '/archive', icon: Archive },
  { key: 'sidebar.teachers', path: '/teachers', icon: UserCheck },
  { key: 'sidebar.courses', path: '/courses', icon: BookOpen },
  { key: 'sidebar.groups', path: '/groups', icon: Users },
  { key: 'sidebar.rooms', path: '/rooms', icon: DoorOpen },
  { key: 'sidebar.botManager', path: '/bot-manager', icon: MessageSquare },
  { key: 'sidebar.staff', path: '/staff', icon: ShieldCheck },
];

const adminOnlyKeys = ['sidebar.archive', 'sidebar.botManager', 'sidebar.staff'];
const teacherHiddenKeys = [
  'sidebar.dashboard',
  'sidebar.leads', 
  'sidebar.payments', 
  'sidebar.reminders', 
  'sidebar.archive', 
  'sidebar.teachers', 
  'sidebar.courses', 
  'sidebar.rooms', 
  'sidebar.botManager',
  'sidebar.staff',
  'sidebar.tasks',
  'sidebar.today'
];

const filteredMenuItems = computed(() => {
  if (userRole.value === 'admin') return menuItems;
  if (userRole.value === 'teacher') {
    return menuItems
      .filter(item => !teacherHiddenKeys.includes(item.key))
      .map(item => {
        if (item.path === '/groups') return { ...item, path: '/teacher/groups' };
        if (item.path === '/students') return { ...item, path: '/teacher/students' };
        return item;
      });
  }
  return menuItems.filter(item => !adminOnlyKeys.includes(item.key));
});

const handleLogout = () => {
  localStorage.removeItem('isLoggedIn');
  localStorage.removeItem('userRole');
  localStorage.removeItem('userName');
  router.push('/login');
};
</script>

<template>
  <aside class="sidebar">
    <div class="sidebar-header">
      <router-link to="/" class="logo-link">
        <img src="../assets/logo.png" alt="EduCRM" class="main-logo" />
      </router-link>
    </div>
    
    <nav class="sidebar-nav">
      <div class="menu-section">
        <p class="section-title">{{ $t('sidebar.mainMenu') || 'MAIN MENU' }}</p>
        <router-link 
          v-for="item in filteredMenuItems" 
          :key="item.key" 
          :to="item.path"
          class="nav-item"
          active-class="active"
        >
          <component :is="item.icon" :size="20" class="icon" />
          <span class="name">{{ $t(item.key) }}</span>
          <ChevronRight :size="16" class="arrow" />
        </router-link>
      </div>
    </nav>
    
    <div class="sidebar-footer">
      <div class="user-info" @click="showLogout = !showLogout" :class="{ 'active': showLogout }">
        <div class="user-avatar-placeholder">
          {{ userName.charAt(0).toUpperCase() }}
        </div>
        <div>
          <p class="user-name">{{ userName }}</p>
          <p class="user-role">{{ 
            userRole === 'admin' ? $t('sidebar.role') : 
            (userRole === 'teacher' ? $t('teachers.teacher') : ($t('sidebar.regular') || 'Regular User'))
          }}</p>
        </div>
      </div>
      
      <div class="logout-menu" :class="{ 'show': showLogout }" @click="handleLogout">
        <LogOut :size="18" class="logout-icon" />
        <span>{{ $t('sidebar.logout') || 'Logout' }}</span>
      </div>
    </div>
  </aside>
</template>

<style scoped>
.sidebar {
  width: var(--sidebar-width);
  height: 100vh;
  background: var(--white);
  border-right: 1px solid var(--border);
  display: flex;
  flex-direction: column;
  position: fixed;
  left: 0;
  top: 0;
  z-index: 100;
  transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

@media (min-width: 768px) and (max-width: 1024px) {
  .sidebar {
    width: var(--sidebar-width);
  }
  .sidebar .name {
    display: none;
  }
  .sidebar .arrow {
    display: none;
  }
  .sidebar .section-title {
    opacity: 0;
  }
  .sidebar .user-info {
    justify-content: center;
  }
  .sidebar .user-info > div:not(.user-avatar-placeholder) {
    display: none;
  }
  .nav-item {
    justify-content: center;
    padding: 0.75rem 0;
  }
  .icon {
    margin-right: 0;
  }
  .logout-menu {
    left: 0.5rem;
    right: auto;
    width: 200px;
  }
}

@media (max-width: 767px) {
  .sidebar {
    transform: translateX(-100%);
    box-shadow: 10px 0 25px rgba(0,0,0,0.1);
    width: 280px;
  }
  
  .sidebar.show {
    transform: translateX(0);
  }
}

.sidebar-header {
  height: 80px; /* Reduced to match smaller logo */
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
}

.logo-link {
  display: flex;
  align-items: center;
  justify-content: center;
  text-decoration: none;
  width: 100%;
}

.main-logo {
  height: 48px; /* Reduced for a cleaner look */
  width: auto;
  object-fit: contain;
  transition: transform 0.3s ease;
}

.main-logo:hover {
  transform: scale(1.05);
}

.sidebar-nav {
  flex: 1;
  padding: 1rem 0.75rem;
  overflow-y: auto;
}

.section-title {
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--gray);
  padding: 1rem 0.75rem 0.5rem;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.nav-item {
  display: flex;
  align-items: center;
  padding: 0.75rem 1rem;
  margin-bottom: 0.25rem;
  border-radius: 8px;
  color: var(--dark);
  transition: all 0.2s ease;
}

.nav-item:hover {
  background: var(--primary-light);
  color: var(--primary);
}

.nav-item.active {
  background: var(--primary);
  color: var(--white);
  box-shadow: 0 4px 12px rgba(115, 102, 255, 0.4);
}

.icon {
  margin-right: 0.75rem;
}

.name {
  flex: 1;
  font-weight: 500;
}

.arrow {
  opacity: 0.3;
}

.nav-item:hover .arrow,
.nav-item.active .arrow {
  opacity: 0.7;
}

.sidebar-footer {
  padding: 1.5rem;
  border-top: 1px solid var(--border);
  position: relative;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.6rem;
  border-radius: 10px;
  cursor: pointer;
  transition: background 0.2s ease;
}

.user-info:hover, .user-info.active {
  background: var(--primary-light);
}

.user-avatar-placeholder {
  width: 40px;
  height: 40px;
  background: var(--primary);
  color: white;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 700;
  font-size: 1.1rem;
  flex-shrink: 0;
}

.user-name {
  font-weight: 600;
  font-size: 0.9rem;
}

.user-role {
  font-size: 0.75rem;
  color: var(--gray);
}

.logout-menu {
  position: absolute;
  bottom: calc(100% - 0.5rem);
  left: 1.5rem;
  right: 1.5rem;
  background: var(--white);
  border: 1px solid var(--border);
  border-radius: 12px;
  padding: 0.8rem 1rem;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  cursor: pointer;
  box-shadow: 0 8px 25px 0 rgba(75, 70, 92, 0.15);
  color: var(--danger);
  font-weight: 600;
  opacity: 0;
  visibility: hidden;
  transform: translateY(10px);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  z-index: 10;
}

.logout-menu.show {
  opacity: 1;
  visibility: visible;
  transform: translateY(0);
}

.logout-menu:hover {
  background: #fdf3f3;
}

.logout-icon {
  stroke-width: 2.5px;
}
</style>
