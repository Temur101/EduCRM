
<script setup>
import { ref, onMounted, computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { 
  ChevronLeft, ChevronRight,
  User, 
  Phone, 
  Mail, 
  Calendar, 
  Users, 
  BookOpen, 
  CreditCard, 
  Clock, 
  CheckCircle2,
  AlertCircle,
  MoreVertical,
  Edit,
  Trash2,
  MessageSquare,
  ArrowRight,
  TrendingUp,
  Wallet,
  CalendarDays,
  Loader2,
  XCircle,
  CheckCircle,
  BellRing,
  Handshake
} from 'lucide-vue-next';
import { supabase } from '../supabase.js';
import PaymentModal from '../components/PaymentModal.vue';

const route = useRoute();
const router = useRouter();
const studentId = route.params.id;
const userRole = ref(localStorage.getItem('userRole') || 'regular');

const student = ref(null);
const group = ref(null);
const payments = ref([]);
const paymentReminders = ref([]);
const attendance = ref([]);
const isLoading = ref(true);
const saveError = ref(null);

// Status Modal Logic
const statusModal = ref({
  show: false,
  title: '',
  message: '',
  type: 'success'
});

const showStatus = (title, message, type = 'success') => {
  statusModal.value = { show: true, title, message, type };
};

const closeStatus = () => {
  statusModal.value.show = false;
};

const loadStudentData = async () => {
  console.log('Starting simplified loadStudentData for:', studentId);
  isLoading.value = true;
  try {
    // 1. Fetch basic student data first
    const { data: studentData, error: studentError } = await supabase
      .from('students')
      .select('*')
      .eq('id', studentId)
      .single();
      
    if (studentError) {
      console.error('Student fetch error:', studentError);
      throw studentError;
    }
    
    student.value = studentData;
    initDiscount(studentData.discount);

    // 2. Fetch group info if exists
    if (studentData.group_id) {
      const { data: groupData } = await supabase
        .from('groups')
        .select('*, courses(*), teachers(*)')
        .eq('id', studentData.group_id)
        .single();
      group.value = groupData;
    }

    // 3. Fetch payments (newest first)
    const { data: paymentsData } = await supabase
      .from('payments')
      .select('*')
      .eq('student_id', studentId)
      .order('date', { ascending: false })
      .order('created_at', { ascending: false });

    payments.value = (paymentsData || []).map(p => {
      let cleanComment = p.comment || '';
      cleanComment = cleanComment.replace(/\[DAYS:[^\]]+\]/g, '').replace(/\[M:[^\]]+\]/g, '').trim();
      return { ...p, comment: cleanComment };
    });

    // 4. Fetch payment reminders (promises)
    const { data: remindersData } = await supabase
      .from('payment_reminders')
      .select('*')
      .eq('student_id', studentId)
      .neq('status', 'Cancelled');

    paymentReminders.value = (remindersData || []).map(r => {
      let cleanNote = r.notes || '';
      cleanNote = cleanNote.replace(/\[DAYS:[^\]]+\]/g, '').replace(/\[M:[^\]]+\]/g, '').trim();
      
      // Normalize month to match StudentDetails format: "Month Year" (Uzbek)
      const d = new Date(r.promised_date);
      const normalizedMonth = MONTH_NAMES[d.getMonth()] + ' ' + d.getFullYear();
      
      return { ...r, notes: cleanNote, normalizedMonth };
    });

  } catch (e) {
    console.error('Data loading failed:', e.message);
    saveError.value = e.message;
  } finally {
    isLoading.value = false;
  }
};

// ═══════════════ ATTENDANCE ═══════════════
const STATUSES = [
  { key: 'present', label: 'Keldi',    color: '#10B981', bg: '#D1FAE5', short: '✓' },
  { key: 'absent',  label: 'Kelmadi',  color: '#EF4444', bg: '#FEE2E2', short: '✗' },
  { key: 'sick',    label: 'Kasal',    color: '#F59E0B', bg: '#FEF3C7', short: '⚕' },
  { key: 'late',    label: 'Kechikdi', color: '#6366F1', bg: '#EEF2FF', short: '⏱' },
];

const MONTH_NAMES = [
  'Yanvar','Fevral','Mart','Aprel','May','Iyun',
  'Iyul','Avgust','Sentabr','Oktabr','Noyabr','Dekabr'
];
const DOW_SHORT = ['Ya','Du','Se','Ch','Pa','Ju','Sh'];
const DAY_INDEX = { 'Du':1,'Se':2,'Ch':3,'Pa':4,'Ju':5,'Sh':6,'Ya':0 };

const today = new Date();
const attYear  = ref(today.getFullYear());
const attMonth = ref(today.getMonth());
const attLoading = ref(false);
const currentPageAtt = ref(1);
const pageSizeAtt = 5;

// attendanceMap: { 'YYYY-MM-DD': status }
const attMap = ref({});

const prevAttMonth = () => {
  if (attMonth.value === 0) { attMonth.value = 11; attYear.value--; }
  else attMonth.value--;
  loadAttendance();
};
const nextAttMonth = () => {
  if (attMonth.value === 11) { attMonth.value = 0; attYear.value++; }
  else attMonth.value++;
  loadAttendance();
};

const loadAttendance = async () => {
  if (!studentId) return;
  console.log('Starting loadAttendance for:', studentId);
  attLoading.value = true;
  try {
    const y = attYear.value;
    const m = attMonth.value;
    const { data, error } = await supabase
      .from('attendance')
      .select('lesson_date, status')
      .eq('student_id', studentId);
      
    if (error) { 
      console.warn('Attendance fetch warning:', error.message); 
      return; 
    }
    
    const map = {};
    (data || []).forEach(r => { map[r.lesson_date] = r.status; });
    attMap.value = map;
    console.log('Attendance loaded:', Object.keys(map).length, 'records');
  } catch (e) {
    console.error('Attendance load error:', e);
  } finally {
    attLoading.value = false;
  }
};

// All calendar days for display (including leading blanks)
const calendarDays = computed(() => {
  const y = attYear.value;
  const m = attMonth.value;
  const daysInMonth = new Date(y, m+1, 0).getDate();
  const firstDow = new Date(y, m, 1).getDay(); // 0=Sun
  // Shift so week starts Monday (Mon=0)
  const startOffset = (firstDow === 0 ? 6 : firstDow - 1);
  const cells = [];
  for (let i = 0; i < startOffset; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(d);
  return cells;
});

const todayKey = `${today.getFullYear()}-${String(today.getMonth()+1).padStart(2,'0')}-${String(today.getDate()).padStart(2,'0')}`;

const dateKey = (d) => {
  if (!d) return null;
  return `${attYear.value}-${String(attMonth.value+1).padStart(2,'0')}-${String(d).padStart(2,'0')}`;
};

const attStats = computed(() => {
  const s = { present: 0, absent: 0, sick: 0, late: 0, total: 0 };
  const targetYear = attYear.value;
  const targetMonth = attMonth.value + 1; // JS month is 0-indexed, DB/attMap key is 1-indexed (usually)
  
  Object.entries(attMap.value).forEach(([date, st]) => {
    const [y, m] = date.split('-').map(Number);
    if (y === targetYear && m === targetMonth) {
      if (s[st] !== undefined) { s[st]++; s.total++; }
    }
  });
  return s;
});

const allRecentRecords = computed(() => {
  return Object.entries(attMap.value)
    .sort((a,b) => b[0].localeCompare(a[0]))
    .map(([date, status]) => ({ date, status }));
});

const paginatedAttendance = computed(() => {
  const start = (currentPageAtt.value - 1) * pageSizeAtt;
  return allRecentRecords.value.slice(start, start + pageSizeAtt);
});

const totalPagesAtt = computed(() => Math.ceil(allRecentRecords.value.length / pageSizeAtt));

watch([attMonth, attYear], () => {
  currentPageAtt.value = 1;
});

const getStatusMeta = (key) => STATUSES.find(s => s.key === key) || null;

// --- Picker & Set Status Logic ---
const activeCell = ref(null); // dateKey
const pickerPos = ref({ top: 0, left: 0 });
const pickerDate = ref(null);

const openPicker = (event, date) => {
  const key = dateKey(date);
  if (activeCell.value === key) {
    activeCell.value = null;
    return;
  }
  
  const rect = event.currentTarget.getBoundingClientRect();
  const pickerWidth = 160;
  const pickerHeight = 220;
  let left = rect.left + rect.width / 2 - pickerWidth / 2;
  let top = rect.bottom + 6;
  
  if (left < 8) left = 8;
  if (left + pickerWidth > window.innerWidth - 8) left = window.innerWidth - pickerWidth - 8;
  if (top + pickerHeight > window.innerHeight - 8) top = rect.top - pickerHeight - 6;
  
  pickerPos.value = { top, left };
  pickerDate.value = new Date(attYear.value, attMonth.value, date);
  activeCell.value = key;
};

const closePicker = () => { activeCell.value = null; };

const checkTrialStatus = async () => {
  if (!student.value || !['Trial', 'Active'].includes(student.value.status)) return;

  const { count, error } = await supabase
    .from('attendance')
    .select('*', { count: 'exact', head: true })
    .eq('student_id', studentId)
    .eq('status', 'present');

  if (error) return;

  if (count > 2 && student.value.status === 'Trial') {
    const { error: updateError } = await supabase
      .from('students')
      .update({ status: 'Active' })
      .eq('id', studentId);
    
    if (!updateError) student.value.status = 'Active';
  } else if (count <= 2 && student.value.status === 'Active') {
    const { error: updateError } = await supabase
      .from('students')
      .update({ status: 'Trial' })
      .eq('id', studentId);
    
    if (!updateError) student.value.status = 'Trial';
  }
};

const setStatus = async (date, newStatus) => {
  if (!studentId) return;
  const key = dateKey(date.getDate());
  const current = attMap.value[key] || null;

  if (current === newStatus) {
    // Clear status
    const newAtt = { ...attMap.value };
    delete newAtt[key];
    attMap.value = newAtt;
    try {
      await supabase.from('attendance').delete()
        .match({ student_id: studentId, lesson_date: key });
      await checkTrialStatus();
    } catch (e) { attMap.value = { ...attMap.value, [key]: current }; }
    return;
  }

  attMap.value = { ...attMap.value, [key]: newStatus };
  try {
    await supabase.from('attendance').upsert([{
      student_id: studentId,
      group_id: student.value?.group_id,
      lesson_date: key,
      status: newStatus
    }], { onConflict: 'student_id,group_id,lesson_date' });
    await checkTrialStatus();
  } catch (e) {
    const newAtt = { ...attMap.value };
    if (current === null) delete newAtt[key];
    else newAtt[key] = current;
    attMap.value = newAtt;
    console.error('Error saving attendance:', e);
  }
};

const isBeforeJoin = (dateNum) => {
  if (!student.value?.created_at || !dateNum) return false;
  const joinDate = new Date(student.value.created_at);
  joinDate.setHours(0,0,0,0);
  const cellDate = new Date(attYear.value, attMonth.value, dateNum);
  cellDate.setHours(0,0,0,0);
  return cellDate < joinDate;
};


onMounted(() => {
  console.log('StudentDetails mounted. Initiating loads...');
  
  // Safety timeout: if loading takes > 3s, force hide skeleton
  setTimeout(() => {
    if (isLoading.value) {
      console.warn('Safety timeout triggered: forcing isLoading = false');
      isLoading.value = false;
      if (!student.value) {
        saveError.value = 'Сервер не ответил вовремя. Попробуйте обновить страницу.';
      }
    }
  }, 3000);

  loadStudentData();
  loadAttendance();
});

const goBack = () => router.back();

const getStatusClass = (status) => {
  if (status === 'Active' || status === 'Present') return 'status-success';
  if (status === 'Left' || status === 'Absent') return 'status-danger';
  if (status === 'Pending') return 'status-warning';
  return 'status-neutral';
};

const formatCurrency = (val) => {
  return new Intl.NumberFormat('uz-UZ', { style: 'currency', currency: 'UZS', maximumFractionDigits: 0 }).format(val);
};

const totalPaid = computed(() => payments.value.reduce((acc, p) => acc + (p.amount || 0), 0));
const lastPayment = computed(() => payments.value[0]);
const coursePrice = computed(() => group.value?.courses?.price || 0);

// ─── Discount ───
const discount = ref(0);        // percentage 0–100
const discountInput = ref(0);   // bound to input
const isSavingDiscount = ref(false);
const discountSaved = ref(false);

// When student data loads, read stored discount
const initDiscount = (val) => {
  discount.value = val || 0;
  discountInput.value = val || 0;
};

const discountAmount = computed(() =>
  Math.min(discount.value, coursePrice.value)  // cap at course price
);
const priceAfterDiscount = computed(() =>
  Math.max(0, coursePrice.value - discountAmount.value)
);
const paymentPercent = computed(() => {
  const target = priceAfterDiscount.value || coursePrice.value;
  if (!target) return 0;
  return Math.min(100, Math.round((totalPaid.value / target) * 100));
});

const saveDiscount = async () => {
  // store raw UZS amount, min 0, max course price
  const val = Math.max(0, Math.min(coursePrice.value || 999_999_999, Number(discountInput.value) || 0));
  isSavingDiscount.value = true;
  try {
    const { error } = await supabase
      .from('students')
      .update({ discount: val, updated_at: new Date().toISOString() })
      .eq('id', studentId);
    if (error) throw error;
    discount.value = val;
    discountInput.value = val;
    discountSaved.value = true;
    setTimeout(() => { discountSaved.value = false; }, 2000);
  } catch (e) {
    console.error('Error saving discount:', e.message);
    showStatus('Xatolik', 'Chegirmani saqlashda xatolik yuz berdi: ' + e.message, 'error');
  } finally {
    isSavingDiscount.value = false;
  }
};

const payMonth = computed(() => attMonth.value);
const payYear = computed(() => attYear.value);

const billingSummary = computed(() => {
  if (!student.value || !student.value.created_at) return [];
  
  const joinDate = new Date(student.value.created_at);
  const now = new Date();
  
  const summary = [];
  let curY = joinDate.getFullYear();
  let curM = joinDate.getMonth();
  
  const monthlyPrice = priceAfterDiscount.value || coursePrice.value || 0;
  
  // Helper to count lessons in a month based on group days
  const countLessons = (y, m, fromDate = null) => {
    const daysInMonth = new Date(y, m+1, 0).getDate();
    let count = 0;
    const dayIndexes = group.value?.days?.split('-').map(d => DAY_INDEX[d.trim().substring(0,2)]).filter(d => d !== undefined) || [];
    if (dayIndexes.length === 0) return 12; // Fallback to avg
    
    for (let d = 1; d <= daysInMonth; d++) {
      const date = new Date(y, m, d);
      if (fromDate && date < fromDate) continue;
      if (dayIndexes.includes(date.getDay())) count++;
    }
    return count;
  };
  
  while (curY < now.getFullYear() || (curY === now.getFullYear() && curM <= now.getMonth())) {
    const monthStr = MONTH_NAMES[curM] + ' ' + curY;
    
    // Pro-rate the first month (join month)
    let targetPrice = monthlyPrice;
    if (curY === joinDate.getFullYear() && curM === joinDate.getMonth()) {
      const totalLessons = countLessons(curY, curM);
      const lessonsAfterJoin = countLessons(curY, curM, joinDate);
      if (totalLessons > 0) {
        targetPrice = Math.round((lessonsAfterJoin / totalLessons) * monthlyPrice);
      }
    }
    
    // Calculate how much was paid for this specific month
    const paidForMonth = payments.value
      .filter(p => (p.month || '').toLowerCase() === monthStr.toLowerCase())
      .reduce((acc, p) => acc + (p.amount || 0), 0);
      
    // Calculate how much is promised for this specific month
    const promisedForMonth = paymentReminders.value
      .filter(r => r.normalizedMonth.toLowerCase() === monthStr.toLowerCase())
      .reduce((acc, r) => acc + (r.amount || 0), 0);
      
    let status = 'unpaid';
    const effectivePaid = paidForMonth + promisedForMonth;
    if (targetPrice > 0 && effectivePaid >= targetPrice - 100) status = 'paid';
    else if (effectivePaid > 0) status = 'partial';
    
    summary.push({
      monthStr,
      m: curM,
      y: curY,
      paid: paidForMonth,
      promised: promisedForMonth,
      target: targetPrice,
      balance: Math.max(0, targetPrice - effectivePaid),
      status
    });
    
    if (curM === 11) { curM = 0; curY++; }
    else curM++;
  }
  
  return summary.reverse(); // Newest first
});

const jumpToMonth = (item) => {
  attMonth.value = item.m;
  attYear.value = item.y;
  loadAttendance();
};

const formatDate = (dateStr) => {
  if (!dateStr) return '-';
  const d = new Date(dateStr);
  return d.toLocaleDateString('ru-RU', { day: 'numeric', month: 'long' });
};

// --- Modal State ---
const showPaymentModal = ref(false);

const openPaymentModal = () => {
  showPaymentModal.value = true;
};

const closePaymentModal = () => {
  showPaymentModal.value = false;
  // Reset overrides after close
  payMonthOverride.value = null;
  payYearOverride.value = null;
};

const payMonthOverride = ref(null);
const payYearOverride = ref(null);

const openPaymentForMonth = (item) => {
  payMonthOverride.value = item.m;
  payYearOverride.value = item.y;
  showPaymentModal.value = true;
};

const onPaymentSuccess = () => {
  loadStudentData();
  showStatus('Muvaffaqiyatli', 'To\'lov muvaffaqiyatli saqlandi!', 'success');
};

</script>

<template>
  <div class="student-details-page">
    <!-- Header -->
    <div class="page-header">
      <button class="btn-back" @click="goBack">
        <ChevronLeft :size="20" />
        {{ $t('common.back') }}
      </button>
      
      <div class="header-actions">
        <button v-if="userRole === 'admin'" class="btn-outline-primary">
          <Edit :size="18" />
          {{ $t('common.edit') }}
        </button>
      </div>
    </div>

    <div v-if="isLoading" class="loading-state">
      <div class="skeleton-header skeleton"></div>
      <div class="debug-info" style="margin-bottom: 1rem; color: #64748b; font-size: 0.8rem;">
        Загрузка данных для ID: {{ studentId }}...
      </div>
      <div class="skeleton-grid">
        <div class="skeleton card" style="height: 300px;"></div>
        <div class="skeleton card" style="height: 300px;"></div>
      </div>
    </div>

    <div v-else-if="saveError" class="error-state card" style="margin: 2rem; padding: 3rem; text-align: center; border-left: 4px solid #EF4444;">
      <AlertCircle :size="48" style="color: #EF4444; margin-bottom: 1rem;" />
      <h2 style="margin-bottom: 1rem;">Ошибка загрузки данных</h2>
      <p style="color: #64748b; margin-bottom: 1.5rem;">{{ saveError }}</p>
      <button class="btn-primary" @click="loadStudentData">Попробовать снова</button>
    </div>

    <div v-else-if="!student" class="error-state card" style="margin: 2rem; padding: 3rem; text-align: center;">
      <XCircle :size="48" style="color: #64748b; margin-bottom: 1rem;" />
      <h2 style="margin-bottom: 1rem;">Студент не найден</h2>
      <p style="color: #64748b; margin-bottom: 1.5rem;">Мы не смогли найти ученика с ID: {{ studentId }}</p>
      <button class="btn-back" @click="goBack">Вернуться назад</button>
    </div>

    <template v-else>
      <!-- Profile Hero -->
      <div class="profile-hero card">
        <div class="profile-main">
          <div class="avatar-container">
            <img :src="`https://ui-avatars.com/api/?name=${encodeURIComponent(student.name)}&background=7366FF&color=fff&size=128`" class="profile-avatar">
            <div :class="['status-dot', (student.status || 'Active').toLowerCase()]"></div>
          </div>
        <div class="profile-info">
            <div class="name-row">
              <h1>{{ student.name }}</h1>
              <span :class="['status-badge', getStatusClass(student.status || 'Active')]">
                {{ $t('students.' + (student.status || 'Active').toLowerCase()) }}
              </span>
            </div>
            <p class="student-id">ID: #ST-{{ String(student.id || '').slice(0, 8) }}</p>
            
            <div class="quick-stats">
              <div class="q-stat">
                <Calendar :size="16" />
                <span>{{ $t('students.addedDate') }}: {{ formatDate(student.created_at) }}</span>
              </div>
              <div class="q-stat" v-if="group">
                <Users :size="16" />
                <span>{{ $t('students.group') }}: {{ group.name }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Content Grid -->
      <div class="details-grid">
        <!-- Left Column: Info & Stats -->
        <div class="details-column">
          <!-- Contact Info -->
          <div class="info-section card">
            <div class="section-title">
              <h3>{{ $t('students.contactInfo') }}</h3>
            </div>
            <div class="info-list">
              <div class="info-item">
                <div class="info-icon"><Phone :size="18" /></div>
                <div class="info-content">
                  <span class="label">{{ $t('students.mainPhone') }}</span>
                  <span class="value">{{ student.phone || '-' }}</span>
                </div>
              </div>
              <div class="info-item" v-if="student.phone2">
                <div class="info-icon"><Phone :size="18" /></div>
                <div class="info-content">
                  <span class="label">{{ $t('students.secondaryPhone') }}</span>
                  <span class="value">{{ student.phone2 }}</span>
                </div>
              </div>
              <div class="info-item">
                <div class="info-icon"><Mail :size="18" /></div>
                <div class="info-content">
                  <span class="label">{{ $t('students.email') }}</span>
                  <span class="value">{{ student.email || 'Kiritilmagan' }}</span>
                </div>
              </div>
            </div>
          </div>

          <!-- Financial Summary -->
          <div class="financial-card card">
            <div class="section-title">
              <h3>{{ $t('students.financialSummary') }}</h3>
            </div>
            <div class="balance-display">
              <div class="balance-item total">
                <div class="b-icon"><Wallet :size="24" /></div>
                <div class="b-info">
                  <span class="label">{{ $t('students.totalPaid') }}</span>
                  <h2 class="value">{{ formatCurrency(totalPaid) }}</h2>
                </div>
              </div>
              <!-- Course price row -->
              <div class="balance-item last" v-if="coursePrice">
                <div class="b-info">
                  <span class="label">Kurs narxi</span>
                  <span class="value price-tag">{{ formatCurrency(coursePrice) }}</span>
                </div>
              </div>
              <!-- Discount row -->
              <div class="balance-item last" v-if="coursePrice">
                <div class="b-info">
                  <span class="label">Chegirma</span>
                  <span class="value" style="color:#EF4444; font-weight:700;">
                    {{ discount > 0 ? '− ' + formatCurrency(discountAmount) : 'Yo\'q' }}
                  </span>
                </div>
              </div>
              <!-- Payable after discount -->
              <div class="balance-item last" v-if="coursePrice && discount > 0">
                <div class="b-info">
                  <span class="label">To'lash kerak</span>
                  <span class="value" style="color:#10B981; font-weight:800;">
                    {{ formatCurrency(priceAfterDiscount) }}
                  </span>
                </div>
              </div>
              <div class="balance-item last" v-if="lastPayment">
                <div class="b-info">
                  <span class="label">{{ $t('students.lastPayment') }}</span>
                  <span class="value">{{ formatCurrency(lastPayment.amount) }} ({{ lastPayment.date }})</span>
                </div>
              </div>
            </div>

            <!-- Discount editor -->
            <div class="discount-editor" v-if="userRole === 'admin' || userRole === 'regular'">
              <div class="discount-label">
                <span>Chegirma berish</span>
                <span class="discount-hint">UZS summasi</span>
              </div>
              <div class="discount-row">
                <div class="discount-input-wrap uzs-input-wrap">
                  <span class="discount-uzs-prefix">UZS</span>
                  <input
                    v-model.number="discountInput"
                    type="number" min="0"
                    :max="coursePrice || undefined"
                    class="discount-input uzs-input"
                    placeholder="0"
                    @keyup.enter="saveDiscount"
                  />
                </div>
                <!-- Quick preset buttons (common UZS amounts) -->
                <div class="discount-presets">
                  <button v-for="p in [0, 50000, 100000, 150000, 200000]" :key="p"
                    class="preset-btn"
                    :class="{ 'preset-active': discountInput === p }"
                    @click="discountInput = p"
                  >{{ p === 0 ? 'Yo\'q' : (p/1000) + 'K' }}</button>
                </div>
                <button class="btn-save-discount" @click="saveDiscount" :disabled="isSavingDiscount">
                  <template v-if="isSavingDiscount"><Loader2 :size="14" class="spin" /></template>
                  <template v-else-if="discountSaved">✓ Saqlandi</template>
                  <template v-else>Saqlash</template>
                </button>
              </div>
              <!-- Live preview -->
              <div v-if="discountInput > 0" class="discount-preview">
                {{ formatCurrency(coursePrice) }} − {{ formatCurrency(discountInput) }} =
                <strong>{{ formatCurrency(Math.max(0, coursePrice - discountInput)) }}</strong>
              </div>
            </div>

            <div class="progress-container">
              <div class="progress-label">
                <span>{{ $t('students.paymentPercentage') }}</span>
                <span :class="paymentPercent >= 100 ? 'pct-full' : ''">
                  {{ paymentPercent }}%
                </span>
              </div>
              <div class="progress-bar">
                <div class="progress-fill"
                  :style="{ width: paymentPercent + '%' }"
                  :class="paymentPercent >= 100 ? 'progress-full' : ''"
                ></div>
              </div>
              <div v-if="coursePrice" class="progress-sub">
                {{ formatCurrency(totalPaid) }} / {{ formatCurrency(discount > 0 ? priceAfterDiscount : coursePrice) }}
              </div>
            </div>
          </div>

          <!-- Monthly Billing Summary -->
          <div class="billing-summary-section card">
            <div class="section-title">
              <h3>To'lovlar holati</h3>
              <span class="summary-count">{{ billingSummary.length }} oy</span>
            </div>
            <div class="billing-list">
              <div 
                v-for="item in billingSummary" 
                :key="item.monthStr" 
                class="billing-month-card" 
                :class="[item.status, { 'clickable': userRole === 'admin' || userRole === 'regular' }]"
                @click="(userRole === 'admin' || userRole === 'regular') && openPaymentForMonth(item)"
              >
                <div class="month-main">
                  <div class="month-name-wrap">
                    <span class="month-name">{{ item.monthStr }}</span>
                    <button class="btn-jump-month" @click.stop="jumpToMonth(item)" title="Kalendarni o'zgartirish">
                      <ArrowRight :size="14" />
                    </button>
                    <div v-if="payMonth === item.m && payYear === item.y" class="current-indicator-dot" title="Hozirgi ko'rinish"></div>
                  </div>
                  <span class="month-status-badge" :class="item.status">
                    <span class="dot"></span>
                    {{ item.status === 'paid' ? 'To\'langan' : (item.status === 'partial' ? 'Qisman' : 'To\'lanmagan') }}
                  </span>
                </div>
                <div class="month-details">
                  <div class="m-stat">
                    <span class="m-label">To'langan:</span>
                    <span class="m-val success">{{ formatCurrency(item.paid) }}</span>
                  </div>
                  <div class="m-stat" v-if="item.promised > 0">
                    <span class="m-label">Va'da:</span>
                    <span class="m-val warning">{{ formatCurrency(item.promised) }}</span>
                  </div>
                  <div class="m-stat" v-if="item.balance > 0">
                    <span class="m-label">Qolgan:</span>
                    <span class="m-val danger">{{ formatCurrency(item.balance) }}</span>
                  </div>
                  <div class="m-stat" v-else>
                    <span class="m-label">Balans:</span>
                    <span class="m-val muted">0</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Payment Button -->
          <div v-if="userRole === 'admin' || userRole === 'regular'" class="payment-action-wrapper" style="margin-top: 1.5rem;">
            <button class="btn-primary" style="width: 100%; justify-content: center; padding: 1rem; border-radius: 12px; font-weight: 600; display: flex; align-items: center; gap: 8px;" @click="openPaymentModal">
              <CreditCard :size="18" />
              {{ $t('students.payNow') }}
            </button>
          </div>
        </div>

        <!-- Right Column: Tables -->
        <div class="details-column main">
          <!-- Group & Course Info -->
          <div class="group-info card" v-if="group">
            <div class="section-header">
              <div class="title-row">
                <BookOpen :size="20" />
                <h3>{{ $t('students.courseInfo') }}</h3>
              </div>
              <button class="btn-text" @click="router.push(`/groups/${group.id}`)">
                {{ $t('students.goToGroup') }} <ArrowRight :size="16" />
              </button>
            </div>
            <div class="course-data">
              <div class="data-item">
                <span class="label">{{ $t('students.course') }}</span>
                <span class="value">{{ group.courses?.name || '-' }}</span>
              </div>
              <div class="data-item">
                <span class="label">{{ $t('students.teacher') }}</span>
                <span class="value">{{ group.teachers?.name || '-' }}</span>
              </div>
              <div class="data-item">
                <span class="label">{{ $t('students.lessonDays') }}</span>
                <span class="value">{{ group.days || '-' }}</span>
              </div>
              <div class="data-item">
                <span class="label">{{ $t('students.lessonTime') }}</span>
                <span class="value">{{ group.time || '-' }}</span>
              </div>
              <div class="data-item course-price-item">
                <span class="label">Kurs narxi</span>
                <span class="value price-value">
                  {{ group.courses?.price ? formatCurrency(group.courses.price) : "Ko'rsatilmagan" }}
                </span>
              </div>
            </div>
          </div>

          <!-- Payments Table -->
          <div class="table-section card">
            <div class="section-header">
              <div class="title-row">
                <CreditCard :size="20" />
                <h3>{{ $t('students.paymentHistory') }}</h3>
              </div>
              <span class="count-badge">{{ payments.length }}</span>
            </div>
            <div class="table-wrapper">
              <table v-if="payments.length > 0">
                <thead>
                  <tr>
                    <th>{{ $t('students.date') }}</th>
                    <th>{{ $t('students.amount') }}</th>
                    <th>{{ $t('students.month') }}</th>
                    <th>{{ $t('students.comment') }}</th>
                    <th>{{ $t('students.method') }}</th>
                    <th>{{ $t('students.status') }}</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="pay in payments" :key="pay.id">
                    <td class="whitespace-nowrap" :data-label="$t('students.date')">{{ formatDate(pay.date) }}</td>
                    <td class="font-bold" :data-label="$t('students.amount')">{{ formatCurrency(pay.amount) }}</td>
                    <td :data-label="$t('students.month')"><span class="month-badge">{{ pay.month || '-' }}</span></td>
                    <td class="comment-cell" :data-label="$t('students.comment')">{{ pay.comment || '-' }}</td>
                    <td :data-label="$t('students.method')">{{ pay.method }}</td>
                    <td :data-label="$t('students.status')">
                      <span :class="['status-badge-small', getStatusClass(pay.status)]">
                        {{ pay.status }}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
              <div v-else class="no-data-mini" style="margin-top:1rem;">
                <AlertCircle :size="28" style="opacity:.4" />
                <p>{{ $t('students.noPaymentHistory') }}</p>
              </div>
            </div>
          </div>

          <!-- ═══ ATTENDANCE SECTION ═══ -->
          <div class="att-section card">
            <!-- Header -->
            <div class="section-header">
              <div class="title-row">
                <CalendarDays :size="20" class="att-icon-color" />
                <h3>{{ $t('students.attendance') }}</h3>
              </div>
              <!-- Month nav -->
              <div class="att-month-nav">
                <button class="att-nav-btn" @click="prevAttMonth"><ChevronLeft :size="16" /></button>
                <span class="att-month-label">{{ MONTH_NAMES[attMonth] }} {{ attYear }}</span>
                <button class="att-nav-btn" @click="nextAttMonth"><ChevronRight :size="16" /></button>
              </div>
            </div>

            <!-- Loading -->
            <div v-if="attLoading" class="att-loading">
              <Loader2 :size="22" class="spin" />
              <span>Yuklanmoqda...</span>
            </div>

            <template v-else>
              <!-- Stats bar -->
              <div class="att-stats">
                <div class="att-stat" v-for="s in STATUSES" :key="s.key"
                  :style="{ background: s.bg, color: s.color }">
                  <span class="att-stat-icon">{{ s.short }}</span>
                  <div>
                    <div class="att-stat-num">{{ attStats[s.key] }}</div>
                    <div class="att-stat-label">{{ s.label }}</div>
                  </div>
                </div>
                <div class="att-stat att-stat-total">
                  <span class="att-stat-icon">📋</span>
                  <div>
                    <div class="att-stat-num">{{ attStats.total }}</div>
                    <div class="att-stat-label">Jami</div>
                  </div>
                </div>
              </div>

              <!-- Calendar heatmap -->
              <div class="att-calendar">
                <!-- Day of week headers -->
                <div class="att-dow" v-for="d in ['Du','Se','Ch','Pa','Ju','Sh','Ya']" :key="d">{{ d }}</div>
                <!-- Empty leading cells -->
                <div
                  v-for="(day, i) in calendarDays"
                  :key="i"
                  :class="[
                    'att-day',
                    day === null ? 'att-day-empty' : '',
                    day !== null && dateKey(day) === todayKey ? 'att-day-today' : '',
                    day !== null && attMap[dateKey(day)] ? 'att-day-filled' : '',
                    day !== null && !isBeforeJoin(day) ? 'att-day-interactive' : ''
                  ]"
                  :style="day !== null && attMap[dateKey(day)] ? {
                    background: getStatusMeta(attMap[dateKey(day)])?.bg,
                    color: getStatusMeta(attMap[dateKey(day)])?.color,
                    borderColor: getStatusMeta(attMap[dateKey(day)])?.color + '44'
                  } : {}"
                  @click="day !== null && !isBeforeJoin(day) && openPicker($event, day)"
                >
                  <template v-if="day !== null">
                    <span class="att-day-num">{{ day }}</span>
                    <span v-if="attMap[dateKey(day)]" class="att-day-icon">
                      {{ getStatusMeta(attMap[dateKey(day)])?.short }}
                    </span>
                  </template>
                </div>
              </div>

              <!-- Recent records list -->
              <div v-if="allRecentRecords.length > 0" class="att-records">
                <div class="att-records-header">
                  <div class="att-records-title">So'nggi yozuvlar</div>
                  <div v-if="totalPagesAtt > 1" class="att-mini-pagination">
                    <button 
                      class="att-p-btn" 
                      :disabled="currentPageAtt === 1" 
                      @click="currentPageAtt--"
                    >
                      <ChevronLeft :size="14" />
                    </button>
                    <span class="att-p-info">{{ currentPageAtt }} / {{ totalPagesAtt }}</span>
                    <button 
                      class="att-p-btn" 
                      :disabled="currentPageAtt === totalPagesAtt" 
                      @click="currentPageAtt++"
                    >
                      <ChevronRight :size="14" />
                    </button>
                  </div>
                </div>
                <div class="att-record-list">
                  <div class="att-record" v-for="r in paginatedAttendance" :key="r.date">
                    <div class="att-record-date">{{ r.date }}</div>
                    <div class="att-record-badge"
                      :style="{ background: getStatusMeta(r.status)?.bg, color: getStatusMeta(r.status)?.color }">
                      {{ getStatusMeta(r.status)?.short }} {{ getStatusMeta(r.status)?.label }}
                    </div>
                  </div>
                </div>
              </div>

              <div v-else class="no-data-mini">
                <AlertCircle :size="28" />
                <p>Bu oyda davomat ma'lumoti yo'q</p>
              </div>
            </template>
          </div>
        </div>
      </div>
      </template>
    
    <!-- Teleported Status Picker -->
    <Teleport to="body">
      <div
        v-if="activeCell && pickerDate"
        class="status-picker-fixed"
        :style="{ top: pickerPos.top + 'px', left: pickerPos.left + 'px' }"
        @click.stop
      >
        <div class="picker-date">
          {{ pickerDate.getDate() }} {{ MONTH_NAMES[pickerDate.getMonth()] }}
        </div>
        <button
          v-for="s in STATUSES"
          :key="s.key"
          class="picker-btn"
          :class="{ 'picker-active': attMap[dateKey(pickerDate.getDate())] === s.key }"
          :style="{ '--btn-color': s.color, '--btn-bg': s.bg }"
          @click="setStatus(pickerDate, s.key); closePicker()"
        >
          <span class="picker-icon">{{ s.short }}</span>
          {{ s.label }}
        </button>
        <button class="picker-btn picker-clear" @click="setStatus(pickerDate, attMap[dateKey(pickerDate.getDate())]); closePicker()">
          ✕ Bekor qilish
        </button>
      </div>
    </Teleport>
    
    <!-- Status Modal -->
    <transition name="modal">
      <div v-if="statusModal.show" class="modal-overlay" @click.self="closeStatus">
        <div class="modal-box status-modal" :class="statusModal.type">
          <div class="status-modal-content">
            <div class="status-icon" :class="statusModal.type">
              <CheckCircle v-if="statusModal.type === 'success'" :size="48" />
              <XCircle v-else :size="48" />
            </div>
            <h2>{{ statusModal.title }}</h2>
            <p>{{ statusModal.message }}</p>
            <button class="btn-status-close" :class="statusModal.type" @click="closeStatus">
              OK
            </button>
          </div>
        </div>
      </div>
    </transition>

    <!-- Payment Modal -->
    <PaymentModal 
      :show="showPaymentModal"
      :initial-student-id="student?.id"
      :initial-student-name="student?.name"
      :initial-group-id="student?.group_id"
      :month_override="payMonthOverride"
      :year_override="payYearOverride"
      @close="closePaymentModal"
      @success="onPaymentSuccess"
    />
  </div>
</template>

<style scoped>
.student-details-page {
  padding: 2rem;
  background: #f8fafc;
  min-height: 100vh;
  overflow-x: hidden;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
}

.btn-back {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #64748b;
  font-weight: 600;
  transition: color 0.2s;
}

.btn-back:hover {
  color: var(--primary);
}

.header-actions {
  display: flex;
  gap: 1rem;
}

.btn-primary {
  background: var(--primary);
  color: white;
  padding: 0.6rem 1.25rem;
  border-radius: 10px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.btn-outline-primary {
  background: white;
  color: var(--primary);
  border: 1.5px solid var(--primary);
  padding: 0.6rem 1.25rem;
  border-radius: 10px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

/* Hero Section */
.profile-hero {
  padding: 1.5rem;
  background: white;
  margin-bottom: 2rem;
  border-radius: 24px;
  box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.05);
  overflow: hidden;
}

.profile-main {
  display: flex;
  align-items: center;
  gap: 1.5rem;
  flex-wrap: wrap;
}

.avatar-container {
  position: relative;
}

.profile-avatar {
  width: 90px;
  height: 90px;
  border-radius: 22px;
  object-fit: cover;
  border: 4px solid #f1f5f9;
  flex-shrink: 0;
  display: block;
}

.status-dot {
  position: absolute;
  bottom: 5px;
  right: 5px;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  border: 4px solid white;
}

.status-dot.active { background: #22c55e; }
.status-dot.left { background: #ef4444; }

.profile-info {
  flex: 1;
  min-width: 0;
}
.profile-info h1 {
  font-size: 1.5rem;
  font-weight: 800;
  color: #1e293b;
  margin-bottom: 0.25rem;
  word-break: break-word;
}

.name-row {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.student-id {
  color: #64748b;
  font-weight: 600;
  font-size: 0.9rem;
  margin-bottom: 1rem;
}

.quick-stats {
  display: flex;
  flex-wrap: wrap;
  gap: 1rem;
}

.q-stat {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #64748b;
  font-size: 0.9rem;
  font-weight: 500;
}

/* Grid Layout */
.details-grid {
  display: grid;
  grid-template-columns: 340px 1fr;
  gap: 1.5rem;
}

@media (max-width: 1100px) {
  .details-grid {
    grid-template-columns: 1fr;
  }
}

.details-column {
  display: flex;
  flex-direction: column;
  gap: 2rem;
}

/* Section Common Styles */
.section-title {
  margin-bottom: 1.5rem;
}

.section-title h3 {
  font-size: 1.1rem;
  font-weight: 700;
  color: #1e293b;
}

.card {
  background: white;
  padding: 1.5rem;
  border-radius: 20px;
  box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.05);
}

/* Info List */
.info-list {
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.info-item {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.info-icon {
  width: 40px;
  height: 40px;
  background: #f1f5f9;
  color: #64748b;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.info-content .label {
  display: block;
  font-size: 0.75rem;
  color: #94a3b8;
  font-weight: 700;
  text-transform: uppercase;
}

.info-content .value {
  font-weight: 600;
  color: #1e293b;
}

/* Financial Card */
.financial-card {
  background: linear-gradient(135deg, white 0%, #f8faff 100%);
}

.balance-display {
  margin-bottom: 1.5rem;
}

.balance-item {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.balance-item.total .b-icon {
  width: 50px;
  height: 50px;
  background: #eff6ff;
  color: var(--primary);
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.balance-item .label {
  display: block;
  font-size: 0.85rem;
  color: #64748b;
  font-weight: 600;
}

.balance-item .value {
  color: #1e293b;
}

.balance-item.total .value {
  font-size: 1.5rem;
  font-weight: 800;
}

.balance-item.last {
  margin-top: 1rem;
  padding-top: 1rem;
  border-top: 1px solid #e2e8f0;
}

.balance-item.last .value {
  font-size: 0.9rem;
  font-weight: 600;
}

.progress-container {
  margin-top: 1rem;
}

.progress-label {
  display: flex;
  justify-content: space-between;
  font-size: 0.8rem;
  font-weight: 700;
  margin-bottom: 0.5rem;
  color: #64748b;
}

.progress-bar {
  height: 8px;
  background: #e2e8f0;
  border-radius: 4px;
  overflow: hidden;
}

.progress-fill {
  height: 100%;
  background: var(--primary);
  border-radius: 4px;
  transition: width .5s ease;
}

.progress-fill.progress-full {
  background: #22c55e;
}

.pct-full { color: #22c55e; font-weight: 800; }

.progress-sub {
  margin-top: .4rem;
  font-size: .75rem;
  color: #94a3b8;
  font-weight: 600;
  text-align: right;
}

.price-tag {
  font-size: 1rem !important;
  font-weight: 800 !important;
  color: var(--primary) !important;
}

.price-value {
  color: var(--primary) !important;
  font-weight: 800 !important;
}

.course-price-item {
  grid-column: 1 / -1;
  border-top: 1px solid #f1f5f9;
  padding-top: .75rem;
  margin-top: .25rem;
}

/* Discount editor */
.discount-editor {
  background: linear-gradient(135deg, #F8F7FF, #F0EEFF);
  border: 1.5px solid #E0D9FF;
  border-radius: 14px;
  padding: 1rem 1.1rem;
  margin: 1rem 0;
}

.discount-label {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: .65rem;
  font-size: .82rem;
  font-weight: 800;
  color: #4B465C;
}

.discount-hint {
  font-size: .72rem;
  font-weight: 600;
  color: #94a3b8;
}

.discount-row {
  display: flex;
  align-items: center;
  gap: .6rem;
  flex-wrap: wrap;
}

.discount-input-wrap {
  position: relative;
  flex-shrink: 0;
}

.uzs-input-wrap {
  display: flex;
  align-items: center;
  background: white;
  border: 1.5px solid #C4B9FF;
  border-radius: 10px;
  overflow: hidden;
  flex-shrink: 0;
}
.uzs-input-wrap:focus-within { border-color: var(--primary); box-shadow: 0 0 0 3px rgba(115,102,255,.15); }

.discount-uzs-prefix {
  padding: 0 .6rem;
  font-size: .72rem;
  font-weight: 800;
  color: var(--primary);
  background: #F0EEFF;
  border-right: 1px solid #C4B9FF;
  height: 100%;
  display: flex;
  align-items: center;
  white-space: nowrap;
}

.discount-input {
  width: 110px;
  padding: .5rem .6rem;
  border: none;
  background: transparent;
  font-size: .9rem;
  font-weight: 700;
  color: var(--primary);
  outline: none;
  font-family: inherit;
}

.discount-preview {
  margin-top: .65rem;
  font-size: .8rem;
  color: #64748b;
  font-weight: 600;
  background: white;
  border-radius: 8px;
  padding: .4rem .75rem;
  border: 1px solid #E0D9FF;
}
.discount-preview strong { color: #10B981; }

.discount-presets {
  display: flex;
  gap: .3rem;
  flex-wrap: wrap;
  flex: 1;
}

.preset-btn {
  padding: .35rem .6rem;
  border-radius: 8px;
  font-size: .75rem;
  font-weight: 700;
  background: white;
  border: 1.5px solid #E0D9FF;
  color: #6259e6;
  cursor: pointer;
  transition: all .15s;
  font-family: inherit;
}
.preset-btn:hover { background: var(--primary); color: white; border-color: var(--primary); }
.preset-btn.preset-active { background: var(--primary); color: white; border-color: var(--primary); }

.btn-save-discount {
  padding: .5rem 1.1rem;
  background: var(--primary);
  color: white;
  border-radius: 10px;
  font-size: .82rem;
  font-weight: 700;
  cursor: pointer;
  border: none;
  transition: all .18s;
  display: flex;
  align-items: center;
  gap: .4rem;
  font-family: inherit;
  white-space: nowrap;
  flex-shrink: 0;
}
.btn-save-discount:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(115,102,255,.3); }
.btn-save-discount:disabled { opacity: .65; cursor: default; }


/* Group Info */
.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
}

.title-row {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.title-row h3 {
  font-size: 1.1rem;
  font-weight: 700;
}

.btn-text {
  color: var(--primary);
  font-weight: 700;
  font-size: 0.9rem;
  display: flex;
  align-items: center;
  gap: 4px;
}

.course-data {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 1.5rem;
}

.data-item .label {
  display: block;
  font-size: 0.75rem;
  color: #94a3b8;
  font-weight: 700;
  text-transform: uppercase;
  margin-bottom: 4px;
}

.data-item .value {
  font-weight: 700;
  color: #1e293b;
  font-size: 1rem;
}

/* Tables */
.table-wrapper {
  overflow-x: auto;
}

table {
  width: 100%;
  border-collapse: collapse;
}

th {
  text-align: left;
  padding: 0.75rem 1rem;
  background: #f8fafc;
  color: #64748b;
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
}

td {
  padding: 1rem;
  border-bottom: 1px solid #f1f5f9;
  font-size: 0.9rem;
  color: #334155;
}

.font-bold {
  font-weight: 700;
}

.status-badge {
  padding: 4px 12px;
  border-radius: 8px;
  font-size: 0.75rem;
  font-weight: 700;
}

.status-badge-small {
  padding: 2px 8px;
  border-radius: 6px;
  font-size: 0.7rem;
  font-weight: 700;
}

.status-success { background: #dcfce7; color: #166534; }
.status-danger { background: #fee2e2; color: #991b1b; }
.status-warning { background: #fef3c7; color: #92400e; }
.status-neutral { background: #f1f5f9; color: #475569; }

.month-badge {
  background: #EEF2FF;
  color: #6366F1;
  padding: 4px 10px;
  border-radius: 8px;
  font-size: 0.75rem;
  font-weight: 700;
  white-space: nowrap;
}

.comment-cell {
  max-width: 200px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  font-size: 0.8rem;
  color: #64748b;
}

.count-badge {
  background: #eff6ff;
  color: var(--primary);
  padding: 2px 10px;
  border-radius: 20px;
  font-size: 0.8rem;
  font-weight: 700;
}

.no-data-mini {
  text-align: center;
  padding: 2rem;
  color: #94a3b8;
}

.no-data-mini p {
  margin-top: 0.5rem;
  font-weight: 600;
}

/* Loading States */
.skeleton-header {
  height: 40px;
  width: 200px;
  border-radius: 8px;
  margin-bottom: 2rem;
}

.skeleton-grid {
  display: grid;
  grid-template-columns: 350px 1fr;
  gap: 2rem;
}

.skeleton {
  background: #e2e8f0;
  animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: .5; }
}

/* \u2550\u2550\u2550\u2550\u2550\u2550 PAYMENT CALCULATOR \u2550\u2550\u2550\u2550\u2550\u2550 */
.pay-calc { border: 1.5px solid #E8E5FF; }

.pay-info-bar {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: .75rem;
  margin: 1rem 0 1.2rem;
}
.pay-info-item {
  background: #F8F7FF;
  border-radius: 12px;
  padding: .65rem .8rem;
  border: 1px solid #EDE9FF;
}
.pay-info-item.highlight {
  background: #FFF8E1;
  border-color: #FFECB3;
  grid-column: span 4;
  margin-top: 0.25rem;
  padding: .85rem 1.25rem;
}

.balance-breakdown {
  display: flex;
  align-items: center;
  justify-content: space-between;
  width: 100%;
}

.bb-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.bb-label {
  font-size: .8rem;
  font-weight: 700;
  color: #94A3B8;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

.bb-val {
  font-size: .95rem;
  font-weight: 800;
  color: #1E293B;
}

.bb-item.total .bb-label { color: #64748B; }
.bb-item.total .bb-val { font-size: 1.1rem; }

.pay-info-label {
  display: block;
  font-size: .68rem;
  font-weight: 700;
  color: #94a3b8;
  text-transform: uppercase;
  margin-bottom: 2px;
}
.pay-info-val {
  font-size: .88rem;
  font-weight: 800;
  color: #1e293b;
}
.pay-info-val.primary { color: var(--primary); }
.pay-info-val.danger { color: #EF4444; }
.warning-text { color: #D97706; }
.success-text { color: #059669; }

.pay-month-note {
  font-size: .8rem;
  font-weight: 600;
  color: #64748b;
  background: #F8F9FA;
  border-radius: 10px;
  padding: .5rem .9rem;
  margin-bottom: 1rem;
}
.pay-month-note.finished { background: #FFF8E1; color: #92400E; }

/* Day chip grid */
.pc-day-grid {
  display: flex;
  flex-wrap: wrap;
  gap: .45rem;
  margin-bottom: 1rem;
}
.pc-day-chip {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 48px;
  height: 52px;
  border-radius: 11px;
  font-size: .85rem;
  font-weight: 800;
  cursor: pointer;
  border: 1.5px solid #E2E8F0;
  background: #F8FAFC;
  color: #334155;
  transition: all .15s;
  font-family: inherit;
  line-height: 1.1;
}
.pc-day-chip:hover:not(:disabled) { border-color: var(--primary); background: #F0EEFF; }
.pc-day-dow {
  font-size: .58rem;
  font-weight: 700;
  color: #94a3b8;
  text-transform: uppercase;
}

.pc-sick-label {
  position: absolute;
  top: 1px;
  right: 1px;
  width: 18px;
  height: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: .65rem;
  color: #CBD5E1;
  border-radius: 6px;
  transition: all .15s;
  z-index: 5;
}
.pc-sick-label.clickable:hover {
  background: #FEF3C7;
  color: #F59E0B;
}
.pc-sick-label.active {
  color: #F59E0B;
}

/* states */
.pc-chip-selected { background: var(--primary); color: white; border-color: var(--primary); }
.pc-chip-selected .pc-day-dow { color: rgba(255,255,255,.75); }

.pc-chip-sick { background: #FEF3C7; color: #92400E; border-color: #FCD34D; }
.pc-chip-sick .pc-day-dow { color: #92400E; opacity: .7; }

.pc-chip-lesson { border-color: #DDD6FF; background: #F5F3FF; }

.pc-chip-past { opacity: 0.7; }

.pc-chip-before-join {
  background: #F1F5F9 !important;
  color: #CBD5E1 !important;
  border: 1px dashed #E2E8F0 !important;
  cursor: not-allowed !important;
  opacity: 0.6;
}
.pc-chip-before-join .pc-day-dow,
.pc-chip-before-join .pc-sick-label {
  display: none !important;
}

.pc-chip-present { background: #D1FAE5; color: #065F46; border-color: #6EE7B7; }
.pc-chip-present .pc-day-dow { color: #065F46; opacity: .7; }
.pc-chip-absent { background: #FEE2E2; color: #991B1B; border-color: #FCA5A5; }
.pc-chip-absent .pc-day-dow { color: #991B1B; opacity: .7; }
.pc-chip-none { background: #F8FAFC; color: #94a3b8; border-color: #E2E8F0; }

.pc-select-actions {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-bottom: 1rem;
}
.pc-main-actions {
  display: flex;
  flex-wrap: wrap;
  gap: .5rem;
}

.pc-sick-toggle {
  background: #FFFBEB;
  border: 1px solid #FEF3C7;
  border-radius: 10px;
  padding: .6rem 1rem;
  display: inline-flex;
}

.toggle-cb {
  display: flex;
  align-items: center;
  gap: .75rem;
  cursor: pointer;
  user-select: none;
}
.toggle-cb input {
  width: 18px;
  height: 18px;
  cursor: pointer;
  accent-color: #F59E0B;
}
.cb-label {
  font-size: .85rem;
  font-weight: 700;
  color: #92400E;
}
.pc-sel-btn {
  font-size: .74rem;
  font-weight: 700;
  color: var(--primary);
  background: #F0EEFF;
  border: 1px solid #DDD6FF;
  border-radius: 8px;
  padding: .3rem .8rem;
  cursor: pointer;
  transition: all .14s;
  font-family: inherit;
}
.pc-sel-btn:hover { background: var(--primary); color: white; }

/* Summary footer */
.pay-summary {
  border-top: 1.5px solid #F1F5F9;
  padding-top: 1rem;
  margin-top: .5rem;
}
.pay-summary-calc {
  font-size: .88rem;
  font-weight: 600;
  color: #475569;
  margin-bottom: .75rem;
}
.pay-summary-eq {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.pay-summary-eq strong {
  font-size: 1.15rem;
  font-weight: 900;
  color: var(--primary);
}

.pay-edit-wrap {
  display: inline-flex;
  align-items: center;
  background: #F0F4FF;
  border: 1.5px solid #C4B9FF;
  border-radius: 12px;
  overflow: hidden;
  margin-left: 0.5rem;
  transition: all 0.2s;
}
.pay-edit-wrap:focus-within {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(115,102,255,0.15);
}

.pay-edit-currency {
  padding: 0 0.6rem;
  font-size: 0.75rem;
  font-weight: 800;
  color: var(--primary);
  background: #E0E7FF;
  height: 38px;
  display: flex;
  align-items: center;
  border-right: 1.5px solid #C4B9FF;
}

.pay-edit-input {
  width: 140px;
  height: 38px;
  border: none;
  background: transparent;
  padding: 0 0.8rem;
  font-size: 1.1rem;
  font-weight: 900;
  color: var(--primary);
  outline: none;
  font-family: inherit;
  appearance: textfield;
}

.pay-form-row {
  display: flex;
  gap: .75rem;
  align-items: center;
}
.pay-method-select {
  padding: .55rem .9rem;
  border: 1.5px solid #DBDADE;
  border-radius: 10px;
  font-size: .85rem;
  font-weight: 700;
  outline: none;
  background: #F8F9FA;
  color: #1e293b;
  font-family: inherit;
  cursor: pointer;
}
.pay-method-select:focus { border-color: var(--primary); }
.btn-pay-save {
  display: flex;
  align-items: center;
  gap: .45rem;
  background: var(--primary);
  color: white;
  padding: .6rem 1.4rem;
  border-radius: 11px;
  font-size: .88rem;
  font-weight: 800;
  cursor: pointer;
  border: none;
  font-family: inherit;
  transition: all .18s;
  flex: 1;
  justify-content: center;
}
.btn-pay-save:hover:not(:disabled) { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(115,102,255,.3); }
.btn-pay-save:disabled { opacity: .5; cursor: default; }

.pay-comment-wrap {
  flex: 2;
  min-width: 200px;
}

.pay-comment-input {
  width: 100%;
  padding: .6rem 1rem;
  border: 1.5px solid #DBDADE;
  border-radius: 11px;
  font-size: .88rem;
  font-weight: 600;
  outline: none;
  background: white;
  transition: all .2s;
  font-family: inherit;
}

.pay-comment-input:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(115,102,255,.1);
}

/* \u2550\u2550\u2550\u2550\u2550\u2550 ATTENDANCE \u2550\u2550\u2550\u2550\u2550\u2550 */

.att-icon-color { color: var(--primary); }

.att-month-nav {
  display: flex;
  align-items: center;
  gap: .5rem;
  background: #F8F9FA;
  border: 1.5px solid #DBDADE;
  border-radius: 12px;
  padding: .3rem .4rem;
}
.att-nav-btn {
  width: 28px; height: 28px;
  border-radius: 8px;
  background: white;
  border: 1px solid #DBDADE;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer;
  color: #4B465C;
  transition: all .15s;
}
.att-nav-btn:hover { background: var(--primary); color: white; border-color: var(--primary); }
.att-month-label {
  font-size: .9rem;
  font-weight: 800;
  color: #1e293b;
  min-width: 110px;
  text-align: center;
}

.att-loading {
  display: flex; align-items: center; justify-content: center;
  gap: .75rem; padding: 2.5rem;
  color: #94a3b8; font-weight: 600;
}

/* Stats bar */
.att-stats {
  display: flex;
  gap: .75rem;
  margin-bottom: 1.5rem;
  flex-wrap: wrap;
}
.att-stat {
  display: flex;
  align-items: center;
  gap: .6rem;
  padding: .6rem .9rem;
  border-radius: 12px;
  flex: 1;
  min-width: 90px;
}
.att-stat-icon { font-size: 1.1rem; }
.att-stat-num { font-size: 1.3rem; font-weight: 800; line-height: 1; }
.att-stat-label { font-size: .7rem; font-weight: 700; opacity: .8; }
.att-stat-total { background: #F1F5F9 !important; color: #475569 !important; }

/* Calendar grid */
.att-calendar {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 4px;
  margin-bottom: 1.5rem;
  min-width: 0;
  overflow: hidden;
}
.att-dow {
  text-align: center;
  font-size: .68rem;
  font-weight: 800;
  color: #94a3b8;
  text-transform: uppercase;
  padding-bottom: .3rem;
}
.att-day {
  aspect-ratio: 1;
  border-radius: 9px;
  border: 1.5px solid transparent;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 1px;
  background: #F8FAFC;
  cursor: default;
  transition: transform .1s;
  position: relative;
}
.att-day:not(.att-day-empty):hover { transform: scale(1.08); }
.att-day-interactive { cursor: pointer !important; }
.att-day-interactive:hover { background: #F0EEFF !important; border-color: var(--primary) !important; z-index: 5; }
.att-day-empty { background: transparent; border-color: transparent; }
.att-day-num {
  font-size: .75rem;
  font-weight: 700;
  color: #334155;
  line-height: 1;
}
.att-day-icon {
  font-size: .65rem;
  line-height: 1;
}
.att-day-today {
  border-color: var(--primary) !important;
  box-shadow: 0 0 0 2px rgba(115,102,255,.15);
}
.att-day-today .att-day-num {
  background: var(--primary);
  color: white;
  border-radius: 50%;
  width: 20px; height: 20px;
  display: flex; align-items: center; justify-content: center;
}
.att-day-filled {
  border-width: 1.5px;
  border-style: solid;
}

/* Records list */
.att-records { border-top: 1px solid #F1F5F9; padding-top: 1.25rem; }
.att-records-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}
.att-records-title {
  font-size: .75rem;
  font-weight: 800;
  color: #94a3b8;
  text-transform: uppercase;
  letter-spacing: .5px;
}
.att-mini-pagination {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  background: #f1f5f9;
  padding: 3px 8px;
  border-radius: 10px;
}
.att-p-btn {
  width: 24px;
  height: 24px;
  border-radius: 6px;
  border: none;
  background: white;
  color: #475569;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
}
.att-p-btn:hover:not(:disabled) {
  background: var(--primary);
  color: white;
}
.att-p-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  background: transparent;
  box-shadow: none;
}
.att-p-info {
  font-size: 0.75rem;
  font-weight: 700;
  color: #475569;
  min-width: 35px;
  text-align: center;
}
.att-record-list {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}
.att-record {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: .6rem .75rem;
  border-radius: 10px;
  transition: background 0.2s;
}
.att-record:hover {
  background: #f8fafc;
}
.att-record-date { font-size: .88rem; font-weight: 600; color: #1e293b; }
/* Billing Summary Section */
.billing-summary-section { margin-top: 1.5rem; }
.summary-count {
  font-size: 0.8rem;
  padding: 4px 10px;
  background: var(--light);
  border-radius: 20px;
  color: var(--gray);
  font-weight: 700;
}

.billing-list {
  display: flex;
  flex-direction: column;
  gap: .75rem;
}

.billing-month-card {
  border: 1.5px solid var(--border);
  border-radius: 16px;
  padding: 1rem;
  cursor: pointer;
  transition: all 0.2s;
}

.billing-month-card:hover {
  transform: translateX(4px);
  border-color: var(--primary);
  background: #F9FAFF;
}

.month-main {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: .75rem;
}

.month-name-wrap {
  display: flex;
  align-items: center;
  gap: .5rem;
}

.month-name {
  font-weight: 800;
  font-size: .95rem;
  color: #1E293B;
}

.current-indicator { color: var(--primary); animation: bounceX 1s infinite; }
@keyframes bounceX {
  0%, 100% { transform: translateX(0); }
  50% { transform: translateX(3px); }
}

.month-status-badge {
  display: flex;
  align-items: center;
  gap: .4rem;
  font-size: .7rem;
  font-weight: 800;
  text-transform: uppercase;
  padding: 4px 10px;
  border-radius: 20px;
}

.month-status-badge .dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
}

.month-status-badge.paid { background: #DCFCE7; color: #166534; }
.month-status-badge.paid .dot { background: #22C55E; }

.month-status-badge.partial { background: #FEF3C7; color: #92400E; }
.month-status-badge.partial .dot { background: #F59E0B; }

.month-status-badge.unpaid { background: #FEE2E2; color: #991B1B; }
.month-status-badge.unpaid .dot { background: #EF4444; }

.btn-jump-month {
  width: 24px;
  height: 24px;
  border-radius: 6px;
  border: 1px solid #E2E8F0;
  background: white;
  color: #94A3B8;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
  padding: 0;
}
.btn-jump-month:hover {
  border-color: var(--primary);
  color: var(--primary);
  background: #F0EEFF;
}

.current-indicator-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--primary);
  box-shadow: 0 0 8px var(--primary);
}

.month-details {
  display: flex;
  gap: 1.5rem;
}

.m-stat {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.m-label {
  font-size: .65rem;
  color: #94A3B8;
  font-weight: 700;
  text-transform: uppercase;
}

.m-val {
  font-size: .85rem;
  font-weight: 800;
}

.m-val.success { color: #10B981; }
.m-val.danger { color: #EF4444; }
.m-val.muted { color: #CBD5E1; }

.att-record-badge {
  font-size: .75rem;
  font-weight: 700;
  padding: 3px 10px;
  border-radius: 8px;
}

/* Modal Styling */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.4);
  backdrop-filter: blur(8px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  padding: 1.5rem;
}

.modal-box {
  background: white;
  width: 100%;
  max-width: 400px;
  border-radius: 28px;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
  overflow: hidden;
  animation: modalScaleUp 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
}

@keyframes modalScaleUp {
  from { opacity: 0; transform: scale(0.9) translateY(10px); }
  to { opacity: 1; transform: scale(1) translateY(0); }
}

.status-modal-content {
  padding: 2.5rem 2rem;
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.status-icon {
  width: 80px;
  height: 80px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 1.5rem;
}

.status-icon.success { background: #F0FDF4; color: #22c55e; }
.status-icon.error { background: #FEF2F2; color: #ef4444; }

.status-modal-content h2 {
  font-size: 1.5rem;
  font-weight: 800;
  color: #1e293b;
  margin-bottom: 0.75rem;
}

.status-modal-content p {
  color: #64748b;
  font-weight: 500;
  line-height: 1.6;
  margin-bottom: 2rem;
  white-space: pre-line;
}

.btn-status-close {
  width: 100%;
  padding: 1rem;
  border-radius: 16px;
  font-weight: 700;
  font-size: 1rem;
  border: none;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}

.btn-status-close.success {
  background: #22c55e;
  color: white;
}
.btn-status-close.success:hover {
  background: #16a34a;
  transform: translateY(-2px);
  box-shadow: 0 10px 15px -3px rgba(34, 197, 94, 0.3);
}

.btn-status-close.error {
  background: #ef4444;
  color: white;
}
.btn-status-close.error:hover {
  background: #dc2626;
  transform: translateY(-2px);
  box-shadow: 0 10px 15px -3px rgba(239, 68, 68, 0.3);
}

.modal-enter-active, .modal-leave-active { transition: opacity 0.3s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }

/* ═══ VA'DA TO'LOV STYLES ═══ */
.vada-card { padding: 1.5rem; }

.vada-form {
  background: #FAFBFF;
  border: 1px solid #E8E6FF;
  border-radius: 16px;
  padding: 1.25rem;
  margin-top: 1rem;
  display: flex;
  flex-direction: column;
  gap: 0.875rem;
}

.vada-form-row {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.875rem;
}

.vada-field {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
}

.vada-label {
  font-size: 0.78rem;
  font-weight: 700;
  color: #475569;
  text-transform: uppercase;
  letter-spacing: 0.4px;
}

.vada-req { color: #EF4444; }

.vada-input {
  padding: 0.65rem 0.9rem;
  border: 1.5px solid #E2E8F0;
  border-radius: 10px;
  background: white;
  font-size: 0.9rem;
  outline: none;
  transition: border-color 0.2s, box-shadow 0.2s;
  width: 100%;
  box-sizing: border-box;
  font-family: inherit;
}
.vada-input:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(127,119,221,0.12);
}

.vada-input-icon-wrap {
  position: relative;
  display: flex;
  align-items: center;
}
.vada-prefix {
  position: absolute;
  left: 0.75rem;
  font-size: 0.75rem;
  font-weight: 700;
  color: #94A3B8;
  pointer-events: none;
}
.vada-amount { padding-left: 2.75rem !important; }

.btn-vada-save {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  background: linear-gradient(135deg, #7F77DD, #6366F1);
  color: white;
  border: none;
  border-radius: 12px;
  padding: 0.75rem 1.5rem;
  font-weight: 700;
  font-size: 0.9rem;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
  margin-top: 0.25rem;
}
.btn-vada-save:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 8px 20px rgba(127,119,221,0.35);
}
.btn-vada-save:disabled { opacity: 0.55; cursor: not-allowed; }

.vada-list {
  margin-top: 1.25rem;
  display: flex;
  flex-direction: column;
  gap: 0.6rem;
}
.vada-list-title {
  font-size: 0.7rem;
  font-weight: 800;
  color: #94A3B8;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 0.25rem;
}

.vada-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1rem;
  background: white;
  border: 1px solid #F1F5F9;
  border-radius: 12px;
  transition: border-color 0.2s;
}
.vada-item:hover { border-color: #C7D2FE; }

.vada-item-left {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex: 1;
  min-width: 0;
}
.vada-item-right {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-shrink: 0;
}

.vada-item-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
  min-width: 0;
}
.vada-date {
  font-size: 0.88rem;
  font-weight: 700;
  color: #334155;
}
.vada-note {
  font-size: 0.75rem;
  color: #94A3B8;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 200px;
}

.vada-amount-chip {
  font-size: 0.8rem;
  font-weight: 800;
  color: #4F46E5;
  background: #EEF2FF;
  padding: 3px 10px;
  border-radius: 8px;
}

/* Status badge colors — 3 colors only */
.vada-badge {
  font-size: 0.68rem;
  font-weight: 800;
  padding: 4px 9px;
  border-radius: 8px;
  white-space: nowrap;
  flex-shrink: 0;
}
.promise-green  { background: #DCFCE7; color: #166534; }
.promise-yellow { background: #FEF9C3; color: #854D0E; }
.promise-red    { background: #FEE2E2; color: #991B1B; }

.vada-btn-paid {
  width: 30px; height: 30px;
  border-radius: 8px;
  background: #DCFCE7;
  color: #16a34a;
  border: none;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
}
.vada-btn-paid:hover { background: #16a34a; color: white; }

.vada-btn-del {
  width: 28px; height: 28px;
  border-radius: 8px;
  background: transparent;
  color: #CBD5E1;
  border: none;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
}
.vada-btn-del:hover { background: #FEE2E2; color: #EF4444; }

/* ═══ PAY / PROMISE MODE TOGGLE ═══ */
.pay-mode-toggle {
  display: flex;
  gap: 0.5rem;
  margin: 1rem 0 0.75rem;
  background: #F1F5F9;
  padding: 4px;
  border-radius: 12px;
}

.pay-mode-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.45rem;
  padding: 0.65rem 1rem;
  border-radius: 9px;
  font-size: 0.85rem;
  font-weight: 700;
  border: none;
  cursor: pointer;
  background: transparent;
  color: #64748B;
  transition: all 0.2s;
  font-family: inherit;
}
.pay-mode-btn.active {
  background: white;
  color: var(--dark);
  box-shadow: 0 2px 8px rgba(0,0,0,0.08);
}
.pay-mode-btn.promise.active {
  background: white;
  color: #7C3AED;
}
.pay-mode-btn:hover:not(.active) {
  color: var(--dark);
  background: rgba(255,255,255,0.6);
}

/* Promise mode form inside pay-calc */
.promise-form-row {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.promise-fields {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.75rem;
}

.promise-field-wrap {
  display: flex;
  flex-direction: column;
  gap: 0.3rem;
}

.promise-mini-label {
  font-size: 0.75rem;
  font-weight: 700;
  color: #64748B;
  text-transform: uppercase;
  letter-spacing: 0.4px;
}

.promise-mini-input {
  padding: 0.6rem 0.85rem;
  border: 1.5px solid #E2E8F0;
  border-radius: 10px;
  background: white;
  font-size: 0.88rem;
  outline: none;
  font-family: inherit;
  transition: border-color 0.2s, box-shadow 0.2s;
  width: 100%;
  box-sizing: border-box;
}
.promise-mini-input:focus {
  border-color: #7C3AED;
  box-shadow: 0 0 0 3px rgba(124,58,237,0.1);
}

.promise-amount-preview {
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: #F3E8FF;
  border-radius: 12px;
  padding: 0.75rem 1rem;
}
.pap-label {
  font-size: 0.8rem;
  font-weight: 700;
  color: #6D28D9;
  text-transform: uppercase;
  letter-spacing: 0.4px;
}
.pap-val {
  font-size: 1.1rem;
  font-weight: 800;
  color: #5B21B6;
}

.btn-promise-save {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  background: linear-gradient(135deg, #7C3AED, #6D28D9);
  color: white;
  border: none;
  border-radius: 12px;
  padding: 0.8rem 1.5rem;
  font-weight: 700;
  font-size: 0.9rem;
  cursor: pointer;
  transition: all 0.2s;
  font-family: inherit;
}
.btn-promise-save:hover:not(:disabled) {
  transform: translateY(-2px);
  box-shadow: 0 8px 20px rgba(124,58,237,0.35);
}
.btn-promise-save:disabled { opacity: 0.5; cursor: not-allowed; }

/* ── StudentDetails Mobile ──────────────────────────────────── */
@media (max-width: 767px) {
  .student-details-page { padding: 1rem; }

  /* Profile hero */
  .profile-hero { padding: 1rem; border-radius: 16px; }
  .profile-main { gap: 1rem; }
  .profile-avatar { width: 72px; height: 72px; border-radius: 16px; }
  .profile-info h1 { font-size: 1.2rem; }
  .name-row { flex-wrap: wrap; gap: 0.5rem; }
  .quick-stats { gap: 0.75rem; }
  .q-stat { font-size: 0.8rem; }

  /* Content grid */
  .details-grid { grid-template-columns: 1fr; gap: 1rem; }
  .details-column { gap: 1rem; }
  .card { padding: 1rem; border-radius: 16px; }

  /* Attendance nav — ensure it doesn't overflow */
  .section-header { flex-wrap: wrap; gap: 0.75rem; }
  .att-month-nav { flex-shrink: 0; }
  .att-month-label { min-width: 90px; font-size: 0.8rem; }

  /* Attendance calendar — smaller cells */
  .att-calendar { gap: 3px; margin-bottom: 1rem; }
  .att-day {
    border-radius: 6px;
    border-width: 1px;
  }
  .att-day-num { font-size: 0.65rem; }
  .att-day-icon { font-size: 0.55rem; }
  .att-dow { font-size: 0.58rem; padding-bottom: 0.2rem; }

  /* Attendance stats */
  .att-stats { gap: 0.5rem; }
  .att-stat { padding: 0.45rem 0.6rem; min-width: 70px; border-radius: 10px; }
  .att-stat-num { font-size: 1.1rem; }
  .att-stat-label { font-size: 0.6rem; }

  /* Disable card hover lift on mobile (can cause glitches) */
  .card:hover { transform: none; }
  .billing-month-card:hover { transform: none; }

  /* Table (payments history) */
  .table-wrapper { overflow-x: auto; }
  .table-section.card { padding: 1rem 0.5rem; }

  /* Discount presets */
  .discount-presets { gap: 0.25rem; }
  .preset-btn { padding: 0.3rem 0.6rem; font-size: 0.75rem; }
}
</style>
