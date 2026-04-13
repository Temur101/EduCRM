<script setup>
import { ref, onMounted, computed, watch, reactive } from 'vue';
import { 
  X, 
  ChevronLeft, 
  ChevronRight, 
  CreditCard, 
  Handshake, 
  Users, 
  Calendar, 
  Loader2, 
  Search,
  CheckCircle,
  AlertCircle,
  Mail,
  Eye
} from 'lucide-vue-next';
import { supabase } from '../supabase.js';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  show: Boolean,
  initialStudentId: {
    type: String,
    default: null
  },
  initialStudentName: {
    type: String,
    default: ''
  },
  initialGroupId: {
    type: String,
    default: null
  },
  month_override: {
    type: Number,
    default: null
  },
  year_override: {
    type: Number,
    default: null
  }
});

const emit = defineEmits(['close', 'success']);
const { t } = useI18n();

// --- Constants ---
const MONTH_NAMES = [
  'Yanvar','Fevral','Mart','Aprel','May','Iyun',
  'Iyul','Avgust','Sentabr','Oktabr','Noyabr','Dekabr'
];
const DOW_SHORT = ['Ya','Du','Se','Ch','Pa','Ju','Sh'];
const DAY_INDEX = { 'Du':1,'Se':2,'Ch':3,'Pa':4,'Ju':5,'Sh':6,'Ya':0 };

// --- State ---
const studentId = ref(props.initialStudentId);
const student = ref(null);
const group = ref(null);
const isLoading = ref(false);
const isSavingPayment = ref(false);
const isSavingPromise = ref(false);
const showSuccessScreen = ref(false);
const saveError = ref(null);

const students = ref([]);
const studentSearchQuery = ref(props.initialStudentName);
const showStudentSearchList = ref(false);

const payMode = ref('pay'); // 'pay' | 'promise'
const payYear = ref(new Date().getFullYear());
const payMonth = ref(new Date().getMonth());
const paidDatesFromPayments = ref(new Set());
const promisedDatesFromReminders = ref(new Set());
const selectedLessonDays = ref(new Set());
const sickLessonDays = ref(new Set());
const countSickDays = ref(false);
const payAmountOverride = ref(0);
const payComment = ref('');
const payMethod = ref('Cash');
const quickPromiseDate = ref('');
const quickPromiseNotes = ref('');

const payMonthAttMap = ref({});
const isLoadingPayAtt = ref(false);
const useActualAttendanceForPast = ref(true);

// --- Initialization ---
const initQuickPromiseDate = () => {
  const tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  quickPromiseDate.value = tomorrow.toISOString().split('T')[0];
};

const formatCurrency = (val) => {
  return new Intl.NumberFormat('uz-UZ', { style: 'currency', currency: 'UZS', maximumFractionDigits: 0 }).format(val);
};

// --- Watchers ---
watch(() => props.show, (newVal) => {
  if (newVal) {
    showSuccessScreen.value = false;
    saveError.value = null;
    
    // Apply overrides if provided
    if (props.month_override !== null) payMonth.value = props.month_override;
    else payMonth.value = new Date().getMonth();
    
    if (props.year_override !== null) payYear.value = props.year_override;
    else payYear.value = new Date().getFullYear();

    if (props.initialStudentId) {
      if (studentId.value !== props.initialStudentId) {
        studentId.value = props.initialStudentId;
      } else {
        loadStudentData();
      }
    } else {
      studentId.value = null;
      loadStudents();
    }
    studentSearchQuery.value = props.initialStudentName;
  }
});

watch(studentId, (newVal) => {
  if (newVal) {
    loadStudentData();
  } else {
    student.value = null;
    group.value = null;
  }
});

// --- Data Loading ---
const loadStudents = async () => {
  const { data } = await supabase.from('students').select('id, name').order('name');
  students.value = data || [];
};

const loadStudentData = async () => {
  if (!studentId.value || isLoading.value) return;
  isLoading.value = true;
  try {
    const { data, error } = await supabase
      .from('students')
      .select('*, groups(*, courses(*))')
      .eq('id', studentId.value)
      .single();
    if (error) throw error;
    student.value = data;
    group.value = data.groups;
    selectedLessonDays.value = new Set();
    sickLessonDays.value = new Set();
    
    // Load secondary data in parallel or catch internally to not block UI
    loadPayMonthAttendance().catch(err => console.error("Secondary load failed:", err));
    
  } catch (e) {
    console.error('Error loading student data:', e);
  } finally {
    isLoading.value = false;
  }
};

const loadPayMonthAttendance = async () => {
  if (!studentId.value || !student.value) return;
  isLoadingPayAtt.value = true;
  try {
    const y = payYear.value;
    const m = payMonth.value;
    const monthName = MONTH_NAMES[m] + ' ' + y;
    const start = `${y}-${String(m+1).padStart(2,'0')}-01`;
    const end   = `${y}-${String(m+1).padStart(2,'0')}-${String(new Date(y,m+1,0).getDate()).padStart(2,'0')}`;

    // 1. Fetch attendance
    const { data: attData } = await supabase
      .from('attendance')
      .select('lesson_date,status')
      .eq('student_id', studentId.value)
      .gte('lesson_date', start)
      .lte('lesson_date', end);

    const map = {};
    (attData||[]).forEach(r => { map[r.lesson_date] = r.status; });
    payMonthAttMap.value = map;

    // 2. Fetch payments
    const { data: payData } = await supabase
      .from('payments')
      .select('comment')
      .eq('student_id', studentId.value)
      .eq('month', monthName);

    // 3. Check for existing reminders (promises) for this month
    const promisedSet = new Set();
    try {
      const { data: existingReminders, error: remErr } = await supabase
        .from('payment_reminders')
        .select('notes')
        .eq('student_id', studentId.value)
        .neq('status', 'Cancelled');

      if (!remErr && existingReminders) {
        existingReminders.forEach(r => {
          if (r.notes && r.notes.includes('[DAYS:')) {
            const match = r.notes.match(/\[DAYS:([^\]]+)\]/);
            if (match && match[1]) {
              match[1].split(',').forEach(d => promisedSet.add(d.trim()));
            }
          }
        });
      }
    } catch (e) {
      console.warn("Reminder day collection fallback", e);
    }
    promisedDatesFromReminders.value = promisedSet;

    const paidSet = new Set();
    (payData || []).forEach(p => {
      if (p.comment && p.comment.includes('[DAYS:')) {
        const match = p.comment.match(/\[DAYS:([^\]]+)\]/);
        if (match && match[1]) {
          match[1].split(',').forEach(d => paidSet.add(d.trim()));
        }
      }
    });
    paidDatesFromPayments.value = paidSet;

  } catch (e) {
    console.warn('Silent failure on month data:', e);
  } finally {
    isLoadingPayAtt.value = false;
  }
};

// --- Computed ---
const filteredStudentsList = computed(() => {
  if (!studentSearchQuery.value) return students.value;
  return students.value.filter(s => s.name.toLowerCase().includes(studentSearchQuery.value.toLowerCase()));
});

const groupDayIndexes = computed(() => {
  const days = group.value?.days || '';
  return days.split('-').map(d => DAY_INDEX[d.trim().substring(0,2)]).filter(d => d !== undefined);
});

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
      dow: DOW_SHORT[date.getDay()], 
      isLesson,
      beforeJoin 
    });
  }
  return result;
});

const lessonDaysOnly = computed(() => allDaysInPayMonth.value.filter(d => d.isLesson).map(d => d.dateStr));

const coursePrice = computed(() => group.value?.courses?.price || 0);

const pricePerLesson = computed(() => {
  const total = lessonDaysOnly.value.length;
  if (!total || !coursePrice.value) return 0;
  return Math.round(coursePrice.value / total);
});

const isPastMonth = computed(() => {
  const now = new Date();
  return (payYear.value < now.getFullYear()) ||
    (payYear.value === now.getFullYear() && payMonth.value < now.getMonth());
});

const isPayMonthFinished = computed(() => {
  if (!useActualAttendanceForPast.value) return false;
  return isPastMonth.value;
});

const alreadyPaidDaysFromDB = computed(() => {
  return Array.from(paidDatesFromPayments.value);
});

const alreadyPromisedDaysFromDB = computed(() => {
  return Array.from(promisedDatesFromReminders.value);
});

const attendedLessonDays = computed(() => {
  if (!isPayMonthFinished.value) return [];
  return allDaysInPayMonth.value
    .filter(d => { 
      if (d.beforeJoin) return false;
      const st = payMonthAttMap.value[d.dateStr]; 
      // Only include days NOT already paid
      if (st?.status === 'paid' || st?.is_paid) return false;
      return st === 'present' || st === 'late' || (st && typeof st === 'object' && (st.status === 'present' || st.status === 'late')); 
    })
    .map(d => d.dateStr);
});

const daysForPayment = computed(() => {
  if (isPayMonthFinished.value) return attendedLessonDays.value;
  return allDaysInPayMonth.value
    .filter(d => {
      if (d.beforeJoin) return false;
      const isPaid = selectedLessonDays.value.has(d.dateStr);
      const isSick = sickLessonDays.value.has(d.dateStr);
      return isPaid || (isSick && countSickDays.value);
    })
    .map(d => d.dateStr);
});

const discount = computed(() => student.value?.discount || 0);

const calcPayAmount = computed(() => {
  const base = daysForPayment.value.length * pricePerLesson.value;
  return Math.max(0, base - discount.value);
});

watch(calcPayAmount, (newVal) => {
  payAmountOverride.value = newVal;
}, { immediate: true });

// --- Actions ---
const selectStudent = (s) => {
  studentId.value = s.id;
  studentSearchQuery.value = s.name;
  showStudentSearchList.value = false;
};

const prevMonth = async () => {
  if (payMonth.value === 0) { payMonth.value = 11; payYear.value--; }
  else payMonth.value--;
  selectedLessonDays.value = new Set();
  await loadPayMonthAttendance();
};

const nextMonth = async () => {
  if (payMonth.value === 11) { payMonth.value = 0; payYear.value++; }
  else payMonth.value++;
  selectedLessonDays.value = new Set();
  await loadPayMonthAttendance();
};

const togglePaid = (dateStr) => {
  const sel = new Set(selectedLessonDays.value);
  const sck = new Set(sickLessonDays.value);
  if (sel.has(dateStr)) sel.delete(dateStr);
  else { sel.add(dateStr); sck.delete(dateStr); }
  selectedLessonDays.value = sel;
  sickLessonDays.value = sck;
};

const toggleSick = (dateStr) => {
  const sel = new Set(selectedLessonDays.value);
  const sck = new Set(sickLessonDays.value);
  if (sck.has(dateStr)) sck.delete(dateStr);
  else { sck.add(dateStr); sel.delete(dateStr); }
  selectedLessonDays.value = sel;
  sickLessonDays.value = sck;
};

const selectAllDays = () => {
  selectedLessonDays.value = new Set(
    allDaysInPayMonth.value
      .filter(d => !d.beforeJoin && !alreadyPaidDaysFromDB.value.includes(d.dateStr) && !alreadyPromisedDaysFromDB.value.includes(d.dateStr))
      .map(d => d.dateStr)
  );
  sickLessonDays.value = new Set();
};

const selectLessonDays = () => {
  selectedLessonDays.value = new Set(
    allDaysInPayMonth.value
      .filter(d => d.isLesson && !d.beforeJoin && !alreadyPaidDaysFromDB.value.includes(d.dateStr) && !alreadyPromisedDaysFromDB.value.includes(d.dateStr))
      .map(d => d.dateStr)
  );
  sickLessonDays.value = new Set();
};

const clearSelection = () => {
  selectedLessonDays.value = new Set();
  sickLessonDays.value = new Set();
};

const savePayment = async () => {
  if (!payAmountOverride.value || !daysForPayment.value.length || isSavingPayment.value) return;
  isSavingPayment.value = true;
  try {
    const receiptId = 'PAY-' + Math.floor(Math.random() * 90000 + 10000);
    
    // Create a tag with selected dates to store in comment
    const daysTag = ` [DAYS:${daysForPayment.value.join(',')}]`;
    const finalComment = (payComment.value || '').trim() + daysTag;

    const { error } = await supabase.from('payments').insert([{
      student: student.value.name.trim(),
      student_id: studentId.value,
      course: group.value?.courses?.name || '',
      amount: payAmountOverride.value,
      method: payMethod.value,
      date: new Date().toISOString().slice(0,10),
      status: 'Success',
      receipt_id: receiptId,
      comment: finalComment,
      month: MONTH_NAMES[payMonth.value] + ' ' + payYear.value,
      id: crypto.randomUUID()
    }]);
    if (error) throw error;
    showSuccessScreen.value = true;
    emit('success');
    setTimeout(() => {
      if (showSuccessScreen.value) close();
    }, 2000);
  } catch (e) {
    console.error(e);
    saveError.value = e.message;
  } finally {
    isSavingPayment.value = false;
  }
};

const savePromise = async () => {
  if (!quickPromiseDate.value || isSavingPromise.value || !daysForPayment.value.length) return;
  isSavingPromise.value = true;
  saveError.value = null;
  try {
    const payload = {
      student_id: studentId.value,
      group_id: group.value?.id || null,
      promised_date: quickPromiseDate.value,
      amount: payAmountOverride.value || 0,
      notes: (quickPromiseNotes.value || '') + ` [M:${MONTH_NAMES[payMonth.value] + ' ' + payYear.value}] [DAYS:${daysForPayment.value.join(',')}]`,
      status: 'Pending',
      id: crypto.randomUUID()
    };

    const { error } = await supabase.from('payment_reminders').insert([payload]);
    if (error) throw error;
    showSuccessScreen.value = true;
    emit('success');
    setTimeout(() => {
      if (showSuccessScreen.value) close();
    }, 2000);
  } catch (e) {
    console.error(e);
    saveError.value = e.message;
  } finally {
    isSavingPromise.value = false;
  }
};

const onPaymentSuccess = () => {
  loadData();
  // Alert removed, modal handles it or it's silent
};

const close = () => {
  emit('close');
};

onMounted(() => {
  initQuickPromiseDate();
});
</script>

<template>
  <transition name="modal">
    <div v-if="show" class="modal-overlay" @click.self="close">
      <div class="modal-box payment-modal">
        <div class="modal-header">
          <div class="header-title">
            <div class="modal-icon"><CreditCard :size="22" /></div>
            <h2>{{ $t('students.payNow') }}</h2>
          </div>
          <button class="btn-icon" @click="close"><X :size="20" /></button>
        </div>

        <div class="modal-body">
          <!-- Success Screen -->
          <div v-if="showSuccessScreen" class="success-screen">
            <div class="success-anim">
              <CheckCircle :size="64" />
            </div>
            <h3>{{ $t('payments.success') }}</h3>
            <p>{{ $t('common.save') }}...</p>
          </div>

          <!-- Error Message -->
          <div v-if="saveError" class="save-error-msg">
            <AlertCircle :size="18" />
            <span>{{ saveError }}</span>
          </div>

          <!-- Student Selector (only if not pre-selected) -->
          <div v-if="!props.initialStudentId && !showSuccessScreen" class="student-select-section">
            <label class="field-label">{{ $t('reminders.student') }} ({{ $t('common.all') }})</label>
            <div class="search-container">
              <div class="search-input-wrap">
                <Search class="search-icon" :size="18" />
                <input 
                  v-model="studentSearchQuery" 
                  :placeholder="$t('reminders.searchPlaceholder')"
                  @focus="showStudentSearchList = true"
                />
              </div>
              <div v-if="showStudentSearchList" class="search-dropdown">
                <div v-if="filteredStudentsList.length === 0" class="search-empty">
                  {{ $t('common.noData') }}
                </div>
                <div 
                  v-for="s in filteredStudentsList" 
                  :key="s.id" 
                  class="search-item"
                  @click="selectStudent(s)"
                >
                  <div class="std-avatar">{{ s.name.charAt(0) }}</div>
                  <div class="std-info">
                    <span class="std-name">{{ s.name }}</span>
                    <span class="std-phone text-xs opacity-60">{{ s.phone || '-' }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div v-if="isLoading && !showSuccessScreen" class="modal-loading">
            <Loader2 class="spin" :size="32" />
            <p>{{ $t('common.loading') }}</p>
          </div>

          <template v-else-if="studentId && student">
            <!-- Group Info Mini -->
            <div class="student-mini-info" v-if="group">
              <div class="info-item">
                <Users :size="14" />
                <span>{{ group.name }}</span>
              </div>
              <div class="info-item">
                <Calendar :size="14" />
                <span>{{ $t('students.addedDate') }}: {{ new Date(student.created_at).toLocaleDateString() }}</span>
              </div>
            </div>

            <!-- Month Navigator -->
            <div class="month-nav-bar">
              <button class="nav-btn" @click="prevMonth"><ChevronLeft :size="18" /></button>
              <span class="month-label">{{ MONTH_NAMES[payMonth] }} {{ payYear }}</span>
              <button class="nav-btn" @click="nextMonth"><ChevronRight :size="18" /></button>
            </div>

            <!-- Day Grid -->
            <div class="day-picker-section">
              <div v-if="isPayMonthFinished" class="finished-note">
                <CheckCircle :size="14" />
                <span>{{ $t('attendance.monthFinishedNote') || "Oy tugagan — davomatga ko'ra" }}</span>
                <button class="text-btn" @click="useActualAttendanceForPast = !useActualAttendanceForPast">
                   {{ useActualAttendanceForPast ? $t('attendance.manualEntry') || "Qo'lda" : $t('attendance.byAtt') || "Davomat" }}
                </button>
              </div>
              <div v-else class="manual-note">
                <AlertCircle :size="14" />
                <span>{{ $t('attendance.manualSelectNote') || "Keladigan kunlarni tanlang" }}</span>
              </div>

              <div class="pc-day-grid">
                <button
                  v-for="d in allDaysInPayMonth" :key="d.dateStr"
                  class="pc-day-chip"
                  :class="{
                    'pc-chip-selected': (selectedLessonDays.has(d.dateStr) || (isPayMonthFinished && attendedLessonDays.includes(d.dateStr))) && !d.beforeJoin,
                    'pc-chip-sick':     sickLessonDays.has(d.dateStr) && !d.beforeJoin,
                    'pc-chip-lesson':   d.isLesson && !d.beforeJoin && !selectedLessonDays.has(d.dateStr) && !sickLessonDays.has(d.dateStr),
                    'pc-chip-before-join': d.beforeJoin,
                    'pc-chip-already-paid': alreadyPaidDaysFromDB.includes(d.dateStr),
                    'pc-chip-already-promised': alreadyPromisedDaysFromDB.includes(d.dateStr)
                  }"
                  :disabled="d.beforeJoin || isPayMonthFinished || alreadyPaidDaysFromDB.includes(d.dateStr) || alreadyPromisedDaysFromDB.includes(d.dateStr)"
                  @click="togglePaid(d.dateStr)"
                >
                  <span class="day-num">{{ d.day }}</span>
                  <span class="day-dow">{{ d.dow }}</span>
                </button>
              </div>
              
              <div class="pc-select-actions">
                <button class="pc-sel-btn" @click="selectAllDays">{{ $t('common.all') || 'Hammasi' }}</button>
                <button class="pc-sel-btn" @click="selectLessonDays">{{ $t('students.lessonDays') || 'Dars kunlari' }}</button>
                <button class="pc-sel-btn btn-clear" @click="clearSelection">{{ $t('common.clear') || 'Tozalash' }}</button>
              </div>
            </div>

            <!-- Summary Table -->
            <div class="calc-summary">
              <div class="summary-row">
                <span>{{ daysForPayment.length }} kun × {{ formatCurrency(pricePerLesson) }}</span>
                <span v-if="discount > 0" class="discount-text">− {{ formatCurrency(discount) }}</span>
                <div class="final-amount">
                  <span class="currency">UZS</span>
                  <input type="number" v-model.number="payAmountOverride" class="amount-input" />
                </div>
              </div>
            </div>

            <!-- Mode Toggle -->
            <div class="pay-mode-tabs">
              <button :class="{ active: payMode === 'pay' }" @click="payMode = 'pay'">
                <CreditCard :size="14" /> {{ $t('students.payNow') }}
              </button>
              <button :class="{ active: payMode === 'promise' }" @click="payMode = 'promise'">
                <Handshake :size="14" /> {{ $t('students.makePromise') }}
              </button>
            </div>

            <!-- Reminder Warning -->
            <div v-if="payMode === 'promise'" class="reminder-multi-note">
               <AlertCircle :size="16" />
               <span>Siz faqat bo'sh kunlar uchun eslatma yaratishingiz mumkin. Allaqachon band qilingan kunlar bloklangan.</span>
            </div>

            <!-- Forms -->
            <div class="modal-form-area">
              <div v-if="payMode === 'pay'" class="pay-form">
                <div class="form-row">
                  <div class="form-group">
                    <label>{{ $t('students.method') }}</label>
                    <select v-model="payMethod">
                      <option value="Cash">{{ $t('payments.methodCash') }}</option>
                      <option value="Card">{{ $t('payments.methodCard') }}</option>
                      <option value="Transfer">{{ $t('payments.methodTransfer') }}</option>
                    </select>
                  </div>
                  <div class="form-group main">
                    <label>{{ $t('students.comment') }}</label>
                    <input v-model="payComment" :placeholder="$t('students.comment') + '...'" />
                  </div>
                </div>
              </div>

              <div v-else class="promise-form">
                <div class="form-row">
                  <div class="form-group">
                    <label>{{ $t('students.promiseDate') }}</label>
                    <input type="date" v-model="quickPromiseDate" />
                  </div>
                  <div class="form-group main">
                    <label>{{ $t('students.comment') }}</label>
                    <input v-model="quickPromiseNotes" :placeholder="$t('students.promiseNote') + '...'" />
                  </div>
                </div>
              </div>
            </div>
          </template>

          <div v-else-if="!studentId" class="empty-selection">
            <Users :size="48" />
            <p>{{ $t('reminders.searchPlaceholder') }}</p>
          </div>
        </div>

        <div class="modal-footer">
          <button class="btn-secondary" @click="close">{{ $t('common.cancel') }}</button>
          <button 
            v-if="payMode === 'pay'"
            class="btn-primary" 
            :disabled="!studentId || isSavingPayment || !daysForPayment.length" 
            @click="savePayment"
          >
            <Loader2 v-if="isSavingPayment" class="spin" :size="18" />
            <span v-else>{{ $t('common.save') }}</span>
          </button>
          <button 
            v-else
            class="btn-primary" 
            :disabled="!studentId || isSavingPromise || !quickPromiseDate" 
            @click="savePromise"
          >
            <Loader2 v-if="isSavingPromise" class="spin" :size="18" />
            <span v-else>{{ $t('students.promiseSave') }}</span>
          </button>
        </div>
      </div>
    </div>
  </transition>
</template>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0,0,0,0.5);
  backdrop-filter: blur(4px);
  display: flex; align-items: center; justify-content: center;
  z-index: 10000;
}

.payment-modal {
  width: 100%;
  max-width: 650px;
  max-height: 90vh;
  overflow-y: auto;
  background: white;
  border-radius: 24px;
  box-shadow: 0 20px 60px rgba(0,0,0,0.2);
}

.modal-header {
  padding: 1.5rem;
  border-bottom: 1px solid #F1F5F9;
  display: flex; justify-content: space-between; align-items: center;
}

.header-title { display: flex; align-items: center; gap: 1rem; }
.modal-icon {
  width: 40px; height: 40px;
  background: #EEF2FF; color: var(--primary);
  border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
}
.header-title h2 { font-size: 1.25rem; font-weight: 800; color: #1E293B; }

.modal-body { padding: 1.5rem; }

/* Student Select */
.student-select-section { margin-bottom: 1.5rem; }
.field-label { display: block; font-size: 0.85rem; font-weight: 700; color: #64748B; margin-bottom: 0.5rem; }
.search-container { position: relative; }
.search-input-wrap { position: relative; }
.search-icon { position: absolute; left: 1rem; top: 50%; transform: translateY(-50%); color: #94A3B8; }
.search-input-wrap input {
  padding-left: 2.75rem;
}

.search-dropdown {
  position: absolute; top: 100%; left: 0; right: 0;
  background: white; border: 1px solid #E2E8F0;
  border-radius: 12px; margin-top: 4px; z-index: 10;
  max-height: 200px; overflow-y: auto;
  box-shadow: 0 10px 25px rgba(0,0,0,0.1);
}
.search-item {
  padding: 0.75rem 1rem; cursor: pointer; font-weight: 500;
  display: flex; align-items: center; gap: 0.75rem;
}
.search-item:hover { background: #F8FAFC; color: var(--primary); }
.std-avatar {
  width: 32px; height: 32px; background: #EEF2FF; color: var(--primary);
  border-radius: 50%; display: flex; align-items: center; justify-content: center;
  font-weight: 800; font-size: 0.8rem;
}
.std-info { display: flex; flex-direction: column; }
.std-name { font-size: 0.9rem; }
.search-empty { padding: 2rem; text-align: center; color: #94A3B8; font-size: 0.85rem; }

.success-screen {
  padding: 3rem 0; text-align: center;
  display: flex; flex-direction: column; align-items: center; gap: 1rem;
}
.success-anim {
  width: 100px; height: 100px; background: #ECFDF5; color: #10B981;
  border-radius: 50%; display: flex; align-items: center; justify-content: center;
  animation: scaleIn 0.5s ease-out;
}
.success-screen h3 { font-size: 1.5rem; font-weight: 800; color: #1E293B; }
.success-screen p { color: #64748B; }

@keyframes scaleIn {
  from { transform: scale(0); opacity: 0; }
  to { transform: scale(1); opacity: 1; }
}

.save-error-msg {
  background: #FEF2F2; color: #EF4444; padding: 0.75rem 1rem;
  border-radius: 12px; margin-bottom: 1rem; font-size: 0.85rem;
  display: flex; align-items: center; gap: 0.5rem;
  border: 1px solid #FCA5A5;
}

.student-mini-info {
  display: flex; gap: 1rem; margin-bottom: 1rem;
  padding: 0.75rem; background: #F8FAFC; border-radius: 12px;
}
.info-item { display: flex; align-items: center; gap: 0.5rem; color: #64748B; font-size: 0.85rem; }

/* Month Nav */
.month-nav-bar {
  display: flex; align-items: center; justify-content: center; gap: 1.5rem;
  margin-bottom: 1rem;
}
.nav-btn {
  width: 32px; height: 32px; border-radius: 8px;
  background: #F1F5F9; color: #475569;
  display: flex; align-items: center; justify-content: center;
}
.month-label { font-weight: 800; color: #1E293B; min-width: 120px; text-align: center; }

/* Day Picker */
.day-picker-section { margin-bottom: 1.5rem; }
.finished-note, .manual-note {
  display: flex; align-items: center; gap: 0.5rem;
  padding: 0.6rem 1rem; border-radius: 10px; font-size: 0.8rem; font-weight: 600;
  margin-bottom: 0.75rem;
}
.finished-note { background: #ECFDF5; color: #065F46; }
.manual-note { background: #FEF3C7; color: #92400E; }
.text-btn { margin-left: auto; background: white; padding: 2px 8px; border-radius: 6px; border: 1px solid currentColor; font-size: 0.7rem; }

.pc-select-actions {
  display: flex; gap: 0.5rem; margin-top: 1rem;
}
.pc-sel-btn {
  padding: 0.4rem 0.8rem; border-radius: 8px; background: #F1F5F9;
  font-size: 0.75rem; font-weight: 700; color: #475569;
}
.pc-sel-btn:hover { background: #E2E8F0; }
.pc-sel-btn.btn-clear { color: #EF4444; background: #FEF2F2; }
.pc-sel-btn.btn-clear:hover { background: #FEE2E2; }

.pc-day-grid {
  display: grid; grid-template-columns: repeat(7, 1fr); gap: 6px;
}
.pc-day-chip {
  aspect-ratio: 1; border-radius: 10px; border: 1.5px solid #F1F5F9;
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  transition: all 0.2s; background: white;
}
.day-num { font-weight: 700; font-size: 0.9rem; }
.day-dow { font-size: 0.65rem; color: #94A3B8; font-weight: 600; }

.pc-chip-lesson { border-color: #E2E8F0; background: #F8FAFC; color: #64748B; }
.pc-chip-selected { background: var(--primary); color: white; border-color: var(--primary); }
.pc-chip-sick { background: #FEF3C7; color: #D97706; border-color: #FCD34D; }
.pc-chip-before-join { opacity: 0.3; pointer-events: none; background: #F1F5F9; }

/* Summary */
.calc-summary {
  background: #F8FAFC; padding: 1rem; border-radius: 16px; margin-bottom: 1.5rem;
}
.summary-row {
  display: flex; align-items: center; justify-content: space-between;
  font-weight: 700; color: #475569;
}
.discount-text { color: #EF4444; }
.final-amount { display: flex; align-items: center; gap: 0.5rem; color: #10B981; }
.amount-input {
  width: 140px; padding: 0.5rem; border: 2px solid #10B981; border-radius: 8px;
  background: white; color: #10B981; font-weight: 800; font-size: 1.1rem; text-align: right;
}

/* Tabs */
.pay-mode-tabs {
  display: flex; background: #F1F5F9; border-radius: 12px; padding: 4px; margin-bottom: 1.25rem;
}
.pay-mode-tabs button {
  flex: 1; padding: 0.6rem; border-radius: 10px;
  display: flex; align-items: center; justify-content: center; gap: 0.5rem;
  font-weight: 700; color: #64748B; font-size: 0.9rem;
}
.pay-mode-tabs button.active { background: white; color: var(--primary); box-shadow: 0 2px 8px rgba(0,0,0,0.05); }

/* Forms */
.form-row { display: flex; gap: 1rem; }
.form-group { flex: 1; }
.form-group.main { flex: 2; }
.form-group label { display: block; font-size: 0.75rem; font-weight: 800; color: #94A3B8; margin-bottom: 4px; text-transform: uppercase; }
input, select {
  width: 100%; padding: 0.75rem 1rem; border: 1.5px solid #E2E8F0; border-radius: 12px;
  background: #F8FAFC; outline: none; transition: all 0.2s;
}
input:focus, select:focus { border-color: var(--primary); background: white; }

.modal-footer {
  padding: 1.5rem; border-top: 1px solid #F1F5F9;
  display: flex; justify-content: flex-end; gap: 1rem;
}
.btn-secondary { padding: 0.75rem 1.5rem; font-weight: 600; color: #64748B; }
.btn-primary {
  padding: 0.75rem 2rem; border-radius: 12px;
  background: var(--primary); color: white; font-weight: 700;
  display: flex; align-items: center; gap: 0.5rem;
}
.btn-primary:disabled { opacity: 0.5; cursor: not-allowed; }

.empty-selection {
  padding: 3rem 0; text-align: center; color: #94A3B8;
}
.empty-selection p { margin-top: 1rem; font-weight: 600; }

.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }

.modal-enter-active, .modal-leave-active { transition: opacity 0.3s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.pc-chip-paid-lock {
  background: #F1F5F9 !important;
  color: #94A3B8 !important;
  border-color: #E2E8F0 !important;
  cursor: not-allowed !important;
  opacity: 0.7;
}
.pc-chip-paid-lock::after {
  content: '✓';
  position: absolute;
  bottom: 2px;
  right: 2px;
  font-size: 10px;
  color: #10B981;
}
.pc-chip-already-paid {
  background: #F1F5F9 !important;
  color: #94A3B8 !important;
  border-color: #E2E8F0 !important;
  cursor: not-allowed !important;
  opacity: 0.6;
  position: relative;
}
.pc-chip-already-paid::after {
  content: '✓';
  position: absolute;
  top: 2px;
  right: 2px;
  font-size: 10px;
  color: #10B981;
  font-weight: 900;
}
.pc-chip-already-promised {
  background: #EEF2FF !important;
  color: #6366F1 !important;
  border-color: #C7D2FE !important;
  cursor: not-allowed !important;
  opacity: 0.8;
  position: relative;
}

.pc-chip-already-promised::after {
  content: '🤝';
  position: absolute;
  top: -2px;
  right: -2px;
  font-size: 0.6rem;
}

.reminder-multi-note {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem;
  background: var(--primary-light);
  color: var(--primary);
  border-radius: 8px;
  font-size: 0.85rem;
  margin-bottom: 1rem;
  border: 1px solid var(--border);
}
</style>
