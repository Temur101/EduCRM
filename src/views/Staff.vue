
<script setup>
import { 
  Plus, 
  Search, 
  MoreVertical, 
  UserPlus,
  Mail,
  Phone,
  Calendar,
  Trash2,
  X,
  Loader2,
  Edit,
  Shield,
  ChevronLeft,
  ChevronRight,
  AlertTriangle,
  Lock,
  Check,
  Users
} from 'lucide-vue-next';
import { ref, reactive, computed, onMounted } from 'vue';
import { supabase } from '../supabase.js';

const staff = ref([]);
const allGroups = ref([]);
const isLoading = ref(true);
const isSubmitting = ref(false);
const deletingStaffId = ref(null);
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
    const { data, error } = await supabase
      .from('staff')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (error) {
       console.error('Error loading staff:', error.message);
       staff.value = [];
    } else {
       staff.value = data || [];
    }

    // Fetch all active groups to allow assignment for teachers
    const { data: groupsData, error: groupsError } = await supabase
      .from('groups')
      .select('id, name')
      .neq('status', 'Finished');
    if (!groupsError) allGroups.value = groupsData || [];
  } catch (e) {
    console.error('Catch error loading staff:', e.message);
    staff.value = [];
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  document.addEventListener('click', closeDropdowns);
  loadData();
});

const filteredStaff = computed(() => {
  let list = staff.value;
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    list = list.filter(s => 
      s.name.toLowerCase().includes(q) || 
      (s.email && s.email.toLowerCase().includes(q)) ||
      (s.phone && s.phone.includes(q))
    );
  }
  return list;
});

const totalPages = computed(() => {
  return Math.ceil(filteredStaff.value.length / itemsPerPage);
});

const paginatedStaff = computed(() => {
  // Show all staff as requested ("пусть все будет видно")
  return filteredStaff.value;
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

const deleteStaff = async () => {
  if (deletingStaffId.value || !itemToDelete.value) return;
  
  const id = itemToDelete.value;
  deletingStaffId.value = id;
  try {
    const person = staff.value.find(s => s.id === id);
    if (!person) throw new Error('Staff not found');

    // 1. Move to archives table
    const archiveData = {
      type: 'staff',
      original_id: String(id),
      data: person,
      archived_at: new Date().toISOString()
    };
    await supabase.from('archives').insert([archiveData]);

    // 2. Delete from staff table
    const { error: deleteError } = await supabase.from('staff').delete().eq('id', id);
    if (deleteError) throw deleteError;

    staff.value = staff.value.filter(s => s.id !== id);
    activeDropdown.value = null;
    showDeleteConfirm.value = false;
  } catch (e) {
    console.error('Error deleting staff:', e);
    alert('Failed to delete staff: ' + e.message);
  } finally {
    deletingStaffId.value = null;
    itemToDelete.value = null;
  }
};

// --- Modal State ---
const showModal = ref(false);
const isEditing = ref(false);
const editingId = ref(null);

const staffForm = reactive({
  name: '',
  phone: '',
  email: '',
  role: 'regular',
  password: '',
  teacher_subject: '',
  teacher_schedule: '',
  groupIds: []
});

const toggleGroupSelection = (groupId) => {
  const index = staffForm.groupIds.indexOf(groupId);
  if (index === -1) {
    staffForm.groupIds.push(groupId);
  } else {
    staffForm.groupIds.splice(index, 1);
  }
};

const openAddModal = () => {
  isEditing.value = false;
  editingId.value = null;
  staffForm.name = '';
  staffForm.phone = '';
  staffForm.email = '';
  staffForm.role = 'regular';
  staffForm.password = '';
  staffForm.teacher_subject = '';
  staffForm.teacher_schedule = '';
  staffForm.groupIds = [];
  showModal.value = true;
};

const openEditModal = (person) => {
  isEditing.value = true;
  editingId.value = person.id;
  staffForm.name = person.name;
  staffForm.phone = person.phone;
  staffForm.email = person.email;
  staffForm.role = person.role || 'regular';
  staffForm.password = person.password || '';
  staffForm.teacher_subject = person.teacher_subject || '';
  staffForm.teacher_schedule = person.teacher_schedule || '';
  // Fetch groups where this staff is assigned
  staffForm.groupIds = [];
  fetchGroupsForStaff(person.id);
  showModal.value = true;
};

const fetchGroupsForStaff = async (staffId) => {
  const { data, error } = await supabase
    .from('groups')
    .select('id')
    .eq('teacher_id', staffId);
  if (!error && data) {
    staffForm.groupIds = data.map(g => g.id);
  }
};

const closeModal = () => {
  showModal.value = false;
};

const submitForm = async () => {
  if (!staffForm.name || !staffForm.password || isSubmitting.value) return;
  
  isSubmitting.value = true;
  const dbStaff = {
    name: staffForm.name,
    phone: staffForm.phone,
    email: staffForm.email,
    role: staffForm.role,
    password: staffForm.password,
    updated_at: new Date().toISOString()
  };

  if (staffForm.role === 'teacher') {
    dbStaff.teacher_subject = staffForm.teacher_subject;
    dbStaff.teacher_schedule = staffForm.teacher_schedule;
  }

  try {
    let currentStaffId = editingId.value;
    if (isEditing.value) {
      const { error } = await supabase
        .from('staff')
        .update(dbStaff)
        .eq('id', editingId.value);
      if (error) throw error;
    } else {
      dbStaff.created_at = new Date().toISOString();
      const { data: newStaffData, error } = await supabase
        .from('staff')
        .insert([dbStaff])
        .select()
        .single();
      if (error) throw error;
      currentStaffId = newStaffData.id;
    }

    if (staffForm.role === 'teacher' && currentStaffId) {
      // 1. Remove this staff from any groups they were previously assigned to
      await supabase.from('groups').update({ teacher_id: null }).eq('teacher_id', currentStaffId);
      // 2. Assign this staff to the newly selected groups
      if (staffForm.groupIds && staffForm.groupIds.length > 0) {
        await supabase.from('groups').update({ teacher_id: currentStaffId }).in('id', staffForm.groupIds);
      }
    }
    await loadData();
    closeModal();
  } catch (e) {
    console.error('Error saving staff:', e);
    alert('Error saving staff.');
  } finally {
    isSubmitting.value = false;
  }
};
</script>

<template>
  <div class="staff-page">
    <div class="page-header">
      <div class="header-content">
        <h1>{{ $t('sidebar.staff') }}</h1>
        <p>{{ $t('staff.subtitle') || 'Manage platform users and roles' }}</p>
      </div>
      <button class="btn-primary" @click="openAddModal">
        <Plus :size="20" /> 
        {{ $t('staff.addNew') || 'Add New User' }}
      </button>
    </div>

    <div class="table-container card">
      <div class="table-header">
        <div class="search-bar">
          <Search :size="18" />
          <input 
            type="text" 
            v-model="searchQuery" 
            :placeholder="$t('common.searchPlaceholder')" 
            @input="currentPage = 1"
          />
        </div>
      </div>

      <div class="table-scroll-wrapper">
        <table>
          <thead>
            <tr>
              <th>{{ $t('staff.name') || 'NAME' }}</th>
              <th>{{ $t('staff.role') || 'ROLE' }}</th>
              <th>{{ $t('staff.phone') || 'PHONE' }}</th>
              <th>{{ $t('common.addedDate') }}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <template v-if="isLoading">
              <tr v-for="i in 5" :key="i">
                <td>
                  <div class="staff-info">
                    <div class="skeleton" style="width: 40px; height: 40px; border-radius: 50%;"></div>
                    <div class="details">
                      <div class="skeleton" style="width: 140px; height: 16px; margin-bottom: 4px;"></div>
                    </div>
                  </div>
                </td>
                <td><div class="skeleton" style="width: 80px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 100px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 90px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 24px; height: 24px; border-radius: 6px;"></div></td>
              </tr>
            </template>

            <template v-else>
              <tr v-if="paginatedStaff.length === 0">
                <td colspan="5" class="no-data">{{ $t('common.noData') }}</td>
              </tr>
              <tr v-for="item in paginatedStaff" :key="item.id">
                <td>
                  <div class="staff-info">
                    <div class="avatar">{{ item.name.charAt(0) }}</div>
                    <div class="details">
                      <span class="name">{{ item.name }}</span>
                      <span class="email">{{ item.email || '-' }}</span>
                    </div>
                  </div>
                </td>
                <td>
                  <div class="role-tag" :class="item.role">
                    <Shield :size="14" />
                    {{ $t('roles.' + item.role) || item.role }}
                  </div>
                </td>
                <td>{{ item.phone || '-' }}</td>
                <td>
                  <div class="date-info">
                    <Calendar :size="14" />
                    {{ new Date(item.created_at).toLocaleDateString() }}
                  </div>
                </td>
                <td>
                  <div class="dropdown-wrapper">
                    <button 
                      class="btn-icon-more" 
                      :class="{ active: activeDropdown === 'staff-' + item.id }"
                      @click="(e) => toggleDropdown('staff-' + item.id, e)"
                    >
                      <MoreVertical :size="20" />
                    </button>
                    <transition name="dropdown">
                      <div v-if="activeDropdown === 'staff-' + item.id" class="dropdown-menu">
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
                </td>
              </tr>
            </template>
          </tbody>
        </table>
      </div>

      <!-- Pagination hidden as requested to show all items -->
      <div v-if="false && totalPages > 1" class="pagination-footer">
        <div class="pagination-info">
          {{ $t('common.showing') }} 
          <b>{{ (currentPage - 1) * itemsPerPage + 1 }}-{{ Math.min(currentPage * itemsPerPage, filteredStaff.length) }}</b> 
          {{ $t('common.outOf') }} 
          <b>{{ filteredStaff.length }}</b>
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
              <div class="modal-icon"><UserPlus :size="22" /></div>
              <h2>{{ isEditing ? ($t('staff.editModalTitle') || 'Edit User') : ($t('staff.createModalTitle') || 'Create New User') }}</h2>
            </div>
            <button class="btn-icon" @click="closeModal"><X :size="20" /></button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>{{ $t('staff.name') || 'Name' }} <span class="required">*</span></label>
              <input v-model="staffForm.name" :placeholder="$t('teachers.namePlaceholder') || 'например, Иван Петров'" />
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>{{ $t('staff.role') || 'Role' }} <span class="required">*</span></label>
                <select v-model="staffForm.role">
                  <option value="regular">{{ $t('roles.regular') }}</option>
                  <option value="admin">{{ $t('roles.admin') }}</option>
                  <option value="teacher">{{ $t('roles.teacher') }}</option>
                </select>
              </div>
              <div class="form-group" v-if="staffForm.role === 'teacher'">
                <label>{{ $t('teachers.subject') || 'Предмет / Кафедра' }} <span class="required">*</span></label>
                <input v-model="staffForm.teacher_subject" :placeholder="$t('teachers.subjectPlaceholder') || 'например, Английский, Математика'" />
              </div>
            </div>

            <div class="form-row">
              <div class="form-group">
                <label>{{ $t('staff.phone') || 'Номер телефона' }}</label>
                <input v-model="staffForm.phone" placeholder="+998 90 000 0000" />
              </div>
              <div class="form-group">
                <label>{{ $t('common.password') }} <span class="required">*</span></label>
                <div class="input-with-icon">
                  <Lock :size="18" class="input-icon" />
                  <input v-model="staffForm.password" type="password" :placeholder="$t('common.passwordPlaceholder')" />
                </div>
              </div>
            </div>

            <div class="form-group">
              <label>{{ $t('staff.email') || 'Электронная почта' }}</label>
              <input v-model="staffForm.email" :placeholder="$t('teachers.emailPlaceholder') || 'uchitel@example.com'" />
            </div>

            <div class="form-group" v-if="staffForm.role === 'teacher'">
              <label>{{ $t('staff.teacherSchedule') || 'График работы' }}</label>
              <textarea v-model="staffForm.teacher_schedule" :placeholder="$t('staff.teacherSchedulePlaceholder')" class="form-textarea"></textarea>
            </div>

            <!-- Group Assignment Section for Teachers -->
            <div class="form-group" v-if="staffForm.role === 'teacher'" style="grid-column: 1 / -1; margin-top: 1rem;">
              <label style="font-size: 1rem; margin-bottom: 1rem; display: flex; align-items: center; gap: 0.5rem;">
                <Users :size="18" /> Assign Groups
              </label>
              <div class="groups-checkbox-grid">
                <label 
                  v-for="group in allGroups" 
                  :key="group.id" 
                  class="checkbox-card"
                  :class="{ active: staffForm.groupIds.includes(group.id) }"
                >
                  <input 
                    type="checkbox" 
                    :value="group.id"
                    :checked="staffForm.groupIds.includes(group.id)"
                    @change="toggleGroupSelection(group.id)"
                    class="hidden-radio"
                  />
                  <span class="group-select-name">{{ group.name }}</span>
                  <div class="checkbox-indicator">
                    <Check v-if="staffForm.groupIds.includes(group.id)" :size="14" />
                  </div>
                </label>
              </div>
              <p v-if="allGroups.length === 0" class="text-muted" style="margin-top: 0.5rem; font-size: 0.85rem;">No active groups available to assign.</p>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn-cancel-modal" @click="closeModal" :disabled="isSubmitting">{{ $t('common.cancel') }}</button>
            <button class="btn-confirm-primary" @click="submitForm" :disabled="!staffForm.name || !staffForm.password || isSubmitting">
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
            <p class="confirm-desc">{{ $t('staff.deleteConfirm') || 'This user will be archived and removed from active staff.' }}</p>
            <div class="confirm-actions">
              <button class="btn-cancel" @click="cancelDelete" :disabled="deletingStaffId">{{ $t('common.cancel') }}</button>
              <button class="btn-danger-confirm" @click="deleteStaff" :disabled="deletingStaffId">
                <Loader2 v-if="deletingStaffId" :size="18" class="spin" />
                <span v-else>{{ $t('common.delete') }}</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped>
.staff-page { padding: 2rem; background: var(--light); }
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem; }
.header-content h1 { font-size: 1.75rem; font-weight: 800; color: var(--dark); }

.btn-primary { background: var(--primary); color: white; padding: 0.75rem 1.5rem; border-radius: 12px; font-weight: 600; display: flex; align-items: center; gap: 0.5rem; }

.table-container { background: white; border-radius: 20px; box-shadow: var(--shadow); overflow: visible; }
.table-header { padding: 1.5rem; border-bottom: 1px solid var(--border); }
.search-bar { display: flex; align-items: center; gap: 0.75rem; background: var(--light); padding: 0.6rem 1rem; border-radius: 12px; max-width: 350px; }
.search-bar input { background: transparent; border: none; outline: none; width: 100%; }

.table-scroll-wrapper { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; }
th { text-align: left; padding: 1.25rem 1.5rem; background: #F8F9FA; font-size: 0.8rem; font-weight: 700; color: var(--gray); text-transform: uppercase; }
td { padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--border); }

.staff-info { display: flex; align-items: center; gap: 0.75rem; }
.avatar { width: 40px; height: 40px; background: var(--primary-light); color: var(--primary); border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 700; }
.details { display: flex; flex-direction: column; }
.name { font-weight: 700; color: var(--dark); }
.email { font-size: 0.75rem; color: var(--gray); }

.role-tag { display: inline-flex; align-items: center; gap: 0.4rem; padding: 0.35rem 0.75rem; border-radius: 20px; font-size: 0.85rem; font-weight: 600; }
.role-tag.admin { background: rgba(115, 102, 255, 0.1); color: var(--primary); }
.role-tag.teacher { background: rgba(40, 199, 111, 0.1); color: var(--success); }
.role-tag.regular { background: rgba(0, 207, 232, 0.1); color: var(--info); }

.form-textarea {
  width: 100%;
  padding: 0.75rem 1rem;
  border: 1.5px solid var(--border);
  border-radius: 12px;
  background: var(--light);
  outline: none;
  transition: all 0.2s;
  min-height: 80px;
  font-family: inherit;
}
.form-textarea:focus {
  border-color: var(--primary);
  background: white;
  box-shadow: 0 0 0 4px var(--primary-light);
}

.teacher-fields-section {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  margin-top: 1rem;
  padding-top: 1rem;
  border-top: 1px dashed var(--border);
}

.date-info { display: flex; align-items: center; gap: 0.4rem; color: var(--gray); font-size: 0.85rem; }

.btn-icon-more { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border-radius: 8px; color: var(--gray); }
.btn-icon-more:hover, .btn-icon-more.active { background: var(--primary); color: white; }

.dropdown-wrapper { position: relative; display: flex; justify-content: flex-end; }
.dropdown-menu { position: absolute; top: 100%; right: 0; margin-top: 0.5rem; background: white; border: 1px solid var(--border); border-radius: 12px; padding: 0.5rem; box-shadow: 0 10px 40px rgba(0, 0, 0, 0.15); z-index: 1000; min-width: 180px; }
.dropdown-item { display: flex; align-items: center; gap: 0.75rem; padding: 0.75rem 1rem; width: 100%; border-radius: 8px; font-size: 0.9rem; font-weight: 600; color: var(--dark); }
.dropdown-item:hover { background: var(--primary-light); color: var(--primary); }
.dropdown-item.danger { color: var(--danger); }
.dropdown-divider { height: 1px; background: rgba(0, 0, 0, 0.05); margin: 0.4rem 0.5rem; }

.modal-overlay { position: fixed; top: 0; left: 0; right: 0; bottom: 0; background: rgba(0, 0, 0, 0.5); display: flex; align-items: center; justify-content: center; z-index: 10000; backdrop-filter: blur(4px); }
.modal-box { background: white; border-radius: 20px; width: 100%; max-width: 600px; max-height: 90vh; display: flex; flex-direction: column; overflow: hidden; }
.modal-header { padding: 1.5rem; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
.modal-title-row { display: flex; align-items: center; gap: 1rem; }
.modal-icon { width: 42px; height: 42px; background: var(--primary-light); color: var(--primary); border-radius: 12px; display: flex; align-items: center; justify-content: center; }
.modal-body { padding: 1.5rem; overflow-y: auto; flex: 1; }
.form-group { margin-bottom: 1.25rem; }
.form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1.25rem; }
label { display: block; font-size: 0.85rem; font-weight: 700; margin-bottom: 0.5rem; }
input, select { width: 100%; padding: 0.75rem 1rem; border: 1.5px solid var(--border); border-radius: 12px; background: var(--light); outline: none; transition: all 0.2s; }
input:focus, select:focus { border-color: var(--primary); background: white; box-shadow: 0 0 0 4px var(--primary-light); }

.input-with-icon { position: relative; }
.input-icon { position: absolute; left: 1rem; top: 50%; transform: translateY(-50%); color: var(--primary); }
.input-with-icon input { padding-left: 2.75rem; }

.modal-footer { padding: 1.5rem; background: #F8F9FA; display: flex; justify-content: flex-end; gap: 1rem; }
.btn-confirm-primary { background: var(--primary); color: white; padding: 0.75rem 2rem; border-radius: 12px; font-weight: 700; }
.btn-cancel-modal { padding: 0.75rem 1.5rem; font-weight: 600; color: var(--gray); }
.required { color: var(--danger); margin-left: 2px; }

.confirm-modal { max-width: 400px; }
.confirm-icon { width: 80px; height: 80px; background: #FFF5F5; color: var(--danger); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 1.5rem; }
.confirm-title { font-size: 1.5rem; font-weight: 800; color: var(--dark); text-align: center; margin-bottom: 0.75rem; }
.confirm-desc { color: var(--gray); text-align: center; margin-bottom: 2rem; padding: 0 1rem; }
.confirm-actions { display: flex; gap: 1rem; }
.btn-cancel { flex: 1; padding: 0.9rem; border-radius: 12px; background: var(--light); color: var(--gray); font-weight: 700; }
.btn-danger-confirm { flex: 1; padding: 0.9rem; border-radius: 12px; background: var(--danger); color: white; font-weight: 700; display: flex; align-items: center; justify-content: center; gap: 0.5rem; }

@media (max-width: 768px) {
  .page-header { flex-direction: column; align-items: flex-start; gap: 1rem; }
  .btn-primary { width: 100%; justify-content: center; }
  .form-row { grid-template-columns: 1fr; }
  .modal-box { width: 95%; max-height: 90vh; overflow-y: auto; }
}

.modal-enter-active, .modal-leave-active { transition: opacity 0.3s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
.skeleton { background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%); background-size: 200% 100%; animation: skeleton-loading 1.5s infinite; }
@keyframes skeleton-loading { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }

.groups-checkbox-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 0.75rem; max-height: 250px; overflow-y: auto; padding: 0.25rem; }
.checkbox-card { display: flex; justify-content: space-between; align-items: center; padding: 0.75rem 1rem; border: 1.5px solid var(--border); border-radius: 12px; cursor: pointer; transition: all 0.2s; background: var(--light); user-select: none; }
.checkbox-card:hover { border-color: var(--primary-light); }
.checkbox-card.active { border-color: var(--primary); background: #fdfcff; }
.hidden-radio { display: none; }
.group-select-name { font-size: 0.9rem; font-weight: 600; color: var(--dark); }
.checkbox-indicator { width: 20px; height: 20px; border-radius: 6px; border: 2px solid var(--border); display: flex; align-items: center; justify-content: center; background: white; color: white; transition: all 0.2s; }
.checkbox-card.active .checkbox-indicator { background: var(--primary); border-color: var(--primary); }
</style>
