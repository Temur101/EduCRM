
<script setup>
import { 
  Plus, 
  Search, 
  MoreVertical, 
  UserPlus,
  Mail,
  Phone,
  GraduationCap,
  Calendar,
  DollarSign,
  Trash2,
  X,
  Check,
  Loader2,
  Edit,
  Briefcase,
  ChevronLeft,
  ChevronRight,
  AlertTriangle,
  Lock,
  ChevronDown,
  ChevronUp,
  Users
} from 'lucide-vue-next';
import { ref, reactive, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { supabase } from '../supabase.js';

const router = useRouter();

const teachers = ref([]);
const allGroups = ref([]);
const isLoading = ref(true);
const isSubmitting = ref(false);
const deletingTeacherId = ref(null);
const activeDropdown = ref(null);
const searchQuery = ref('');
const currentPage = ref(1);
const itemsPerPage = 10;
const groupSearchQuery = ref('');

const toggleDropdown = (id, event) => {
  event.stopPropagation();
  activeDropdown.value = activeDropdown.value === id ? null : id;
};

const closeDropdowns = () => {
  activeDropdown.value = null;
};

const expandedTeacherId = ref(null);
const toggleRow = (id) => {
  expandedTeacherId.value = expandedTeacherId.value === id ? null : id;
};

const goToGroup = (id) => {
  router.push('/groups/' + id);
};

const loadData = async () => {
  isLoading.value = true;
  try {
    const { data, error } = await supabase
      .from('teachers')
      .select('*, groups(id, name, status)')
      .eq('is_deleted', false)
      .order('created_at', { ascending: false });
    
    if (error) throw error;
    teachers.value = data;

    // Fetch all active groups to allow assignment
    const { data: groupsData, error: groupsError } = await supabase
      .from('groups')
      .select('id, name')
      .eq('is_deleted', false)
      .neq('status', 'Finished');
    if (!groupsError) allGroups.value = groupsData || [];

  } catch (e) {
    console.error('Error loading teachers:', e.message);
    teachers.value = [];
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  document.addEventListener('click', closeDropdowns);
  loadData();
});

const filteredTeachers = computed(() => {
  let list = teachers.value;
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    list = list.filter(t => 
      t.name.toLowerCase().includes(q) || 
      t.subject.toLowerCase().includes(q) ||
      (t.phone && t.phone.toLowerCase().includes(q))
    );
  }
  return list;
});

const totalPages = computed(() => {
  return Math.ceil(filteredTeachers.value.length / itemsPerPage);
});

const paginatedTeachers = computed(() => {
  // Show all teachers as requested ("пусть все будет видно")
  return filteredTeachers.value;
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

const deleteTeacher = async () => {
  if (deletingTeacherId.value || !itemToDelete.value) return;
  
  const id = itemToDelete.value;
  deletingTeacherId.value = id;
  try {
    // SOFT DELETE: Update is_deleted instead of hard delete
    const { error: deleteError } = await supabase
      .from('teachers')
      .update({ 
        is_deleted: true, 
        deleted_at: new Date().toISOString() 
      })
      .eq('id', id);
    if (deleteError) throw deleteError;

    teachers.value = teachers.value.filter(t => t.id !== id);
    activeDropdown.value = null;
    showDeleteConfirm.value = false;
  } catch (e) {
    console.error('Error archiving teacher:', e);
    alert('Failed to archive teacher: ' + e.message);
  } finally {
    deletingTeacherId.value = null;
    itemToDelete.value = null;
  }
};

// --- Modal State ---
const showModal = ref(false);
const isEditing = ref(false);
const editingId = ref(null);

const teacherForm = reactive({
  name: '',
  subject: '',
  phone: '',
  email: '',
  percentage: 0,
  password: '',
  groupIds: []
});

const filteredGroupsAssign = computed(() => {
  if (!groupSearchQuery.value) return allGroups.value;
  const q = groupSearchQuery.value.toLowerCase();
  return allGroups.value.filter(g => g.name.toLowerCase().includes(q));
});

const toggleGroupSelection = (groupId) => {
  const index = teacherForm.groupIds.indexOf(groupId);
  if (index === -1) {
    teacherForm.groupIds.push(groupId);
  } else {
    teacherForm.groupIds.splice(index, 1);
  }
};

const openAddModal = () => {
  isEditing.value = false;
  editingId.value = null;
  teacherForm.name = '';
  teacherForm.subject = '';
  teacherForm.phone = '';
  teacherForm.email = '';
  teacherForm.percentage = 0;
  teacherForm.password = '';
  teacherForm.groupIds = [];
  groupSearchQuery.value = '';
  showModal.value = true;
};

const openEditModal = (teacher) => {
  isEditing.value = true;
  editingId.value = teacher.id;
  teacherForm.name = teacher.name;
  teacherForm.subject = teacher.subject;
  teacherForm.phone = teacher.phone;
  teacherForm.email = teacher.email;
  teacherForm.percentage = teacher.percentage || 0;
  teacherForm.password = teacher.password || '';
  teacherForm.groupIds = (teacher.groups || []).map(g => g.id);
  showModal.value = true;
};

const closeModal = () => {
  showModal.value = false;
};

const submitForm = async () => {
  if (!teacherForm.name || isSubmitting.value) return;
  
  isSubmitting.value = true;
  
  try {
    // 1. Check for duplicate email
    if (teacherForm.email) {
      let emailQuery = supabase
        .from('teachers')
        .select('id')
        .eq('email', teacherForm.email);
      
      if (isEditing.value) {
        emailQuery = emailQuery.neq('id', editingId.value);
      }
      
      const { data: existingEmail } = await emailQuery.single();
      
      if (existingEmail) {
        alert('This email is already registered for another teacher.');
        isSubmitting.value = false;
        return;
      }
    }

    const dbTeacher = {
      name: teacherForm.name,
      subject: teacherForm.subject,
      phone: teacherForm.phone,
      email: teacherForm.email,
      percentage: teacherForm.percentage || 0,
      password: teacherForm.password,
      updated_at: new Date().toISOString()
    };

    let currentTeacherId = editingId.value;

    if (isEditing.value) {
      const { error } = await supabase
        .from('teachers')
        .update(dbTeacher)
        .eq('id', editingId.value);
      if (error) throw error;
    } else {
      dbTeacher.created_at = new Date().toISOString();
      const { data: newTeacherData, error } = await supabase
        .from('teachers')
        .insert([dbTeacher])
        .select()
        .single();
      if (error) throw error;
      currentTeacherId = newTeacherData.id;
    }

    // --- SYNC WITH STAFF TABLE ---
    if (teacherForm.email) {
      const staffObj = {
        name: teacherForm.name,
        email: teacherForm.email,
        phone: teacherForm.phone,
        password: teacherForm.password,
        role: 'teacher',
        updated_at: new Date().toISOString()
      };

      const { data: existingStaff } = await supabase
        .from('staff')
        .select('id')
        .eq('email', teacherForm.email)
        .single();

      if (existingStaff) {
        await supabase.from('staff').update(staffObj).eq('id', existingStaff.id);
      } else {
        staffObj.created_at = new Date().toISOString();
        await supabase.from('staff').insert([staffObj]);
      }
    }

    if (currentTeacherId) {
      // 1. Remove this teacher from any groups they were previously assigned to
      // We set teacher_id to null and also reset teacher_ids array to be safe
      await supabase.from('groups')
        .update({ 
          teacher_id: null,
          teacher_ids: [] 
        })
        .eq('teacher_id', currentTeacherId);
      
      // 2. Assign this teacher to the newly selected groups
      if (teacherForm.groupIds && teacherForm.groupIds.length > 0) {
        // We set teacher_id for backward compatibility and teacher_ids for the new array-based logic
        await supabase.from('groups')
          .update({ 
            teacher_id: currentTeacherId,
            teacher_ids: [currentTeacherId] // Resetting/setting primary array
          })
          .in('id', teacherForm.groupIds);
      }
    }

    await loadData();
    closeModal();
  } catch (e) {
    console.error('Error saving teacher:', e);
    alert('Error saving teacher.');
  } finally {
    isSubmitting.value = false;
  }
};

const getStatusClass = (status) => {
  return status === 'Active' ? 'status-active' : 'status-inactive';
};
</script>

<template>
  <div class="teachers-page">
    <div class="page-header">
      <div class="header-content">
        <h1>{{ $t('teachers.title') }}</h1>
        <p>{{ $t('teachers.subtitle') }}</p>
      </div>
      <button class="btn-primary" @click="openAddModal">
        <Plus :size="20" /> 
        {{ $t('teachers.addNew') }}
      </button>
    </div>

    <div class="table-container card">
      <div class="table-header">
        <div class="search-bar">
          <Search :size="18" />
          <input 
            type="text" 
            v-model="searchQuery" 
            :placeholder="$t('teachers.searchPlaceholder')" 
            @input="currentPage = 1"
          />
        </div>
      </div>

      <div class="table-scroll-wrapper">
        <table>
          <thead>
            <tr>
              <th>{{ $t('teachers.name') }}</th>
              <th>{{ $t('teachers.subject') }}</th>
              <th>{{ $t('sidebar.groups') || 'Guruhlar' }}</th>
              <th>{{ $t('teachers.percentage') || 'Foiz (%)' }}</th>
              <th>{{ $t('teachers.phone') }}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <template v-if="isLoading">
              <tr v-for="i in 5" :key="i">
                <td :data-label="$t('teachers.name')">
                  <div class="teacher-info">
                    <div class="skeleton" style="width: 40px; height: 40px; border-radius: 50%;"></div>
                    <div class="details">
                      <div class="skeleton" style="width: 140px; height: 16px; margin-bottom: 4px;"></div>
                      <div class="skeleton" style="width: 100px; height: 12px;"></div>
                    </div>
                  </div>
                </td>
                <td :data-label="$t('teachers.subject')"><div class="skeleton" style="width: 100px; height: 16px;"></div></td>
                <td :data-label="$t('sidebar.groups') || 'Guruhlar'"><div class="skeleton" style="width: 100px; height: 16px;"></div></td>
                <td :data-label="$t('teachers.phone')"><div class="skeleton" style="width: 60px; height: 16px;"></div></td>
                <td :data-label="$t('common.actions')">
                  <div class="skeleton" style="width: 24px; height: 24px; border-radius: 6px;"></div>
                </td>
              </tr>
            </template>

            <template v-else>
              <tr v-if="paginatedTeachers.length === 0">
                <td colspan="5" class="no-data">{{ $t('common.noData') }}</td>
              </tr>
              <template v-for="item in paginatedTeachers" :key="item.id">
                <tr class="cursor-pointer hover-bg" @click="toggleRow(item.id)">
                  <td :data-label="$t('teachers.name')">
                    <div class="teacher-info">
                      <div class="avatar">{{ item.name.charAt(0) }}</div>
                      <div class="details">
                        <span class="name">{{ item.name }}</span>
                        <span class="email">{{ item.email || '-' }}</span>
                      </div>
                    </div>
                  </td>
                  <td :data-label="$t('teachers.subject')">
                    <div class="subject-tag">
                      <GraduationCap :size="14" />
                      {{ item.subject }}
                    </div>
                  </td>
                  <td :data-label="$t('sidebar.groups') || 'Guruhlar'">
                    <div class="groups-count">
                      <Users :size="14" />
                      <span class="share-value">{{ item.groups?.length || 0 }}</span>
                    </div>
                  </td>
                  <td :data-label="$t('teachers.percentage') || 'Foiz (%)'">
                    <span class="percentage-badge">{{ item.percentage || 0 }}%</span>
                  </td>
                  <td :data-label="$t('teachers.phone')">{{ item.phone }}</td>
                  <td :data-label="$t('common.actions')">
                    <div class="actions-wrapper">
                      <button class="btn-icon-more" @click.stop="toggleRow(item.id)">
                        <ChevronUp v-if="expandedTeacherId === item.id" :size="20" />
                        <ChevronDown v-else :size="20" />
                      </button>
                      <div class="dropdown-wrapper">
                        <button 
                          class="btn-icon-more" 
                          :class="{ active: activeDropdown === 'teacher-' + item.id }"
                          @click="(e) => toggleDropdown('teacher-' + item.id, e)"
                        >
                          <MoreVertical :size="20" />
                        </button>
                        <transition name="dropdown">
                          <div v-if="activeDropdown === 'teacher-' + item.id" class="dropdown-menu">
                            <button class="dropdown-item" @click.stop="openEditModal(item)">
                              <Edit :size="16" /> {{ $t('common.edit') }}
                            </button>
                            <div class="dropdown-divider"></div>
                            <button class="dropdown-item danger" @click.stop="confirmDelete(item.id)">
                              <Trash2 :size="16" /> 
                              {{ $t('common.delete') }}
                            </button>
                          </div>
                        </transition>
                      </div>
                    </div>
                  </td>
                </tr>
                <tr v-if="expandedTeacherId === item.id" class="expanded-row">
                  <td colspan="5">
                    <div class="nested-groups">
                      <h4 class="nested-title">{{ item.name }}'s Groups</h4>
                      <div class="groups-grid" v-if="item.groups && item.groups.length > 0">
                        <div class="group-card" v-for="g in item.groups" :key="g.id" @click.stop="goToGroup(g.id)">
                          <span class="g-name">{{ g.name }}</span>
                          <span :class="['status-badge', getStatusClass(g.status)]">{{ g.status || 'Active' }}</span>
                        </div>
                      </div>
                      <div v-else class="text-muted">Guruhlar yo'q / No groups assigned</div>
                    </div>
                  </td>
                </tr>
              </template>
            </template>
          </tbody>
        </table>
      </div>

      <!-- Pagination hidden as requested to show all items -->
      <div v-if="false && totalPages > 1" class="pagination-footer">
        <div class="pagination-info">
          {{ $t('common.showing') }} 
          <b>{{ (currentPage - 1) * itemsPerPage + 1 }}-{{ Math.min(currentPage * itemsPerPage, filteredTeachers.length) }}</b> 
          {{ $t('common.outOf') }} 
          <b>{{ filteredTeachers.length }}</b>
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
              <h2>{{ isEditing ? $t('teachers.editModalTitle') : $t('teachers.createModalTitle') }}</h2>
            </div>
            <button class="btn-icon" @click="closeModal"><X :size="20" /></button>
          </div>

          <div class="modal-body">
            <div class="form-group">
              <label>{{ $t('teachers.name') }} <span class="required">*</span></label>
              <input v-model="teacherForm.name" :placeholder="$t('teachers.namePlaceholder')" />
            </div>
            <div class="form-group">
              <label>{{ $t('teachers.subject') }} <span class="required">*</span></label>
              <input v-model="teacherForm.subject" :placeholder="$t('teachers.subjectPlaceholder')" />
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>{{ $t('teachers.phone') }}</label>
                <input v-model="teacherForm.phone" placeholder="+998 90 000 0000" />
              </div>
              <div class="form-group">
                <label>{{ $t('teachers.email') }}</label>
                <input v-model="teacherForm.email" :placeholder="$t('teachers.emailPlaceholder')" />
              </div>
            </div>
            <div class="form-group">
              <label>{{ $t('teachers.percentage') || 'Foiz (%)' }}</label>
              <div class="input-with-icon">
                <DollarSign :size="18" class="input-icon" />
                <input v-model.number="teacherForm.percentage" type="number" min="0" max="100" placeholder="0 - 100" />
              </div>
            </div>
            <div class="form-group">
              <label>{{ $t('common.password') }} <span class="required">*</span></label>
              <div class="input-with-icon">
                <Lock :size="18" class="input-icon" />
                <input v-model="teacherForm.password" type="password" :placeholder="$t('common.passwordPlaceholder')" />
              </div>
            </div>
            
            <div class="form-group" style="grid-column: 1 / -1;">
              <label>Guruhlarni biriktirish</label>
              
              <!-- Group Search Input -->
              <div class="group-search-mini">
                <Search :size="16" />
                <input v-model="groupSearchQuery" placeholder="Guruhni qidirish..." />
              </div>

              <div class="groups-checkbox-grid">
                <label 
                  v-for="group in filteredGroupsAssign" 
                  :key="group.id" 
                  class="checkbox-card"
                  :class="{ active: teacherForm.groupIds.includes(group.id) }"
                >
                  <input 
                    type="checkbox" 
                    :value="group.id"
                    :checked="teacherForm.groupIds.includes(group.id)"
                    @change="toggleGroupSelection(group.id)"
                    class="hidden-radio"
                  />
                  <span class="group-select-name">{{ group.name }}</span>
                  <div class="checkbox-indicator">
                    <Check v-if="teacherForm.groupIds.includes(group.id)" :size="14" />
                  </div>
                </label>
              </div>
              <p v-if="allGroups.length === 0" class="text-muted" style="margin-top: 0.5rem; font-size: 0.85rem;">No active groups available to assign.</p>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn-cancel-modal" @click="closeModal" :disabled="isSubmitting">{{ $t('common.cancel') }}</button>
            <button class="btn-confirm-primary" @click="submitForm" :disabled="!teacherForm.name || isSubmitting">
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
            <p class="confirm-desc">{{ $t('teachers.deleteConfirm') }}</p>
            <div class="confirm-actions">
              <button class="btn-cancel" @click="cancelDelete" :disabled="deletingTeacherId">{{ $t('common.cancel') }}</button>
              <button class="btn-danger-confirm" @click="deleteTeacher" :disabled="deletingTeacherId">
                <Loader2 v-if="deletingTeacherId" :size="18" class="spin" />
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
.teachers-page {
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

.table-scroll-wrapper { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; }
th { text-align: left; padding: 1.25rem 1.5rem; background: #F8F9FA; font-size: 0.8rem; font-weight: 700; color: var(--gray); text-transform: uppercase; }
td { padding: 1.25rem 1.5rem; border-bottom: 1px solid var(--border); }
.cursor-pointer { cursor: pointer; transition: background 0.2s; }
.hover-bg:hover { background: #fdfdfd; }
.actions-wrapper { display: flex; align-items: center; justify-content: flex-end; gap: 0.5rem; }

.teacher-info { display: flex; align-items: center; gap: 0.75rem; }
.avatar { width: 40px; height: 40px; background: var(--primary-light); color: var(--primary); border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 700; }
.details { display: flex; flex-direction: column; }
.name { font-weight: 700; color: var(--dark); }
.email { font-size: 0.75rem; color: var(--gray); }

.subject-tag { display: inline-flex; align-items: center; gap: 0.4rem; padding: 0.35rem 0.75rem; background: #f0f4ff; color: var(--primary); border-radius: 20px; font-size: 0.85rem; }
.groups-count { display: flex; align-items: center; gap: 0.4rem; color: var(--gray); font-weight: 700; }
.share-value { font-weight: 700; color: var(--primary); background: var(--primary-light); padding: 0.3rem 0.7rem; border-radius: 8px; font-size: 0.85rem; }

.expanded-row td { background: #fafafa; padding: 1.5rem; border-bottom: 1px solid var(--border); }
.nested-groups { background: white; border: 1px solid var(--border); border-radius: 12px; padding: 1.25rem; box-shadow: 0 4px 15px rgba(0,0,0,0.02); }
.nested-title { font-size: 1.1rem; font-weight: 700; color: var(--dark); margin-bottom: 1rem; }
.groups-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 1rem; }
.group-card { background: var(--light); border: 1.5px solid var(--border); padding: 1rem; border-radius: 10px; cursor: pointer; transition: all 0.2s; display: flex; justify-content: space-between; align-items: center; }
.group-card:hover { border-color: var(--primary); transform: translateY(-2px); box-shadow: 0 4px 12px rgba(115,102,255,0.1); }
.g-name { font-weight: 700; color: var(--dark); }
.text-muted { color: var(--gray); font-size: 0.9rem; font-style: italic; }

.status-inactive { background: rgba(234, 84, 85, 0.1); color: var(--danger); }

.percentage-badge {
  background: var(--primary-light);
  color: var(--primary);
  padding: 0.35rem 0.75rem;
  border-radius: 8px;
  font-size: 0.85rem;
  font-weight: 800;
}

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
.modal-box { background: white; border-radius: 20px; width: 100%; max-width: 600px; max-height: 90vh; display: flex; flex-direction: column; overflow: hidden; }
.modal-header { padding: 1.5rem; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
.modal-title-row { display: flex; align-items: center; gap: 1rem; }
.modal-icon { width: 42px; height: 42px; background: var(--primary-light); color: var(--primary); border-radius: 12px; display: flex; align-items: center; justify-content: center; }
.modal-body { padding: 1.5rem; overflow-y: auto; flex: 1; }
.form-group { margin-bottom: 1.25rem; }
.form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1.25rem; }
label { display: block; font-size: 0.85rem; font-weight: 700; margin-bottom: 0.5rem; }
input, select { width: 100%; padding: 0.75rem 1rem; border: 1.5px solid var(--border); border-radius: 12px; background: var(--light); outline: none; }
input:focus, select:focus { border-color: var(--primary); background: white; box-shadow: 0 0 0 4px var(--primary-light); }
.input-with-icon { position: relative; }
.input-icon { position: absolute; left: 1rem; top: 50%; transform: translateY(-50%); color: var(--primary); font-weight: 700; pointer-events: none; }
.input-with-icon input { padding-left: 2.5rem; }
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

.modal-enter-active, .modal-leave-active { transition: opacity 0.3s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
.skeleton { background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%); background-size: 200% 100%; animation: skeleton-loading 1.5s infinite; }
@keyframes skeleton-loading { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }

.groups-checkbox-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 0.75rem; max-height: 200px; overflow-y: auto; padding: 0.25rem; }
.checkbox-card { display: flex; justify-content: space-between; align-items: center; padding: 0.75rem 1rem; border: 1.5px solid var(--border); border-radius: 12px; cursor: pointer; transition: all 0.2s; background: var(--light); user-select: none; }
.checkbox-card:hover { border-color: var(--primary-light); }
.checkbox-card.active { border-color: var(--primary); background: #fdfcff; }
.hidden-radio { display: none; }
.group-select-name { font-size: 0.9rem; font-weight: 600; color: var(--dark); }
.checkbox-indicator { width: 20px; height: 20px; border-radius: 6px; border: 2px solid var(--border); display: flex; align-items: center; justify-content: center; background: white; color: white; transition: all 0.2s; }
.checkbox-card.active .checkbox-indicator { background: var(--primary); border-color: var(--primary); }

.group-search-mini {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  background: var(--light);
  padding: 0.5rem 0.85rem;
  border-radius: 10px;
  margin-bottom: 1rem;
  border: 1.5px solid var(--border);
  transition: all 0.2s;
}
.group-search-mini:focus-within {
  border-color: var(--primary);
  background: white;
  box-shadow: 0 0 0 3px var(--primary-light);
}
.group-search-mini input {
  background: transparent;
  border: none;
  outline: none;
  width: 100%;
  font-size: 0.85rem;
}
.group-search-mini svg {
  color: var(--gray);
}
</style>
