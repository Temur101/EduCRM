
<script setup>
import { 
  Plus, 
  Search, 
  MoreVertical, 
  BookOpen,
  User,
  Tag,
  Trash2,
  X,
  Check,
  Loader2,
  Edit,
  ChevronLeft,
  ChevronRight,
  AlertTriangle
} from 'lucide-vue-next';
import { ref, reactive, computed, onMounted } from 'vue';
import { supabase } from '../supabase.js';

const courses = ref([]);
const isLoading = ref(true);
const isSubmitting = ref(false);
const deletingCourseId = ref(null);
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
    const { data: coursesData, error: coursesError } = await supabase
      .from('courses')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (coursesError) throw coursesError;
    courses.value = coursesData;
  } catch (e) {
    console.error('Data loading error:', e.message);
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  document.addEventListener('click', closeDropdowns);
  loadData();
});

const filteredCourses = computed(() => {
  let list = courses.value;
  if (searchQuery.value) {
    const q = searchQuery.value.toLowerCase();
    list = list.filter(c => 
      c.name.toLowerCase().includes(q) || 
      c.category.toLowerCase().includes(q)
    );
  }
  return list;
});

const totalPages = computed(() => {
  return Math.ceil(filteredCourses.value.length / itemsPerPage);
});

const paginatedCourses = computed(() => {
  const start = (currentPage.value - 1) * itemsPerPage;
  const end = start + itemsPerPage;
  return filteredCourses.value.slice(start, end);
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

const deleteCourse = async () => {
  if (deletingCourseId.value || !itemToDelete.value) return;
  
  const id = itemToDelete.value;
  deletingCourseId.value = id;
  try {
    const courseToArchive = courses.value.find(c => c.id === id);
    if (courseToArchive) {
      const { error: archError } = await supabase.from('archives').insert([{
        type: 'course',
        original_id: String(id),
        data: courseToArchive,
        archived_at: new Date().toISOString()
      }]);
      if (archError) throw archError;
    }

    const { error } = await supabase.from('courses').delete().eq('id', id);
    if (error) throw error;
    courses.value = courses.value.filter(c => c.id !== id);
    activeDropdown.value = null;
    showDeleteConfirm.value = false;
  } catch (e) {
    console.error('Error deleting course:', e);
  } finally {
    deletingCourseId.value = null;
    itemToDelete.value = null;
  }
};

// --- Modal State ---
const showModal = ref(false);
const isEditing = ref(false);
const editingId = ref(null);

const courseForm = reactive({
  name: '',
  category: '',
  teacher_id: '',
  price: '',
  status: 'Active'
});

const openAddModal = () => {
  isEditing.value = false;
  editingId.value = null;
  courseForm.name = '';
  courseForm.category = '';
  courseForm.teacher_id = '';
  courseForm.price = '';
  courseForm.status = 'Active';
  showModal.value = true;
};

const openEditModal = (course) => {
  isEditing.value = true;
  editingId.value = course.id;
  courseForm.name = course.name;
  courseForm.category = course.category;
  courseForm.teacher_id = course.teacher_id;
  courseForm.price = course.price;
  courseForm.status = course.status;
  showModal.value = true;
};

const closeModal = () => {
  showModal.value = false;
};

const submitForm = async () => {
  if (!courseForm.name || !courseForm.category || isSubmitting.value) return;
  
  isSubmitting.value = true;
  const dbCourse = {
    name: courseForm.name,
    category: courseForm.category,
    teacher_id: courseForm.teacher_id || null,
    price: Number(courseForm.price),
    status: courseForm.status,
    updated_at: new Date().toISOString()
  };

  try {
    if (isEditing.value) {
      const { error } = await supabase
        .from('courses')
        .update(dbCourse)
        .eq('id', editingId.value);
      if (error) throw error;
    } else {
      dbCourse.created_at = new Date().toISOString();
      const { error } = await supabase
        .from('courses')
        .insert([dbCourse]);
      if (error) throw error;
    }
    await loadData();
    closeModal();
  } catch (e) {
    console.error('Error saving course:', e);
    alert('Error saving course.');
  } finally {
    isSubmitting.value = false;
  }
};

const formatCurrency = (val) => {
  if (!val) return '0';
  return new Intl.NumberFormat('uz-UZ', { style: 'currency', currency: 'UZS', maximumFractionDigits: 0 }).format(val);
};

const getStatusClass = (status) => {
  return status === 'Active' ? 'status-active' : 'status-inactive';
};
</script>

<template>
  <div class="courses-page">
    <div class="page-header">
      <div class="header-content">
        <h1>{{ $t('courses.title') }}</h1>
        <p>{{ $t('courses.subtitle') }}</p>
      </div>
      <button class="btn-primary" @click="openAddModal">
        <Plus :size="20" /> 
        {{ $t('courses.addNew') }}
      </button>
    </div>

    <div class="table-container card">
      <div class="table-header">
        <div class="search-bar">
          <Search :size="18" />
          <input 
            type="text" 
            v-model="searchQuery" 
            :placeholder="$t('courses.searchPlaceholder')" 
            @input="currentPage = 1"
          />
        </div>
      </div>

      <div class="table-scroll-wrapper">
        <table>
          <thead>
            <tr>
              <th>{{ $t('courses.name') }}</th>
              <th>{{ $t('courses.category') }}</th>
              <th>{{ $t('courses.price') }}</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <template v-if="isLoading">
              <tr v-for="i in 5" :key="i">
                <td>
                  <div class="course-info">
                    <div class="skeleton" style="width: 40px; height: 40px; border-radius: 12px;"></div>
                    <div class="details">
                      <div class="skeleton" style="width: 160px; height: 16px; margin-bottom: 4px;"></div>
                      <div class="skeleton" style="width: 100px; height: 12px;"></div>
                    </div>
                  </div>
                </td>
                <td><div class="skeleton" style="width: 100px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 120px; height: 16px;"></div></td>
                <td><div class="skeleton" style="width: 24px; height: 24px; border-radius: 6px;"></div></td>
              </tr>
            </template>

            <template v-else>
              <tr v-if="paginatedCourses.length === 0">
                <td colspan="4" class="no-data">{{ $t('common.noData') }}</td>
              </tr>
              <tr v-for="item in paginatedCourses" :key="item.id">
                <td>
                  <div class="course-info">
                    <div class="course-icon-bg">
                      <BookOpen :size="20" />
                    </div>
                    <div class="details">
                      <span class="name">{{ item.name }}</span>
                    </div>
                  </div>
                </td>
                <td>
                  <div class="category-tag">
                    <Tag :size="14" />
                    {{ item.category }}
                  </div>
                </td>
                <td><span class="price-value">{{ formatCurrency(item.price) }}</span></td>
                <td>
                  <div class="dropdown-wrapper">
                    <button 
                      class="btn-icon-more" 
                      :class="{ active: activeDropdown === 'course-' + item.id }"
                      @click="(e) => toggleDropdown('course-' + item.id, e)"
                    >
                      <MoreVertical :size="20" />
                    </button>
                    <transition name="dropdown">
                      <div v-if="activeDropdown === 'course-' + item.id" class="dropdown-menu">
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

      <div v-if="totalPages > 1" class="pagination-footer">
        <div class="pagination-info">
          {{ $t('common.showing') || 'Showing' }} 
          <b>{{ (currentPage - 1) * itemsPerPage + 1 }}-{{ Math.min(currentPage * itemsPerPage, filteredCourses.length) }}</b> 
          {{ $t('common.outOf') || 'out of' }} 
          <b>{{ filteredCourses.length }}</b>
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
              <h2>{{ isEditing ? $t('courses.editModalTitle') : $t('courses.createModalTitle') }}</h2>
            </div>
            <button class="btn-icon" @click="closeModal"><X :size="20" /></button>
          </div>

          <div class="modal-body">
            <div class="form-group">
              <label>{{ $t('courses.name') }} <span class="required">*</span></label>
              <input v-model="courseForm.name" :placeholder="$t('courses.namePlaceholder')" />
            </div>
            <div class="form-row">
              <div class="form-group">
                <label>{{ $t('courses.category') }} <span class="required">*</span></label>
                <input v-model="courseForm.category" :placeholder="$t('courses.categoryPlaceholder')" />
              </div>
              <div class="form-group">
                <label>{{ $t('courses.price') }}</label>
                <div class="input-with-icon">
                  <span class="currency-text">so'm</span>
                  <input v-model="courseForm.price" type="number" :placeholder="$t('courses.pricePlaceholder')" />
                </div>
              </div>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn-cancel-modal" @click="closeModal" :disabled="isSubmitting">{{ $t('common.cancel') }}</button>
            <button class="btn-confirm-primary" @click="submitForm" :disabled="!courseForm.name || isSubmitting">
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
            <p class="confirm-desc">{{ $t('courses.deleteConfirm') }}</p>
            <div class="confirm-actions">
              <button class="btn-cancel" @click="cancelDelete" :disabled="deletingCourseId">{{ $t('common.cancel') }}</button>
              <button class="btn-danger-confirm" @click="deleteCourse" :disabled="deletingCourseId">
                <Loader2 v-if="deletingCourseId" :size="18" class="spin" />
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
.courses-page {
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

.table-header {
  padding: 1.5rem;
  border-bottom: 1px solid var(--border);
}

.search-bar {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  background: var(--light);
  padding: 0.6rem 1rem;
  border-radius: 12px;
  max-width: 350px;
}

.search-bar input {
  background: transparent;
  border: none;
  outline: none;
  width: 100%;
}

.table-scroll-wrapper {
  overflow-x: auto;
  padding-bottom: 8rem;
}

table {
  width: 100%;
  border-collapse: collapse;
}

th {
  text-align: left;
  padding: 1.25rem 1.5rem;
  background: #F8F9FA;
  font-size: 0.8rem;
  font-weight: 700;
  color: var(--gray);
  text-transform: uppercase;
}

td {
  padding: 1.25rem 1.5rem;
  border-bottom: 1px solid var(--border);
}

.course-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.course-icon-bg {
  width: 40px;
  height: 40px;
  background: var(--primary-light);
  color: var(--primary);
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.name {
  font-weight: 700;
  color: var(--dark);
}

.category-tag {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.35rem 0.75rem;
  background: #f0f4ff;
  color: var(--primary);
  border-radius: 20px;
  font-size: 0.85rem;
}

.teacher-info {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  color: var(--gray);
  font-size: 0.85rem;
}

.price-value {
  font-weight: 700;
  color: var(--dark);
}

.status-badge {
  padding: 0.35rem 0.75rem;
  border-radius: 8px;
  font-size: 0.75rem;
  font-weight: 700;
}

.status-active { background: rgba(40, 199, 111, 0.1); color: var(--success); }
.status-inactive { background: rgba(234, 84, 85, 0.1); color: var(--danger); }

.pagination-footer {
  padding: 1.25rem 1.5rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-top: 1px solid var(--border);
}

.pagination-controls { display: flex; align-items: center; gap: 1rem; }
.page-numbers { display: flex; gap: 0.5rem; }
.btn-page, .btn-number {
  width: 36px; height: 36px;
  display: flex; align-items: center; justify-content: center;
  border-radius: 10px; border: 1px solid var(--border);
  background: white; font-weight: 600;
}
.btn-number.active { background: var(--primary); color: white; border-color: var(--primary); }

.dropdown-wrapper { position: relative; display: flex; justify-content: flex-end; }
.btn-icon-more { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border-radius: 8px; color: var(--gray); }
.btn-icon-more:hover, .btn-icon-more.active { background: var(--primary); color: white; }

.dropdown-menu {
  position: absolute; top: 100%; right: 0; margin-top: 0.5rem;
  background: white; border: 1px solid var(--border); border-radius: 12px;
  padding: 0.5rem; box-shadow: 0 10px 40px rgba(0, 0, 0, 0.15); z-index: 1000; min-width: 180px;
}

.dropdown-item {
  display: flex; align-items: center; gap: 0.75rem; padding: 0.75rem 1rem; width: 100%;
  border-radius: 8px; font-size: 0.9rem; font-weight: 600; color: var(--dark);
}
.dropdown-item:hover { background: var(--primary-light); color: var(--primary); }
.dropdown-item.danger { color: var(--danger); }
.dropdown-divider { height: 1px; background: rgba(0, 0, 0, 0.05); margin: 0.4rem 0.5rem; }

.modal-overlay {
  position: fixed; top: 0; left: 0; right: 0; bottom: 0;
  background: rgba(0, 0, 0, 0.5); display: flex; align-items: center; justify-content: center; z-index: 10000; backdrop-filter: blur(4px);
}

.modal-box { background: white; border-radius: 20px; width: 100%; max-width: 600px; overflow: hidden; }
.modal-header { padding: 1.5rem; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
.modal-title-row { display: flex; align-items: center; gap: 1rem; }
.modal-icon { width: 42px; height: 42px; background: var(--primary-light); color: var(--primary); border-radius: 12px; display: flex; align-items: center; justify-content: center; }
.modal-body { padding: 1.5rem; }
.form-group { margin-bottom: 1.25rem; }
.form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin-bottom: 1.25rem; }
label { display: block; font-size: 0.85rem; font-weight: 700; margin-bottom: 0.5rem; }
input, select { width: 100%; padding: 0.75rem 1rem; border: 1.5px solid var(--border); border-radius: 12px; background: var(--light); outline: none; }
input:focus, select:focus { border-color: var(--primary); background: white; box-shadow: 0 0 0 4px var(--primary-light); }
.input-with-icon { position: relative; }
.input-icon { position: absolute; left: 1rem; top: 50%; transform: translateY(-50%); color: var(--gray); pointer-events: none; }
.currency-text { position: absolute; left: 0.75rem; top: 50%; transform: translateY(-50%); color: var(--primary); font-weight: 700; font-size: 0.75rem; text-transform: uppercase; pointer-events: none; }
.input-with-icon input, .input-with-icon select { padding-left: 3.5rem; }
.modal-footer { padding: 1.5rem; background: #F8F9FA; display: flex; justify-content: flex-end; gap: 1rem; }
.btn-confirm-primary { background: var(--primary); color: white; padding: 0.75rem 2rem; border-radius: 12px; font-weight: 700; }
.btn-cancel-modal { padding: 0.75rem 1.5rem; font-weight: 600; color: var(--gray); }
.required { color: var(--danger); margin-left: 2px; }

.confirm-modal { max-width: 400px; }
.confirm-icon { width: 80px; height: 80px; background: #FFF5F5; color: var(--danger); border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 1.5rem; }
.confirm-title { font-size: 1.5rem; font-weight: 800; color: var(--dark); margin-bottom: 0.75rem; text-align: center; }
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
</style>
