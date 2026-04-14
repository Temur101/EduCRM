<script setup>
import {
  MoreVertical,
  MessageSquare,
  Phone,
  Plus,
  X,
  Check,
  Layout,
  UserPlus,
  Archive,
  Edit,
  Save,
  Trash2,
  Loader2,
  BookOpen,
  Globe,
  Zap
} from 'lucide-vue-next';
import { ref, reactive, nextTick, onMounted, onUnmounted } from 'vue';
import draggable from 'vuedraggable';
import { supabase } from '../supabase.js';

const activeDropdown = ref(null);
const isLoading = ref(true);
const boards = ref([]);
const priorityFilters = ['All', 'Hot', 'Warm', 'Cold'];
const activePriority = ref('All');
const isSubmitting = ref(false);
const isSubmittingStage = ref(false);
const deletingLeadId = ref(null);
const movingLeadId = ref(null);

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
    const { data: stagesData, error: stagesErr } = await supabase.from('lead_stages').select('*').order('created_at', { ascending: true });
    if (stagesErr) throw stagesErr;

    const { data: leadsData, error: leadsErr } = await supabase.from('leads').select('*');
    if (leadsErr) throw leadsErr;

    boards.value = stagesData.map(s => ({
      id: s.id,
      title: s.title,
      color: s.color,
      leads: leadsData.filter(l => l.stage_id === s.id).map(l => ({
        id: l.id,
        name: l.name,
        phone: l.phone,
        phone2: l.phone2,
        source: l.source,
        interest: l.interest,
        description: l.description,
        priority: l.priority || 'Warm',
        initials: l.name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2),
        avatarColor: l.avatar_color || '#7366FF',
        commentsList: l.comments_list || []
      }))
    }));
  } catch (e) {
    console.error('Error loading data:', e);
  } finally {
    isLoading.value = false;
  }
};

const filteredCount = (leads) => {
  if (!leads) return 0;
  if (activePriority.value === 'All') return leads.length;
  return leads.filter(l => l.priority === activePriority.value).length;
};

onMounted(() => {
  document.addEventListener('click', closeDropdowns);
  loadData();
});

onUnmounted(() => {
  document.removeEventListener('click', closeDropdowns);
});

const deleteBoard = async (boardId) => {
  try {
    const { error } = await supabase.from('lead_stages').delete().eq('id', boardId);
    if (error) throw error;
    boards.value = boards.value.filter(b => b.id !== boardId);
  } catch (e) {
    console.error(e);
  }
};

const deleteLead = async (boardId, leadId) => {
  if (deletingLeadId.value) return;
  deletingLeadId.value = leadId;
  try {
    const board = boards.value.find(b => b.id === boardId);
    if (board) {
      const leadToArchive = board.leads.find(l => l.id === leadId);
      if (leadToArchive) {
         await supabase.from('archives').insert([{
            type: 'lead',
            original_id: leadId,
            data: leadToArchive
         }]);
      }
    }
    const { error } = await supabase.from('leads').delete().eq('id', leadId);
    if (error) throw error;
    if (board) {
      board.leads = board.leads.filter(l => l.id !== leadId);
      activeDropdown.value = null;
    }
  } catch (e) {
    console.error('Error archiving/deleting lead:', e);
    deletingLeadId.value = null;
  }
};

const moveLeadToToday = async (lead) => {
  if (movingLeadId.value) return;
  movingLeadId.value = lead.id;
  try {
    const TODAY_BOARD_TITLE = "Today task list";
    // 1. Find or create the Today board
    let { data: todayBoard, error: boardErr } = await supabase
      .from('boards')
      .select('id, title, color')
      .eq('title', TODAY_BOARD_TITLE)
      .maybeSingle();

    if (boardErr || !todayBoard) {
      const { data: newBoard, error: createErr } = await supabase
        .from('boards')
        .insert([{ 
          id: crypto.randomUUID(), 
          title: TODAY_BOARD_TITLE, 
          color: '#7366FF',
          created_at: new Date().toISOString()
        }])
        .select()
        .single();
      if (createErr) throw createErr;
      todayBoard = newBoard;
    }

    // 2. Create a task based on this lead
    const creationDate = new Date().toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    const dbTask = {
      id: crypto.randomUUID(),
      board_id: todayBoard.id,
      title: lead.name,
      description: `[LEAD_DATA]${JSON.stringify({ 
        initials: lead.initials, 
        avatarColor: lead.avatarColor, 
        phone: lead.phone, 
        phone2: lead.phone2,
        source: lead.source,
        interest: lead.interest,
        leadPriority: lead.priority
      })}[/LEAD_DATA]\n${lead.description || ''}`,
      priority: 'High', // Backend priority level
      due_date: creationDate,
      progress: 0,
      comments_list: []
    };

    const { error: taskErr } = await supabase.from('tasks').insert([dbTask]);
    if (taskErr) throw taskErr;

  } catch (e) {
    console.error('Error moving lead to today:', e);
  } finally {
    movingLeadId.value = null;
  }
};

// --- Lead Modal State ---
const showLeadModal = ref(false);
const targetBoardId = ref(null);
const newLead = reactive({
  name: '',
  phone: '',
  phone2: '',
  source: '',
  interest: '',
  description: '',
  priority: 'Warm'
});
const priorities = ['Hot', 'Warm', 'Cold'];
const getPriorityColor = (p) => {
  switch (p) {
    case 'Hot': return '#EA5455';
    case 'Warm': return '#FF9F43';
    case 'Cold': return '#00CFE8';
    default: return '#7366FF';
  }
};
const sources = ['Website', 'Referral', 'Cold Call', 'Social Media', 'Event', 'Other'];
const courses = [
  { label: 'English', icon: '🇬🇧' },
  { label: 'IT / Programming', icon: '💻' },
  { label: 'Mathematics', icon: '📐' },
  { label: 'Russian', icon: '🇷🇺' },
  { label: 'Chinese', icon: '🇨🇳' },
  { label: 'Design', icon: '🎨' },
  { label: 'Marketing', icon: '📣' },
  { label: 'Other', icon: '📚' },
];
const avatarColors = ['#7366FF', '#FF9F43', '#28C76F', '#EA5455', '#00CFE8', '#A29BFE'];

const openLeadModal = (boardId) => {
  targetBoardId.value = boardId;
  newLead.name = '';
  newLead.phone = '';
  newLead.phone2 = '';
  newLead.source = '';
  newLead.interest = '';
  newLead.description = '';
  newLead.priority = 'Warm';
  showLeadModal.value = true;
};

const closeLeadModal = () => {
  showLeadModal.value = false;
};

// --- Lead Details Modal State ---
const showLeadDetailsModal = ref(false);
const selectedLeadDetails = ref(null);
const newComment = ref('');

const openLeadDetails = (lead) => {
  if (!lead.commentsList) {
    lead.commentsList = []; 
  }
  selectedLeadDetails.value = lead;
  newComment.value = '';
  showLeadDetailsModal.value = true;
};

const closeLeadDetails = () => {
  showLeadDetailsModal.value = false;
  selectedLeadDetails.value = null;
  isEditing.value = false;
};

const isEditing = ref(false);
const editForm = reactive({
  name: '',
  description: '',
  priority: '',
  source: '',
  interest: '',
  phone: '',
  phone2: ''
});

const startEditing = () => {
  editForm.name = selectedLeadDetails.value.name;
  editForm.description = selectedLeadDetails.value.description;
  editForm.priority = selectedLeadDetails.value.priority;
  editForm.source = selectedLeadDetails.value.source;
  editForm.interest = selectedLeadDetails.value.interest;
  editForm.phone = selectedLeadDetails.value.phone;
  editForm.phone2 = selectedLeadDetails.value.phone2;
  isEditing.value = true;
};

const saveLeadChanges = async () => {
  if (!editForm.name.trim()) return;
  try {
    const { error } = await supabase.from('leads').update({
      name: editForm.name,
      description: editForm.description,
      priority: editForm.priority,
      source: editForm.source,
      interest: editForm.interest,
      phone: editForm.phone,
      phone2: editForm.phone2
    }).eq('id', selectedLeadDetails.value.id);
    
    if (error) throw error;
    
    selectedLeadDetails.value.name = editForm.name;
    selectedLeadDetails.value.description = editForm.description;
    selectedLeadDetails.value.priority = editForm.priority;
    selectedLeadDetails.value.source = editForm.source;
    selectedLeadDetails.value.interest = editForm.interest;
    selectedLeadDetails.value.phone = editForm.phone;
    selectedLeadDetails.value.phone2 = editForm.phone2;
    selectedLeadDetails.value.initials = getInitials(editForm.name);
    
    boards.value.forEach(b => {
      const l = b.leads.find(lead => lead.id === selectedLeadDetails.value.id);
      if (l) {
        Object.assign(l, {
          name: editForm.name,
          description: editForm.description,
          priority: editForm.priority,
          source: editForm.source,
          interest: editForm.interest,
          phone: editForm.phone,
          phone2: editForm.phone2,
          initials: getInitials(editForm.name)
        });
      }
    });

    isEditing.value = false;
  } catch (e) {
    console.error(e);
  }
};

const addComment = async () => {
  if (!newComment.value.trim() || !selectedLeadDetails.value) return;
  const comment = {
    id: Date.now(),
    text: newComment.value.trim(),
    author: 'Admin User',
    time: new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})
  };
  const updatedComments = [...(selectedLeadDetails.value.commentsList || []), comment];
  try {
    await supabase.from('leads').update({ comments_list: updatedComments }).eq('id', selectedLeadDetails.value.id);
    selectedLeadDetails.value.commentsList.push(comment);
    newComment.value = '';
  } catch (e) {
    console.error(e);
  }
};

const getInitials = (name) => {
  return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
};

const confirmAddLead = async () => {
  if (!newLead.name.trim() || isSubmitting.value) return;
  isSubmitting.value = true;
  const boardId = targetBoardId.value;
  const boardIndex = boards.value.findIndex(b => b.id === boardId);
  if (boardIndex > -1) {
    const randomColor = avatarColors[Math.floor(Math.random() * avatarColors.length)];
    const dbLead = {
      id: crypto.randomUUID(),
      stage_id: boardId,
      name: newLead.name.trim(),
      phone: newLead.phone.trim(),
      phone2: newLead.phone2.trim(),
      source: newLead.source || 'Other',
      interest: newLead.interest,
      description: newLead.description.trim(),
      priority: newLead.priority,
      avatar_color: randomColor,
      comments_list: []
    };
    try {
      await supabase.from('leads').insert([dbLead]);
      boards.value[boardIndex].leads.push({
        ...dbLead,
        initials: getInitials(dbLead.name),
        avatarColor: dbLead.avatar_color,
        commentsList: []
      });
      closeLeadModal();
    } catch (e) {
      console.error(e);
    } finally {
      isSubmitting.value = false;
    }
  } else {
    isSubmitting.value = false;
  }
};

// --- Board Modal State ---
const showBoardModal = ref(false);
const newBoard = reactive({ title: '', color: '#7366FF' });
const boardColors = [
  '#7366FF', '#FF9F43', '#28C76F', '#EA5455',
  '#00CFE8', '#FF6B6B', '#A29BFE', '#FD79A8'
];

const openBoardModal = () => {
  newBoard.title = '';
  newBoard.color = '#7366FF';
  showBoardModal.value = true;
};

const closeBoardModal = () => {
  showBoardModal.value = false;
};

const confirmAddBoard = async () => {
  if (!newBoard.title.trim() || isSubmittingStage.value) return;
  isSubmittingStage.value = true;
  const newStage = {
    id: `stage-${Date.now()}`,
    title: newBoard.title.trim(),
    color: newBoard.color,
    created_at: new Date().toISOString()
  };
  try {
    await supabase.from('lead_stages').insert([newStage]);
    boards.value.push({
      ...newStage,
      leads: []
    });
    closeBoardModal();
  } catch (e) {
    console.error(e);
  } finally {
    isSubmittingStage.value = false;
  }
};

const handleDragChange = async (event, stageId) => {
  if (event.added) {
    const leadId = event.added.element.id;
    try {
      await supabase.from('leads').update({ stage_id: stageId }).eq('id', leadId);
    } catch (e) {
      console.error('Error updating lead stage:', e);
    }
  }
};
</script>

<template>
  <div class="leads-page">
    <!-- Header Filters -->
    <div class="leads-filters">
      <div class="priority-tabs">
        <span class="label">{{ $t('leads.priority') }}</span>
        <button
          v-for="p in priorityFilters"
          :key="p"
          :class="['tab', { active: activePriority === p }]"
          @click="activePriority = p"
        >
          {{ $t('leads.' + p.toLowerCase()) }}
        </button>
      </div>
      <div class="filter-actions">
        <button class="btn-add-board" @click="openBoardModal">
          <Plus :size="18" /> {{ $t('leads.addStage') }}
        </button>
      </div>
    </div>

    <!-- Kanban Board -->
    <div class="kanban-outer-container">
      <div class="kanban-wrapper">
        <!-- Skeleton Loading State -->
        <template v-if="isLoading">
          <div v-for="i in 4" :key="i" class="kanban-column skeleton-column">
            <div class="board-header" style="margin-bottom: 1.5rem;">
              <div class="header-main">
                <div class="skeleton" style="width: 12px; height: 12px; border-radius: 50%;"></div>
                <div class="skeleton" style="width: 100px; height: 18px;"></div>
              </div>
              <div class="skeleton" style="width: 24px; height: 24px; border-radius: 6px;"></div>
            </div>
            
            <div class="drag-area">
              <div v-for="j in 2" :key="j" class="lead-card card skeleton-card">
                <div class="lead-top" style="margin-bottom: 1rem;">
                  <div class="skeleton" style="width: 42px; height: 42px; border-radius: 12px;"></div>
                  <div class="lead-identity" style="flex: 1;">
                    <div class="skeleton" style="width: 70%; height: 18px; margin-bottom: 0.5rem;"></div>
                    <div class="skeleton" style="width: 40%; height: 12px;"></div>
                  </div>
                </div>
                <div class="lead-tags" style="margin-bottom: 1rem;">
                  <div class="skeleton" style="width: 60px; height: 20px; border-radius: 20px;"></div>
                  <div class="skeleton" style="width: 80px; height: 20px; border-radius: 20px;"></div>
                </div>
                <div class="card-footer" style="padding-top: 1rem; border-top: 1px solid var(--border);">
                   <div class="skeleton" style="width: 50px; height: 16px;"></div>
                   <div class="skeleton" style="width: 70px; height: 26px; border-radius: 20px;"></div>
                </div>
              </div>
            </div>
            
            <div class="skeleton" style="width: 100%; height: 45px; border-radius: 12px; margin-top: 1rem;"></div>
          </div>
        </template>

        <!-- Real Data -->
        <template v-else>
          <div v-for="board in boards" :key="board.id" class="kanban-column">
            <div class="board-header">
              <div class="header-main">
                <span class="dot" :style="{ backgroundColor: board.color }"></span>
                <h3 class="board-title">{{ board.title }}</h3>
                <span class="count">{{ filteredCount(board.leads).toString().padStart(2, '0') }}</span>
              </div>
              <div class="dropdown-wrapper">
                <button class="btn-icon" @click="(e) => toggleDropdown('board-' + board.id, e)">
                  <MoreVertical :size="18" />
                </button>
                <div v-if="activeDropdown === 'board-' + board.id" class="dropdown-menu">
                  <button class="dropdown-item" @click="deleteBoard(board.id)">
                    <Trash2 :size="16" /> {{ $t('leads.delete') }}
                  </button>
                </div>
              </div>
            </div>

            <draggable
              v-model="board.leads"
              group="leads"
              item-key="id"
              class="drag-area"
              ghost-class="ghost-card"
              @change="(e) => handleDragChange(e, board.id)"
            >
              <template #item="{ element: lead }">
                <div class="lead-card card" v-show="activePriority === 'All' || lead.priority === activePriority">
                  <!-- Avatar + Name -->
                  <div class="lead-top">
                    <div class="lead-avatar" :style="{ backgroundColor: lead.avatarColor + '25', color: lead.avatarColor }">
                      {{ lead.initials }}
                    </div>
                    <div class="lead-identity">
                      <h4 class="lead-name">{{ lead.name }}</h4>
                      <span 
                        class="tag tag-priority"
                        :style="{ backgroundColor: getPriorityColor(lead.priority) }"
                      >
                        <span class="dot-small"></span>
                        {{ $t('leads.' + lead.priority.toLowerCase()) }}
                      </span>
                    </div>
                    <div class="dropdown-wrapper ml-auto">
                      <button class="btn-icon" @click="(e) => toggleDropdown('lead-' + lead.id, e)">
                        <MoreVertical :size="16" />
                      </button>
                      <div v-if="activeDropdown === 'lead-' + lead.id" class="dropdown-menu">
                        <button class="dropdown-item" @click="deleteLead(board.id, lead.id)" :disabled="deletingLeadId === lead.id">
                          <Loader2 v-if="deletingLeadId === lead.id" :size="16" class="spin" />
                          <Trash2 v-else :size="16" /> 
                          {{ deletingLeadId === lead.id ? $t('common.loading') : $t('leads.delete') }}
                        </button>
                      </div>
                    </div>
                  </div>

                  <!-- Interest & Source Tags -->
                  <div class="lead-tags">
                    <span v-if="lead.interest" class="tag tag-interest">
                      <BookOpen :size="12" />
                      {{ lead.interest }}
                    </span>
                    <span class="tag tag-source">
                      <Globe :size="12" />
                      {{ lead.source }}
                    </span>
                  </div>

                  <!-- Description snippet -->
                  <p v-if="lead.description" class="lead-desc">{{ lead.description }}</p>

                  <!-- Phone 1 & 2 -->
                  <div class="lead-contacts">
                    <div class="contact-row" v-if="lead.phone">
                      <Phone :size="14" />
                      <span>{{ lead.phone }}</span>
                    </div>
                    <div class="contact-row" v-if="lead.phone2">
                      <Phone :size="14" />
                      <span>{{ lead.phone2 }}</span>
                    </div>
                  </div>

                  <!-- Footer -->
                  <div class="card-footer">
                    <div class="lead-meta">
                      <button class="meta-item btn-msg" @click="openLeadDetails(lead)">
                        <MessageSquare :size="15" /> {{ lead.commentsList ? lead.commentsList.length : (lead.comments ?? 0) }}
                      </button>
                    </div>
                    <button 
                      class="btn-move-today ml-auto" 
                      @click="moveLeadToToday(lead)"
                      :disabled="movingLeadId === lead.id"
                      :title="$t('leads.moveToTodayTooltip')"
                    >
                      <Loader2 v-if="movingLeadId === lead.id" :size="14" class="spin" />
                      <Zap v-else :size="14" /> 
                      {{ movingLeadId === lead.id ? $t('common.loading') : $t('leads.moveToToday') }}
                    </button>
                  </div>
                </div>
              </template>
            </draggable>

            <button class="btn-new-lead" @click="openLeadModal(board.id)">
              <Plus :size="18" /> {{ $t('leads.newLeadBtn') }}
            </button>
          </div>

          <!-- Add Stage Placeholder -->
          <div class="kanban-column add-column-placeholder" @click="openBoardModal">
            <div class="placeholder-content">
              <Plus :size="32" />
              <span>{{ $t('leads.addStagePlaceholder') }}</span>
            </div>
          </div>
        </template>
      </div>
    </div>

    <!-- Add Lead Modal -->
    <transition name="modal">
      <div v-if="showLeadModal" class="modal-overlay" @click.self="closeLeadModal">
        <div class="modal-box lead-modal-box">
          <div class="modal-header">
            <div class="modal-title-row">
              <div class="modal-icon lead-icon"><UserPlus :size="22" /></div>
              <h2>{{ $t('leads.newLeadModalTitle') || 'Add New Lead' }}</h2>
            </div>
            <button class="btn-icon" @click="closeLeadModal"><X :size="20" /></button>
          </div>

          <div class="modal-body">
            <!-- Full Name (full width) -->
            <div class="form-group">
              <label>{{ $t('leads.name') }} <span class="required">*</span></label>
              <input v-model="newLead.name" :placeholder="$t('leads.namePlaceholder') || 'e.g. John Smith'" @keyup.enter="confirmAddLead" autofocus />
            </div>

            <!-- Phone 1 & Phone 2 -->
            <div class="form-row">
              <div class="form-group">
                <label>{{ $t('leads.phone1') }} <span class="required">*</span></label>
                <input v-model="newLead.phone" placeholder="+998 90 000 0000" />
              </div>
              <div class="form-group">
                <label>{{ $t('leads.phone2') }}</label>
                <input v-model="newLead.phone2" placeholder="+998 71 000 0000" />
              </div>
            </div>

            <!-- Lead Source (full width) -->
            <div class="form-group">
              <label>{{ $t('leads.source') }}</label>
              <select v-model="newLead.source">
                <option value="" disabled>{{ $t('leads.selectSource') }}</option>
                <option v-for="s in sources" :key="s" :value="s">{{ s }}</option>
              </select>
            </div>

            <!-- Wants to Learn -->
            <div class="form-group">
              <label>{{ $t('leads.wantsToLearn') }}</label>
              <div class="course-pills">
                <button
                  v-for="course in courses"
                  :key="course.label"
                  type="button"
                  :class="['course-pill', { active: newLead.interest === course.label }]"
                  @click="newLead.interest = newLead.interest === course.label ? '' : course.label"
                >
                  <span>{{ course.icon }}</span> {{ course.label }}
                </button>
              </div>
            </div>

            <!-- Priority Selector -->
            <div class="form-group">
              <label>{{ $t('leads.leadPriority') }}</label>
              <div class="priority-selector">
                <button
                  v-for="p in priorities"
                  :key="p"
                  type="button"
                  :class="['priority-pill', { active: newLead.priority === p }]"
                  :style="newLead.priority === p ? { background: getPriorityColor(p), color: 'white' } : {}"
                  @click="newLead.priority = p"
                >
                  <span class="pill-dot" :style="{ backgroundColor: newLead.priority === p ? 'white' : getPriorityColor(p) }"></span>
                  {{ $t('leads.' + p.toLowerCase()) }}
                </button>
              </div>
            </div>

            <!-- Description -->
            <div class="form-group">
              <label>{{ $t('leads.description') }} <span class="optional">({{ $t('leads.optional') }})</span></label>
              <textarea
                v-model="newLead.description"
                :placeholder="$t('leads.notesPlaceholder')"
                rows="3"
              ></textarea>
            </div>
          </div>

          <div class="modal-footer">
            <button class="btn-cancel-modal" @click="closeLeadModal" :disabled="isSubmitting">{{ $t('common.cancel') }}</button>
            <button
              class="btn-create-lead"
              :disabled="!newLead.name.trim() || isSubmitting"
              @click="confirmAddLead"
            >
              <template v-if="isSubmitting">
                <Loader2 :size="16" class="spin" /> {{ $t('common.loading') }}
              </template>
              <template v-else>
                <Plus :size="16" /> {{ $t('leads.addLeadBtn') }}
              </template>
            </button>
          </div>
        </div>
      </div>
    </transition>

    <!-- Add Stage Board Modal -->
    <transition name="modal">
      <div v-if="showBoardModal" class="modal-overlay" @click.self="closeBoardModal">
        <div class="modal-box">
          <div class="modal-header">
            <div class="modal-title-row">
              <div class="modal-icon"><Layout :size="22" /></div>
              <h2>{{ $t('leads.createStageModalTitle') || 'Create New Stage' }}</h2>
            </div>
            <button class="btn-icon" @click="closeBoardModal"><X :size="20" /></button>
          </div>
          <div class="modal-body">
            <div class="form-group">
              <label>{{ $t('leads.stageName') }} <span class="required">*</span></label>
              <input v-model="newBoard.title" :placeholder="$t('leads.stageNamePlaceholder')" @keyup.enter="confirmAddBoard" autofocus />
            </div>
            <div class="form-group">
              <label>{{ $t('leads.stageColor') }}</label>
              <div class="color-swatches">
                <button
                  v-for="color in boardColors"
                  :key="color"
                  class="swatch"
                  :class="{ active: newBoard.color === color }"
                  :style="{ backgroundColor: color }"
                  @click="newBoard.color = color"
                >
                  <Check v-if="newBoard.color === color" :size="14" color="white" />
                </button>
              </div>
            </div>
          </div>
          <div class="modal-footer">
            <button class="btn-cancel-modal" @click="closeBoardModal" :disabled="isSubmittingStage">{{ $t('common.cancel') }}</button>
            <button class="btn-create-lead" @click="confirmAddBoard" :disabled="!newBoard.title.trim() || isSubmittingStage">
              <template v-if="isSubmittingStage">{{ $t('leads.creating') }}</template>
              <template v-else>
                <Plus :size="16" /> {{ $t('leads.createStageBtn') }}
              </template>
            </button>
          </div>
        </div>
      </div>
    </transition>

    <!-- Lead Details Modal -->
    <transition name="modal">
      <div v-if="showLeadDetailsModal" class="modal-overlay" @click.self="closeLeadDetails">
        <div class="modal-box lead-details-box">
          <div class="td-layout">
            <!-- Left Side: Lead Info -->
            <div class="td-left">
              <div class="td-header">
                <div v-if="!isEditing" class="td-tags">
                  <span class="tag tag-source">{{ selectedLeadDetails.source }}</span>
                  <span v-if="selectedLeadDetails.interest" class="tag tag-interest">{{ selectedLeadDetails.interest }}</span>
                </div>
                <div v-else class="edit-tags-group">
                   <select v-model="editForm.source" class="edit-select-small">
                     <option v-for="s in sources" :key="s" :value="s">{{ s }}</option>
                   </select>
                   <select v-model="editForm.interest" class="edit-select-small">
                     <option value="">{{ $t('leads.noInterest') || 'No course' }}</option>
                     <option v-for="c in courses" :key="c.label" :value="c.label">{{ c.label }}</option>
                   </select>
                </div>

                <div class="td-header-actions ml-auto">
                   <button v-if="!isEditing" class="btn-edit-lead" @click="startEditing">
                     <Edit :size="16" /> {{ $t('common.edit') }}
                   </button>
                   <button v-else class="btn-save-lead" @click="saveLeadChanges">
                     <Save :size="16" /> {{ $t('common.save') }}
                   </button>
                   <button class="btn-icon td-close-mobile" @click="closeLeadDetails"><X :size="20" /></button>
                </div>
              </div>
              
              <div class="td-lead-profile" v-if="!isEditing">
                <div class="td-lead-avatar" :style="{ backgroundColor: selectedLeadDetails.avatarColor + '25', color: selectedLeadDetails.avatarColor }">
                  {{ selectedLeadDetails.initials }}
                </div>
                <h2 class="td-title">{{ selectedLeadDetails.name }}</h2>
              </div>
              <div v-else class="edit-profile-group">
                <label>{{ $t('leads.name') }}</label>
                <input v-model="editForm.name" class="edit-input-title" />
                
                <div class="edit-priority-row">
                  <label>{{ $t('leads.priority') }}</label>
                  <div class="priority-selector">
                    <button
                      v-for="p in priorities"
                      :key="p"
                      type="button"
                      :class="['priority-pill', { active: editForm.priority === p }]"
                      :style="editForm.priority === p ? { background: getPriorityColor(p), color: 'white' } : {}"
                      @click="editForm.priority = p"
                    >
                      <span class="pill-dot" :style="{ backgroundColor: editForm.priority === p ? 'white' : getPriorityColor(p) }"></span>
                      {{ $t('leads.' + p.toLowerCase()) }}
                    </button>
                  </div>
                </div>
              </div>
              
              <div class="td-desc">
                <h3>{{ $t('leads.description') }}</h3>
                <p v-if="!isEditing">{{ selectedLeadDetails.description || $t('leads.noDescription') }}</p>
                <textarea v-else v-model="editForm.description" rows="4" class="edit-textarea"></textarea>
              </div>
              
              <div class="td-meta">
                <div class="td-meta-item">
                  <span class="label">{{ $t('leads.phone1') }}</span>
                  <span v-if="!isEditing" class="value td-phone"><Phone :size="14"/> {{ selectedLeadDetails.phone || '-' }}</span>
                  <input v-else v-model="editForm.phone" class="edit-input-small" />
                </div>
                <div class="td-meta-item">
                  <span class="label">{{ $t('leads.phone2') }}</span>
                  <span v-if="!isEditing" class="value td-phone"><Phone :size="14"/> {{ selectedLeadDetails.phone2 || '-' }}</span>
                  <input v-else v-model="editForm.phone2" class="edit-input-small" />
                </div>
              </div>
            </div>

            <!-- Right Side: Comments -->
            <div class="td-right">
              <div class="td-right-header">
                <h3>{{ $t('leads.comments') }}</h3>
                <button class="btn-icon td-close-desktop" @click="closeLeadDetails"><X :size="20" /></button>
              </div>
              
              <div class="comments-list">
                <div v-if="selectedLeadDetails.commentsList.length === 0" class="no-comments">
                  {{ $t('leads.noComments') }}
                </div>
                <div v-for="comment in selectedLeadDetails.commentsList" :key="comment.id" class="comment-item">
                  <div class="comment-avatar">{{ comment.author.charAt(0) }}</div>
                  <div class="comment-content">
                    <div class="comment-top">
                      <span class="comment-author">{{ comment.author }}</span>
                      <span class="comment-time">{{ comment.time }}</span>
                    </div>
                    <p class="comment-text">{{ comment.text }}</p>
                  </div>
                </div>
              </div>
              
              <div class="comment-input-area">
                <textarea 
                  v-model="newComment" 
                  :placeholder="$t('leads.typeComment')" 
                  @keyup.enter.prevent="addComment"
                ></textarea>
                <div class="comment-actions">
                    <button class="btn-send-comment" :disabled="!newComment.trim()" @click="addComment">
                      <Send :size="16" /> {{ $t('leads.send') }}
                    </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </transition>
  </div>
</template>

<style scoped>
.leads-page {
  padding: 1.5rem;
  background: var(--light);
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  height: calc(100vh - 70px);
}

/* Filters */
.leads-filters {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2rem;
  gap: 1rem;
}

.priority-tabs {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: white;
  padding: 0.5rem 1rem;
  border-radius: 12px;
  box-shadow: var(--shadow);
  flex-shrink: 0;
}
.priority-tabs .label { 
  font-weight: 700; 
  color: var(--dark); 
  margin-right: 0.5rem;
  font-size: 1rem;
}

.tab {
  padding: 0.4rem 1rem;
  border-radius: 8px;
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--gray);
  transition: all 0.2s ease;
  border: 2px solid transparent;
  background: transparent;
}

.tab:hover {
  color: var(--dark);
}

.tab.active { 
  background: #f0f0ff; 
  color: var(--primary); 
  border-color: var(--primary);
}

.filter-actions { display: flex; gap: 0.75rem; align-items: center; }

.btn-add-board {
  background: var(--primary);
  color: white;
  padding: 0.6rem 1.2rem;
  border-radius: 10px;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-family: inherit;
  cursor: pointer;
  transition: all 0.2s;
}
.btn-add-board:hover { background: #6259e6; box-shadow: 0 4px 12px rgba(115,102,255,0.4); }

/* Kanban */
.kanban-outer-container { flex: 1; overflow: hidden; }
.kanban-wrapper {
  display: flex;
  gap: 1.5rem;
  overflow-x: auto;
  overflow-y: hidden;
  height: 100%;
  padding-bottom: 2rem;
  padding-right: 2rem;
}

.kanban-wrapper::-webkit-scrollbar { height: 8px; }
.kanban-wrapper::-webkit-scrollbar-track { background: transparent; }
.kanban-wrapper::-webkit-scrollbar-thumb { background: var(--border); border-radius: 10px; }
.kanban-wrapper::-webkit-scrollbar-thumb:hover { background: var(--gray); }

.kanban-column {
  width: 320px;
  min-width: 320px;
  background: rgba(235, 237, 242, 0.4);
  padding: 1rem;
  border-radius: 16px;
  display: flex;
  flex-direction: column;
  gap: 1rem;
  height: 100%;
  box-sizing: border-box;
}

.board-header { display: flex; justify-content: space-between; align-items: center; }
.header-main { display: flex; align-items: center; gap: 0.75rem; }
.dot { width: 10px; height: 10px; border-radius: 50%; }
.board-title { font-size: 1.1rem; font-weight: 700; }
.count { background: white; font-size: 0.75rem; padding: 0.2rem 0.5rem; border-radius: 6px; color: var(--gray); font-weight: 600; }

.drag-area {
  flex: 1;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding-right: 4px;
}
.drag-area::-webkit-scrollbar { width: 4px; }
.drag-area::-webkit-scrollbar-thumb { background: var(--border); border-radius: 10px; }

/* Lead Card */
.lead-card {
  background: white;
  padding: 1.25rem;
  cursor: grab;
}
.lead-card:active { cursor: grabbing; }
.ghost-card { opacity: 0.5; background: var(--primary-light) !important; border: 2px dashed var(--primary) !important; }

.lead-top {
  display: flex;
  align-items: flex-start;
  gap: 0.75rem;
  margin-bottom: 1rem;
}

.lead-avatar {
  width: 42px;
  height: 42px;
  min-width: 42px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 0.85rem;
}

.lead-identity { flex: 1; }
.lead-name { font-size: 0.95rem; font-weight: 700; margin-bottom: 0.2rem; }

.ml-auto { margin-left: auto; }

/* Tags */
.lead-tags {
  display: flex;
  gap: 0.6rem;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}

.tag {
  font-size: 0.75rem;
  font-weight: 700;
  padding: 0.35rem 0.8rem;
  border-radius: 8px;
  display: flex;
  align-items: center;
  gap: 0.4rem;
  transition: all 0.2s;
}

.tag-interest {
  background: #fff8f0;
  color: #ff9f43;
  border: 1px solid #ffe8cc;
}

.tag-interest:hover {
  background: #ff9f43;
  color: white;
  transform: translateY(-1px);
}

.tag-source {
  background: #f0f0ff;
  color: var(--primary);
  border: 1px solid #e0e0ff;
}

.tag-source:hover {
  background: var(--primary);
  color: white;
  transform: translateY(-1px);
}

.course-pills {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.tag-priority {
  color: white;
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.2rem 0.6rem;
  border-radius: 6px;
  font-size: 0.65rem;
  margin-top: 0.25rem;
  font-weight: 700;
}

.dot-small {
  width: 6px;
  height: 6px;
  background: white;
  border-radius: 50%;
}

.course-pill {
  padding: 0.5rem 0.8rem;
  border-radius: 10px;
  background: var(--light);
  border: 1px solid var(--border);
  font-size: 0.85rem;
  font-weight: 600;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  transition: all 0.2s;
}

.course-pill.active {
  background: var(--primary-light);
  border-color: var(--primary);
  color: var(--primary);
}

.priority-selector {
  display: flex;
  gap: 0.75rem;
}

.priority-pill {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.75rem;
  border-radius: 12px;
  background: var(--light);
  border: 1px solid var(--border);
  font-weight: 700;
  font-size: 0.9rem;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.priority-pill .pill-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
}

.priority-pill.active {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
  border-color: transparent;
}

/* Contact Info */
.lead-contacts {
  display: flex;
  flex-direction: column;
  gap: 0.4rem;
  margin-bottom: 1rem;
}

.contact-row {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.8rem;
  color: var(--gray);
}

.contact-row span {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Card Footer */
.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 0.9rem;
  border-top: 1px solid var(--border);
}

.lead-meta { display: flex; gap: 0.75rem; align-items: center; }
.meta-item {
  display: flex;
  align-items: center;
  gap: 0.3rem;
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--gray);
}

.btn-call {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.35rem 0.85rem;
  border-radius: 20px;
  background: #e8f9ee;
  color: var(--success);
  font-size: 0.75rem;
  font-weight: 700;
  font-family: inherit;
  cursor: pointer;
  border: 1.5px solid #b7f0ce;
  transition: all 0.2s;
}
.btn-call:hover {
  background: var(--success);
  color: white;
  border-color: var(--success);
}

/* New Lead Button */
.btn-new-lead {
  width: 100%;
  padding: 0.8rem;
  background: white;
  border: 2px dashed var(--border);
  border-radius: 12px;
  color: var(--dark);
  font-weight: 600;
  font-family: inherit;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  cursor: pointer;
  transition: all 0.2s;
}
.btn-new-lead:hover { border-color: var(--primary); color: var(--primary); background: var(--primary-light); }

/* Placeholder column */
.add-column-placeholder {
  background: rgba(255,255,255,0.5);
  border: 2px dashed var(--border);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s;
}
.add-column-placeholder:hover { background: var(--primary-light); border-color: var(--primary); color: var(--primary); }

.placeholder-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
  color: var(--gray);
}
.add-column-placeholder:hover .placeholder-content { color: var(--primary); }

.btn-icon { width: 32px; height: 32px; display: flex; align-items: center; justify-content: center; border-radius: 6px; color: var(--gray); cursor: pointer; }
.btn-icon:hover { background: var(--light); }

/* Dropdowns */
.dropdown-wrapper {
  position: relative;
}

.dropdown-menu {
  position: absolute;
  top: 100%;
  right: 0;
  background: white;
  border: 1px solid var(--border);
  border-radius: 8px;
  box-shadow: 0 4px 12px rgba(0,0,0,0.1);
  padding: 0.5rem;
  z-index: 20;
  min-width: 150px;
}

.dropdown-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  width: 100%;
  padding: 0.5rem;
  border-radius: 6px;
  color: var(--danger);
  font-weight: 600;
  cursor: pointer;
  transition: background 0.2s;
  background: transparent;
  border: none;
  font-family: inherit;
  font-size: 0.85rem;
}

.dropdown-item:hover {
  background: #fdf3f3;
}

/* ===== MODAL ===== */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(75, 70, 92, 0.45);
  backdrop-filter: blur(4px);
  z-index: 1000;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
}

.modal-box {
  background: #fff;
  border-radius: 20px;
  width: 100%;
  max-width: 520px;
  box-shadow: 0 25px 60px rgba(75, 70, 92, 0.25);
  overflow: hidden;
}

.lead-modal-box { max-width: 600px; }

.modal-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1.5rem 1.75rem 1.25rem;
  border-bottom: 1px solid var(--border);
}

.modal-title-row { display: flex; align-items: center; gap: 0.75rem; }
.modal-title-row h2 { font-size: 1.2rem; font-weight: 700; margin: 0; }

.modal-icon {
  width: 40px;
  height: 40px;
  background: var(--primary-light);
  color: var(--primary);
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.lead-icon { background: #e8f9ee; color: var(--success); }

.modal-body {
  padding: 1.75rem;
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
}

.form-row { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; }

.form-group { display: flex; flex-direction: column; gap: 0.5rem; }
.form-group label { font-size: 0.85rem; font-weight: 600; color: var(--dark); }
.form-group .required { color: var(--danger); }

.form-group input,
.form-group select {
  width: 100%;
  padding: 0.75rem 1rem;
  border: 1.5px solid var(--border);
  border-radius: 10px;
  font-family: inherit;
  font-size: 0.9rem;
  color: var(--dark);
  outline: none;
  transition: border-color 0.2s;
  background: white;
}

.form-group input:focus,
.form-group select:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(115, 102, 255, 0.12);
}

/* Color swatches */
.color-swatches { display: flex; gap: 0.75rem; flex-wrap: wrap; }
.swatch {
  width: 36px; height: 36px;
  border-radius: 50%;
  border: 3px solid transparent;
  display: flex; align-items: center; justify-content: center;
  cursor: pointer;
  transition: transform 0.2s;
}
.swatch:hover { transform: scale(1.15); }
.swatch.active { border-color: white; box-shadow: 0 0 0 3px currentColor; transform: scale(1.1); }

.modal-footer {
  padding: 1.25rem 1.75rem 1.5rem;
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
  border-top: 1px solid var(--border);
}

.btn-cancel-modal {
  padding: 0.65rem 1.4rem;
  border-radius: 10px;
  border: 1.5px solid var(--border);
  font-weight: 600;
  font-family: inherit;
  color: var(--dark);
  background: white;
  cursor: pointer;
  transition: all 0.2s;
}
.btn-cancel-modal:hover { background: var(--light); }

.btn-create-lead {
  padding: 0.65rem 1.4rem;
  border-radius: 10px;
  background: var(--primary);
  color: white;
  font-weight: 600;
  font-family: inherit;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  transition: all 0.2s;
}
.btn-create-lead:hover { background: #6259e6; box-shadow: 0 4px 12px rgba(115,102,255,0.4); }
.btn-create-lead:disabled { opacity: 0.5; cursor: not-allowed; box-shadow: none; }

/* Course Pills */
.course-pills {
  display: flex;
  flex-wrap: wrap;
  gap: 0.6rem;
}

.course-pill {
  padding: 0.5rem 0.9rem;
  border-radius: 12px;
  border: 1.5px solid var(--border);
  background: white;
  font-family: inherit;
  font-size: 0.85rem;
  font-weight: 600;
  color: var(--dark);
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  transition: all 0.2s;
}

.course-pill:hover {
  border-color: var(--primary);
  background: var(--primary-light);
}

.course-pill.active {
  background: var(--primary);
  color: white;
  border-color: var(--primary);
  box-shadow: 0 4px 10px rgba(115, 102, 255, 0.3);
}

.form-group textarea {
  width: 100%;
  padding: 0.75rem 1rem;
  border: 1.5px solid var(--border);
  border-radius: 10px;
  font-family: inherit;
  font-size: 0.9rem;
  color: var(--dark);
  outline: none;
  transition: border-color 0.2s;
  background: white;
  resize: vertical;
}

.form-group textarea:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(115, 102, 255, 0.12);
}

/* Card Specifics */
.tag-interest {
  background: #fff8f0;
  color: #ff9f43;
}

.lead-desc {
  font-size: 0.78rem;
  color: var(--gray);
  margin-bottom: 0.85rem;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  line-height: 1.4;
}

/* Modal animation */
.modal-enter-active { transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1); }
.modal-leave-active { transition: all 0.2s ease; }
.modal-enter-from { opacity: 0; transform: scale(0.85); }
.modal-leave-to { opacity: 0; transform: scale(0.9); }

/* ========== LEAD DETAILS MODAL ========== */
.lead-details-box {
  max-width: 900px;
  width: 95%;
  padding: 0;
  overflow: hidden;
  background: white;
}

.td-layout {
  display: flex;
  height: 600px;
  max-height: 85vh;
}

.td-left {
  flex: 1;
  padding: 2.5rem;
  overflow-y: auto;
  border-right: 1px solid var(--border);
}

.td-header {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  margin-bottom: 2rem;
}

.td-close-mobile { display: none; }
.td-close-desktop { margin-left: auto; }

.td-lead-profile {
  display: flex;
  align-items: center;
  gap: 1rem;
  margin-bottom: 2rem;
}

.td-lead-avatar {
  width: 60px;
  height: 60px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 800;
  font-size: 1.4rem;
}

.td-title {
  font-size: 1.75rem;
  font-weight: 800;
  color: var(--dark);
  margin: 0;
  line-height: 1.3;
}

.td-desc h3 {
  font-size: 0.85rem;
  color: var(--gray);
  margin-bottom: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  font-weight: 700;
}

.td-desc p {
  line-height: 1.6;
  color: var(--dark);
  margin-bottom: 2rem;
  background: var(--light);
  padding: 1.5rem;
  border-radius: 12px;
  font-size: 1rem;
}

.td-meta {
  display: flex;
  flex-wrap: wrap;
  gap: 2.5rem;
  padding-top: 1.5rem;
  border-top: 1px solid var(--light);
}

.td-meta-item {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.td-meta-item .label {
  font-size: 0.8rem;
  color: var(--gray);
  font-weight: 700;
  text-transform: uppercase;
}

.td-meta-item .value {
  font-weight: 700;
  font-size: 1.1rem;
  color: var(--dark);
}

.td-phone {
  display: flex;
  align-items: center;
  gap: 0.4rem;
}

.td-right {
  width: 400px;
  display: flex;
  flex-direction: column;
  background: #fcfcfc;
}

.td-right-header {
  padding: 1.5rem;
  border-bottom: 1px solid var(--border);
  display: flex;
  align-items: center;
  justify-content: space-between;
  background: white;
}

.td-right-header h3 {
  font-size: 1.1rem;
  font-weight: 800;
  margin: 0;
}

.comments-list {
  flex: 1;
  padding: 1.5rem;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.no-comments {
  text-align: center;
  color: var(--gray);
  margin-top: 2rem;
  font-weight: 600;
  background: var(--light);
  padding: 1rem;
  border-radius: 10px;
}

.comment-item {
  display: flex;
  gap: 1rem;
}

.comment-avatar {
  width: 38px;
  height: 38px;
  border-radius: 12px;
  background: var(--primary-light);
  color: var(--primary);
  font-weight: 800;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  font-size: 1.1rem;
}

.comment-content {
  flex: 1;
}

.comment-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.4rem;
}

.comment-author {
  font-weight: 800;
  font-size: 0.95rem;
  color: var(--dark);
}

.comment-time {
  font-size: 0.75rem;
  color: var(--gray);
  font-weight: 500;
}

.comment-text {
  font-size: 0.95rem;
  line-height: 1.5;
  color: var(--dark);
  background: white;
  padding: 0.85rem 1rem;
  border-radius: 0 12px 12px 12px;
  border: 1px solid var(--border);
  box-shadow: 0 4px 10px rgba(75,70,92,0.03);
}

.btn-edit-lead, .btn-save-lead {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  border-radius: 10px;
  font-weight: 700;
  font-size: 0.85rem;
  transition: all 0.2s;
  border: none;
  cursor: pointer;
  font-family: inherit;
}
.btn-edit-lead {
  background: var(--light);
  color: var(--gray);
}
.btn-edit-lead:hover {
  background: var(--primary-light);
  color: var(--primary);
}
.btn-save-lead {
  background: var(--primary);
  color: white;
}
.btn-save-lead:hover {
  background: #6259e6;
  box-shadow: 0 4px 12px rgba(115,102,255,0.3);
}

.edit-tags-group {
  display: flex;
  gap: 0.75rem;
}
.edit-select-small {
  padding: 0.4rem 0.75rem;
  border-radius: 10px;
  border: 1.5px solid var(--border);
  font-size: 0.85rem;
  font-weight: 700;
  background: white;
  outline: none;
}
.edit-select-small:focus { border-color: var(--primary); }

.edit-profile-group {
  margin-bottom: 2rem;
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}
.edit-profile-group label {
  display: block;
  font-size: 0.85rem;
  font-weight: 700;
  color: var(--gray);
  text-transform: uppercase;
  margin-bottom: 0.5rem;
}
.edit-input-title {
  width: 100%;
  font-size: 1.75rem;
  font-weight: 800;
  color: var(--dark);
  border: none;
  border-bottom: 2px solid var(--primary-light);
  background: transparent;
  outline: none;
  padding: 0.5rem 0;
}
.edit-input-title:focus { border-bottom-color: var(--primary); }

.edit-priority-row {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.edit-input-small {
  width: 100%;
  padding: 0.4rem 0.75rem;
  border: 1.5px solid var(--border);
  border-radius: 8px;
  font-size: 1.1rem;
  font-weight: 700;
  color: var(--dark);
  outline: none;
}
.edit-input-small:focus { border-color: var(--primary); }

.edit-textarea {
  width: 100%;
  padding: 1.25rem;
  border: 1.5px solid var(--border);
  border-radius: 12px;
  background: white;
  font-size: 1rem;
  color: var(--dark);
  line-height: 1.6;
  outline: none;
  resize: vertical;
}
.edit-textarea:focus { border-color: var(--primary); box-shadow: 0 0 0 3px rgba(115,102,255,0.1); }

.td-tags {
  display: flex;
  gap: 0.75rem;
}

.td-header-actions {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.comment-input-area {
  padding: 1.5rem;
  border-top: 1px solid var(--border);
  background: white;
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.comment-input-area textarea {
  width: 100%;
  resize: none;
  border: 1.5px solid var(--border);
  border-radius: 12px;
  padding: 0.85rem 1rem;
  font-family: inherit;
  font-size: 0.95rem;
  outline: none;
  transition: border-color 0.2s;
  height: 90px;
}

.comment-input-area textarea:focus {
  border-color: var(--primary);
  box-shadow: 0 0 0 3px rgba(115,102,255,0.1);
}

.comment-actions {
  display: flex;
  justify-content: flex-end;
}

.btn-send-comment {
  background: var(--primary);
  color: white;
  padding: 0.6rem 1.25rem;
  border-radius: 10px;
  font-weight: 700;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  border: none;
  cursor: pointer;
  font-family: inherit;
}

.btn-send-comment:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-send-comment:not(:disabled):hover {
  background: #6259e6;
  box-shadow: 0 4px 12px rgba(115,102,255,0.3);
}

.btn-msg {
  background: none;
  border: none;
  padding: 0;
  font-family: inherit;
  cursor: pointer;
  transition: color 0.2s;
  display: flex;
  align-items: center;
  gap: 0.4rem; 
  font-size: 0.8rem; 
  font-weight: 600;
  color: var(--gray);
}
.btn-msg:hover {
  color: var(--primary);
}

.btn-move-today {
  display: flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.4rem 0.8rem;
  background: var(--primary-light);
  color: var(--primary);
  border: none;
  border-radius: 8px;
  font-size: 0.75rem;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-move-today:hover {
  background: var(--primary);
  color: white;
  transform: translateY(-2px);
  box-shadow: 0 4px 8px rgba(115, 102, 255, 0.2);
}

.spin { animation: spin 1s linear infinite; }
@keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
@media (max-width: 768px) {
  .td-layout {
    flex-direction: column;
    height: 85vh;
  }
  .td-left { border-right: none; border-bottom: 1px solid var(--border); flex: none; height: 50%; padding: 1.5rem; }
  .td-right { width: 100%; height: 50%; }
  .td-close-desktop { display: none; }
  .td-close-mobile { display: flex; margin-left: auto; }
}
</style>
