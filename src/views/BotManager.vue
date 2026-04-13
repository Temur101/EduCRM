<script setup>
import { 
  MessageSquare, 
  Settings, 
  Terminal, 
  Play, 
  ExternalLink, 
  Bot, 
  Save, 
  RefreshCcw,
  CheckCircle2,
  AlertCircle,
  Copy,
  Plus,
  Users
} from 'lucide-vue-next';
import { ref, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { supabase } from '../supabase.js';

const { t } = useI18n();

const isEditing = ref(false);
const botToken = ref('************************************');
const isConnecting = ref(false);
const connectionStatus = ref('active'); // active, error, dormant
const webhookUrl = ref('https://your-crm-functions.supabase.co/functions/v1/telegram-bot');

const logs = ref([
  { id: 1, type: 'info', msg: t('bot.logConnected', { group: 'IT Academy Staff' }), time: '22:30' },
  { id: 2, type: 'success', msg: t('bot.logTaskCreated', { task: 'Nodiraopa Teacher: Mansur (Yoq)' }), time: '22:31' },
  { id: 3, type: 'info', msg: t('bot.logSyncing'), time: '22:31' },
]);

const toggleEdit = () => {
    isEditing.value = !isEditing.value;
};

const saveConfig = () => {
    isEditing.value = false;
    // Here we would update Supabase vault or secrets
};

const copyWebhook = () => {
    navigator.clipboard.writeText(webhookUrl.value);
    alert(t('bot.webhookCopied'));
};

const groupMembers = [
  { name: 'Nodiraopa Teacher', role: 'Teacher', avatar: 'N' },
  { name: 'Shohruh Tech', role: 'Admin', avatar: 'S' },
  { name: 'Yodgor Teacher', role: 'Teacher', avatar: 'Y' },
];

</script>

<template>
  <div class="bot-manager-page">
    <div class="page-header">
      <div class="header-left">
        <h1 class="page-title">{{ $t('bot.title') }}</h1>
        <p class="breadcrumb">{{ $t('bot.breadcrumb') }}</p>
      </div>
      <div class="header-right">
        <div class="status-badge" :class="connectionStatus">
          <div class="pulse-dot"></div>
          {{ connectionStatus === 'active' ? $t('bot.systemRunning') : $t('bot.connectionError') }}
        </div>
      </div>
    </div>

    <div class="content-grid">
      <!-- Left: Bot Configuration -->
      <div class="config-section">
        <div class="card bot-card">
          <div class="bot-header">
            <div class="bot-info">
              <div class="bot-avatar">
                <Bot :size="32" />
              </div>
              <div class="bot-meta">
                <h3>{{ $t('bot.botName') }}</h3>
                <span class="platform">{{ $t('bot.platform') }}</span>
              </div>
            </div>
          </div>

          <div class="bot-controls">
            <div class="form-group">
              <label>{{ $t('bot.botToken') }}</label>
              <div class="token-input">
                <input :type="isEditing ? 'text' : 'password'" v-model="botToken" :disabled="!isEditing" />
                <button v-if="!isEditing" class="btn-edit" @click="toggleEdit"><Settings :size="16" /> {{ $t('common.edit') }}</button>
                <button v-else class="btn-save" @click="saveConfig"><Save :size="16" /> {{ $t('common.save') }}</button>
              </div>
              <p class="help-text">{{ $t('bot.helpText') }}</p>
            </div>

            <div class="form-group">
                <label>{{ $t('bot.webhookEndpoint') }}</label>
                <div class="webhook-display">
                    <code>{{ webhookUrl }}</code>
                    <button class="btn-copy" @click="copyWebhook"><Copy :size="16" /></button>
                </div>
            </div>
          </div>
        </div>

        <div class="card groups-card">
            <h3>{{ $t('bot.connectedGroups', { count: 1 }) }}</h3>
            <div class="group-item active">
                <div class="group-icon">
                    <Users :size="20" />
                </div>
                <div class="group-info">
                    <p class="group-name">{{ $t('bot.staffGroup') }}</p>
                    <p class="group-members">{{ $t('bot.membersInfo', { count: 16 }) }}</p>
                </div>
                <button class="btn-icon"><Settings :size="16" /></button>
            </div>
            <button class="btn-add-group"><Plus :size="18" /> {{ $t('bot.connectNewGroup') }}</button>
        </div>
      </div>

      <!-- Right: Live Activity & Logs -->
      <div class="logs-section">
        <div class="card terminal-card">
          <div class="card-header">
            <div class="title-row">
                <Terminal :size="20" class="icon" />
                <h3>{{ $t('bot.liveLogs') }}</h3>
            </div>
            <button class="btn-clear"><RefreshCcw :size="14" /> {{ $t('bot.refresh') || 'Refresh' }}</button>
          </div>
          <div class="terminal-box">
             <div v-for="log in logs" :key="log.id" class="log-line" :class="log.type">
                <span class="log-time">[{{ log.time }}]</span>
                <span class="log-type">[{{ log.type.toUpperCase() }}]</span>
                <p class="log-msg">{{ log.msg }}</p>
             </div>
          </div>
        </div>

        <div class="card automation-rules">
            <h3>{{ $t('bot.activeTriggers') }}</h3>
            <div class="rule-item">
                <div class="rule-header">
                    <CheckCircle2 :size="18" class="icon-success" />
                    <h4>{{ $t('bot.attendanceRuleTitle') }}</h4>
                </div>
                <p>{{ $t('bot.attendanceRuleDesc') }}</p>
                <div class="tag-row">
                    <span class="rule-tag">{{ $t('bot.autoParse') }}</span>
                    <span class="rule-tag">{{ $t('bot.priorityHigh') }}</span>
                </div>
            </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.bot-manager-page {
  padding: 2.5rem;
  background: #f8f9fa;
  flex: 1;
  overflow-y: auto;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 2.5rem;
}

.page-title {
  font-size: 1.75rem;
  font-weight: 800;
  color: var(--dark);
  margin-bottom: 0.5rem;
}

.breadcrumb {
  font-size: 0.9rem;
  color: var(--gray);
  font-weight: 500;
}

.status-badge {
    padding: 0.5rem 1rem;
    background: white;
    border-radius: 12px;
    border: 1px solid var(--border);
    display: flex;
    align-items: center;
    gap: 0.75rem;
    font-weight: 700;
    font-size: 0.85rem;
    color: var(--dark);
}

.status-badge.active .pulse-dot { background: var(--success); box-shadow: 0 0 0 4px rgba(40, 199, 111, 0.2); }
.pulse-dot { width: 8px; height: 8px; border-radius: 50%; animation: pulse 2s infinite; }

@keyframes pulse {
    0% { transform: scale(0.95); opacity: 1; }
    50% { transform: scale(1.1); opacity: 0.7; }
    100% { transform: scale(0.95); opacity: 1; }
}

.content-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 2rem;
}

.card {
    background: white;
    border-radius: 20px;
    padding: 2rem;
    border: 1px solid rgba(235, 237, 242, 0.5);
    box-shadow: 0 10px 40px rgba(0,0,0,0.02);
    margin-bottom: 2rem;
}

.bot-card {
    background: linear-gradient(135deg, white, #fdfdfd);
}

.bot-header {
    border-bottom: 1px solid var(--border);
    padding-bottom: 1.5rem;
    margin-bottom: 1.5rem;
}

.bot-info {
    display: flex;
    align-items: center;
    gap: 1.25rem;
}

.bot-avatar {
    width: 64px;
    height: 64px;
    background: var(--primary-light);
    color: var(--primary);
    border-radius: 18px;
    display: flex;
    align-items: center;
    justify-content: center;
}

.bot-meta h3 { font-size: 1.15rem; font-weight: 800; color: var(--dark); margin-bottom: 0.25rem; }
.platform { font-size: 0.75rem; font-weight: 800; color: var(--gray); letter-spacing: 1px; }

.form-group { margin-bottom: 1.5rem; }
.form-group label { display: block; font-size: 0.85rem; font-weight: 800; color: var(--dark); margin-bottom: 0.75rem; }

.token-input, .webhook-display {
    display: flex;
    gap: 0.75rem;
    background: var(--light);
    padding: 0.5rem;
    border-radius: 12px;
    border: 1px solid var(--border);
}

.token-input input { flex: 1; background: transparent; border: none; padding: 0.5rem; font-family: 'Courier New', Courier, monospace; font-size: 0.95rem; outline: none; }
.webhook-display code { flex: 1; font-size: 0.85rem; padding: 0.5rem; word-break: break-all; color: var(--gray); font-weight: 600; }

.btn-edit, .btn-save, .btn-copy { background: white; border: 1px solid var(--border); padding: 0.5rem 0.85rem; border-radius: 8px; font-weight: 700; font-size: 0.8rem; display: flex; align-items: center; gap: 0.4rem; cursor: pointer; }
.btn-save { background: var(--primary); color: white; border-color: var(--primary); }

.help-text { font-size: 0.8rem; color: var(--gray); margin-top: 0.5rem; }

/* Groups Card */
.group-item {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 1rem;
    background: var(--light);
    border-radius: 14px;
    margin-bottom: 1rem;
}

.group-item.active { border: 1.5px solid var(--success-light); background: #f9fdfa; }
.group-icon { width: 40px; height: 40px; border-radius: 10px; background: white; display: flex; align-items: center; justify-content: center; color: var(--success); }
.group-name { font-weight: 700; color: var(--dark); margin-bottom: 0.2rem; }
.group-members { font-size: 0.75rem; color: var(--gray); font-weight: 600; }

.btn-add-group { width: 100%; padding: 1rem; background: transparent; border: 2px dashed var(--border); border-radius: 14px; font-weight: 700; color: var(--gray); cursor: pointer; margin-top: 1rem; }
.btn-add-group:hover { border-color: var(--primary); color: var(--primary); background: var(--primary-light); }

/* Terminal */
.terminal-card { min-height: 400px; display: flex; flex-direction: column; }
.terminal-box { background: #1E1E1E; border-radius: 14px; padding: 1.5rem; flex: 1; font-family: 'Courier New', Courier, monospace; overflow-y: auto; display: flex; flex-direction: column; gap: 0.75rem; }
.log-line { display: flex; gap: 0.75rem; font-size: 0.85rem; line-height: 1.5; }
.log-time { color: #888; }
.log-type { font-weight: 700; }
.log-msg { color: #E0E0E0; }

.info .log-type { color: #4FACFE; }
.success .log-type { color: #28C76F; }
.error .log-type { color: #EA5455; }

.automation-rules h3 { margin-bottom: 1.5rem; font-size: 1.1rem; }
.rule-item { padding: 1.5rem; background: var(--light); border-radius: 16px; border-left: 4px solid var(--success); }
.rule-header { display: flex; align-items: center; gap: 0.75rem; margin-bottom: 0.75rem; }
.rule-header h4 { font-weight: 700; font-size: 1rem; color: var(--dark); }
.rule-item p { font-size: 0.85rem; color: var(--gray); line-height: 1.6; margin-bottom: 1rem; }
.tag-row { display: flex; gap: 0.5rem; }
.rule-tag { background: white; padding: 0.25rem 0.6rem; border-radius: 6px; font-size: 0.7rem; font-weight: 800; color: var(--gray); border: 1px solid var(--border); text-transform: uppercase; }

@media (max-width: 1200px) {
    .content-grid { grid-template-columns: 1fr; }
}
</style>
