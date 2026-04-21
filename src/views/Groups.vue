
<script setup>
import { 
  Plus, 
  Search, 
  MoreVertical, 
  Users,
  BookOpen,
  User,
  Calendar,
  Clock,
  Trash2,
  X,
  Check,
  Loader2,
  Edit,
  ChevronLeft,
  ChevronRight,
  AlertTriangle,
  Eye
} from 'lucide-vue-next';
import { ref, reactive, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '../supabase.js';
const router = useRouter();
const userRole = ref(localStorage.getItem('userRole') || 'regular');

const groups = ref([]);
const courses = ref([]);
const teachers = ref([]);
const isLoading = ref(true);
const isSubmitting = ref(false);
const deletingGroupId = ref(null);
const activeDropdown = ref(null);
const searchQuery = ref('');
const currentPage = ref(1);
const itemsPerPage = 10;

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

    let query = supabase
      .from('groups')
      .select('*, courses(name), teachers!groups_teacher_id_fkey(name)')
      .eq('is_deleted', false)
      .order('created_at', { ascending: false });

    if (userRole === 'teacher' && teacherId) {
      // Show groups where teacher is either the primary teacher or in the teacher_ids array
      query = query.or(`teacher_id.eq.${teacherId},teacher_ids.cs.{${teacherId}}`);
    }
    
    const { data: groupsData, error: groupsError } = await query;
    if (groupsError) throw groupsError;
    groups.value = groupsData || [];

    // Fetch courses for dropdown
    const { data: coursesData } = await supabase
      .from('courses')
      .select('id, name');
    courses.value = coursesData || [];

    // Fetch teachers for dropdown
    const { data: teachersData } = await supabase
      .from('teachers')
      .select('id, name')
      .eq('is_deleted', false)
      .eq('status', 'Active');
    teachers.value = teachersData || [];

    // Fetch extra teacher details for groups with multiple teachers
    if (groupsData?.length > 0) {
      const allTeacherIds = [...new Set(groupsData.flatMap(g => g.teacher_ids || []))];
      if (allTeacherIds.length > 0) {
        const { data: extraTeachers } = await supabase
          .from('teachers')
          .select('id, name')
          .in('id', allTeacherIds);
        
        // Create a lookup map
        const teacherMap = {};
        (extraTeachers || []).forEach(t => teacherMap[t.id] = t.name);
        
        // Attach names to groups
        groups.value = groupsData.map(g => ({
          ...g,
          teacher_names: (g.teacher_ids || []).map(id => teacherMap[id]).filter(Boolean)
        }));
      } else {
        groups.value = groupsData.map(g => ({ ...g, teacher_names: [] }));
      }
    }
    
  } catch (e) {
    console.error('Data loading error:', e.message);
    // If table doesn't exist, we just show empty list
    groups.value = [];
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  document.addEventListener('click', closeDropdowns);
  loadData();
});

const filteredGroups = computed(() => {
  let list = groups.value;
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    list = list.filter(g => 
      g.name.toLowerCase().includes(q) || 
      g.courses?.name?.toLowerCase().includes(q)
    );
  }
  return list;
});

const totalPages = computed(() => {
  return Math.ceil(filteredGroups.value.length / itemsPerPage);
});

const paginatedGroups = computed(() => {
  const start = (currentPage.value - 1) * itemsPerPage;
  const end = start + itemsPerPage;
  return filteredGroups.value.slice(start, end);
});

const setPage = (page) => {
  if (page < 1 || page > totalPages.value) return;
  currentPage.value = page;
};

// --- Delete Confirmation State ---
// --- Specialized Delete Modal for Groups ---
const showDeleteConfirm = ref(false);
const itemToDelete = ref(null);
const deleteOption = ref('moveAnother'); // 'moveAnother', 'archiveWith', 'noGroup'
const targetGroupId = ref('');
const isDeleting = ref(false);

const groupsForTransfer = computed(() => {
  return groups.value.filter(g => g.id !== itemToDelete.value);
});

const confirmDelete = (id) => {
  itemToDelete.value = id;
  showDeleteConfirm.value = true;
};

const cancelDelete = () => {
  itemToDelete.value = null;
  showDeleteConfirm.value = false;
};

const deleteGroup = async () => {
  if (!itemToDelete.value || isDeleting.value) return;
  if (deleteOption.value === 'moveAnother' && !targetGroupId.value) {
    alert('Please select a target group for transfer.');
    return;
  }

  isDeleting.value = true;
  const id = itemToDelete.value;
  try {
    // 1. Handle students based on selected option
    const { data: groupStudents } = await supabase.from('students').select('*').eq('group_id', id);
    const students = groupStudents || [];
    if (deleteOption.value === 'moveAnother') {
      // Move to another group
      const { error: moveError } = await supabase
        .from('students')
        .update({ group_id: targetGroupId.value })
        .eq('group_id', id);
      if (moveError) throw moveError;

    } else if (deleteOption.value === 'noGroup') {
      // Move to Student list with no group
      const { error: resetError } = await supabase
        .from('students')
        .update({ group_id: null })
        .eq('group_id', id);
      if (resetError) throw resetError;

    } else if (deleteOption.value === 'archiveWith') {
      // SOFT DELETE students
      const { error: delStudError } = await supabase
        .from('students')
        .update({ 
          is_deleted: true, 
          deleted_at: new Date().toISOString() 
        })
        .eq('group_id', id);
      if (delStudError) throw delStudError;
    }

    // 2. SOFT DELETE the group itself
    const { error: deleteGroupErr } = await supabase
      .from('groups')
      .update({ 
        is_deleted: true, 
        deleted_at: new Date().toISOString() 
      })
      .eq('id', id);
    if (deleteGroupErr) throw deleteGroupErr;

    groups.value = groups.value.filter(g => g.id !== id);
    showDeleteConfirm.value = false;
  } catch (e) {
    console.error('Error in complex group deletion:', e);
    alert('Operation failed: ' + e.message);
  } finally {
    isDeleting.value = false;
    itemToDelete.value = null;
  }
};

// --- Modal State ---
const goToDetails = (id) => {
  router.push(`/groups/${id}`);
};
const showModal = ref(false);
const isEditing = ref(false);
const editingId = ref(null);

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

const openAddModal = () => {
  isEditing.value = false;
  editingId.value = null;
  groupForm.name = '';
  groupForm.course_id = '';
  groupForm.teacher_id = '';
  groupForm.teacher_ids = [];
  groupForm.days = 'Du-Chor-Ju';
  groupForm.time = '09:00';
  groupForm.status = 'Active';
  showModal.value = true;
};

const openEditModal = (group) => {
  isEditing.value = true;
  editingId.value = group.id;
  groupForm.name = group.name;
  groupForm.course_id = group.course_id;
  groupForm.teacher_id = group.teacher_id;
  groupForm.teacher_ids = group.teacher_ids || [];
  groupForm.days = group.days;
  groupForm.time = group.time;
  groupForm.status = group.status;
  showModal.value = true;
};

const closeModal = () => {
  showModal.value = false;
};

const submitForm = async () => {
  if (!groupForm.name || !groupForm.course_id || isSubmitting.value) return;
  
  isSubmitting.value = true;
  // Consolidate teachers: if we have a primary teacher_id but no teacher_ids array, use it.
  const finalTeacherId = groupForm.teacher_id || (groupForm.teacher_ids && groupForm.teacher_ids.length > 0 ? groupForm.teacher_ids[0] : null);
  const finalTeacherIds = groupForm.teacher_ids && groupForm.teacher_ids.length > 0 ? groupForm.teacher_ids : (finalTeacherId ? [finalTeacherId] : []);

  const dbGroup = {
    name: groupForm.name,
    course_id: groupForm.course_id,
    teacher_id: finalTeacherId,
    teacher_ids: finalTeacherIds,
    days: groupForm.days,
    time: groupForm.time,
    status: groupForm.status,
    updated_at: new Date().toISOString()
  };

  try {
    if (isEditing.value) {
      const { error } = await supabase
        .from('groups')
        .update(dbGroup)
        .eq('id', editingId.value);
      if (error) throw error;
    } else {
      dbGroup.created_at = new Date().toISOString();
      const { error } = await supabase
        .from('groups')
        .insert([dbGroup]);
      if (error) throw error;
    }
    await loadData();
    closeModal();
  } catch (e) {
    console.error('Error saving group:', e);
    alert('Error saving group. Please ensure the "groups" table exists in your Supabase database.');
  } finally {
    isSubmitting.value = false;
  }
};

const getStatusClass = (status) => {
  if (status === 'Active') return 'status-active';
  if (status === 'Pending') return 'status-pending';
  return 'status-finished';
};

const formatDate = (dateStr) => {
  if (!dateStr) return '-';
  const date = new Date(dateStr);
  return date.toLocaleDateString();
};
</script>

<template>
  <div class="groups-page">
    <div class="page-header">
      <div class="header-content">
        <h1>{{ $t('groups.title') }}</h1>
        <p>{{ $t('groups.subtitle') }}</p>
      </div>
      <button v-if="userRole === 'admin'" class="btn-primary" @click="openAddModal">
        <Plus :size="20" /> 
        {{ $t('groups.addNew') }}
      </button>
    </div>

    <div class="table-container card">
      <div class="table-header">
        <div class="search-bar">
          <Search :size="18" />
          <input 
            type="text" 
            v-model="searchQuery" 
            :placeholder="$t('groups.searchPlaceholder')" 
            @input="currentPage = 1"
          />
        </div>
      </div>

      <div class="table-scroll-wrapper">
        <table>
          <thead>
            <tr>
              <th>{{ $t('groups.name') }}</th>
              <th>{{ $t('groups.course') }}</th>
              <th>{{ $t('groups.teacher') }}</th>
              <th>{{ $t('groups.days') }}</th>
              <th>{{ $t('groups.time') }}</th>
              <th>{{ $t('groups.status') }}</th>
              <th>{{ $t('common.addedDate') }}</th>
              <th class="text-right"></th>
            </tr>
          </thead>
          <tbody>
            <template v-if="isLoading">
              <tr v-for="i in 5" :key="i">
                <td :data-label="$t('groups.name')">
                  <div class="skeleton" style="width: 120px; height: 16px; border-radius: 4px;"></div>
                </td>
                <td :data-label="$t('groups.course')"><div class="skeleton" style="width: 100px; height: 16px; border-radius: 4px;"></div></td>
                <td :data-label="$t('groups.teacher')"><div class="skeleton" style="width: 120px; height: 16px; border-radius: 4px;"></div></td>
                <td :data-label="$t('groups.days')"><div class="skeleton" style="width: 100px; height: 16px; border-radius: 4px;"></div></td>
                <td :data-label="$t('groups.time')"><div class="skeleton" style="width: 80px; height: 16px; border-radius: 4px;"></div></td>
                <td :data-label="$t('groups.status')"><div class="skeleton" style="width: 70px; height: 26px; border-radius: 8px;"></div></td>
                <td :data-label="$t('common.addedDate')"><div class="skeleton" style="width: 90px; height: 16px; border-radius: 4px;"></div></td>
                <td :data-label="$t('common.actions') || 'Actions'">
                  <div style="display: flex; gap: 0.75rem; justify-content: flex-end;">
                    <div class="skeleton" style="width: 38px; height: 38px; border-radius: 10px;"></div>
                    <div v-if="userRole === 'admin'" class="skeleton" style="width: 32px; height: 32px; border-radius: 8px;"></div>
                  </div>
                </td>
              </tr>
            </template>

            <template v-else>
              <tr v-if="paginatedGroups.length === 0">
                <td :colspan="8" class="no-data">{{ $t('common.noData') }}</td>
              </tr>
              <tr v-for="item in paginatedGroups" :key="item.id">
                <td :data-label="$t('groups.name')">
                  <div class="group-name-cell">
                    <span class="name">{{ item.name }}</span>
                  </div>
                </td>
                <td :data-label="$t('groups.course')">
                  <div class="course-tag">
                    <BookOpen :size="14" />
                    {{ item.courses?.name || '-' }}
                  </div>
                </td>
                <td :data-label="$t('groups.teacher')">
                  <div class="teacher-info-stack">
                    <template v-if="item.teacher_names?.length > 0">
                      <div v-for="tName in item.teacher_names" :key="tName" class="teacher-mini-badge">
                        <User :size="12" />
                        {{ tName }}
                      </div>
                    </template>
                    <template v-else-if="item.teachers?.name">
                      <div class="teacher-mini-badge">
                        <User :size="12" />
                        {{ item.teachers.name }}
                      </div>
                    </template>
                    <span v-else>-</span>
                  </div>
                </td>
                <td :data-label="$t('groups.days')">
                  <div class="days-info">
                    <Calendar :size="14" />
                    {{ item.days || '-' }}
                  </div>
                </td>
                <td :data-label="$t('groups.time')">
                  <div class="time-info">
                    <Clock :size="14" />
                    {{ item.time || '-' }}
                  </div>
                </td>
                <td :data-label="$t('groups.status')">
                  <span :class="['status-badge', getStatusClass(item.status)]">
                    {{ $t('groups.' + item.status.toLowerCase()) }}
                  </span>
                </td>
                <td :data-label="$t('common.addedDate')">
                  <div class="date-info">
                    <Calendar :size="14" />
                    {{ formatDate(item.created_at) }}
                  </div>
                </td>
                <td :data-label="$t('common.actions') || 'Actions'">
                  <div class="actions-group" style="display: flex; align-items: center; justify-content: flex-end; gap: 0.75rem;">
                    <button class="btn-view-action" @click="goToDetails(item.id)" title="View Details">
                      <Eye :size="20" />
                    </button>
                    <div class="dropdown-wrapper" v-if="userRole === 'admin'">
                    <button 
                      class="btn-icon-more" 
                      :class="{ active: activeDropdown === 'group-' + item.id }"
                      @click="(e) => toggleDropdown('group-' + item.id, e)"
                    >
                      <MoreVertical :size="20" />
                    </button>
                    <transition name="dropdown">
                      <div v-if="activeDropdown === 'group-' + item.id" class="dropdown-menu">
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
          <b>{{ (currentPage - 1) * itemsPerPage + 1 }}-{{ Math.min(currentPage * itemsPerPage, filteredGroups.length) }}</b> 
          {{ $t('common.outOf') }} 
          <b>{{ filteredGroups.length }}</b>
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
              <h2>{{ isEditing ? $t('groups.editModalTitle') : $t('groups.createModalTitle') }}</h2>
            </div>
            <button class="btn-icon" @click="closeModal"><X :size="20" /></button>
          </div>

          <div class="modal-body">
            <div class="form-group">
              <label>{{ $t('groups.name') }} <span class="required">*</span></label>
              <input v-model="groupForm.name" :placeholder="$t('groups.namePlaceholder')" />
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>{{ $t('groups.course') }} <span class="required">*</span></label>
                <select v-model="groupForm.course_id">
                  <option value="">{{ $t('groups.coursePlaceholder') }}</option>
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
                <label>{{ $t('groups.days') }}</label>
                <select v-model="groupForm.days">
                  <option v-for="pattern in dayPatterns" :key="pattern.value" :value="pattern.value">
                    {{ pattern.label }}
                  </option>
                  <option value="Custom">{{ $t('common.other') || 'Boshqa...' }}</option>
                </select>
                <input 
                  v-if="groupForm.days === 'Custom' || !dayPatterns.find(p => p.value === groupForm.days)" 
                  v-model="groupForm.days" 
                  class="mt-2"
                  :placeholder="$t('groups.daysPlaceholder')" 
                />
              </div>
              <div class="form-group">
                <label>{{ $t('groups.timeStarting') || 'Boshlanish vaqti' }}</label>
                <div class="input-with-icon">
                  <Clock :size="16" class="input-icon" />
                  <input type="time" v-model="groupForm.time" />
                </div>
              </div>
            </div>
            <div class="form-group" v-if="isEditing">
              <label>{{ $t('groups.status') }}</label>
              <select v-model="groupForm.status">
                <option value="Active">Faol</option>
                <option value="Finished">Yakunlangan</option>
              </select>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn-cancel-modal" @click="closeModal" :disabled="isSubmitting">{{ $t('common.cancel') }}</button>
            <button class="btn-confirm-primary" @click="submitForm" :disabled="!groupForm.name || !groupForm.course_id || isSubmitting">
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
                <div v-if="deleteOption === 'moveAnother'" class="target-group-select">
                  <select v-model="targetGroupId">
                    <option value="">{{ $t('groups.deleteModal.selectGroup') }}</option>
                    <option v-for="g in groupsForTransfer" :key="g.id" :value="g.id">{{ g.name }}</option>
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

            <div class="confirm-actions">
              <button class="btn-cancel" @click="cancelDelete" :disabled="isDeleting">{{ $t('common.cancel') }}</button>
              <button class="btn-danger-confirm" @click="deleteGroup" :disabled="isDeleting || (deleteOption === 'moveAnother' && !targetGroupId)">
                <Loader2 v-if="isDeleting" :size="18" class="spin" />
                <span v-else>{{ $t('groups.deleteModal.confirm') }}</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped>
.groups-page {
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

.group-name-cell { display: flex; align-items: center; gap: 0.5rem; }
.name { font-weight: 700; color: var(--dark); }

.text-center { text-align: center; }
.btn-view-action { width: 38px; height: 38px; border-radius: 10px; display: flex; align-items: center; justify-content: center; color: var(--primary); background: var(--primary-light); transition: all 0.2s; }
.btn-view-action:hover { background: var(--primary); color: white; transform: scale(1.05); }

.course-tag { display: inline-flex; align-items: center; gap: 0.4rem; padding: 0.35rem 0.75rem; background: #f0f4ff; color: var(--primary); border-radius: 20px; font-size: 0.85rem; }
.teacher-info, .days-info, .time-info { display: flex; align-items: center; gap: 0.4rem; color: var(--gray); font-size: 0.85rem; }

.status-badge { padding: 0.35rem 0.75rem; border-radius: 8px; font-size: 0.75rem; font-weight: 700; }
.status-active { background: rgba(40, 199, 111, 0.1); color: var(--success); }
.status-pending { background: rgba(255, 159, 67, 0.1); color: #FF9F43; }
.status-finished { background: rgba(168, 170, 174, 0.1); color: #A8AAAE; }

.teacher-info-stack { display: flex; flex-direction: column; gap: 0.25rem; }
.teacher-mini-badge { display: flex; align-items: center; gap: 0.3rem; font-size: 0.75rem; color: var(--gray); font-weight: 600; white-space: nowrap; }

.teachers-checkbox-list {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 0.5rem;
  max-height: 150px;
  overflow-y: auto;
  padding: 0.75rem;
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

.mt-2 { margin-top: 0.5rem; }

.modal-footer { padding: 1.5rem; background: #F8F9FA; display: flex; justify-content: flex-end; gap: 1rem; }
.btn-confirm-primary { background: var(--primary); color: white; padding: 0.75rem 2rem; border-radius: 12px; font-weight: 700; }
.btn-cancel-modal { padding: 0.75rem 1.5rem; font-weight: 600; color: var(--gray); }
.required { color: var(--danger); margin-left: 2px; }

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
}
.option-card:hover { border-color: var(--primary-light); background: white; }
.option-card.active { border-color: var(--primary); background: #f5f4ff; box-shadow: 0 4px 12px rgba(115,102,255,0.1); }
.option-name { font-weight: 700; color: var(--dark); font-size: 0.95rem; }
.option-check { width: 22px; height: 22px; border-radius: 50%; border: 2px solid var(--border); background: transparent; color: white; display: flex; align-items: center; justify-content: center; transition: all 0.2s; }
.option-card.active .option-check { border-color: var(--primary); background: var(--primary); }
.hidden-radio { display: none; }
.target-group-select { margin-top: -0.5rem; transition: all 0.3s ease; }

.confirm-modal { max-width: 480px; }
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
  table { min-width: 800px; }
  .confirm-actions { flex-direction: column; }
}

.modal-enter-active, .modal-leave-active { transition: opacity 0.3s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
.skeleton { background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%); background-size: 200% 100%; animation: skeleton-loading 1.5s infinite; }
@keyframes skeleton-loading { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }
</style>
