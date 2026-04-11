
<script setup>
import { 
  Plus, 
  Search, 
  MoreVertical, 
  DoorOpen,
  Users,
  Edit,
  Trash2,
  X,
  Loader2,
  ChevronLeft,
  ChevronRight,
  AlertTriangle,
  Info
} from 'lucide-vue-next';
import { ref, reactive, computed, onMounted } from 'vue';
import { supabase } from '../supabase.js';

const rooms = ref([]);
const isLoading = ref(true);
const isSubmitting = ref(false);
const deletingRoomId = ref(null);
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

const loadRooms = async () => {
  isLoading.value = true;
  try {
    const { data, error } = await supabase
      .from('rooms')
      .select('*')
      .order('name');
    
    if (error) throw error;
    rooms.value = data || [];
  } catch (e) {
    console.error('Error loading rooms:', e.message);
  } finally {
    isLoading.value = false;
  }
};

onMounted(() => {
  document.addEventListener('click', closeDropdowns);
  loadRooms();
});

const filteredRooms = computed(() => {
  if (!searchQuery.value) return rooms.value;
  const q = searchQuery.value.toLowerCase();
  return rooms.value.filter(r => r.name.toLowerCase().includes(q));
});

const totalPages = computed(() => Math.ceil(filteredRooms.value.length / itemsPerPage));
const paginatedRooms = computed(() => {
  const start = (currentPage.value - 1) * itemsPerPage;
  return filteredRooms.value.slice(start, start + itemsPerPage);
});

const setPage = (page) => {
  if (page >= 1 && page <= totalPages.value) currentPage.value = page;
};

// --- Modal Logic ---
const showModal = ref(false);
const isEditing = ref(false);
const editingId = ref(null);

const roomForm = reactive({
  name: '',
  capacity: 20,
  description: '',
  status: 'Active'
});

const openAddModal = () => {
  isEditing.value = false;
  roomForm.name = '';
  roomForm.capacity = 20;
  roomForm.description = '';
  roomForm.status = 'Active';
  showModal.value = true;
};

const openEditModal = (room) => {
  isEditing.value = true;
  editingId.value = room.id;
  roomForm.name = room.name;
  roomForm.capacity = room.capacity;
  roomForm.description = room.description || '';
  roomForm.status = room.status || 'Active';
  showModal.value = true;
};

const submitForm = async () => {
  if (!roomForm.name || isSubmitting.value) return;
  isSubmitting.value = true;
  
  const roomData = {
    name: roomForm.name,
    capacity: parseInt(roomForm.capacity),
    description: roomForm.description,
    status: roomForm.status
  };

  try {
    if (isEditing.value) {
      const { error } = await supabase.from('rooms').update(roomData).eq('id', editingId.value);
      if (error) throw error;
    } else {
      const { error } = await supabase.from('rooms').insert([roomData]);
      if (error) throw error;
    }
    await loadRooms();
    showModal.value = false;
  } catch (e) {
    console.error('Error saving room:', e);
    alert('Database error. Ensure "rooms" table exists.');
  } finally {
    isSubmitting.value = false;
  }
};

const showDeleteConfirm = ref(false);
const itemToDelete = ref(null);
const confirmDelete = (id) => {
  itemToDelete.value = id;
  showDeleteConfirm.value = true;
};

const deleteRoom = async () => {
  if (!itemToDelete.value || deletingRoomId.value) return;
  
  const id = itemToDelete.value;
  deletingRoomId.value = id;
  try {
    const room = rooms.value.find(r => r.id === id);
    if (!room) throw new Error('Room not found');

    // 1. Move to archives table
    const archiveData = {
      type: 'room',
      original_id: String(id),
      data: room,
      archived_at: new Date().toISOString()
    };
    const { error: archiveError } = await supabase.from('archives').insert([archiveData]);
    if (archiveError) throw archiveError;

    // 2. Delete from rooms table
    const { error: deleteError } = await supabase.from('rooms').delete().eq('id', id);
    if (deleteError) throw deleteError;

    rooms.value = rooms.value.filter(r => r.id !== id);
    showDeleteConfirm.value = false;
  } catch (e) {
    console.error('Error archiving room:', e);
    alert('Failed to archive room: ' + e.message);
  } finally {
    deletingRoomId.value = null;
    itemToDelete.value = null;
  }
};
</script>

<template>
  <div class="rooms-page">
    <div class="page-header">
      <div class="header-info">
        <h1>{{ $t('rooms.title') }}</h1>
        <p>{{ $t('rooms.subtitle') }}</p>
      </div>
      <button class="btn-primary" @click="openAddModal">
        <Plus :size="20" /> {{ $t('rooms.addNew') }}
      </button>
    </div>

    <!-- Stats summary -->
    <div class="rooms-stats">
      <div class="stat-mini card">
        <div class="stat-icon total"><DoorOpen :size="20" /></div>
        <div class="stat-details">
          <span class="label">Total Rooms</span>
          <span class="value">{{ rooms.length }}</span>
        </div>
      </div>
      <div class="stat-mini card">
        <div class="stat-icon capacity"><Users :size="20" /></div>
        <div class="stat-details">
          <span class="label">Total Capacity</span>
          <span class="value">{{ rooms.reduce((acc, r) => acc + (r.capacity || 0), 0) }}</span>
        </div>
      </div>
    </div>

    <div class="rooms-grid-container card">
      <div class="grid-header">
        <div class="search-box">
          <Search :size="18" />
          <input v-model="searchQuery" :placeholder="$t('rooms.searchPlaceholder')" />
        </div>
      </div>

      <div class="rooms-grid">
        <template v-if="isLoading">
          <div v-for="i in 8" :key="i" class="room-card skeleton-card">
            <div class="room-header" style="margin-bottom: 1.5rem;">
              <div class="skeleton" style="width: 48px; height: 48px; border-radius: 12px;"></div>
              <div class="skeleton" style="width: 24px; height: 24px; border-radius: 6px;"></div>
            </div>
            <div class="room-body">
              <div class="skeleton" style="width: 60%; height: 20px; margin-bottom: 0.75rem;"></div>
              <div class="skeleton" style="width: 90%; height: 14px; margin-bottom: 0.5rem;"></div>
              <div class="skeleton" style="width: 40%; height: 14px; margin-bottom: 1.5rem;"></div>
              <div class="room-meta" style="padding-top: 1rem; border-top: 1px solid var(--border);">
                <div class="skeleton" style="width: 80px; height: 16px;"></div>
              </div>
            </div>
          </div>
        </template>
        <template v-else>
          <div v-for="room in paginatedRooms" :key="room.id" class="room-card card">
            <div class="room-header">
              <div class="room-icon-box">
                <DoorOpen :size="24" />
              </div>
              <div class="room-actions">
                <button class="btn-icon-more" @click="(e) => toggleDropdown('room-' + room.id, e)">
                  <MoreVertical :size="18" />
                </button>
                <transition name="dropdown">
                  <div v-if="activeDropdown === 'room-' + room.id" class="dropdown-menu">
                    <button class="dropdown-item" @click="openEditModal(room)">
                      <Edit :size="16" /> {{ $t('common.edit') }}
                    </button>
                    <div class="dropdown-divider"></div>
                    <button class="dropdown-item danger" @click="confirmDelete(room.id)">
                      <Trash2 :size="16" /> {{ $t('common.delete') }}
                    </button>
                  </div>
                </transition>
              </div>
            </div>
            <div class="room-body">
              <h3>{{ room.name }}</h3>
              <p class="description">{{ room.description || $t('common.noData') }}</p>
              <div class="room-meta">
                <div class="meta-item">
                  <Users :size="14" />
                  <span>{{ room.capacity }} {{ $t('rooms.capacity') }}</span>
                </div>
              </div>
            </div>
          </div>
          <div v-if="paginatedRooms.length === 0" class="no-data-card">
            <Info :size="48" />
            <p>{{ $t('common.noData') }}</p>
          </div>
        </template>
      </div>

      <div v-if="totalPages > 1" class="pagination-footer">
        <div class="pagination-info">
          {{ $t('common.showing') || 'Showing' }} 
          <b>{{ (currentPage - 1) * itemsPerPage + 1 }}-{{ Math.min(currentPage * itemsPerPage, filteredRooms.length) }}</b> 
          {{ $t('common.outOf') || 'out of' }} 
          <b>{{ filteredRooms.length }}</b>
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
      <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
        <div class="modal-box">
          <div class="modal-header">
            <div class="title-with-icon">
              <div class="icon-bg primary"><DoorOpen :size="22" /></div>
              <h2>{{ isEditing ? $t('rooms.editModalTitle') : $t('rooms.createModalTitle') }}</h2>
            </div>
            <button class="btn-close" @click="showModal = false"><X :size="20" /></button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>{{ $t('rooms.name') }}</label>
              <input v-model="roomForm.name" :placeholder="$t('rooms.namePlaceholder')" />
            </div>
            <div class="form-group">
              <label>{{ $t('rooms.capacity') }}</label>
              <input type="number" v-model="roomForm.capacity" :placeholder="$t('rooms.capacityPlaceholder')" />
            </div>
            <div class="form-group">
              <label>{{ $t('rooms.description') }}</label>
              <textarea v-model="roomForm.description" :placeholder="$t('rooms.descriptionPlaceholder')" rows="3"></textarea>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn-secondary" @click="showModal = false">{{ $t('common.cancel') }}</button>
            <button class="btn-primary-confirm" @click="submitForm" :disabled="isSubmitting || !roomForm.name">
              <Loader2 v-if="isSubmitting" :size="18" class="spin" />
              <span v-else>{{ isEditing ? $t('common.save') : $t('common.add') }}</span>
            </button>
          </div>
        </div>
      </div>
    </transition>

    <!-- Delete Modal -->
    <transition name="modal">
      <div v-if="showDeleteConfirm" class="modal-overlay" @click.self="showDeleteConfirm = false">
        <div class="confirm-modal card">
          <div class="confirm-icon"><AlertTriangle :size="48" /></div>
          <h3>{{ $t('common.areYouSure') }}</h3>
          <p>{{ $t('rooms.deleteConfirm') }}</p>
          <div class="confirm-actions">
            <button class="btn-secondary" @click="showDeleteConfirm = false">{{ $t('common.cancel') }}</button>
            <button class="btn-danger" @click="deleteRoom" :disabled="deletingRoomId">
              <Loader2 v-if="deletingRoomId" :size="18" class="spin" />
              <span v-else>{{ $t('common.delete') }}</span>
            </button>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped>
.rooms-page { padding: 2rem; background: var(--light); min-height: 100vh; }
.page-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 2rem; }
.header-info h1 { font-size: 1.75rem; font-weight: 800; color: var(--dark); }
.header-info p { color: var(--gray); font-size: 0.95rem; margin-top: 4px; }

.btn-primary { background: var(--primary); color: white; padding: 0.75rem 1.5rem; border-radius: 12px; font-weight: 600; display: flex; align-items: center; gap: 0.5rem; transition: all 0.2s; }
.btn-primary:hover { transform: translateY(-2px); box-shadow: 0 4px 12px var(--primary-light); }

.rooms-stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1.5rem; margin-bottom: 2rem; }
.stat-mini { padding: 1.25rem; display: flex; align-items: center; gap: 1rem; }
.stat-icon { width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; }
.stat-icon.total { background: #E3F2FD; color: #2196F3; }
.stat-icon.capacity { background: #F3E5F5; color: #9C27B0; }
.stat-details .label { display: block; font-size: 0.75rem; color: var(--gray); font-weight: 600; text-transform: uppercase; }
.stat-details .value { font-size: 1.25rem; font-weight: 800; color: var(--dark); }

.rooms-grid-container { padding: 1.5rem; }
.grid-header { margin-bottom: 1.5rem; }
.search-box { display: flex; align-items: center; gap: 0.75rem; background: var(--light); padding: 0.6rem 1rem; border-radius: 12px; max-width: 350px; }
.search-box input { background: transparent; border: none; outline: none; width: 100%; font-size: 0.9rem; }

.rooms-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 1.5rem; }
.room-card { padding: 1.5rem; border: 1.5px solid var(--border); border-radius: 20px; transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1); }
.room-card:hover { border-color: var(--primary); transform: translateY(-5px); box-shadow: 0 10px 30px rgba(0,0,0,0.05); }

.room-header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 1rem; }
.room-icon-box { width: 48px; height: 48px; background: var(--primary-light); color: var(--primary); border-radius: 12px; display: flex; align-items: center; justify-content: center; }
.btn-icon-more { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border-radius: 8px; color: var(--gray); transition: all 0.2s; }
.btn-icon-more:hover { background: var(--light); color: var(--dark); }

.room-body h3 { font-size: 1.2rem; font-weight: 800; color: var(--dark); margin-bottom: 0.5rem; }
.room-body .description { font-size: 0.85rem; color: var(--gray); line-height: 1.5; margin-bottom: 1.25rem; min-height: 2.5em; overflow: hidden; display: -webkit-box; -webkit-line-clamp: 2; line-clamp: 2; -webkit-box-orient: vertical; }

.room-meta { display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--border); padding-top: 1rem; }
.meta-item { display: flex; align-items: center; gap: 6px; color: var(--gray); font-size: 0.85rem; font-weight: 600; }
.status-pill { padding: 4px 12px; border-radius: 8px; font-size: 0.75rem; font-weight: 700; }
.status-pill.active { background: #E8F5E9; color: #2E7D32; }
.status-pill.busy { background: #FFEBEE; color: #C62828; }

.no-data-card { grid-column: 1 / -1; display: flex; flex-direction: column; align-items: center; gap: 1rem; padding: 4rem; color: var(--gray); opacity: 0.5; }

.pagination-footer { margin-top: 1.5rem; padding-top: 1.5rem; display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--border); }
.pagination-info { font-size: 0.9rem; color: var(--gray); }
.pagination-info b { color: var(--dark); }
.pagination-controls { display: flex; align-items: center; gap: 1rem; }
.page-numbers { display: flex; gap: 0.5rem; }
.btn-page, .btn-number { width: 36px; height: 36px; display: flex; align-items: center; justify-content: center; border-radius: 10px; border: 1px solid var(--border); background: white; font-weight: 600; color: var(--dark); transition: all 0.2s; }
.btn-page:not(:disabled):hover, .btn-number:not(.active):hover { border-color: var(--primary); color: var(--primary); }
.btn-number.active { background: var(--primary); color: white; border-color: var(--primary); }
.btn-page:disabled { opacity: 0.5; cursor: not-allowed; }

/* Modal Styles */
.modal-overlay { position: fixed; inset: 0; background: rgba(0,0,0,0.5); backdrop-filter: blur(4px); z-index: 1000; display: flex; align-items: center; justify-content: center; padding: 1rem; }
.modal-box { background: white; border-radius: 24px; width: 100%; max-width: 500px; box-shadow: 0 20px 60px rgba(0,0,0,0.2); }
.modal-header { padding: 1.5rem; border-bottom: 1px solid var(--border); display: flex; justify-content: space-between; align-items: center; }
.title-with-icon { display: flex; align-items: center; gap: 1rem; }
.icon-bg { width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; }
.icon-bg.primary { background: var(--primary-light); color: var(--primary); }
.modal-body { padding: 1.5rem; }
.form-group { margin-bottom: 1.25rem; }
.form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }
label { display: block; font-size: 0.85rem; font-weight: 700; color: var(--dark); margin-bottom: 6px; }
input, select, textarea { width: 100%; padding: 0.75rem 1rem; border: 1.5px solid var(--border); border-radius: 12px; background: var(--light); outline: none; transition: all 0.2s; }
input:focus, select:focus, textarea:focus { border-color: var(--primary); background: white; box-shadow: 0 0 0 4px var(--primary-light); }
.modal-footer { padding: 1.5rem; background: #F8F9FA; display: flex; justify-content: flex-end; gap: 1rem; border-radius: 0 0 24px 24px; }

.btn-secondary { padding: 0.75rem 1.5rem; font-weight: 700; color: var(--gray); border-radius: 12px; }
.btn-primary-confirm { padding: 0.75rem 2rem; background: var(--primary); color: white; font-weight: 700; border-radius: 12px; display: flex; align-items: center; gap: 8px; }
.btn-danger { padding: 0.75rem 2rem; background: var(--danger); color: white; border-radius: 12px; font-weight: 700; }

.confirm-modal { padding: 2.5rem; text-align: center; max-width: 400px; }
.confirm-icon { color: var(--danger); margin-bottom: 1rem; }
.confirm-modal h3 { font-size: 1.5rem; font-weight: 800; margin-bottom: 0.5rem; }
.confirm-modal p { color: var(--gray); margin-bottom: 2rem; }
.confirm-actions { display: flex; gap: 1rem; }
.confirm-actions button { flex: 1; display: flex; justify-content: center; align-items: center; }

.room-actions { position: relative; }
.dropdown-menu { position: absolute; top: 100%; right: 0; margin-top: 0.5rem; background: white; border: 1.5px solid var(--border); border-radius: 12px; padding: 0.5rem; min-width: 170px; z-index: 10; box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1); }
.dropdown-item { width: 100%; display: flex; align-items: center; gap: 0.75rem; padding: 0.75rem 1rem; font-size: 0.9rem; font-weight: 600; border-radius: 8px; transition: all 0.2s; }
.dropdown-item:hover { background: var(--light); color: var(--primary); }
.dropdown-item.danger { color: var(--danger); }
.dropdown-item.danger:hover { background: #FFEBEE; }

.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
.skeleton-card { border: none !important; }
.skeleton { background: linear-gradient(90deg, #f0f0f0 25%, #e0e0e0 50%, #f0f0f0 75%); background-size: 200% 100%; animation: skeleton-loading 1.5s infinite; }
@keyframes skeleton-loading { 0% { background-position: 200% 0; } 100% { background-position: -200% 0; } }
</style>
