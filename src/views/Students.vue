
<script setup>
import { 
  Plus, 
  Search, 
  MoreVertical, 
  GraduationCap,
  User,
  Phone,
  Users,
  Calendar,
  Trash2,
  X,
  Loader2,
  Edit,
  ChevronLeft,
  ChevronRight,
  AlertTriangle,
  Mail,
  Eye,
  CreditCard
} from 'lucide-vue-next';
import { ref, reactive, computed, onMounted, watch } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '../supabase.js';
import PaymentModal from '../components/PaymentModal.vue';
import { useI18n } from 'vue-i18n';

const router = useRouter();
const userRole = ref(localStorage.getItem('userRole') || 'regular');
const students = ref([]);
const teachers = ref([]);
const groups = ref([]);
const isLoading = ref(true);
const isSubmitting = ref(false);
const deletingStudentId = ref(null);
const activeDropdown = ref(null);
const searchQuery = ref('');
const currentPage = ref(1);
const itemsPerPage = 15;

const toggleDropdown = (id, event) => {
  event.stopPropagation();
  activeDropdown.value = activeDropdown.value === id ? null : id;
};

const closeDropdowns = () => {
  activeDropdown.value = null;
};

const loadData = async () => {
  isLoading.value = true;
  try {
    const userRole = localStorage.getItem('userRole');
    const teacherId = localStorage.getItem('userTeacherId');

    // 1. Fetch groups for the assignment dropdown (admins see all, teachers see theirs)
    let gQuery = supabase.from('groups').select('id, name').eq('status', 'Active');
    if (userRole === 'teacher' && teacherId) {
      gQuery = gQuery.eq('teacher_id', teacherId);
    }
    const { data: groupsData } = await gQuery;
    groups.value = groupsData || [];
    const teacherGroupIds = groups.value.map(g => g.id);

    // 2. Fetch students
    let sQuery = supabase
      .from('students')
      .select('*, groups(name, courses(name))')
      .order('created_at', { ascending: false });
    
    if (userRole === 'teacher' && teacherId) {
      // Only show students who are in the teacher's groups
      if (teacherGroupIds.length > 0) {
        sQuery = sQuery.in('group_id', teacherGroupIds);
      } else {
        // Teacher has no groups, so they have no students
        students.value = [];
        isLoading.value = false;
        return;
      }
    }

    const { data: studentsData, error: studentsError } = await sQuery;
    if (studentsError) throw studentsError;
    students.value = (studentsData || []).map(s => ({ ...s, isTeacher: false }));

    // 3. Fetch teachers for unified search
    const { data: teachersData, error: teachersError } = await supabase
      .from('teachers')
      .select('*')
      .order('created_at', { ascending: false });
    if (!teachersError) {
      teachers.value = (teachersData || []).map(t => ({ ...t, isTeacher: true }));
    }

    
  } catch (e) {
    console.error('Data loading error:', e.message);
    students.value = [];
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  document.addEventListener('click', closeDropdowns);
  loadData();
});

watch(searchQuery, () => {
  currentPage.value = 1;
});

const filteredStudents = computed(() => {
  let list = [...students.value, ...teachers.value];
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    const qDigits = q.replace(/\D/g, ''); // strip to only digits for phone search

    list = list.filter(item => {
      const nameMatch = item.name.toLowerCase().includes(q);
      
      const phoneDigits = item.phone ? item.phone.toString().replace(/\D/g, '') : '';
      const phone2Digits = item.phone2 ? item.phone2.toString().replace(/\D/g, '') : '';
      
      const phoneMatch = qDigits && (phoneDigits.includes(qDigits) || phone2Digits.includes(qDigits));
      
      return nameMatch || phoneMatch;
    });
  }
  return list;
});

const totalPages = computed(() => {
  return Math.ceil(filteredStudents.value.length / itemsPerPage);
});

const paginatedStudents = computed(() => {
  const start = (currentPage.value - 1) * itemsPerPage;
  const end = start + itemsPerPage;
  return filteredStudents.value.slice(start, end);
});

const setPage = (page) => {
  if (page < 1 || page > totalPages.value) return;
  currentPage.value = page;
};

// --- Delete Confirmation State ---
const showDeleteConfirm = ref(false);
const itemToDelete = ref(null);

const confirmDelete = (id) => {
  itemToDelete.value = id;
  showDeleteConfirm.value = true;
};

const cancelDelete = () => {
  itemToDelete.value = null;
  showDeleteConfirm.value = false;
};

const deleteStudent = async () => {
  if (deletingStudentId.value || !itemToDelete.value) return;
  
  const id = itemToDelete.value;
  deletingStudentId.value = id;
  try {
    const studentToArchive = students.value.find(s => s.id === id);
    if (studentToArchive) {
      const { error: archError } = await supabase.from('archives').insert([{
        type: 'student',
        original_id: String(id),
        data: studentToArchive,
        archived_at: new Date().toISOString()
      }]);
      if (archError) throw archError;
    }

    const { error } = await supabase.from('students').delete().eq('id', id);
    if (error) throw error;
    students.value = students.value.filter(s => s.id !== id);
    activeDropdown.value = null;
    showDeleteConfirm.value = false;
  } catch (e) {
    console.error('Error deleting student:', e);
  } finally {
    deletingStudentId.value = null;
    itemToDelete.value = null;
  }
};

const goToStudentDetail = (id) => {
  if (id) router.push(`/students/${id}`);
};

const goToGroup = (id) => {
  if (id) router.push(`/groups/${id}`);
};

// --- Modal State ---
const showModal = ref(false);
const showPaymentModal = ref(false);
const selectedStudentForPayment = ref(null);
const isEditing = ref(false);
const editingId = ref(null);

const studentForm = reactive({
  name: '',
  phone: '',
  phone2: '',
  group_id: '',
  status: 'Active',
  created_at: new Date().toISOString().split('T')[0]
});

const openAddModal = () => {
  isEditing.value = false;
  editingId.value = null;
  studentForm.name = '';
  studentForm.phone = '';
  studentForm.phone2 = '';
  studentForm.group_id = '';
  studentForm.status = 'Active';
  studentForm.created_at = new Date().toISOString().split('T')[0];
  showModal.value = true;
};

const openEditModal = (student) => {
  isEditing.value = true;
  editingId.value = student.id;
  studentForm.name = student.name;
  studentForm.phone = student.phone || '';
  studentForm.phone2 = student.phone2 || '';
  studentForm.group_id = student.group_id || '';
  studentForm.status = student.status || 'Active';
  studentForm.created_at = student.created_at ? new Date(student.created_at).toISOString().split('T')[0] : new Date().toISOString().split('T')[0];
  showModal.value = true;
};

const closeModal = () => {
  showModal.value = false;
};

const openPaymentModal = (student) => {
  selectedStudentForPayment.value = student;
  showPaymentModal.value = true;
};

const closePaymentModal = () => {
  showPaymentModal.value = false;
  selectedStudentForPayment.value = null;
};

const onPaymentSuccess = () => {
  loadData();
};

const submitForm = async () => {
  if (!studentForm.name || isSubmitting.value) return;
  
  isSubmitting.value = true;
  const dbStudent = {
  name: studentForm.name,
  phone: studentForm.phone,
  phone2: studentForm.phone2,
  group_id: studentForm.group_id || null,
  status: studentForm.status,
  created_at: studentForm.created_at ? new Date(studentForm.created_at).toISOString() : new Date().toISOString(),
  updated_at: new Date().toISOString()
};

  try {
    if (isEditing.value) {
      const { error } = await supabase
        .from('students')
        .update(dbStudent)
        .eq('id', editingId.value);
      if (error) throw error;
    } else {
      const { error } = await supabase
        .from('students')
        .insert([dbStudent]);
      if (error) throw error;
    }
    await loadData();
    closeModal();
  } catch (e) {
    console.error('Error saving student:', e);
    alert('Error saving student. Please ensure the "students" table exists in your Supabase database.');
  } finally {
    isSubmitting.value = false;
  }
};

const getStatusClass = (status) => {
  if (status === 'Active') return 'status-active';
  if (status === 'Left') return 'status-left';
  if (status === 'Trial') return 'status-trial';
  return 'status-finished';
};

const formatDate = (dateStr) => {
  if (!dateStr) return '-';
  const date = new Date(dateStr);
  return date.toLocaleDateString();
};
</script>

<template>
  <div class="students-page">
    <div class="page-header">
      <div class="header-content">
        <h1>{{ $t('students.title') }}</h1>
        <p>{{ $t('students.subtitle') }}</p>
      </div>
      <button v-if="userRole === 'admin'" class="btn-primary" @click="openAddModal">
        <Plus :size="20" /> 
        {{ $t('students.addNew') }}
      </button>
    </div>

    <div class="table-container card">
      <div class="table-header">
        <div class="search-bar">
          <Search :size="18" />
          <input 
            type="text" 
            v-model="searchQuery" 
            :placeholder="$t('students.searchPlaceholder')" 
            @input="currentPage = 1"
          />
        </div>
      </div>

      <div class="table-scroll-wrapper">
        <table>
          <thead>
            <tr>
              <th>{{ $t('students.name') }}</th>
              <th>{{ $t('students.phone') }}</th>
              <th>{{ $t('students.group') }}</th>
              <th>{{ $t('students.course') }}</th>
              <th>{{ $t('students.addedDate') }}</th>
              <th>{{ $t('students.status') }}</th>
              <th class="text-right">{{ $t('common.actions') }}</th>
            </tr>
          </thead>
          <tbody>
            <template v-if="isLoading">
              <tr v-for="i in 5" :key="i">
                <td>
                  <div class="student-info">
                    <div class="skeleton" style="width: 40px; height: 40px; border-radius: 50%;"></div>
                    <div class="details">
                      <div class="skeleton" style="width: 140px; height: 16px; margin-bottom: 4px;"></div>
                    </div>
                  </div>
                </td>
                <td><div class="skeleton" style="width: 100px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 80px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 100px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 80px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 70px; height: 26px; border-radius: 8px;"></div></td>
                <td>
                  <div style="display: flex; gap: 0.5rem; justify-content: flex-end;">
                    <div class="skeleton" style="width: 32px; height: 32px; border-radius: 8px;"></div>
                    <div v-if="userRole === 'admin'" class="skeleton" style="width: 32px; height: 32px; border-radius: 8px;"></div>
                  </div>
                </td>
              </tr>
            </template>

            <template v-else>
              <tr v-if="paginatedStudents.length === 0">
                <td :colspan="7" class="no-data">{{ $t('common.noData') }}</td>
              </tr>
              <tr v-for="item in paginatedStudents" :key="item.id">
                <td>
                  <div class="student-info">
                    <div class="student-avatar">
                      <img :src="`https://ui-avatars.com/api/?name=${encodeURIComponent(item.name)}&background=7366FF&color=fff`" :alt="item.name">
                    </div>
                    <div class="details">
                      <span class="name">
                        {{ item.name }}
                        <span v-if="item.isTeacher" class="teacher-badge">Teacher</span>
                      </span>
                    </div>
                  </div>
                </td>
                <td>
                  <div class="phone-column">
                    <div class="phone-item main">
                      <Phone :size="14" />
                      {{ item.phone || '-' }}
                    </div>
                    <div v-if="item.phone2" class="phone-item secondary">
                      <Phone :size="12" />
                      {{ item.phone2 }}
                    </div>
                  </div>
                </td>
                <td>
                  <div class="group-tag clickable" v-if="!item.isTeacher" @click="goToGroup(item.group_id)">
                    <Users :size="14" />
                    {{ item.groups?.name || '-' }}
                  </div>
                  <div class="teacher-subject-tag" v-else>
                    {{ item.subject || '-' }}
                  </div>
                </td>
                <td>
                  <span class="course-name">{{ item.isTeacher ? 'Staff' : (item.groups?.courses?.name || '-') }}</span>
                </td>
                <td>
                  <div class="date-info">
                    <Calendar :size="14" />
                    {{ formatDate(item.created_at) }}
                  </div>
                </td>
                <td>
                  <span :class="['status-badge', getStatusClass(item.status)]">
                    {{ $t('students.' + item.status.toLowerCase()) }}
                  </span>
                </td>
                <td>
                  <div class="actions-group" style="display: flex; align-items: center; justify-content: flex-end; gap: 0.75rem;">
                    <template v-if="!item.isTeacher">
                      <button class="btn-view-action" @click="goToStudentDetail(item.id)">
                        <Eye :size="20" />
                      </button>
                      <button class="btn-view-action payment-btn" @click="openPaymentModal(item)">
                        <CreditCard :size="20" />
                      </button>
                      <div class="dropdown-wrapper" v-if="userRole === 'admin'">
                        <button 
                          class="btn-icon-more" 
                          :class="{ active: activeDropdown === 'student-' + item.id }"
                          @click="(e) => toggleDropdown('student-' + item.id, e)"
                        >
                          <MoreVertical :size="20" />
                        </button>
                        <transition name="dropdown">
                          <div v-if="activeDropdown === 'student-' + item.id" class="dropdown-menu">
                            <button class="dropdown-item" @click="openEditModal(item)">
                              <Edit :size="16" /> {{ $t('common.edit') }}
                            </button>
                            <div class="dropdown-divider"></div>
                            <button class="dropdown-item danger" @click="confirmDelete(item.id)">
                              <Trash2 :size="16" /> 
                              {{ $t('common.delete') }}
                            </button>
                          </div>
                        </transition>
                      </div>
                    </template>
                    <template v-else>
                      <span style="font-size: 0.8rem; color: var(--gray);">View in Teachers</span>
                    </template>
                  </div>
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>

      <div v-if="totalPages > 1" class="pagination-footer">
        <div class="pagination-info">
          {{ $t('common.showing') }} 
          <b>{{ (currentPage - 1) * itemsPerPage + 1 }}-{{ Math.min(currentPage * itemsPerPage, filteredStudents.length) }}</b> 
          {{ $t('common.outOf') }} 
          <b>{{ filteredStudents.length }}</b>
        </div>
        <div class="pagination-controls">
          <button class="btn-page" :disabled="currentPage === 1" @click="setPage(currentPage - 1)">
            <ChevronLeft :size="18" />
          </button>
          <div class="page-numbers">
            <button 
              v-for="p in totalPages" 
              :key="p" 
              class="btn-number" 
              :class="{ active: currentPage === p }"
              @click="setPage(p)"
            >
              {{ p }}
            </button>
          </div>
          <button class="btn-page" :disabled="currentPage === totalPages" @click="setPage(currentPage + 1)">
            <ChevronRight :size="18" />
          </button>
        </div>
      </div>
    </div>

    <!-- Add/Edit Modal -->
    <transition name="modal">
      <div v-if="showModal" class="modal-overlay" @click.self="closeModal">
        <div class="modal-box">
          <div class="modal-header">
            <div class="modal-title-row">
              <div class="modal-icon"><Plus :size="22" /></div>
              <h2>{{ isEditing ? $t('students.editModalTitle') : $t('students.createModalTitle') }}</h2>
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
            <div class="form-group">
              <label>{{ $t('students.group') }}</label>
              <select v-model="studentForm.group_id">
                <option value="">{{ $t('students.groupPlaceholder') }}</option>
                <option v-for="g in groups" :key="g.id" :value="g.id">{{ g.name }}</option>
              </select>
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
              <template v-if="isSubmitting">
                <Loader2 :size="16" class="spin" /> {{ $t('common.loading') }}
              </template>
              <template v-else>{{ isEditing ? $t('common.save') : $t('common.add') }}</template>
            </button>
          </div>
        </div>
      </div>
    </transition>

    <!-- Delete Confirmation Modal -->
    <transition name="modal">
      <div v-if="showDeleteConfirm" class="modal-overlay" @click.self="cancelDelete">
        <div class="modal-box confirm-modal">
          <div class="modal-body text-center p-2rem">
            <div class="confirm-icon">
              <AlertTriangle :size="48" />
            </div>
            <h2 class="confirm-title">{{ $t('common.areYouSure') }}</h2>
            <p class="confirm-desc">{{ $t('students.deleteConfirm') }}</p>
            <div class="confirm-actions">
              <button class="btn-cancel" @click="cancelDelete" :disabled="deletingStudentId">{{ $t('common.cancel') }}</button>
              <button class="btn-danger-confirm" @click="deleteStudent" :disabled="deletingStudentId">
                <Loader2 v-if="deletingStudentId" :size="18" class="spin" />
                <span v-else>{{ $t('common.delete') }}</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </transition>
    <!-- Payment Modal -->
    <PaymentModal 
      :show="showPaymentModal"
      :initial-student-id="selectedStudentForPayment?.id"
      :initial-student-name="selectedStudentForPayment?.name"
      :initial-group-id="selectedStudentForPayment?.group_id"
      @close="closePaymentModal"
      @success="onPaymentSuccess"
    />
  </div>
</template>

<style scoped>
.students-page {
  padding: 2rem;
  background: var(--light);
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
}

.header-content h1 {
  font-size: 1.75rem;
  font-weight: 800;
  color: var(--dark);
}

.btn-primary {
  background: var(--primary);
  color: white;
  padding: 0.75rem 1.5rem;
  border-radius: 12px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.table-container {
  background: white;
  border-radius: 20px;
  box-shadow: var(--shadow);
  overflow: visible;
}

.table-header { padding: 1.5rem; border-bottom: 1px solid var(--border); }
.search-bar { display: flex; align-items: center; gap: 0.75rem; background: var(--light); padding: 0.6rem 1rem; border-radius: 12px; max-width: 350px; }
.search-bar input { background: transparent; border: none; outline: none; width: 100%; }

.table-scroll-wrapper { overflow-x: auto; padding-bottom: 8rem; }
table { width: 100%; border-collapse: collapse; }
th { text-align: left; padding: 1.25rem 1.5rem; background: #F8F9FA; font-size: 0.8rem; font-weight: 700; color: var(--gray); text-transform: uppercase; }
td { padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--border); }

.student-info { display: flex; align-items: center; gap: 0.75rem; }
.student-avatar { width: 40px; height: 40px; border-radius: 50%; overflow: hidden; border: 2px solid var(--primary-light); }
.student-avatar img { width: 100%; height: 100%; object-fit: cover; }
.name { font-weight: 700; color: var(--dark); }

.phone-column { display: flex; flex-direction: column; gap: 4px; }
.phone-item { display: flex; align-items: center; gap: 6px; }
.phone-item.main { color: var(--dark); font-weight: 500; font-size: 0.9rem; }
.phone-item.secondary { color: var(--gray); font-size: 0.8rem; opacity: 0.8; }
.phone-item svg { color: var(--primary); opacity: 0.7; }

.date-info { display: flex; align-items: center; gap: 0.4rem; color: var(--gray); font-size: 0.85rem; }
.group-tag { display: inline-flex; align-items: center; gap: 0.4rem; padding: 0.35rem 0.75rem; background: #f0f4ff; color: var(--primary); border-radius: 20px; font-size: 0.85rem; transition: all 0.2s; }
.group-tag.clickable { cursor: pointer; }
.group-tag.clickable:hover { background: var(--primary); color: white; transform: translateY(-1px); }
.teacher-subject-tag { display: inline-flex; align-items: center; gap: 0.4rem; padding: 0.35rem 0.75rem; background: #e0f2fe; color: #0284c7; border-radius: 20px; font-size: 0.85rem; font-weight: 600; }
.teacher-badge { font-size: 0.65rem; background: #0ea5e9; color: white; padding: 0.15rem 0.4rem; border-radius: 4px; margin-left: 0.4rem; font-weight: 700; text-transform: uppercase;}
.course-name { color: var(--gray); font-size: 0.85rem; }

.status-badge { padding: 0.35rem 0.75rem; border-radius: 8px; font-size: 0.75rem; font-weight: 700; }
.status-active { background: rgba(40, 199, 111, 0.1); color: var(--success); }
.status-left { background: rgba(234, 84, 85, 0.1); color: var(--danger); }
.status-finished { background: rgba(168, 170, 174, 0.1); color: #A8AAAE; }
.status-trial { background: rgba(115, 102, 255, 0.1); color: var(--primary); }

.pagination-footer { padding: 1.25rem 1.5rem; display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--border); }
.pagination-controls { display: flex; align-items: center; gap: 1rem; }
.page-numbers { display: flex; gap: 0.5rem; }
.btn-page, .btn-number { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 10px; border: 1px solid var(--border); background: white; font-weight: 600; }
.btn-number.active { background: var(--primary); color: white; border-color: var(--primary); }

.dropdown-wrapper { position: relative; display: flex; justify-content: flex-end; }
.btn-icon-more { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border-radius: 8px; color: var(--gray); }
.btn-icon-more:hover, .btn-icon-more.active { background: var(--primary); color: white; }
.dropdown-menu { position: absolute; top: 100%; right: 0; margin-top: 0.5rem; background: white; border: 1px solid var(--border); border-radius: 12px; padding: 0.5rem; box-shadow: 0 10px 40px rgba(0, 0, 0, 0.15); z-index: 1000; min-width: 180px; }
.dropdown-item { display: flex; align-items: center; gap: 0.75rem; padding: 0.75rem 1rem; width: 100%; border-radius: 8px; font-size: 0.9rem; font-weight: 600; color: var(--dark); }
.dropdown-item:hover { background: var(--primary-light); color: var(--primary); }
.dropdown-item.danger { color: var(--danger); }
.dropdown-divider { height: 1px; background: rgba(0, 0, 0, 0.05); margin: 0.4rem 0.5rem; }

.text-right { text-align: right; }
.btn-view-action { width: 38px; height: 38px; border-radius: 10px; display: flex; align-items: center; justify-content: center; color: var(--primary); background: var(--primary-light); transition: all 0.2s; border: none; cursor: pointer; }
.btn-view-action:hover { background: var(--primary); color: white; transform: scale(1.05); }
.btn-view-action.payment-btn { background: #F3E8FF; color: #7C3AED; border: 1.5px solid #E9D5FF; }
.btn-view-action.payment-btn:hover { background: #7C3AED; color: white; border-color: #7C3AED; }

.modal-overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0, 0, 0, 0.5); display: flex; align-items: center; justify-content: center; z-index: 10000; backdrop-filter: blur(4px); }
.modal-box { background: white; border-radius: 20px; width: 100%; max-width: 600px; overflow: hidden; }
.modal-header { padding: 1.5rem; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
.modal-title-row { display: flex; align-items: center; gap: 1rem; }
.modal-icon { width: 42px; height: 42px; background: var(--primary-light); color: var(--primary); border-radius: 12px; display: flex; align-items: center; justify-content: center; }
.modal-body { padding: 1.5rem; }
.form-group { margin-bottom: 1.25rem; }
.form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1.25rem; }
label { display: block; font-size: 0.85rem; font-weight: 700; margin-bottom: 0.5rem; }
input, select { width: 100%; padding: 0.75rem 1rem; border: 1.5px solid var(--border); border-radius: 12px; background: var(--light); outline: none; transition: all 0.2s; }
input:focus, select:focus { border-color: var(--primary); background: white; box-shadow: 0 0 0 4px var(--primary-light); }

.input-with-icon { position: relative; }
.input-with-icon .input-icon { position: absolute; left: 1rem; top: 50%; transform: translateY(-50%); color: var(--gray); pointer-events: none; }
.input-with-icon input { padding-left: 2.75rem; }

.modal-footer { padding: 1.5rem; background: #F8F9FA; display: flex; justify-content: flex-end; gap: 1rem; }
.btn-confirm-primary { background: var(--primary); color: white; padding: 0.75rem 2rem; border-radius: 12px; font-weight: 700; }
.btn-cancel-modal { padding: 0.75rem 1.5rem; font-weight: 600; color: var(--gray); }
.required { color: var(--danger); margin-left: 2px; }

.confirm-modal { max-width: 400px; }
.confirm-icon { width: 80px; height: 80px; background: #FFF5F5; color: var(--danger); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 1.5rem; }
.confirm-title { font-size: 1.5rem; font-weight: 800; color: var(--dark); text-align: center; margin-bottom: 0.75rem; }
.confirm-desc { color: var(--gray); text-align: center; margin-bottom: 2rem; }
.confirm-actions { display: flex; gap: 1rem; }
.btn-cancel { flex: 1; padding: 0.9rem; border-radius: 12px; background: var(--light); color: var(--gray); font-weight: 700; }
.btn-danger-confirm { flex: 1; padding: 0.9rem; border-radius: 12px; background: var(--danger); color: white; font-weight: 700; display: flex; align-items: center; justify-content: center; gap: 0.5rem; }

@media (max-width: 768px) {
  .page-header { flex-direction: column; align-items: flex-start; gap: 1rem; }
  .btn-primary { width: 100%; justify-content: center; }
  .form-row { grid-template-columns: 1fr; }
  .modal-box { width: 95%; max-height: 90vh; overflow-y: auto; }
  .table-scroll-wrapper { width: 100%; overflow-x: auto; -webkit-overflow-scrolling: touch; }
  table { min-width: 900px; }
  .confirm-actions { flex-direction: column; }
}

.modal-enter-active, .modal-leave-active { transition: opacity 0.3s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
.skeleton { background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%); background-size: 200% 100%; animation: skeleton-loading 1.5s infinite; }
@keyframes skeleton-loading { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }
</style>
