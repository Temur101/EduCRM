
<script setup>
import { 
  Plus, X, Loader2, MoreVertical, Trash2, Edit, AlertTriangle,
  ChevronLeft, ChevronRight, Check,
  Users, BookOpen, User, Calendar, Clock, Phone, ArrowRight, CalendarDays
} from 'lucide-vue-next';
import { ref, reactive, onMounted, computed, watch, onUnmounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { supabase } from '../supabase.js';

const route = useRoute();
const router = useRouter();
const groupId = route.params.id;
const userRole = ref(localStorage.getItem('userRole') || 'regular');

const group = ref(null);
const students = ref([]);
const isLoading = ref(true);

// Group management state
const showGroupOptions = ref(false);
const showGroupEditModal = ref(false);
const showDeleteConfirm = ref(false);
const isSubmittingGroup = ref(false);
const deleteOption = ref('moveAnother');
const targetGroupIdForStudents = ref('');
const otherGroups = ref([]);
const courses = ref([]);
const teachers = ref([]);
const groupForm = reactive({
  name: '',
  course_id: '',
  teacher_id: '',
  teacher_ids: [],
  days: 'Du-Chor-Ju',
  time: '09:00',
  status: 'Active'
});

const dayPatterns = [
  { label: 'Du-Chor-Ju', value: 'Du-Chor-Ju' },
  { label: 'Se-Pay-Sha', value: 'Se-Pay-Sha' },
  { label: 'Har kuni', value: 'Har kuni' },
  { label: 'Dam olish kunlari', value: 'Dam olish kunlari' }
];

const loadHelperData = async () => {
  const { data: cData } = await supabase.from('courses').select('id, name');
  courses.value = cData || [];
  const { data: tData } = await supabase.from('teachers').select('id, name').eq('is_deleted', false).eq('status', 'Active');
  teachers.value = tData || [];
};

const loadOtherGroups = async () => {
  try {
    const { data } = await supabase.from('groups').select('id, name').neq('id', groupId).eq('is_deleted', false).eq('status', 'Active');
    otherGroups.value = data || [];
  } catch (e) {
    console.error('Error loading other groups:', e);
  }
};

const openEditGroup = () => {
  if (!group.value) return;
  groupForm.name = group.value.name;
  groupForm.course_id = group.value.course_id;
  groupForm.teacher_id = group.value.teacher_id;
  groupForm.teacher_ids = group.value.teacher_ids || [];
  groupForm.days = group.value.days;
  groupForm.time = group.value.time;
  groupForm.status = group.value.status;
  showGroupEditModal.value = true;
  showGroupOptions.value = false;
  loadHelperData();
};

const updateGroup = async () => {
  if (!groupForm.name || !groupForm.course_id || isSubmittingGroup.value) return;
  isSubmittingGroup.value = true;
  try {
    const { error } = await supabase
      .from('groups')
      .update({
        name: groupForm.name,
        course_id: groupForm.course_id,
        teacher_id: groupForm.teacher_id || (groupForm.teacher_ids?.[0] || null),
        teacher_ids: groupForm.teacher_ids?.length > 0 ? groupForm.teacher_ids : (groupForm.teacher_id ? [groupForm.teacher_id] : []),
        days: groupForm.days,
        time: groupForm.time,
        status: groupForm.status,
        updated_at: new Date().toISOString()
      })
      .eq('id', groupId);
    if (error) throw error;
    await loadGroupData();
    showGroupEditModal.value = false;
  } catch (e) {
    console.error('Error updating group:', e);
    alert('Saqlashda xatolik yuz berdi.');
  } finally {
    isSubmittingGroup.value = false;
  }
};

const confirmDeleteGroup = async () => {
  await loadOtherGroups();
  showDeleteConfirm.value = true;
  showGroupOptions.value = false;
};

const deleteGroupAction = async () => {
  if (isSubmittingGroup.value) return;
  if (deleteOption.value === 'moveAnother' && !targetGroupIdForStudents.value) {
    alert('Please select a target group for transfer.');
    return;
  }

  isSubmittingGroup.value = true;
  try {
    // 1. Handle students based on selected option
    if (deleteOption.value === 'moveAnother') {
      const { error } = await supabase.from('students').update({ group_id: targetGroupIdForStudents.value }).eq('group_id', groupId);
      if (error) throw error;
    } else if (deleteOption.value === 'noGroup') {
      const { error } = await supabase.from('students').update({ group_id: null }).eq('group_id', groupId);
      if (error) throw error;
    } else if (deleteOption.value === 'archiveWith') {
      // SOFT DELETE students
      await supabase
        .from('students')
        .update({ 
          is_deleted: true, 
          deleted_at: new Date().toISOString() 
        })
        .eq('group_id', groupId);
    }

    // 2. SOFT DELETE group
    const { error } = await supabase
      .from('groups')
      .update({ 
        is_deleted: true, 
        deleted_at: new Date().toISOString() 
      })
      .eq('id', groupId);
    if (error) throw error;
    
    router.push('/groups');
  } catch (e) {
    console.error('Error deleting group:', e);
    alert('O\'chirishda xatolik yuz berdi: ' + e.message);
  } finally {
    isSubmittingGroup.value = false;
  }
};

const handleClickOutside = () => { showGroupOptions.value = false; };
onMounted(() => { document.addEventListener('click', handleClickOutside); });
onUnmounted(() => { document.removeEventListener('click', handleClickOutside); });

const groupPayments = ref([]);

const loadGroupData = async () => {
  isLoading.value = true;
  try {
    const { data: groupData, error: groupError } = await supabase
      .from('groups')
      .select('*, courses(name, price)')
      .eq('id', groupId)
      .single();
    if (groupError) throw groupError;

    // Fetch teachers - ensure we fallback to single teacher_id if array is empty
    const tIds = groupData.teacher_ids || [];
    const teacherIds = tIds.length > 0 ? tIds : (groupData.teacher_id ? [groupData.teacher_id] : []);
    
    if (teacherIds.length > 0) {
      const { data: tData } = await supabase
        .from('teachers')
        .select('name')
        .in('id', teacherIds);
      groupData.teacher_names = (tData || []).map(t => t.name);
    } else {
      groupData.teacher_names = [];
    }
    
    group.value = groupData;

    const { data: studentsData, error: studentsError } = await supabase
      .from('students')
      .select('*')
      .eq('group_id', groupId)
      .eq('is_deleted', false)
      .order('name');
    if (studentsError) throw studentsError;
    students.value = studentsData || [];
    
    // Load payments for these students
    await loadGroupPayments();
  } catch (e) {
    console.error('Error loading group details:', e.message);
    router.push('/groups');
  } finally {
    isLoading.value = false;
  }
};

const loadGroupPayments = async () => {
  if (!students.value.length) return;
  const studentNames = students.value.map(s => s.name);
  
  const { data, error } = await supabase
    .from('payments')
    .select('*')
    .in('student', studentNames);
  
  if (!error) groupPayments.value = data || [];
};

const getDebtSummary = (student) => {
  if (!student.created_at) return [];
  const joinDate = new Date(student.created_at);
  const now = new Date();
  const debtList = [];
  
  let curY = joinDate.getFullYear();
  let curM = joinDate.getMonth();
  const endY = now.getFullYear();
  const endM = now.getMonth();

  while (curY < endY || (curY === endY && curM <= endM)) {
    const monthStr = MONTH_NAMES_UZ[curM] + ' ' + curY;
    const price = group.value?.courses?.price || 0;
    let target = Math.max(0, price - (student.discount || 0));
    
    const daysInMonth = new Date(curY, curM+1, 0).getDate();
    let validD = 0; let totalD = 0;
    const copyJoinDate = new Date(student.created_at);
    copyJoinDate.setHours(0,0,0,0);
    
    for (let d = 1; d <= daysInMonth; d++) {
      const dDate = new Date(curY, curM, d);
      dDate.setHours(0,0,0,0);
      if (lessonDayNums.value.includes(dDate.getDay())) {
         totalD++;
         if (dDate >= copyJoinDate) validD++;
      }
    }
    
    if (totalD > 0 && validD < totalD) {
       target = validD * Math.round(target / totalD);
    }
    
    const paid = groupPayments.value
      .filter(p => p.student.trim() === student.name.trim() && (p.month || '').toLowerCase() === monthStr.toLowerCase())
      .reduce((acc, p) => acc + (Number(p.amount) || 0), 0);
    
    if (target > 0 && paid < target - 100) {
      debtList.push(monthStr);
    }
    
    if (curM === 11) { curM = 0; curY++; }
    else curM++;
  }
  return debtList;
};

const getStatusClass = (status) => {
  if (!status) return 'status-pending';
  const s = status.toLowerCase();
  if (s === 'active') return 'status-active';
  if (s === 'pending') return 'status-pending';
  return 'status-finished';
};

const goBack = () => router.back();
const goToStudent = (id) => router.push(`/students/${id}`);

const formatDate = (dateStr) => {
  if (!dateStr) return '-';
  return new Date(dateStr).toLocaleDateString();
};

// ─────────────────────────── Add Student Modal ───────────────────────────
const showModal = ref(false);
const isSubmitting = ref(false);
const studentForm = reactive({ name: '', phone: '', phone2: '', status: 'Active', created_at: new Date().toISOString().split('T')[0] });

const openAddModal = () => {
  Object.assign(studentForm, { name: '', phone: '', phone2: '', status: 'Active', created_at: new Date().toISOString().split('T')[0] });
  showModal.value = true;
};
const closeModal = () => { showModal.value = false; };

const submitForm = async () => {
  if (!studentForm.name || isSubmitting.value) return;
  isSubmitting.value = true;
  try {
    const { error } = await supabase.from('students').insert([{
      name: studentForm.name,
      phone: studentForm.phone || null,
      phone2: studentForm.phone2 || null,
      group_id: groupId || null,
      status: studentForm.status || 'Active',
      created_at: studentForm.created_at ? new Date(studentForm.created_at).toISOString() : new Date().toISOString(),
      updated_at: new Date().toISOString()
    }]);
    if (error) throw error;
    await loadGroupData();
    closeModal();
  } catch (e) {
    console.error('Error saving student:', e);
    alert('Error saving. Please try again.');
  } finally {
    isSubmitting.value = false;
  }
};

// ════════════════════ ATTENDANCE SYSTEM ════════════════════

// Attendance statuses
const STATUSES = [
  { key: 'present', label: 'Keldi',   color: '#10B981', bg: '#D1FAE5', short: '✓' },
  { key: 'absent',  label: 'Kelmadi', color: '#EF4444', bg: '#FEE2E2', short: '✗' },
  { key: 'sick',    label: 'Kasal',   color: '#F59E0B', bg: '#FEF3C7', short: '⚕' },
  { key: 'late',    label: 'Kechikdi',color: '#6366F1', bg: '#EEF2FF', short: '⏱' },
];

// Uzbek day name → JS day-of-week mapping
const UZ_DAY_MAP = {
  'dushanba': 1, 'du': 1, 'monday': 1, 'mon': 1,
  'seshanba': 2, 'se': 2, 'tuesday': 2, 'tue': 2,
  'chorshanba': 3, 'ch': 3, 'wednesday': 3, 'wed': 3,
  'payshanba': 4, 'pa': 4, 'thursday': 4, 'thu': 4,
  'juma': 5, 'ju': 5, 'friday': 5, 'fri': 5,
  'shanba': 6, 'sh': 6, 'saturday': 6, 'sat': 6,
  'yakshanba': 0, 'ya': 0, 'sunday': 0, 'sun': 0,
};

const UZ_SHORT_DAYS = ['Ya', 'Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh'];
const MONTH_NAMES_UZ = [
  'Yanvar', 'Fevral', 'Mart', 'Aprel', 'May', 'Iyun',
  'Iyul', 'Avgust', 'Sentabr', 'Oktabr', 'Noyabr', 'Dekabr'
];

// Current month (year & month index)
const today = new Date();
const currentYear = ref(today.getFullYear());
const currentMonth = ref(today.getMonth()); // 0-based

const prevMonth = () => {
  if (currentMonth.value === 0) { currentMonth.value = 11; currentYear.value--; }
  else currentMonth.value--;
};
const nextMonth = () => {
  if (currentMonth.value === 11) { currentMonth.value = 0; currentYear.value++; }
  else currentMonth.value++;
};

// Parse group.days string → array of day numbers [1,4,6] etc.
const lessonDayNums = computed(() => {
  if (!group.value?.days) return [2, 4, 6];
  const raw = group.value.days.toLowerCase();
  const parts = raw.split(/[\s,\-\/]+/).filter(Boolean);
  const days = parts.map(p => UZ_DAY_MAP[p.trim().substring(0, 2)] || UZ_DAY_MAP[p.trim()]).filter(d => d !== undefined);
  return days.length > 0 ? [...new Set(days)].sort() : [2, 4, 6];
});

// ALL days of the month (every day 1..31)
const monthLessonDates = computed(() => {
  const y = currentYear.value;
  const m = currentMonth.value;
  const daysInMonth = new Date(y, m + 1, 0).getDate();
  const result = [];
  for (let d = 1; d <= daysInMonth; d++) {
    result.push(new Date(y, m, d));
  }
  return result;
});

// Check if a date is a scheduled lesson day (for subtle highlight)
const isLessonDay = (date) => lessonDayNums.value.includes(date.getDay());

// Format helpers
const formatDateKey = (date) => {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
};

const todayKey = formatDateKey(today);

// attendanceMap: { "studentId__YYYY-MM-DD": "present"|"absent"|"sick"|"late" }
const attendanceMap = ref({});
const isAttLoading = ref(false);

const loadAttendance = async () => {
  isAttLoading.value = true;
  try {
    const y = currentYear.value;
    const m = currentMonth.value;
    const startDate = `${y}-${String(m + 1).padStart(2, '0')}-01`;
    const endDate   = `${y}-${String(m + 1).padStart(2, '0')}-${String(new Date(y, m + 1, 0).getDate()).padStart(2, '0')}`;

    const { data, error } = await supabase
      .from('attendance')
      .select('student_id, lesson_date, status')
      .eq('group_id', groupId)
      .gte('lesson_date', startDate)
      .lte('lesson_date', endDate);

    if (error) {
      console.warn('Attendance table not ready:', error.message);
      return;
    }

    const map = {};
    (data || []).forEach(row => {
      map[`${row.student_id}__${row.lesson_date}`] = row.status;
    });
    attendanceMap.value = map;
  } catch (e) {
    console.error('Error loading attendance:', e);
  } finally {
    isAttLoading.value = false;
  }
};

// Reload attendance and payments when month changes
watch([currentYear, currentMonth], () => {
  loadAttendance();
  loadGroupPayments();
});

const getStatus = (studentId, date) => {
  return attendanceMap.value[`${studentId}__${formatDateKey(date)}`] || null;
};

const getStatusMeta = (key) => STATUSES.find(s => s.key === key) || null;

// Cycle through statuses: null → present → absent → sick → late → null
const CYCLE = [null, 'present', 'absent', 'sick', 'late'];

const checkTrialStatus = async (studentId) => {
  const student = students.value.find(s => s.id === studentId);
  if (!student || !['Trial', 'Active'].includes(student.status)) return;

  const { count, error } = await supabase
    .from('attendance')
    .select('*', { count: 'exact', head: true })
    .eq('student_id', studentId)
    .eq('status', 'present');

  if (error) return;

  if (count > 2 && student.status === 'Trial') {
    const { error: updateError } = await supabase
      .from('students')
      .update({ status: 'Active' })
      .eq('id', studentId);
    
    if (!updateError) student.status = 'Active';
  } else if (count <= 2 && student.status === 'Active') {
    const { error: updateError } = await supabase
      .from('students')
      .update({ status: 'Trial' })
      .eq('id', studentId);
    
    if (!updateError) student.status = 'Trial';
  }
};

const cycleStatus = async (studentId, date) => {
  const key = `${studentId}__${formatDateKey(date)}`;
  const current = attendanceMap.value[key] || null;
  const idx = CYCLE.indexOf(current);
  const next = CYCLE[(idx + 1) % CYCLE.length];

  // Optimistic update
  if (next === null) {
    delete attendanceMap.value[key];
  } else {
    attendanceMap.value[key] = next;
  }

  try {
    if (next === null) {
      await supabase.from('attendance').delete()
        .match({ student_id: studentId, group_id: groupId, lesson_date: formatDateKey(date) });
    } else {
      await supabase.from('attendance').upsert([{
        student_id: studentId,
        group_id: groupId,
        lesson_date: formatDateKey(date),
        status: next
      }], { onConflict: 'student_id,group_id,lesson_date' });
    }
    await checkTrialStatus(studentId);
  } catch (e) {
    // revert
    if (current === null) delete attendanceMap.value[key];
    else attendanceMap.value[key] = current;
    console.error('Error saving attendance:', e);
  }
};

// Set a specific status via dropdown-style click
const setStatus = async (studentId, date, newStatus) => {
  const key = `${studentId}__${formatDateKey(date)}`;
  const current = attendanceMap.value[key] || null;

  if (current === newStatus) {
    // clicking same status clears it
    delete attendanceMap.value[key];
    try {
      await supabase.from('attendance').delete()
        .match({ student_id: studentId, group_id: groupId, lesson_date: formatDateKey(date) });
      await checkTrialStatus(studentId);
    } catch (e) { attendanceMap.value[key] = current; }
    return;
  }

  attendanceMap.value[key] = newStatus;
  try {
    await supabase.from('attendance').upsert([{
      student_id: studentId,
      group_id: groupId,
      lesson_date: formatDateKey(date),
      status: newStatus
    }], { onConflict: 'student_id,group_id,lesson_date' });
    await checkTrialStatus(studentId);
  } catch (e) {
    if (current === null) delete attendanceMap.value[key];
    else attendanceMap.value[key] = current;
    console.error('Error saving attendance:', e);
  }
};

// Per-student summary for the month
const studentSummary = (studentId) => {
  const summary = { present: 0, absent: 0, sick: 0, late: 0, total: monthLessonDates.value.length };
  monthLessonDates.value.forEach(d => {
    const st = getStatus(studentId, d);
    if (st && summary[st] !== undefined) summary[st]++;
  });
  return summary;
};

// Tooltip/popover state for status picker
const activeCell = ref(null);     // "studentId__dateKey"
const pickerPos  = ref({ top: 0, left: 0 }); // fixed screen coords
const pickerStudent = ref(null);
const pickerDate    = ref(null);

const openPicker = (event, studentId, date) => {
  const key = `${studentId}__${formatDateKey(date)}`;
  if (activeCell.value === key) {
    activeCell.value = null;
    return;
  }
  // Calculate fixed position from the clicked element
  const rect = event.currentTarget.getBoundingClientRect();
  const pickerWidth = 160;
  const pickerHeight = 220; // approx
  let left = rect.left + rect.width / 2 - pickerWidth / 2;
  let top  = rect.bottom + 6;
  // Keep within viewport
  if (left < 8) left = 8;
  if (left + pickerWidth > window.innerWidth - 8) left = window.innerWidth - pickerWidth - 8;
  if (top + pickerHeight > window.innerHeight - 8) top = rect.top - pickerHeight - 6;
  pickerPos.value   = { top, left };
  pickerStudent.value = studentId;
  pickerDate.value    = date;
  activeCell.value    = key;
};

const closePicker = () => { activeCell.value = null; };

// Helper: check if student joined before this date
const isBeforeJoin = (student, date) => {
  if (!student.created_at) return false;
  const joinDate = new Date(student.created_at);
  joinDate.setHours(0,0,0,0);
  const cellDate = new Date(date);
  cellDate.setHours(0,0,0,0);
  return cellDate < joinDate;
};

onMounted(() => {
  loadGroupData();
  loadAttendance();
});
</script>

<template>
  <div class="group-details" @click="closePicker">
    <!-- Header -->
    <div class="page-header">
      <div class="header-left">
        <button class="btn-back" @click="goBack">
          <ChevronLeft :size="20" /> {{ $t('common.back') }}
        </button>
        <div class="header-main">
          <h1>{{ group?.name || $t('groups.details') }}</h1>
          <div v-if="group?.status" :class="['status-badge', getStatusClass(group.status)]">
            {{ $t('groups.' + group.status.toLowerCase()) }}
          </div>
        </div>
      </div>
      
      <div class="header-right" v-if="userRole === 'admin'">
        <div class="options-wrapper">
          <button class="btn-options" @click.stop="showGroupOptions = !showGroupOptions">
            <MoreVertical :size="20" />
          </button>
          <transition name="dropdown">
            <div v-if="showGroupOptions" class="dropdown-menu-group" @click.stop>
              <button class="dropdown-item" @click="openEditGroup">
                <Edit :size="16" /> Tahrirlash
              </button>
              <div class="dropdown-divider"></div>
              <button class="dropdown-item danger" @click="confirmDeleteGroup">
                <Trash2 :size="16" /> O'chirish
              </button>
            </div>
          </transition>
        </div>
      </div>
    </div>

    <!-- Loading skeleton -->
    <div v-if="isLoading" class="loading-state">
      <div class="skeleton-cards">
        <div v-for="i in 4" :key="i" class="skeleton card" style="height:120px;"></div>
      </div>
      <div class="skeleton card" style="height:400px;margin-top:2rem;"></div>
    </div>

    <template v-else-if="group">
      <!-- Info Grid -->
      <div class="info-grid">
        <div class="info-card card">
          <div class="card-icon course"><BookOpen :size="22" /></div>
          <div class="card-content">
            <span class="label">{{ $t('groups.course') }}</span>
            <span class="value">{{ group.courses?.name }}</span>
          </div>
        </div>
        <div class="info-card card">
          <div class="card-icon teacher"><User :size="22" /></div>
          <div class="card-content">
            <span class="label">{{ $t('groups.teacher') }}</span>
            <div class="teachers-list-inline">
              <span v-if="group.teacher_names?.length > 0" class="value">
                {{ group.teacher_names.join(', ') }}
              </span>
              <span v-else class="value">-</span>
            </div>
          </div>
        </div>
        <div class="info-card card">
          <div class="card-icon schedule"><Calendar :size="22" /></div>
          <div class="card-content">
            <span class="label">{{ $t('groups.days') }}</span>
            <span class="value">{{ group.days }}</span>
          </div>
        </div>
        <div class="info-card card">
          <div class="card-icon time"><Clock :size="22" /></div>
          <div class="card-content">
            <span class="label">{{ $t('groups.timeStarting') }}</span>
            <span class="value">{{ group.time }}</span>
          </div>
        </div>
      </div>

      <!-- Students Table -->
      <div class="students-section card">
        <div class="section-header">
          <div class="title-row">
            <div class="title-main">
              <Users :size="20" />
              <h2>{{ $t('groups.studentsInGroup') }}</h2>
              <span class="count-badge">{{ students.length }}</span>
            </div>
            <button v-if="userRole === 'admin'" class="btn-add-student" @click="openAddModal">
              <Plus :size="18" /> {{ $t('students.addNew') }}
            </button>
          </div>
        </div>
        <div class="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>{{ $t('students.name') }}</th>
                <th>{{ $t('students.phone') }}</th>
                <th>{{ $t('students.status') }}</th>
                <th>To'lov holati (Qarz)</th>
                <th>Chegirma</th>
                <th>{{ $t('students.addedDate') }}</th>
                <th v-if="userRole === 'admin'"></th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="students.length === 0">
                <td :colspan="userRole === 'admin' ? 7 : 6" class="no-data">{{ $t('common.noData') }}</td>
              </tr>
              <tr v-for="student in students" :key="student.id">
                <td :data-label="$t('students.name')">
                  <div class="student-info">
                    <img :src="`https://ui-avatars.com/api/?name=${encodeURIComponent(student.name)}&background=7366FF&color=fff`" class="avatar">
                    <span class="name">{{ student.name }}</span>
                  </div>
                </td>
                <td :data-label="$t('students.phone')">
                  <div class="phone-column">
                    <div class="phone-item"><Phone :size="14" /> {{ student.phone }}</div>
                    <div v-if="student.phone2" class="phone-item secondary">{{ student.phone2 }}</div>
                  </div>
                </td>
                <td :data-label="$t('students.status')">
                  <span :class="['status-badge-small', student.status.toLowerCase()]">
                    {{ $t('students.' + student.status.toLowerCase()) }}
                  </span>
                </td>
                <td data-label="To'lov holati (Qarz)">
                  <div class="debt-list-cell">
                    <template v-if="getDebtSummary(student).length > 0">
                      <div class="debt-group">
                        <span v-for="m in getDebtSummary(student)" :key="m" class="debt-item unpaid">
                          {{ m }}
                        </span>
                      </div>
                    </template>
                    <template v-else>
                      <span class="debt-item paid">Hamma oylar to'langan</span>
                    </template>
                  </div>
                </td>
                <td data-label="Chegirma">
                  <span v-if="student.discount && student.discount > 0" class="discount-badge">
                    &minus; {{ new Intl.NumberFormat('uz-UZ').format(student.discount) }} UZS
                  </span>
                  <span v-else class="no-discount">—</span>
                </td>
                <td :data-label="$t('students.addedDate')">
                  <div class="date-info"><Calendar :size="14" /> {{ formatDate(student.created_at) }}</div>
                </td>
                <td v-if="userRole === 'admin'" class="text-right" :data-label="$t('common.actions') || 'Actions'">
                  <button class="btn-icon" @click="goToStudent(student.id)"><ArrowRight :size="18" /></button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- ═══════════════ ATTENDANCE SECTION ═══════════════ -->
      <div class="attendance-section card">

        <!-- Header row -->
        <div class="att-header">
          <div class="att-title-block">
            <div class="att-icon"><CalendarDays :size="20" /></div>
            <div>
              <h2 class="att-heading">{{ $t('common.attendance') }}</h2>
              <p class="att-sub">{{ group.days }} &bull; {{ monthLessonDates.length }} kun</p>
            </div>
          </div>

          <!-- Month Navigator -->
          <div class="month-nav">
            <button class="nav-btn" @click.stop="prevMonth"><ChevronLeft :size="18" /></button>
            <div class="month-label">
              <span class="month-name">{{ MONTH_NAMES_UZ[currentMonth] }}</span>
              <span class="month-year">{{ currentYear }}</span>
            </div>
            <button class="nav-btn" @click.stop="nextMonth"><ChevronRight :size="18" /></button>
          </div>

          <!-- Legend -->
          <div class="legend">
            <span v-for="s in STATUSES" :key="s.key" class="legend-item" :style="{background: s.bg, color: s.color}">
              {{ s.short }} {{ s.label }}
            </span>
          </div>
        </div>

        <!-- Loading overlay while switching month -->
        <div v-if="isAttLoading" class="att-loading">
          <Loader2 :size="28" class="spin" />
          <span>Yuklanmoqda...</span>
        </div>

        <!-- No students -->
        <div v-else-if="students.length === 0" class="no-data">{{ $t('common.noData') }}</div>

        <!-- Attendance Table -->
        <div v-else class="att-scroll">
          <table class="att-table">
            <thead>
              <tr>
                <!-- Sticky name column -->
                <th class="th-name">#  {{ $t('students.name') }}</th>
                <!-- One column per lesson date -->
                <th
                  v-for="(date, i) in monthLessonDates"
                  :key="i"
                  :class="[
                    'th-day',
                    formatDateKey(date) === todayKey ? 'col-today' : ''
                  ]"
                >
                  <div class="th-day-inner">
                    <span class="th-dow">{{ UZ_SHORT_DAYS[date.getDay()] }}</span>
                    <span class="th-date">{{ date.getDate() }}</span>
                  </div>
                </th>
                <!-- Summary columns -->
                <th class="th-sum th-present">✓</th>
                <th class="th-sum th-absent">✗</th>
                <th class="th-sum th-sick">⚕</th>
                <th class="th-sum th-late">⏱</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(student, sIdx) in students" :key="student.id">
                <!-- Name -->
                <td class="td-name" :data-label="'# ' + $t('students.name')">
                  <div class="td-name-inner">
                    <span class="td-num">{{ sIdx + 1 }}</span>
                    <span class="td-sname">{{ student.name }}</span>
                  </div>
                </td>

                <!-- Attendance cells -->
                <td
                  v-for="(date, dIdx) in monthLessonDates"
                  :key="dIdx"
                  :data-label="date.getDate() + ' ' + MONTH_NAMES_UZ[date.getMonth()]"
                  :class="[
                    'td-cell',
                    formatDateKey(date) === todayKey ? 'col-today' : '',
                    isBeforeJoin(student, date) ? 'td-disabled' : ''
                  ]"
                >
                  <div 
                    v-if="!isBeforeJoin(student, date)"
                    class="cell-wrapper" 
                    @click.stop="openPicker($event, student.id, date)"
                  >
                    <!-- Status pill -->
                    <div
                      v-if="getStatus(student.id, date)"
                      class="status-pill"
                      :style="{
                        background: getStatusMeta(getStatus(student.id, date))?.bg,
                        color: getStatusMeta(getStatus(student.id, date))?.color
                      }"
                    >
                      {{ getStatusMeta(getStatus(student.id, date))?.short }}
                    </div>
                    <div v-else class="empty-cell"></div>
                  </div>
                </td>

                <!-- Summary cells -->
                <td class="td-sum sum-present" data-label="✓ Present">{{ studentSummary(student.id).present }}</td>
                <td class="td-sum sum-absent" data-label="✗ Absent">{{ studentSummary(student.id).absent }}</td>
                <td class="td-sum sum-sick" data-label="⚕ Sick">{{ studentSummary(student.id).sick }}</td>
                <td class="td-sum sum-late" data-label="⏱ Late">{{ studentSummary(student.id).late }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </template>

    <!-- Teleported Status Picker (renders at body level, never clipped) -->
    <Teleport to="body">
      <div
        v-if="activeCell && pickerDate"
        class="status-picker-fixed"
        :style="{ top: pickerPos.top + 'px', left: pickerPos.left + 'px' }"
        @click.stop
      >
        <div class="picker-date">
          {{ pickerDate.getDate() }} {{ MONTH_NAMES_UZ[pickerDate.getMonth()] }}
        </div>
        <button
          v-for="s in STATUSES"
          :key="s.key"
          class="picker-btn"
          :class="{ 'picker-active': getStatus(pickerStudent, pickerDate) === s.key }"
          :style="{ '--btn-color': s.color, '--btn-bg': s.bg }"
          @click="setStatus(pickerStudent, pickerDate, s.key); closePicker()"
        >
          <span class="picker-icon">{{ s.short }}</span>
          {{ s.label }}
        </button>
        <button class="picker-btn picker-clear" @click="setStatus(pickerStudent, pickerDate, getStatus(pickerStudent, pickerDate)); closePicker()">
          ✕ Tozalash
        </button>
      </div>
    </Teleport>

    <!-- Group Edit Modal -->
    <transition name="modal">
      <div v-if="showGroupEditModal" class="modal-overlay" @click.self="showGroupEditModal = false">
        <div class="modal-box">
                  <div class="modal-header">
            <div class="modal-title-row">
              <div class="modal-icon"><Edit :size="22" /></div>
              <h2>Guruhni tahrirlash</h2>
            </div>
            <button class="btn-icon" @click="showGroupEditModal = false"><X :size="20" /></button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>Guruh nomi <span class="required">*</span></label>
              <input v-model="groupForm.name" placeholder="Masalan: Ingliz tili Elementary" />
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>{{ $t('groups.course') }} <span class="required">*</span></label>
                <select v-model="groupForm.course_id">
                  <option v-for="c in courses" :key="c.id" :value="c.id">{{ c.name }}</option>
                </select>
              </div>
              <div class="form-group">
                <label>{{ $t('groups.teacher') }} ({{ $t('common.multiSelect') || 'Ko\'p tanlash' }})</label>
                <div class="teachers-checkbox-list">
                  <label v-for="t in teachers" :key="t.id" class="teacher-checkbox-item">
                    <input type="checkbox" v-model="groupForm.teacher_ids" :value="t.id" />
                    <span>{{ t.name }}</span>
                  </label>
                </div>
              </div>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>Kunlar</label>
                <select v-model="groupForm.days">
                  <option v-for="pattern in dayPatterns" :key="pattern.value" :value="pattern.value">{{ pattern.label }}</option>
                  <option value="Custom">Boshqa...</option>
                </select>
                <input v-if="groupForm.days === 'Custom' || !dayPatterns.find(p => p.value === groupForm.days)" v-model="groupForm.days" class="mt-2" placeholder="Kunlarni yozing..." />
              </div>
              <div class="form-group">
                <label>Vaqti</label>
                <input type="time" v-model="groupForm.time" />
              </div>
            </div>
            <div class="form-group">
              <label>Holat</label>
              <select v-model="groupForm.status">
                <option value="Active">Faol</option>
                <option value="Finished">Yakunlangan</option>
              </select>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn-cancel-modal" @click="showGroupEditModal = false">Bekor qilish</button>
            <button class="btn-confirm-primary" @click="updateGroup" :disabled="isSubmittingGroup">
              <Loader2 v-if="isSubmittingGroup" :size="16" class="spin" />
              Saqlash
            </button>
          </div>
        </div>
      </div>
    </transition>

    <transition name="modal">
      <div v-if="showDeleteConfirm" class="modal-overlay" @click.self="showDeleteConfirm = false">
        <div class="modal-box confirm-modal">
          <div class="modal-body p-2rem">
            <div class="confirm-icon" style="margin: 0 auto 1.5rem">
              <AlertTriangle :size="48" style="color: var(--danger)" />
            </div>
            <h2 class="confirm-title text-center">{{ $t('groups.deleteModal.title') }}</h2>
            <p class="confirm-desc text-center" style="margin-bottom: 2rem">{{ $t('groups.deleteModal.question') }}</p>
            
            <div class="delete-options-list" style="display: flex; flex-direction: column; gap: 1rem; margin-bottom: 2rem;">
              <label class="option-card" :class="{ active: deleteOption === 'moveAnother' }">
                <input type="radio" v-model="deleteOption" value="moveAnother" class="hidden-radio" />
                <div class="option-info">
                  <span class="option-name">{{ $t('groups.deleteModal.moveAnother') }}</span>
                </div>
                <div class="option-check"><Check v-if="deleteOption === 'moveAnother'" :size="16" /></div>
              </label>

              <transition name="fade">
                <div v-if="deleteOption === 'moveAnother'" class="target-group-select" style="padding-left: 1rem;">
                  <select v-model="targetGroupIdForStudents" style="width: 100%; padding: 0.6rem; border-radius: 12px; border: 1.5px solid var(--border); background: var(--light);">
                    <option value="">{{ $t('groups.deleteModal.selectGroup') }}</option>
                    <option v-for="g in otherGroups" :key="g.id" :value="g.id">{{ g.name }}</option>
                  </select>
                </div>
              </transition>

              <label class="option-card" :class="{ active: deleteOption === 'archiveWith' }">
                <input type="radio" v-model="deleteOption" value="archiveWith" class="hidden-radio" />
                <div class="option-info">
                  <span class="option-name">{{ $t('groups.deleteModal.archiveWith') }}</span>
                </div>
                <div class="option-check"><Check v-if="deleteOption === 'archiveWith'" :size="16" /></div>
              </label>

              <label class="option-card" :class="{ active: deleteOption === 'noGroup' }">
                <input type="radio" v-model="deleteOption" value="noGroup" class="hidden-radio" />
                <div class="option-info">
                  <span class="option-name">{{ $t('groups.deleteModal.noGroup') }}</span>
                </div>
                <div class="option-check"><Check v-if="deleteOption === 'noGroup'" :size="16" /></div>
              </label>
            </div>

            <div class="confirm-actions" style="display: flex; gap: 1rem;">
              <button class="btn-cancel" style="flex: 1; padding: 0.8rem; border-radius: 12px; font-weight: 700; background: var(--light); color: var(--gray);" @click="showDeleteConfirm = false" :disabled="isSubmittingGroup">{{ $t('common.cancel') }}</button>
              <button class="btn-danger-confirm" style="flex: 1; padding: 0.8rem; border-radius: 12px; font-weight: 700; background: var(--danger); color: white; border: none; display: flex; align-items: center; justify-content: center; gap: 0.5rem;" @click="deleteGroupAction" :disabled="isSubmittingGroup || (deleteOption === 'moveAnother' && !targetGroupIdForStudents)">
                <Loader2 v-if="isSubmittingGroup" :size="18" class="spin" />
                <span v-else>{{ $t('groups.deleteModal.confirm') }}</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </transition>

    <!-- Add Student Modal -->

    <transition name="modal">
      <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
        <div class="modal-box">
          <div class="modal-header">
            <div class="modal-title-row">
              <div class="modal-icon"><Plus :size="22" /></div>
              <h2>{{ $t('students.createModalTitle') }}</h2>
            </div>
            <button class="btn-icon" @click="closeModal"><X :size="20" /></button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>{{ $t('students.name') }} <span class="required">*</span></label>
              <input v-model="studentForm.name" :placeholder="$t('students.namePlaceholder')" />
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>{{ $t('students.phone1') }}</label>
                <div class="input-with-icon">
                  <Phone :size="16" class="input-icon" />
                  <input v-model="studentForm.phone" :placeholder="$t('students.phonePlaceholder')" />
                </div>
              </div>
              <div class="form-group">
                <label>{{ $t('students.phone2') }}</label>
                <div class="input-with-icon">
                  <Phone :size="16" class="input-icon" />
                  <input v-model="studentForm.phone2" :placeholder="$t('students.phonePlaceholder')" />
                </div>
              </div>
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>{{ $t('students.status') }}</label>
                <select v-model="studentForm.status">
                  <option value="Active">{{ $t('students.active') }}</option>
                  <option value="Left">{{ $t('students.left') }}</option>
                  <option value="Finished">{{ $t('students.finished') }}</option>
                  <option value="Trial">{{ $t('students.trial') }}</option>
                </select>
              </div>
              <div class="form-group">
                <label>{{ $t('common.addedDate') || "Qo'shilgan sana" }}</label>
                <div class="input-with-icon">
                  <Calendar :size="16" class="input-icon" />
                  <input type="date" v-model="studentForm.created_at" style="padding-left: 2.5rem;" />
                </div>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn-cancel-modal" @click="closeModal" :disabled="isSubmitting">{{ $t('common.cancel') }}</button>
            <button class="btn-confirm-primary" @click="submitForm" :disabled="!studentForm.name || isSubmitting">
              <template v-if="isSubmitting"><Loader2 :size="16" class="spin" /> {{ $t('common.loading') }}</template>
              <template v-else>{{ $t('common.add') }}</template>
            </button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped>
/* ─── Base ─── */
.group-details { padding: 2rem; background: var(--light); min-height: 100vh; }
.page-header { margin-bottom: 2rem; display: flex; justify-content: space-between; align-items: center; }
.header-left { display: flex; flex-direction: column; }
.btn-back { display: flex; align-items: center; gap: .5rem; color: var(--gray); font-weight: 600; margin-bottom: 0.5rem; transition: color .2s; }
.btn-back:hover { color: var(--primary); }
.header-main { display: flex; align-items: center; gap: 1.5rem; }
.header-main h1 { font-size: 2rem; font-weight: 800; color: var(--dark); }

.options-wrapper { position: relative; }
.btn-options { width: 42px; height: 42px; border-radius: 12px; display: flex; align-items: center; justify-content: center; background: white; border: 1.5px solid var(--border); color: var(--gray); transition: all .2s; }
.btn-options:hover { border-color: var(--primary); color: var(--primary); background: #F9FAFF; }

.dropdown-menu-group {
  position: absolute;
  top: 100%;
  right: 0;
  margin-top: 0.75rem;
  background: white;
  border: 1px solid var(--border);
  border-radius: 16px;
  padding: 0.6rem;
  box-shadow: 0 20px 50px rgba(0,0,0,0.15);
  z-index: 1000;
  min-width: 180px;
}
.dropdown-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  width: 100%;
  border-radius: 10px;
  font-size: 0.92rem;
  font-weight: 700;
  color: #1E293B;
  transition: all .2s;
}
.dropdown-item:hover { background: #F1F5F9; color: var(--primary); }
.dropdown-item.danger { color: #EF4444; }
.dropdown-item.danger:hover { background: #FEF2F2; color: #EF4444; }
.dropdown-divider { height: 1px; background: #F1F5F9; margin: 0.4rem 0.5rem; }

/* ─── Info grid ─── */
.info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 1.5rem; margin-bottom: 2rem; }
.info-card { padding: 1.4rem; display: flex; align-items: center; gap: 1.1rem; }
.card-icon { width: 46px; height: 46px; border-radius: 13px; display: flex; align-items: center; justify-content: center; flex-shrink: 0; }
.card-icon.course  { background:#E3F2FD; color:#2196F3; }
.card-icon.teacher { background:#F3E5F5; color:#9C27B0; }
.card-icon.schedule{ background:#E8F5E9; color:#4CAF50; }
.card-icon.time    { background:#FFF3E0; color:#FF9800; }
.card-content { display: flex; flex-direction: column; }
.card-content .label { font-size:.72rem; font-weight:700; color:var(--gray); text-transform:uppercase; letter-spacing:.5px; }
.card-content .value { font-size:1.05rem; font-weight:700; color:var(--dark); margin-top:2px; }

/* ─── Students table ─── */
.students-section { overflow: hidden; margin-bottom: 2rem; }
.section-header { padding: 1.5rem; border-bottom: 1px solid var(--border); }
.title-row { display: flex; justify-content: space-between; align-items: center; }
.title-main { display: flex; align-items: center; gap: .75rem; }
.title-main h2 { font-size: 1.2rem; font-weight: 800; color: var(--dark); }
.count-badge { background: var(--primary-light); color: var(--primary); padding: 2px 10px; border-radius: 20px; font-size: .82rem; font-weight: 700; }
.table-wrapper { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; }
th { text-align: left; padding: .9rem 1.4rem; background: #F8F9FA; font-size: .76rem; font-weight: 700; color: var(--gray); text-transform: uppercase; letter-spacing: .4px; }
td { padding: .9rem 1.4rem; border-bottom: 1px solid var(--border); }
.student-info { display: flex; align-items: center; gap: .9rem; }
.avatar { width: 34px; height: 34px; border-radius: 50%; }
.name { font-weight: 700; color: var(--dark); }
.phone-column { display: flex; flex-direction: column; gap: 2px; }
.phone-item { display: flex; align-items: center; gap: 6px; font-size: .83rem; color: var(--dark); }
.phone-item.secondary { font-size: .78rem; color: var(--gray); padding-left: 20px; }
.phone-item svg { color: var(--primary); opacity: .6; }
.status-badge-small { padding: 3px 10px; border-radius: 6px; font-size: .73rem; font-weight: 700; }
.status-badge-small.active   { background:#E8F5E9; color:#2E7D32; }
.status-badge-small.left     { background:#FFEBEE; color:#C62828; }
.status-badge-small.finished { background:#F5F5F5; color:#757575; }
.status-badge-small.trial    { background:rgba(115,102,255,.1); color:var(--primary); }
.date-info { display: flex; align-items: center; gap: .4rem; color: var(--gray); font-size: .83rem; }
.discount-badge {
  display: inline-flex;
  align-items: center;
  background: #FEE2E2;
  color: #DC2626;
  font-size: .78rem;
  font-weight: 700;
  padding: 3px 10px;
  border-radius: 8px;
  white-space: nowrap;
}
.no-discount { color: #CBD5E1; font-weight: 600; font-size: .9rem; }

.text-right { text-align: right; }
.btn-icon { width: 34px; height: 34px; border-radius: 10px; display: inline-flex; align-items: center; justify-content: center; color: var(--gray); transition: all .2s; }
.btn-icon:hover { background: var(--primary-light); color: var(--primary); transform: translateX(3px); }
.status-badge { padding: 5px 12px; border-radius: 8px; font-size: .82rem; font-weight: 700; }
.debt-list-cell { min-width: 140px; }
.debt-group { display: flex; flex-wrap: wrap; gap: 4px; }
.debt-item {
  font-size: .7rem;
  font-weight: 800;
  padding: 3px 8px;
  border-radius: 6px;
  text-transform: uppercase;
  white-space: nowrap;
}
.debt-item.unpaid { background: #FEE2E2; color: #DC2626; border: 1px solid #FECACA; }
.debt-item.paid { background: #DCFCE7; color: #166534; }

.status-active   { background:#E8F5E9; color:#2E7D32; }
.status-pending  { background:#FFF3E0; color:#EF6C00; }
.status-finished { background:#F5F5F5; color:#757575; }
.skeleton-cards { display: grid; grid-template-columns: repeat(4,1fr); gap: 1.5rem; }
.no-data { text-align: center; padding: 3rem !important; color: var(--gray); font-size: .95rem; }

/* ══════════════ ATTENDANCE ══════════════ */
.attendance-section { overflow: visible; }

.att-header {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 1.2rem;
  padding: 1.4rem 1.5rem;
  border-bottom: 1px solid var(--border);
}

.att-title-block { display: flex; align-items: center; gap: .85rem; }
.att-icon {
  width: 40px; height: 40px;
  border-radius: 11px;
  background: linear-gradient(135deg, #7366FF22, #7366FF44);
  color: var(--primary);
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.att-heading { font-size: 1.15rem; font-weight: 800; color: var(--dark); margin: 0; }
.att-sub { font-size: .75rem; color: var(--gray); margin: 2px 0 0; }

/* Month Navigator */
.month-nav {
  display: flex;
  align-items: center;
  gap: .6rem;
  background: #F8F9FA;
  border: 1.5px solid var(--border);
  border-radius: 13px;
  padding: .35rem .45rem;
  margin-left: auto;
}
.nav-btn {
  width: 32px; height: 32px;
  border-radius: 9px;
  display: flex; align-items: center; justify-content: center;
  background: white;
  border: 1px solid var(--border);
  color: var(--dark);
  transition: all .18s;
  box-shadow: 0 1px 3px rgba(0,0,0,.06);
}
.nav-btn:hover { background: var(--primary); color: white; border-color: var(--primary); }
.month-label {
  display: flex; flex-direction: column;
  align-items: center;
  min-width: 130px;
  text-align: center;
}
.month-name { font-size: 1rem; font-weight: 800; color: var(--dark); }
.month-year { font-size: .72rem; font-weight: 600; color: var(--gray); }

/* Legend */
.legend { display: flex; gap: .4rem; flex-wrap: wrap; }
.legend-item {
  font-size: .72rem;
  font-weight: 700;
  padding: 3px 9px;
  border-radius: 7px;
  white-space: nowrap;
}

/* Loading */
.att-loading {
  display: flex; align-items: center; justify-content: center;
  gap: .75rem; padding: 3rem;
  color: var(--gray); font-weight: 600;
}

/* Table scroll — horizontal only, page handles vertical */
.att-scroll {
  overflow-x: auto;
  overflow-y: visible;
  position: relative;
  /* custom horizontal scrollbar */
}
.att-scroll::-webkit-scrollbar { height: 6px; }
.att-scroll::-webkit-scrollbar-track { background: #F1F1F1; border-radius: 10px; }
.att-scroll::-webkit-scrollbar-thumb { background: var(--border); border-radius: 10px; }
.att-scroll::-webkit-scrollbar-thumb:hover { background: var(--gray); }

.att-table { border-collapse: collapse; width: max-content; min-width: 100%; }

/* Header cells */
.th-name {
  position: sticky; left: 0; z-index: 12;
  background: #F0F0FA;
  text-align: left;
  padding: .75rem 1.2rem;
  font-size: .72rem; font-weight: 700; color: var(--gray);
  text-transform: uppercase; letter-spacing: .4px;
  border-bottom: 2px solid var(--border);
  border-right: 2px solid var(--border);
  min-width: 200px;
  white-space: nowrap;
}

.th-day {
  padding: .5rem .3rem;
  text-align: center;
  border-bottom: 2px solid var(--border);
  border-left: 1px solid #EBEBEB;
  min-width: 48px;
  background: #F8F9FA;
}

.th-sum {
  padding: .6rem .5rem;
  text-align: center;
  font-size: .8rem; font-weight: 800;
  border-bottom: 2px solid var(--border);
  border-left: 2px solid var(--border);
  min-width: 38px;
}
.th-present { background:#D1FAE5; color:#059669; }
.th-absent  { background:#FEE2E2; color:#DC2626; }
.th-sick    { background:#FEF3C7; color:#D97706; }
.th-late    { background:#EEF2FF; color:#4F46E5; }

.th-day-inner { display: flex; flex-direction: column; align-items: center; gap: 3px; }
.th-dow  { font-size: .62rem; font-weight: 700; color: var(--gray); text-transform: uppercase; }
.th-date { font-size: .95rem; font-weight: 800; color: var(--dark); line-height: 1; }

/* Today highlight */
.col-today { background: rgba(115, 102, 255, 0.08) !important; }
.col-today .th-date {
  background: var(--primary);
  color: white;
  border-radius: 8px;
  width: 28px; height: 28px;
  display: flex; align-items: center; justify-content: center;
  font-size: .88rem;
}
.col-today .th-dow { color: var(--primary); }


/* Body cells */
.td-name {
  position: sticky; left: 0; z-index: 10;
  background: white;
  padding: .65rem 1.2rem;
  border-bottom: 1px solid var(--border);
  border-right: 2px solid var(--border);
  min-width: 200px;
}
.att-table tr:nth-child(even) .td-name { background: #FAFAFA; }
.att-table tr:hover .td-name { background: #F5F4FF; }
.att-table tr:nth-child(even) .td-cell { background: #FAFAFA; }
.att-table tr:hover .td-cell { background: #F5F4FF; }

.td-name-inner { display: flex; align-items: center; gap: .65rem; }
.td-num {
  width: 22px; height: 22px;
  border-radius: 6px;
  background: var(--primary-light); color: var(--primary);
  font-size: .7rem; font-weight: 800;
  display: flex; align-items: center; justify-content: center;
  flex-shrink: 0;
}
.td-sname { font-weight: 700; color: var(--dark); font-size: .88rem; white-space: nowrap; }

.td-cell {
  padding: .3rem .25rem;
  text-align: center;
  border-bottom: 1px solid var(--border);
  border-left: 1px solid #EBEBEB;
  vertical-align: middle;
  position: relative;
}

.td-disabled { background: #f8fafc !important; cursor: not-allowed; opacity: 0.6; }
.td-disabled::after { content: "—"; color: #cbd5e1; font-weight: 700; font-size: .8rem; }

.td-sum {
  text-align: center;
  padding: .65rem .5rem;
  border-bottom: 1px solid var(--border);
  border-left: 2px solid var(--border);
  font-size: .85rem; font-weight: 800;
}
.sum-present { color: #059669; background: rgba(16,185,129,.06); }
.sum-absent  { color: #DC2626; background: rgba(239,68,68,.06);  }
.sum-sick    { color: #D97706; background: rgba(245,158,11,.06); }
.sum-late    { color: #4F46E5; background: rgba(99,102,241,.06); }

/* Cell wrapper */
.cell-wrapper {
  position: relative;
  display: flex; align-items: center; justify-content: center;
  width: 100%; height: 36px;
  cursor: pointer;
  border-radius: 6px;
  transition: background .15s;
}
.cell-wrapper:hover { background: rgba(115,102,255,.08); }

/* Status pill inside cell */
.status-pill {
  width: 30px; height: 30px;
  border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  font-size: .88rem; font-weight: 700;
  transition: transform .15s;
}
.cell-wrapper:hover .status-pill { transform: scale(1.12); }

/* Empty cell dot */
.empty-cell {
  width: 8px; height: 8px;
  border-radius: 50%;
  background: #E5E7EB;
  transition: all .15s;
}
.cell-wrapper:hover .empty-cell { background: var(--primary); transform: scale(1.3); }

/* Old .status-picker removed — now handled by Teleport (see global style below) */

/* ─── Modal ─── */
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,.5); display: flex; align-items: center; justify-content: center; z-index: 10000; backdrop-filter: blur(4px); }
.modal-box { background: white; border-radius: 20px; width: 100%; max-width: 540px; overflow: hidden; box-shadow: 0 20px 60px rgba(0,0,0,.2); }
.modal-header { padding: 1.5rem; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
.modal-title-row { display: flex; align-items: center; gap: 1rem; }
.modal-icon { width: 40px; height: 40px; background: var(--primary-light); color: var(--primary); border-radius: 11px; display: flex; align-items: center; justify-content: center; }
.modal-body { padding: 1.5rem; }
.form-group { margin-bottom: 1.2rem; }
.form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1.2rem; }
label { display: block; font-size: .83rem; font-weight: 700; margin-bottom: .5rem; color: var(--dark); }
input, select { width: 100%; padding: .72rem 1rem; border: 1.5px solid var(--border); border-radius: 11px; background: #F8F9FA; outline: none; transition: all .2s; font-size: .93rem; }
input:focus, select:focus { border-color: var(--primary); background: white; box-shadow: 0 0 0 4px var(--primary-light); }
.input-with-icon { position: relative; }
.input-with-icon .input-icon { position: absolute; left: 1rem; top: 50%; transform: translateY(-50%); color: var(--gray); pointer-events: none; }
.input-with-icon input { padding-left: 2.7rem; }
.modal-footer { padding: 1.2rem 1.5rem; background: #F8F9FA; display: flex; justify-content: flex-end; gap: 1rem; }

/* Group Deletion Option Cards */
.option-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.25rem;
  background: var(--light);
  border: 1.5px solid var(--border);
  border-radius: 14px;
  cursor: pointer;
  transition: all 0.2s;
  margin-bottom: 0;
}
.option-card:hover { border-color: var(--primary-light); background: white; }
.option-card.active { border-color: var(--primary); background: #f5f4ff; box-shadow: 0 4px 12px rgba(115,102,255,0.1); }
.option-name { font-weight: 700; color: var(--dark); font-size: 0.95rem; }
.option-check { width: 24px; height: 24px; border-radius: 50%; background: var(--primary); color: white; display: flex; align-items: center; justify-content: center; }
.hidden-radio { display: none; }
.fade-enter-active, .fade-leave-active { transition: all 0.3s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; transform: translateY(-10px); }
.btn-confirm-primary { background: var(--primary); color: white; padding: .72rem 2rem; border-radius: 11px; font-weight: 700; transition: all .2s; }
.btn-confirm-primary:hover:not(:disabled) { transform: translateY(-2px); box-shadow: 0 5px 15px rgba(115,102,255,.3); }
.btn-cancel-modal { padding: .72rem 1.5rem; font-weight: 600; color: var(--gray); }
.required { color: var(--danger); margin-left: 2px; }
.btn-add-student { background: var(--primary); color: white; padding: .55rem 1.2rem; border-radius: 10px; font-size: .83rem; font-weight: 700; display: flex; align-items: center; gap: .5rem; transition: all .2s; }
.btn-add-student:hover { transform: translateY(-2px); box-shadow: 0 4px 12px rgba(115,102,255,.2); }
@media (max-width: 991px) {
  .info-grid { grid-template-columns: repeat(2, 1fr); }
  .dashboard-content-grid { grid-template-columns: 1fr; }
}

@media (max-width: 768px) {
  .page-header { flex-direction: column; align-items: flex-start; gap: 1rem; }
  .header-actions { width: 100%; display: flex; justify-content: flex-end; }
  .info-grid { grid-template-columns: 1fr; }
  .title-row { flex-direction: column; align-items: flex-start; gap: 1rem; }
  .btn-add-student { width: 100%; justify-content: center; }
  .table-wrapper, .att-scroll { width: 100%; overflow-x: auto; -webkit-overflow-scrolling: touch; }
  table, .att-table { min-width: 1000px; }
  .form-row { grid-template-columns: 1fr; }
  .modal-box { width: 95%; max-height: 90vh; overflow-y: auto; }
}

.modal-enter-active, .modal-leave-active { transition: opacity .3s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
</style>

<!-- Global style for teleported picker (not scoped) -->
<style>
.status-picker-fixed {
  position: fixed;
  z-index: 99999;
  background: white;
  border: 1.5px solid #DBDADE;
  border-radius: 14px;
  padding: .6rem;
  box-shadow: 0 10px 40px rgba(0,0,0,0.18);
  width: 160px;
  display: flex;
  flex-direction: column;
  gap: .3rem;
  animation: picker-in .12s ease;
}
@keyframes picker-in {
  from { opacity: 0; transform: scale(0.95) translateY(-4px); }
  to   { opacity: 1; transform: scale(1)    translateY(0); }
}
.status-picker-fixed .picker-date {
  font-size: .7rem; font-weight: 700; color: #8E8A99;
  text-align: center;
  padding-bottom: .35rem;
  border-bottom: 1px solid #DBDADE;
  margin-bottom: .1rem;
}
.status-picker-fixed .picker-btn {
  display: flex; align-items: center; gap: .5rem;
  padding: .44rem .75rem;
  border-radius: 9px;
  font-size: .82rem; font-weight: 700;
  transition: all .13s;
  text-align: left;
  width: 100%;
  cursor: pointer;
  border: none;
  background: var(--btn-bg, #F5F5F5);
  color: var(--btn-color, #4B465C);
  font-family: inherit;
}
.status-picker-fixed .picker-btn:hover { filter: brightness(0.92); transform: scale(1.02); }
.status-picker-fixed .picker-btn.picker-active { outline: 2px solid var(--btn-color); }
.status-picker-fixed .picker-icon { font-size: .9rem; }
.status-picker-fixed .picker-clear {
  --btn-bg: #F5F5F5 !important;
  --btn-color: #9CA3AF !important;
  margin-top: .1rem;
  font-size: .76rem;
  justify-content: center;
  border-top: 1px solid #DBDADE;
  border-radius: 0 0 9px 9px;
  padding-top: .4rem;
}
.teachers-list-inline { display: flex; flex-wrap: wrap; gap: 0.25rem; }
.teachers-list-inline .value { font-size: 0.95rem; font-weight: 700; color: var(--dark); }

.teachers-checkbox-list {
  display: grid;
  grid-template-columns: 1fr;
  gap: 0.25rem;
  max-height: 120px;
  overflow-y: auto;
  padding: 0.5rem;
  background: var(--light);
  border: 1.5px solid var(--border);
  border-radius: 12px;
}
.teacher-checkbox-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.85rem;
  font-weight: 600;
  cursor: pointer;
  margin-bottom: 0;
}
.teacher-checkbox-item input { width: auto; }
</style>
