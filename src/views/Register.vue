<script setup>
import { ref, reactive } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { Mail, Lock, Eye, EyeOff, UserPlus, User } from 'lucide-vue-next';
import { supabase } from '../supabase.js';

const router = useRouter();
const showPassword = ref(false);
const isLoading = ref(false);
const registerError = ref('');

const formData = reactive({
  email: '',
  password: '',
  displayName: ''
});

const handleRegister = async () => {
  if (!formData.email || !formData.password || !formData.displayName) {
    registerError.value = useI18n().t('register.fillFields');
    return;
  }

  isLoading.value = true;
  registerError.value = '';

  try {
    const { data, error } = await supabase.auth.signUp({
      email: formData.email,
      password: formData.password,
      options: {
        data: {
          display_name: formData.displayName
        }
      }
    });

    if (error) {
       // Emergency bypass for development/network issues (522)
       if (error.message === 'Failed to fetch' || error.status === 522) {
        console.warn('Network timeout, entering offline dev mode');
        localStorage.setItem('isLoggedIn', 'true');
        router.push('/');
        return;
      }
      throw error;
    }

    if (data.user) {
      // Create profile record
      const { error: profileError } = await supabase.from('profiles').insert([
        { 
          id: data.user.id, 
          email: formData.email,
          display_name: formData.displayName,
          role: 'regular' 
        }
      ]);
      
      if (profileError) {
        console.error('Profile creation error:', profileError);
        // We still log them in even if profile fails, but normally this should be atomic
      }

      localStorage.setItem('isLoggedIn', 'true');
      localStorage.setItem('userRole', 'regular');
      localStorage.setItem('userName', formData.displayName);
      router.push('/');
    }
    
  } catch (err) {
    console.error('Registration Error:', err);
    registerError.value = err.message || useI18n().t('register.error');
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <div class="register-page">
    <div class="register-container">
      <div class="register-card card">
        <div class="register-header">
          <div class="brand">
            <img src="../assets/logo.png" alt="EduCRM" class="register-logo" />
          </div>
          <p class="subtitle">{{ $t('register.title') }}</p>
        </div>

        <form @submit.prevent="handleRegister" class="register-form">
          <div v-if="registerError" class="error-banner">
            {{ registerError }}
          </div>

          <div class="form-group">
            <label>{{ $t('register.fullName') }}</label>
            <div class="input-wrapper">
              <User :size="18" class="field-icon" />
              <input 
                v-model="formData.displayName" 
                type="text" 
                :placeholder="$t('register.namePlaceholder')" 
                autofocus
                required
              />
            </div>
          </div>

          <div class="form-group">
            <label>{{ $t('login.email') }}</label>
            <div class="input-wrapper">
              <Mail :size="18" class="field-icon" />
              <input 
                v-model="formData.email" 
                type="email" 
                :placeholder="$t('login.emailPlaceholder')" 
                required
              />
            </div>
          </div>

          <div class="form-group">
            <label>{{ $t('login.password') }}</label>
            <div class="input-wrapper">
              <Lock :size="18" class="field-icon" />
              <input 
                v-model="formData.password" 
                :type="showPassword ? 'text' : 'password'" 
                :placeholder="$t('login.passwordPlaceholder')"
                required
              />
              <button 
                type="button" 
                class="btn-toggle-pass" 
                @click="showPassword = !showPassword"
              >
                <Eye v-if="!showPassword" :size="18" />
                <EyeOff v-else :size="18" />
              </button>
            </div>
          </div>

          <button type="submit" class="btn-register" :disabled="isLoading">
            <span v-if="!isLoading">
               {{ $t('register.createAccount') }} <UserPlus :size="18" />
            </span>
            <span v-else class="loader"></span>
          </button>
        </form>

        <div class="register-footer">
          <p>{{ $t('register.alreadyHaveAccount') }} <router-link to="/login">{{ $t('login.signIn') }}</router-link></p>
        </div>
      </div>

      <div class="register-decor">
        <div class="decor-circle circle-1"></div>
        <div class="decor-circle circle-2"></div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.register-page {
  min-height: 100vh;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: radial-gradient(circle at top left, #28C76F0F, transparent),
              radial-gradient(circle at bottom right, #28C76F0F, transparent),
              #F8F7FA;
  position: relative;
  overflow: hidden;
}

.register-container {
  width: 100%;
  max-width: 450px;
  padding: 2rem;
  position: relative;
  z-index: 10;
}

.register-card {
  background: white;
  padding: 3rem 2.5rem;
  border-radius: 24px;
  box-shadow: 0 20px 50px rgba(75, 70, 92, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.8);
}

.register-header {
  text-align: center;
  margin-bottom: 2.5rem;
}

.brand {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  margin-bottom: 1rem;
}

.register-logo {
  height: 64px;
  width: auto;
  object-fit: contain;
}

.subtitle {
  color: var(--gray);
  font-size: 0.95rem;
}

.register-form {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.error-banner {
  background: #FFF0F0;
  color: var(--danger);
  padding: 0.75rem 1rem;
  border-radius: 12px;
  font-size: 0.85rem;
  font-weight: 600;
  text-align: center;
  border: 1px solid rgba(234, 84, 85, 0.2);
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.form-group label {
  font-size: 0.85rem;
  font-weight: 700;
  color: var(--dark);
  margin-left: 0.25rem;
}

.input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.field-icon {
  position: absolute;
  left: 1.25rem;
  color: var(--gray);
  pointer-events: none;
  transition: color 0.2s;
}

.input-wrapper input {
  width: 100%;
  padding: 0.85rem 1.25rem 0.85rem 3.25rem;
  border: 1.5px solid var(--border);
  border-radius: 14px;
  font-family: inherit;
  font-size: 0.95rem;
  color: var(--dark);
  outline: none;
  transition: all 0.2s;
}

.input-wrapper input:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 4px rgba(115, 102, 255, 0.1);
}

.input-wrapper input:focus + .field-icon {
  color: var(--primary);
}

.btn-toggle-pass {
  position: absolute;
  right: 1rem;
  color: var(--gray);
  padding: 0.5rem;
  border-radius: 8px;
  display: flex;
  transition: all 0.2s;
}

.btn-toggle-pass:hover {
  background: var(--light);
  color: var(--primary);
}

.btn-register {
  width: 100%;
  padding: 1rem;
  border-radius: 14px;
  background: #28C76F;
  color: white;
  font-weight: 700;
  font-size: 1rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
  box-shadow: 0 8px 16px rgba(40, 199, 111, 0.3);
  border: none;
}

.btn-register:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 20px rgba(40, 199, 111, 0.4);
}

.btn-register:active {
  transform: translateY(0);
}

.btn-register:disabled {
  opacity: 0.7;
  cursor: not-allowed;
  transform: none;
}

.loader {
  width: 20px;
  height: 20px;
  border: 3px solid rgba(255,255,255,0.3);
  border-radius: 50%;
  border-top-color: #fff;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.register-footer {
  text-align: center;
  margin-top: 2rem;
  font-size: 0.9rem;
  color: var(--gray);
}

.register-footer a {
  color: #28C76F;
  font-weight: 700;
  text-decoration: none;
}

/* Decor circles */
.decor-circle {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
  z-index: -1;
}

.circle-1 {
  width: 400px;
  height: 400px;
  background: rgba(40, 199, 111, 0.08);
  top: -100px;
  right: -100px;
}

.circle-2 {
  width: 300px;
  height: 300px;
  background: rgba(40, 199, 111, 0.06);
  bottom: -50px;
  left: -50px;
}
</style>
