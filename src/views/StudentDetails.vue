
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
  CheckCircle
} from 'lucide-vue-next';
import { supabase } from '../supabase.js';

const route = useRoute();
const router = useRouter();
const studentId = route.params.id;

const student = ref(null);
const group = ref(null);
const payments = ref([]);
const attendance = ref([]);
const isLoading = ref(true);

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
  isLoading.value = true;
  try {
    const { data: studentData, error: studentError } = await supabase
      .from('students')
      .select('*, groups(*, courses(*), teachers(*))')
      .eq('id', studentId)
      .single();
    if (studentError) throw studentError;
    student.value = studentData;
    group.value = studentData.groups;
    initDiscount(studentData.discount);

    const { data: paymentsData } = await supabase
      .from('payments')
      .select('*')
      .eq('student', studentData.name.trim())
      .order('date', { ascending: false });
    payments.value = paymentsData || [];

  } catch (e) {
    console.error('Error loading student details:', e.message);
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

const today = new Date();
const attYear  = ref(today.getFullYear());
const attMonth = ref(today.getMonth());
const attLoading = ref(false);

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
  attLoading.value = true;
  try {
    const y = attYear.value;
    const m = attMonth.value;
    const start = `${y}-${String(m+1).padStart(2,'0')}-01`;
    const end   = `${y}-${String(m+1).padStart(2,'0')}-${String(new Date(y,m+1,0).getDate()).padStart(2,'0')}`;
    const { data, error } = await supabase
      .from('attendance')
      .select('lesson_date, status')
      .eq('student_id', studentId)
      .gte('lesson_date', start)
      .lte('lesson_date', end);
    if (error) { console.warn('attendance table:', error.message); return; }
    const map = {};
    (data || []).forEach(r => { map[r.lesson_date] = r.status; });
    attMap.value = map;
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
  Object.values(attMap.value).forEach(st => {
    if (s[st] !== undefined) { s[st]++; s.total++; }
  });
  return s;
});

const recentRecords = computed(() => {
  return Object.entries(attMap.value)
    .sort((a,b) => b[0].localeCompare(a[0]))
    .slice(0, 8)
    .map(([date, status]) => ({ date, status }));
});

const getStatusMeta = (key) => STATUSES.find(s => s.key === key) || null;


onMounted(() => {
  loadStudentData();
  loadAttendance();
  loadPayMonthAttendance();
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

const formatDate = (dateStr) => {
  if (!dateStr) return '-';
  return new Date(dateStr).toLocaleDateString('uz-UZ', { day: 'numeric', month: 'long', year: 'numeric' });
};

// ══════════════ PAYMENT CALCULATOR ══════════════
// Day name → JS getDay() index (0=Sun)
const DAY_INDEX = { 'Du':1,'Se':2,'Ch':3,'Pa':4,'Ju':5,'Sh':6,'Ya':0 };

// Parse group days string like "Se-Pay-Sha" → [2,4,6]
const groupDayIndexes = computed(() => {
  const days = group.value?.days || '';
  return days.split('-').map(d => DAY_INDEX[d.trim().substring(0,2)]).filter(d => d !== undefined);
});

// State for payment month picker
const payYear  = ref(today.getFullYear());
const payMonth = ref(today.getMonth());

// ALL days in payMonth as objects: { dateStr, day, dow, isLesson, beforeJoin }
const allDaysInPayMonth = computed(() => {
  const y = payYear.value;
  const m = payMonth.value;
  const daysInMonth = new Date(y, m+1, 0).getDate();
  const joinDateRaw = student.value?.created_at;
  const joinDate = joinDateRaw ? new Date(joinDateRaw) : null;
  if (joinDate) joinDate.setHours(0,0,0,0);

  const result = [];
  for (let d = 1; d <= daysInMonth; d++) {
    const date = new Date(y, m, d);
    date.setHours(0,0,0,0);
    const dateStr = `${y}-${String(m+1).padStart(2,'0')}-${String(d).padStart(2,'0')}`;
    const isLesson = groupDayIndexes.value.includes(date.getDay());
    const beforeJoin = joinDate ? date < joinDate : false;
    result.push({ 
      dateStr, 
      day: d, 
      dow: ['Ya','Du','Se','Ch','Pa','Ju','Sh'][date.getDay()], 
      isLesson,
      beforeJoin 
    });
  }
  return result;
});

// Only lesson days — for price per lesson calculation
const lessonDaysOnly = computed(() => allDaysInPayMonth.value.filter(d => d.isLesson).map(d => d.dateStr));

// Price per lesson = coursePrice / total lesson days in the month
const pricePerLesson = computed(() => {
  const total = lessonDaysOnly.value.length;
  if (!total || !coursePrice.value) return 0;
  return Math.round(coursePrice.value / total);
});

const useActualAttendanceForPast = ref(true);

// Is the selected pay month finished (past)?
const isPastMonth = computed(() => {
  const now = new Date();
  return (payYear.value < now.getFullYear()) ||
    (payYear.value === now.getFullYear() && payMonth.value < now.getMonth());
});

const isPayMonthFinished = computed(() => {
  if (!useActualAttendanceForPast.value) return false;
  return isPastMonth.value;
});

// For current/future month: manual selection state (Normal or Sick)
const selectedLessonDays = ref(new Set());
const sickLessonDays = ref(new Set());
const countSickDays = ref(false);

// Toggle only paid status (cycle: None <-> Paid)
const togglePaid = (dateStr) => {
  const sel = new Set(selectedLessonDays.value);
  const sck = new Set(sickLessonDays.value);
  
  if (sel.has(dateStr)) {
    sel.delete(dateStr);
  } else {
    sel.add(dateStr);
    sck.delete(dateStr); // clear sick if marking as paid
  }
  selectedLessonDays.value = sel;
  sickLessonDays.value = sck;
};

// Toggle only sick status (cycle: None <-> Sick)
const toggleSick = (dateStr) => {
  const sel = new Set(selectedLessonDays.value);
  const sck = new Set(sickLessonDays.value);
  
  if (sck.has(dateStr)) {
    sck.delete(dateStr);
  } else {
    sck.add(dateStr);
    sel.delete(dateStr); // clear paid if marking as sick
  }
  selectedLessonDays.value = sel;
  sickLessonDays.value = sck;
};

// For finished month: actual attendance map
const payMonthAttMap = ref({});
const isLoadingPayAtt = ref(false);

const loadPayMonthAttendance = async () => {
  if (!studentId) return;
  isLoadingPayAtt.value = true;
  try {
    const y = payYear.value;
    const m = payMonth.value;
    const start = `${y}-${String(m+1).padStart(2,'0')}-01`;
    const end   = `${y}-${String(m+1).padStart(2,'0')}-${String(new Date(y,m+1,0).getDate()).padStart(2,'0')}`;
    const { data } = await supabase
      .from('attendance')
      .select('lesson_date,status')
      .eq('student_id', studentId)
      .gte('lesson_date', start)
      .lte('lesson_date', end);
    const map = {};
    (data||[]).forEach(r => { map[r.lesson_date] = r.status; });
    payMonthAttMap.value = map;
  } finally {
    isLoadingPayAtt.value = false;
  }
};

// Attended days = present or late
const attendedLessonDays = computed(() => {
  if (!isPayMonthFinished.value) return [];
  return allDaysInPayMonth.value
    .filter(d => { 
      if (d.beforeJoin) return false;
      const st = payMonthAttMap.value[d.dateStr]; 
      return st === 'present' || st === 'late'; 
    })
    .map(d => d.dateStr);
});

// Days counted for payment
const daysForPayment = computed(() => {
  if (isPayMonthFinished.value) return attendedLessonDays.value;

  // For current/future month: include paid days and optionally sick days
  return allDaysInPayMonth.value
    .filter(d => {
      if (d.beforeJoin) return false;
      const isPaid = selectedLessonDays.value.has(d.dateStr);
      const isSick = sickLessonDays.value.has(d.dateStr);
      return isPaid || (isSick && countSickDays.value);
    })
    .map(d => d.dateStr);
});

// Calculated payment amount
const calcPayAmount = computed(() => {
  const base = daysForPayment.value.length * pricePerLesson.value;
  return Math.max(0, base - discountAmount.value);
});

const totalPaidInSelectedMonth = computed(() => {
  const curMonthStr = MONTH_NAMES[payMonth.value] + ' ' + payYear.value;
  return (payments.value || [])
    .filter(p => p.month === curMonthStr)
    .reduce((acc, p) => acc + (Number(p.amount) || 0), 0);
});

const monthlyTarget = computed(() => {
  const target = discount.value > 0 ? priceAfterDiscount.value : (coursePrice.value || 0);
  const totalLessonDays = lessonDaysOnly.value.length;
  const validDays = allDaysInPayMonth.value.filter(d => d.isLesson && !d.beforeJoin).length;
  
  if (totalLessonDays > 0 && validDays < totalLessonDays) {
     return validDays * Math.round(target / totalLessonDays);
  }
  return target;
});

const leftToPayInSelectedMonth = computed(() => {
  return Math.max(0, monthlyTarget.value - totalPaidInSelectedMonth.value);
});

const billingSummary = computed(() => {
  if (!student.value?.created_at) return [];
  const joinDate = new Date(student.value.created_at);
  const now = new Date();
  const summary = [];
  
  // Find the furthest month with a payment, or the current month
  let endMonthDate = new Date(now.getFullYear(), now.getMonth(), 1);
  (payments.value || []).forEach(p => {
    if (!p.month) return;
    const parts = p.month.split(' '); // "Mart 2026"
    if (parts.length === 2) {
      const mIdx = MONTH_NAMES.indexOf(parts[0]);
      const yVal = parseInt(parts[1]);
      if (mIdx !== -1 && !isNaN(yVal)) {
        const d = new Date(yVal, mIdx, 1);
        if (d > endMonthDate) endMonthDate = d;
      }
    }
  });

  let currY = joinDate.getFullYear();
  let currM = joinDate.getMonth();
  const endY = endMonthDate.getFullYear();
  const endM = endMonthDate.getMonth();

  while (currY < endY || (currY === endY && currM <= endM)) {
    const monthStr = MONTH_NAMES[currM] + ' ' + currY;
    
    const daysInMonth = new Date(currY, currM+1, 0).getDate();
    let validD = 0; let totalD = 0;
    if (joinDate) joinDate.setHours(0,0,0,0);
    
    for(let d=1; d<=daysInMonth; d++){
       const dDate = new Date(currY, currM, d);
       dDate.setHours(0,0,0,0);
       const isL = groupDayIndexes.value.includes(dDate.getDay());
       const beforeJoin = joinDate ? dDate < joinDate : false;
       if(isL){
          totalD++;
          if(!beforeJoin) validD++;
       }
    }
    
    let target = discount.value > 0 ? priceAfterDiscount.value : (coursePrice.value || 0);
    if (totalD > 0 && validD < totalD) {
       target = validD * Math.round(target / totalD);
    }
    
    const paid = (payments.value || [])
      .filter(p => (p.month || '').toLowerCase() === monthStr.toLowerCase())
      .reduce((acc, p) => acc + (Number(p.amount) || 0), 0);
    const balance = Math.max(0, target - paid);
    
    let status = 'unpaid';
    // Use a small 100 UZS epsilon for "fully paid" to avoid rounding annoyance
    if (paid >= target - 100 && target > 0) status = 'paid';
    else if (paid > 0) status = 'partial';

    summary.push({ monthStr, target, paid, balance, status, y: currY, m: currM });
    
    if (currM === 11) { currM = 0; currY++; }
    else currM++;
  }
  return summary.reverse();
});

const jumpToMonth = (item) => {
  payYear.value = item.y;
  payMonth.value = item.m;
  selectedLessonDays.value = new Set();
  loadPayMonthAttendance();
  // Scroll to calculator
  const calcEl = document.querySelector('.payment-calculator-section');
  if (calcEl) calcEl.scrollIntoView({ behavior: 'smooth' });
};

// Payment form state
const payMethod = ref('Cash');
const payAmountOverride = ref(0);
const payComment = ref('');
const isSavingPayment = ref(false);

watch(calcPayAmount, (newVal) => {
  payAmountOverride.value = newVal;
}, { immediate: true });

const prevPayMonth = async () => {
  if (payMonth.value === 0) { payMonth.value = 11; payYear.value--; }
  else payMonth.value--;
  selectedLessonDays.value = new Set();
  await loadPayMonthAttendance();
};
const nextPayMonth = async () => {
  if (payMonth.value === 11) { payMonth.value = 0; payYear.value++; }
  else payMonth.value++;
  selectedLessonDays.value = new Set();
  await loadPayMonthAttendance();
};

const savePayment = async () => {
  if (!payAmountOverride.value || !daysForPayment.value.length) return;
  isSavingPayment.value = true;
  try {
    const receiptId = 'PAY-' + Math.floor(Math.random() * 90000 + 10000);
    const { error } = await supabase.from('payments').insert([{
      id: 'pay-' + Date.now(),
      student: student.value.name,
      course: group.value?.courses?.name || '',
      amount: payAmountOverride.value,
      method: payMethod.value,
      date: new Date().toISOString().slice(0,10),
      status: 'Success',
      receipt_id: receiptId,
      comment: payComment.value,
      month: MONTH_NAMES[payMonth.value] + ' ' + payYear.value
    }]);
    if (error) throw error;
    // Refresh payments list
    const { data: newPayments } = await supabase
      .from('payments').select('*')
      .eq('student', student.value.name)
      .order('date', { ascending: false });
    payments.value = newPayments || [];
    selectedLessonDays.value = new Set();
    payComment.value = '';
    showStatus('Muvaffaqiyatli', `To'lov muvaffaqiyatli saqlandi!\nSumma: ${formatCurrency(payAmountOverride.value)}`, 'success');
  } catch(e) {
    console.error(e);
    showStatus('Xatolik', 'To\'lovni saqlashda xatolik yuz berdi: ' + e.message, 'error');
  } finally {
    isSavingPayment.value = false;
  }
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
        <button class="btn-outline-primary">
          <Edit :size="18" />
          {{ $t('common.edit') }}
        </button>
      </div>
    </div>

    <div v-if="isLoading" class="loading-state">
      <div class="skeleton-header skeleton"></div>
      <div class="skeleton-grid">
        <div class="skeleton card" style="height: 300px;"></div>
        <div class="skeleton card" style="height: 300px;"></div>
      </div>
    </div>

    <template v-else-if="student">
      <!-- Profile Hero -->
      <div class="profile-hero card">
        <div class="profile-main">
          <div class="avatar-container">
            <img :src="`https://ui-avatars.com/api/?name=${encodeURIComponent(student.name)}&background=7366FF&color=fff&size=128`" class="profile-avatar">
            <div :class="['status-dot', student.status.toLowerCase()]"></div>
          </div>
        <div class="profile-info">
            <div class="name-row">
              <h1>{{ student.name }}</h1>
              <span :class="['status-badge', getStatusClass(student.status)]">
                {{ $t('students.' + student.status.toLowerCase()) }}
              </span>
            </div>
            <p class="student-id">ID: #ST-{{ student.id.slice(0, 8) }}</p>
            
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
            <div class="discount-editor">
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
                :class="item.status"
                @click="jumpToMonth(item)"
              >
                <div class="month-main">
                  <div class="month-name-wrap">
                    <span class="month-name">{{ item.monthStr }}</span>
                    <ArrowRight v-if="payMonth === item.m && payYear === item.y" :size="14" class="current-indicator" />
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
                    <td>{{ pay.date }}</td>
                    <td class="font-bold">{{ formatCurrency(pay.amount) }}</td>
                    <td><span class="month-badge">{{ pay.month || '-' }}</span></td>
                    <td class="comment-cell">{{ pay.comment || '-' }}</td>
                    <td>{{ pay.method }}</td>
                    <td>
                      <span :class="['status-badge-small', getStatusClass(pay.status)]">
                        {{ pay.status }}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
              <div v-else class="no-data-mini">
                <AlertCircle :size="32" />
                <p>{{ $t('students.noPaymentHistory') }}</p>
              </div>
            </div>
          </div>

          <!-- ═══ PAYMENT CALCULATOR ═══ -->
          <div class="pay-calc card">
            <div class="section-header">
              <div class="title-row">
                <CreditCard :size="20" style="color:var(--primary)" />
                <h3>To'lov qo'shish</h3>
              </div>
              <!-- Month navigator -->
              <div class="att-month-nav">
                <button class="att-nav-btn" @click="prevPayMonth"><ChevronLeft :size="16" /></button>
                <span class="att-month-label">{{ MONTH_NAMES[payMonth] }} {{ payYear }}</span>
                <button class="att-nav-btn" @click="nextPayMonth"><ChevronRight :size="16" /></button>
              </div>
            </div>

            <!-- Info bar -->
            <div class="pay-info-bar">
              <div class="pay-info-item">
                <span class="pay-info-label">Dars kunlari</span>
                <span class="pay-info-val">{{ lessonDaysOnly.length }} kun</span>
              </div>
              <div class="pay-info-item">
                <span class="pay-info-label">Kun narxi</span>
                <span class="pay-info-val">{{ formatCurrency(pricePerLesson) }}</span>
              </div>
              <div class="pay-info-item">
                <span class="pay-info-label">Tanlangan</span>
                <span class="pay-info-val primary">{{ daysForPayment.length }} kun</span>
              </div>
              <div class="pay-info-item">
                <span class="pay-info-label">Chegirma</span>
                <span class="pay-info-val danger">{{ discount > 0 ? '− ' + formatCurrency(discountAmount) : 'Yo\'q' }}</span>
              </div>
              <div class="pay-info-item highlight">
                <div class="balance-breakdown">
                  <div class="bb-item">
                    <span class="bb-label">Oylik to'lov:</span>
                    <span class="bb-val">{{ formatCurrency(monthlyTarget) }}</span>
                  </div>
                  <div class="bb-item">
                    <span class="bb-label">To'langan:</span>
                    <span class="bb-val success-text">{{ formatCurrency(totalPaidInSelectedMonth) }}</span>
                  </div>
                  <div class="bb-item total">
                    <span class="bb-label">Qolgan:</span>
                    <span class="bb-val" :class="leftToPayInSelectedMonth > 0 ? 'warning-text' : 'success-text'">
                      {{ formatCurrency(leftToPayInSelectedMonth) }}
                    </span>
                  </div>
                </div>
              </div>
            </div>

            <!-- Finished month: show actual attendance -->
            <template v-if="isPayMonthFinished">
              <div class="pay-month-note finished" style="display:flex; justify-content:space-between; align-items:center;">
                <span>🗓️ Oy tugagan — haqiqiy davomatga qarab hisoblanmoqda</span>
                <button class="pc-sel-btn" @click="useActualAttendanceForPast = false" style="background: white; border-color: #FCD34D; color: #92400E;">Qo'lda kiritish</button>
              </div>
              <div v-if="isLoadingPayAtt" class="att-loading"><Loader2 :size="18" class="spin"/> Yuklanmoqda...</div>
              <div v-else class="pc-day-grid">
                <div
                  v-for="d in allDaysInPayMonth" :key="d.dateStr"
                  class="pc-day-chip"
                  :class="{
                    'pc-chip-lesson':   d.isLesson && !d.beforeJoin && !payMonthAttMap[d.dateStr],
                    'pc-chip-present':  payMonthAttMap[d.dateStr] === 'present' || payMonthAttMap[d.dateStr] === 'late',
                    'pc-chip-absent':   payMonthAttMap[d.dateStr] === 'absent'  || payMonthAttMap[d.dateStr] === 'sick',
                    'pc-chip-none':     (!d.isLesson || d.beforeJoin) && !payMonthAttMap[d.dateStr],
                    'pc-chip-before-join': d.beforeJoin
                  }"
                >
                  {{ d.day }}
                  <span class="pc-day-dow">{{ d.dow }}</span>
                </div>
              </div>
            </template>

            <!-- Current / future month: manual selection -->
            <template v-else>
              <div class="pay-month-note" style="display:flex; justify-content:space-between; align-items:center;">
                <span>📌 O'quvchi qaysi kunlari kelishini belgilang</span>
                <button v-if="isPastMonth" class="pc-sel-btn" @click="useActualAttendanceForPast = true" style="background: white;">Davomat asosida</button>
              </div>
              <div class="pc-day-grid">
                <button
                  v-for="d in allDaysInPayMonth" :key="d.dateStr"
                  class="pc-day-chip"
                  :class="{
                    'pc-chip-selected': selectedLessonDays.has(d.dateStr) && !d.beforeJoin,
                    'pc-chip-sick':     sickLessonDays.has(d.dateStr) && !d.beforeJoin,
                    'pc-chip-lesson':   d.isLesson && !d.beforeJoin && !selectedLessonDays.has(d.dateStr) && !sickLessonDays.has(d.dateStr),
                    'pc-chip-past':     new Date(d.dateStr) < today && !d.beforeJoin,
                    'pc-chip-before-join': d.beforeJoin
                  }"
                  :disabled="d.beforeJoin"
                  @click="togglePaid(d.dateStr)"
                  @contextmenu.prevent="toggleSick(d.dateStr)"
                  :title="d.beforeJoin ? 'O\'quvchi hali qo\'shilmagan' : (selectedLessonDays.has(d.dateStr) ? 'To\'lov (o\'ng tugma: Kasal)' : 'Kasal (o\'ng tugma)')"
                >
                  <span
                    class="pc-sick-label clickable"
                    :class="{ 'active': sickLessonDays.has(d.dateStr) }"
                    @click.stop="toggleSick(d.dateStr)"
                  >⚕</span>
                  {{ d.day }}
                  <span class="pc-day-dow">{{ d.dow }}</span>
                </button>
              </div>
              <div class="pc-select-actions">
                <div class="pc-main-actions">
                  <button class="pc-sel-btn" @click="selectedLessonDays = new Set(allDaysInPayMonth.filter(d => !d.beforeJoin).map(d => d.dateStr)); sickLessonDays = new Set()">Barchasini tanlash</button>
                  <button class="pc-sel-btn" @click="selectedLessonDays = new Set(allDaysInPayMonth.filter(d => d.isLesson && !d.beforeJoin).map(d => d.dateStr)); sickLessonDays = new Set()">Dars kunlari</button>
                  <button class="pc-sel-btn" @click="selectedLessonDays = new Set(); sickLessonDays = new Set()">Tozalash</button>
                  <button class="pc-sel-btn" @click="selectedLessonDays = new Set(allDaysInPayMonth.filter(d => [2,4,6].includes(new Date(d.dateStr + 'T00:00:00').getDay())).map(d => d.dateStr)); sickLessonDays = new Set()">Se | Pa | Sh</button>
                  <button class="pc-sel-btn" @click="selectedLessonDays = new Set(allDaysInPayMonth.filter(d => [1,3,5].includes(new Date(d.dateStr + 'T00:00:00').getDay())).map(d => d.dateStr)); sickLessonDays = new Set()">Du | Ch | Ju</button>
                </div>
                <!-- Sick days toggle -->
                <div class="pc-sick-toggle">
                  <label class="toggle-cb">
                    <input type="checkbox" v-model="countSickDays">
                    <span class="cb-label">⚕ Kasal kunlarini hisoblash</span>
                  </label>
                </div>
              </div>
            </template>

            <!-- Summary & Save -->
            <div class="pay-summary">
              <div class="pay-summary-calc">
                <span>{{ daysForPayment.length }} kun × {{ formatCurrency(pricePerLesson) }}</span>
                <span v-if="discount > 0"> − {{ formatCurrency(discountAmount) }}</span>
                <span class="pay-summary-eq"> = 
                  <div class="pay-edit-wrap">
                    <span class="pay-edit-currency">UZS</span>
                    <input type="number" v-model.number="payAmountOverride" class="pay-edit-input" />
                  </div>
                </span>
              </div>
              <div class="pay-form-row">
                <div class="pay-comment-wrap">
                  <input v-model="payComment" class="pay-comment-input" :placeholder="$t('students.comment') + '...'" />
                </div>
                <select v-model="payMethod" class="pay-method-select">
                  <option value="Cash">Naqd pul</option>
                  <option value="Card">Karta</option>
                  <option value="Transfer">O'tkazma</option>
                </select>
                <button
                  class="btn-pay-save"
                  :disabled="!calcPayAmount || !daysForPayment.length || isSavingPayment"
                  @click="savePayment"
                >
                  <Loader2 v-if="isSavingPayment" :size="16" class="spin" />
                  <CreditCard v-else :size="16" />
                  To'lov saqlash
                </button>
              </div>
            </div>
          </div>

          <!-- ═══ ATTENDANCE SECTION ═══ -->
          <div class="att-section card">
            <!-- Header -->
            <div class="section-header">
              <div class="title-row">
                <CalendarDays :size="20" class="att-icon-color" />
                <h3>Davomat</h3>
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
                    day !== null && attMap[dateKey(day)] ? 'att-day-filled' : ''
                  ]"
                  :style="day !== null && attMap[dateKey(day)] ? {
                    background: getStatusMeta(attMap[dateKey(day)])?.bg,
                    color: getStatusMeta(attMap[dateKey(day)])?.color,
                    borderColor: getStatusMeta(attMap[dateKey(day)])?.color + '44'
                  } : {}"
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
              <div v-if="recentRecords.length > 0" class="att-records">
                <div class="att-records-title">So'nggi yozuvlar</div>
                <div class="att-record" v-for="r in recentRecords" :key="r.date">
                  <div class="att-record-date">{{ r.date }}</div>
                  <div class="att-record-badge"
                    :style="{ background: getStatusMeta(r.status)?.bg, color: getStatusMeta(r.status)?.color }">
                    {{ getStatusMeta(r.status)?.short }} {{ getStatusMeta(r.status)?.label }}
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
  </div>
</template>

<style scoped>
.student-details-page {
  padding: 2rem;
  background: #f8fafc;
  min-height: 100vh;
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
  padding: 2rem;
  background: white;
  margin-bottom: 2rem;
  border-radius: 24px;
  box-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.05);
}

.profile-main {
  display: flex;
  align-items: center;
  gap: 2rem;
}

.avatar-container {
  position: relative;
}

.profile-avatar {
  width: 120px;
  height: 120px;
  border-radius: 30px;
  object-fit: cover;
  border: 4px solid #f1f5f9;
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

.profile-info h1 {
  font-size: 2rem;
  font-weight: 800;
  color: #1e293b;
  margin-bottom: 0.25rem;
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
  gap: 1.5rem;
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
  grid-template-columns: 350px 1fr;
  gap: 2rem;
}

@media (max-width: 1024px) {
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
  gap: 5px;
  margin-bottom: 1.5rem;
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
.att-records { border-top: 1px solid #F1F5F9; padding-top: 1rem; }
.att-records-title {
  font-size: .72rem;
  font-weight: 800;
  color: #94a3b8;
  text-transform: uppercase;
  letter-spacing: .5px;
  margin-bottom: .75rem;
}
.att-record {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: .45rem 0;
  border-bottom: 1px solid #F8FAFC;
}
.att-record-date { font-size: .83rem; font-weight: 600; color: #475569; }
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
</style>
