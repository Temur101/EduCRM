<script setup>
import { useRoute } from 'vue-router';
import Sidebar from './components/Sidebar.vue';
import Navbar from './components/Navbar.vue';

const route = useRoute();
</script>

<template>
  <div v-if="route.meta.layout === 'blank'" class="blank-layout">
    <router-view />
  </div>
  
  <div v-else class="app-container">
    <Sidebar />
    <main class="main-content">
      <Navbar />
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
