<script setup>
import { Search, Maximize } from 'lucide-vue-next';
</script>

<template>
  <header class="navbar">
    <div class="search-box">
      <Search :size="20" class="search-icon" />
      <input type="text" placeholder="Search in EduCRM (CTRL + /)" />
    </div>
    
    <div class="nav-actions">
      <button class="nav-btn"><Maximize :size="20" /></button>
    </div>
  </header>
</template>

<style scoped>
.navbar {
  height: var(--header-height);
  padding: 0 2rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: rgba(255, 255, 255, 0.8);
  backdrop-filter: blur(10px);
  position: sticky;
  top: 0;
  z-index: 50;
  border-bottom: 1px solid var(--border);
}

.search-box {
  display: flex;
  align-items: center;
  background: var(--light);
  padding: 0.5rem 1rem;
  border-radius: 8px;
  width: 350px;
}

.search-icon {
  color: var(--gray);
  margin-right: 0.5rem;
}

.search-box input {
  border: none;
  background: transparent;
  width: 100%;
  outline: none;
  font-size: 0.9rem;
}

.nav-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.nav-btn {
  width: 40px;
  height: 40px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 8px;
  color: var(--dark);
  transition: background 0.2s;
}

.nav-btn:hover {
  background: var(--light);
}

.position-relative {
  position: relative;
}

.badge {
  position: absolute;
  top: 5px;
  right: 5px;
  background: var(--primary);
  color: white;
  font-size: 10px;
  width: 16px;
  height: 16px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 2px solid var(--white);
}
</style>
