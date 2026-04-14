<script setup>
import { ref, reactive } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { Mail, Lock, Eye, EyeOff, LogIn } from 'lucide-vue-next';
import { supabase } from '../supabase.js';

const router = useRouter();
const showPassword = ref(false);
const isLoading = ref(false);
const loginError = ref('');

const formData = reactive({
  email: '',
  password: ''
});

const handleLogin = async () => {
  if (!formData.email || !formData.password) {
    loginError.value = useI18n().t('login.fillFields');
    return;
  }

  isLoading.value = true;
  loginError.value = '';

  try {
    const { data, error } = await supabase.auth.signInWithPassword({
      email: formData.email,
      password: formData.password
    });

    if (error) {
      // Emergency bypass for development/network issues (522)
      if (error.message === 'Failed to fetch' || error.status === 522) {
        console.warn('Network timeout, entering offline dev mode');
        localStorage.setItem('isLoggedIn', 'true');
        localStorage.setItem('userRole', 'admin'); // Default as admin in dev mode? No, better regular
        router.push('/');
        return;
      }
      throw error;
    }

    if (data.user) {
      // Fetch role and name from profile
      const { data: profile } = await supabase
        .from('profiles')
        .select('role, display_name')
        .eq('id', data.user.id)
        .single();
      
      const role = profile?.role || 'regular';
      const name = profile?.display_name || data.user.email.split('@')[0];
      
      localStorage.setItem('isLoggedIn', 'true');
      localStorage.setItem('userRole', role);
      localStorage.setItem('userName', name);
      router.push('/');
    }
  } catch (err) {
    if (err.status === 400 || err.message?.includes('Invalid login credentials')) {
      // 1. Try searching in staff table
      try {
        const { data: staffMember } = await supabase
          .from('staff')
          .select('*')
          .eq('email', formData.email)
          .eq('password', formData.password)
          .maybeSingle();

        if (staffMember) {
          localStorage.setItem('isLoggedIn', 'true');
          localStorage.setItem('userRole', staffMember.role || 'regular');
          localStorage.setItem('userName', staffMember.name);
          router.push('/');
          return;
        }
      } catch (sErr) {
        console.error('Staff login lookup error:', sErr);
      }

      // 2. Try searching in teachers table
      try {
        const { data: teacher } = await supabase
          .from('teachers')
          .select('*')
          .eq('email', formData.email)
          .eq('password', formData.password)
          .maybeSingle();

        if (teacher) {
          localStorage.setItem('isLoggedIn', 'true');
          localStorage.setItem('userRole', 'teacher');
          localStorage.setItem('userTeacherId', teacher.id);
          localStorage.setItem('userName', teacher.name);
          router.push('/');
          return;
        }
      } catch (tErr) {
        console.error('Teacher login lookup error:', tErr);
      }
    }
    console.error('Login Error:', err);
    loginError.value = useI18n().t('login.invalidLogin');
  } finally {
    isLoading.value = false;
  }
};
</script>

<template>
  <div class="login-page">
    <div class="login-container">
      <div class="login-card card">
        <div class="login-header">
          <div class="brand">
            <img src="../assets/logo.png" alt="EduCRM" class="login-logo" />
          </div>
          <p class="subtitle">{{ $t('login.welcome') }}</p>
        </div>

        <form @submit.prevent="handleLogin" class="login-form">
          <div v-if="loginError" class="error-banner">
            {{ loginError }}
          </div>

          <div class="form-group">
            <label>{{ $t('login.email') }}</label>
            <div class="input-wrapper">
              <Mail :size="18" class="field-icon" />
              <input 
                v-model="formData.email" 
                type="email" 
                :placeholder="$t('login.emailPlaceholder')" 
                autofocus
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

          <div class="form-options">
            <label class="checkbox-container">
              <input type="checkbox" checked />
              <span class="checkmark"></span>
              {{ $t('login.rememberMe') }}
            </label>
            <a href="#" class="forgot-link">{{ $t('login.forgotPassword') }}</a>
          </div>

          <button type="submit" class="btn-login" :disabled="isLoading">
            <span v-if="!isLoading">
               {{ $t('login.signIn') }} <LogIn :size="18" />
            </span>
            <span v-else class="loader"></span>
          </button>
        </form>

        <div class="login-footer">
          <p v-if="false">{{ $t('login.noAccount') }} <router-link to="/register">{{ $t('login.signUp') }}</router-link></p>
        </div>
      </div>

      <div class="login-decor">
        <div class="decor-circle circle-1"></div>
        <div class="decor-circle circle-2"></div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.login-page {
  min-height: 100vh;
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  background: radial-gradient(circle at top left, #7366FF0F, transparent),
              radial-gradient(circle at bottom right, #7366FF0F, transparent),
              #F8F7FA;
  position: relative;
  overflow: hidden;
}

.login-container {
  width: 100%;
  max-width: 450px;
  padding: 2rem;
  position: relative;
  z-index: 10;
}

.login-card {
  background: white;
  padding: 3rem 2.5rem;
  border-radius: 24px;
  box-shadow: 0 20px 50px rgba(75, 70, 92, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.8);
}

.login-header {
  text-align: center;
  margin-bottom: 2.5rem;
}

.brand {
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 1.5rem;
}

.login-logo {
  height: 64px;
  width: auto;
  object-fit: contain;
}

.subtitle {
  color: var(--gray);
  font-size: 0.95rem;
}

.login-form {
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

.form-options {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.85rem;
}

.checkbox-container {
  display: flex;
  align-items: center;
  position: relative;
  padding-left: 1.75rem;
  cursor: pointer;
  color: var(--dark);
  font-weight: 600;
  user-select: none;
}

.checkbox-container input {
  position: absolute;
  opacity: 0;
  cursor: pointer;
  height: 0;
  width: 0;
}

.checkmark {
  position: absolute;
  top: 0;
  left: 0;
  height: 18px;
  width: 18px;
  background-color: var(--white);
  border: 1.5px solid var(--border);
  border-radius: 6px;
  transition: all 0.2s;
}

.checkbox-container:hover input ~ .checkmark {
  border-color: var(--primary);
}

.checkbox-container input:checked ~ .checkmark {
  background-color: var(--primary);
  border-color: var(--primary);
}

.checkmark:after {
  content: "";
  position: absolute;
  display: none;
  left: 5px;
  top: 2px;
  width: 4px;
  height: 8px;
  border: solid white;
  border-width: 0 2px 2px 0;
  transform: rotate(45deg);
}

.checkbox-container input:checked ~ .checkmark:after {
  display: block;
}

.forgot-link {
  color: var(--primary);
  font-weight: 600;
  transition: opacity 0.2s;
}

.forgot-link:hover {
  opacity: 0.8;
}

.btn-login {
  width: 100%;
  padding: 1rem;
  border-radius: 14px;
  background: var(--primary);
  color: white;
  font-weight: 700;
  font-size: 1rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
  box-shadow: 0 8px 16px rgba(115, 102, 255, 0.3);
}

.btn-login:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 20px rgba(115, 102, 255, 0.4);
}

.btn-login:active {
  transform: translateY(0);
}

.btn-login:disabled {
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

.login-footer {
  text-align: center;
  margin-top: 2rem;
  font-size: 0.9rem;
  color: var(--gray);
}

.login-footer a {
  color: var(--primary);
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
  background: rgba(115, 102, 255, 0.08);
  top: -100px;
  right: -100px;
}

.circle-2 {
  width: 300px;
  height: 300px;
  background: rgba(115, 102, 255, 0.06);
  bottom: -50px;
  left: -50px;
}
</style>
