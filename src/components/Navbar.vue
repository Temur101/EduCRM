<script setup>
import { Search, Maximize, Minimize, Globe, Check, Menu } from 'lucide-vue-next';
import { ref, onMounted, onUnmounted } from 'vue';
import { useI18n } from 'vue-i18n';

const { locale } = useI18n();
const emit = defineEmits(['toggle-sidebar']);
const showLangDropdown = ref(false);
const isFullscreen = ref(false);

const toggleFullscreen = () => {
  if (!document.fullscreenElement) {
    if (document.documentElement.requestFullscreen) {
      document.documentElement.requestFullscreen();
    }
  } else {
    if (document.exitFullscreen) {
      document.exitFullscreen();
    }
  }
};

const handleFullscreenChange = () => {
  isFullscreen.value = !!document.fullscreenElement;
};

const languages = [
  { code: 'en', name: 'English', flag: '🇺🇸' },
  { code: 'ru', name: 'Русский', flag: '🇷🇺' },
  { code: 'uz', name: 'O\'zbek', flag: '🇺🇿' }
];

const changeLanguage = (lang) => {
  locale.value = lang;
  localStorage.setItem('lang', lang);
  showLangDropdown.value = false;
};

onMounted(() => {
  const savedLang = localStorage.getItem('lang');
  if (savedLang) {
    locale.value = savedLang;
  }

  // Close dropdown on click outside
  window.addEventListener('click', (e) => {
    if (!e.target.closest('.lang-switcher')) {
      showLangDropdown.value = false;
    }
  });

  document.addEventListener('fullscreenchange', handleFullscreenChange);
});

onUnmounted(() => {
  document.removeEventListener('fullscreenchange', handleFullscreenChange);
});
</script>

<template>
  <header class="navbar">
    <div class="navbar-left">
      <button class="nav-btn mobile-toggle" @click="emit('toggle-sidebar')">
        <Menu :size="22" />
      </button>

      <div class="search-box desktop-only">
        <Search :size="20" class="search-icon" />
        <input type="text" :placeholder="$t('common.searchPlaceholder') || 'Search in EduCRM (CTRL + /)'" />
      </div>
    </div>
    
    <div class="nav-actions">
      <!-- Language Switcher -->
      <div class="lang-switcher">
        <button class="nav-btn" @click.stop="showLangDropdown = !showLangDropdown">
          <Globe :size="20" />
          <span class="active-lang">{{ locale.toUpperCase() }}</span>
        </button>
        
        <transition name="dropdown">
          <div v-if="showLangDropdown" class="lang-dropdown">
            <button 
              v-for="lang in languages" 
              :key="lang.code"
              class="lang-item"
              :class="{ active: locale === lang.code }"
              @click="changeLanguage(lang.code)"
            >
              <span class="flag">{{ lang.flag }}</span>
              <span class="name">{{ lang.name }}</span>
              <Check v-if="locale === lang.code" :size="14" class="check-icon" />
            </button>
          </div>
        </transition>
      </div>

      <button class="nav-btn" @click="toggleFullscreen" title="Full Screen">
        <Minimize v-if="isFullscreen" :size="20" />
        <Maximize v-else :size="20" />
      </button>
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

.navbar-left {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.mobile-toggle {
  display: none;
}

@media (max-width: 767px) {
  .mobile-toggle {
    display: flex;
  }
}

.search-box {
  display: flex;
  align-items: center;
  background: var(--light);
  padding: 0.5rem 1rem;
  border-radius: 8px;
  width: 350px;
}

.desktop-only {
  display: flex;
}

@media (max-width: 768px) {
  .desktop-only {
    display: none;
  }
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

/* Language Switcher Styles */
.lang-switcher {
  position: relative;
}

.active-lang {
  font-size: 0.75rem;
  font-weight: 800;
  margin-left: 0.35rem;
  color: var(--primary);
}

.lang-dropdown {
  position: absolute;
  top: calc(100% + 10px);
  right: 0;
  background: white;
  border: 1px solid var(--border);
  border-radius: 12px;
  box-shadow: 0 10px 30px rgba(0,0,0,0.1);
  min-width: 160px;
  padding: 0.5rem;
  z-index: 1000;
}

.lang-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  width: 100%;
  padding: 0.6rem 0.8rem;
  border-radius: 8px;
  transition: all 0.2s;
  cursor: pointer;
  background: transparent;
  border: none;
}

.lang-item:hover {
  background: var(--light);
}

.lang-item.active {
  background: var(--primary-light);
  color: var(--primary);
}

.flag {
  font-size: 1.15rem;
}

.lang-item .name {
  flex: 1;
  font-size: 0.9rem;
  font-weight: 600;
  text-align: left;
}

.check-icon {
  color: var(--primary);
}

/* Transitions */
.dropdown-enter-active,
.dropdown-leave-active {
  transition: all 0.2s ease-out;
}

.dropdown-enter-from,
.dropdown-leave-to {
  opacity: 0;
  transform: translateY(10px);
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
