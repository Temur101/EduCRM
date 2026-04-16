<script setup>
import { ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import Sidebar from './components/Sidebar.vue';
import Navbar from './components/Navbar.vue';

const route = useRoute();
const isSidebarOpen = ref(false);

const toggleSidebar = () => {
  isSidebarOpen.value = !isSidebarOpen.value;
};

// Close sidebar when navigating on mobile
watch(() => route.path, () => {
  isSidebarOpen.value = false;
});
</script>

<template>
  <div v-if="route.meta.layout === 'blank'" class="blank-layout">
    <router-view />
  </div>
  
  <div v-else class="app-container">
    <Sidebar :class="{ 'show': isSidebarOpen }" />
    
    <!-- Mobile Overlay -->
    <div 
      v-if="isSidebarOpen" 
      class="mobile-overlay" 
      @click="isSidebarOpen = false"
    ></div>

    <main class="main-content">
      <Navbar @toggle-sidebar="toggleSidebar" />
      <div class="content-wrapper">
        <router-view v-slot="{ Component }">
          <transition name="fade" mode="out-in">
            <div class="route-wrapper">
              <component :is="Component" />
            </div>
          </transition>
        </router-view>
      </div>
    </main>
  </div>
</template>

<style>
@import './assets/styles/main.css';

.blank-layout {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.app-container {
  display: flex;
  height: 100vh;
  overflow: hidden;
}

.main-content {
  flex: 1;
  margin-left: var(--sidebar-width);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  min-height: 0;
}

.content-wrapper {
  flex: 1;
  background: var(--light);
  overflow-y: auto;
  overflow-x: hidden;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.route-wrapper {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 100%;
}

@media (max-width: 767px) {
  .main-content {
    margin-left: 0;
  }
}

.mobile-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(0, 0, 0, 0.4);
  backdrop-filter: blur(2px);
  z-index: 90;
  animation: fadeIn 0.3s ease;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}

/* Scrollbar styling */
::-webkit-scrollbar {
  width: 6px;
}

::-webkit-scrollbar-track {
  background: var(--light);
}

::-webkit-scrollbar-thumb {
  background: var(--border);
  border-radius: 10px;
}

::-webkit-scrollbar-thumb:hover {
  background: var(--gray);
}
</style>
