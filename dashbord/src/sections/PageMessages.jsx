import { useMemo, useState, useEffect, useCallback } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Stack from '@mui/material/Stack';
import Alert from '@mui/material/Alert';
import Button from '@mui/material/Button';
import Avatar from '@mui/material/Avatar';
import Chip from '@mui/material/Chip';
import Divider from '@mui/material/Divider';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import CardHeader from '@mui/material/CardHeader';
import CircularProgress from '@mui/material/CircularProgress';

import { DashboardContent } from 'src/layouts/dashboard';
import { sendMessageTo, getMessagesWith, getMessageConversations } from 'src/Controller/actions';

import { toast } from 'src/components/snackbar';
import { Iconify } from 'src/components/iconify';

const FILTER_OPTIONS = [
  { key: 'all', label: 'Tous', color: 'default', icon: 'solar:chat-round-dots-bold' },
  { key: 'unread', label: 'Non lus', color: 'warning', icon: 'solar:letter-unread-bold' },
  { key: 'reclamation', label: 'Reclamations', color: 'error', icon: 'solar:danger-bold' },
  { key: 'help', label: 'Demandes d\'aide', color: 'info', icon: 'solar:help-bold' },
];

const RECLAMATION_KEYWORDS = [
  'reclamation',
  'reclam',
  'reclamation',
  'plainte',
  'probleme',
  'probleme',
  'bug',
  'retard',
  'remboursement',
  'annulation',
  'annuler',
];

const HELP_KEYWORDS = [
  'aide',
  'help',
  'assistance',
  'urgent',
  'urgence',
  'sos',
  'svp',
  'besoin',
];

const AUTO_REFRESH_MS = 10000;

function detectConversationType(lastMessage = '') {
  const text = String(lastMessage || '').toLowerCase();
  if (!text) return 'other';
  if (RECLAMATION_KEYWORDS.some((kw) => text.includes(kw))) return 'reclamation';
  if (HELP_KEYWORDS.some((kw) => text.includes(kw))) return 'help';
  return 'other';
}

function normalizeMessage(item) {
  return {
    id: item?._id ?? item?.id ?? '',
    senderId: item?.sender_id?._id ?? item?.sender_id ?? '',
    senderName: item?.sender_id?.fullname ?? item?.sender_id?.email ?? 'Utilisateur',
    senderAvatar: item?.sender_id?.avatar ?? '',
    receiverId: item?.receiver_id?._id ?? item?.receiver_id ?? '',
    content: item?.content ?? '',
    createdAt: item?.createdAt ?? null,
  };
}

function formatDateTime(value) {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '';
  return date.toLocaleString('fr-FR');
}

export function MessagesView({ sx }) {
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [conversations, setConversations] = useState([]);
  const [activeFilter, setActiveFilter] = useState('all');
  const [selectedConversation, setSelectedConversation] = useState(null);
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState('');
  const [error, setError] = useState('');

  const loadMessagesWithUser = useCallback(async (userId) => {
    if (!userId) return;
    try {
      const data = await getMessagesWith(userId);
      const normalized = data.map(normalizeMessage);
      setMessages(normalized);
      setSelectedConversation(userId);
    } catch {
      setError('Impossible de charger les messages avec cet utilisateur.');
      toast.error('Chargement échoué');
    }
  }, []);

  // Initialiser avec une API pour les conversations
  // Pour l'instant, on va charger depuis getMessageConversations
  const initConversations = useCallback(async ({ silent = false } = {}) => {
    try {
      if (!silent) {
        setLoading(true);
      }
      setError('');
      const convList = await getMessageConversations();

      setConversations(
        convList.map((conv) => ({
          partnerId: conv.partner?._id ?? conv.partner?.id ?? '',
          partnerName: conv.partner?.fullname ?? conv.partner?.email ?? 'Utilisateur',
          partnerAvatar: conv.partner?.avatar ?? '',
          lastMessage: conv.lastMessage?.content ?? '',
          category: detectConversationType(conv.lastMessage?.content ?? ''),
          unreadCount: conv.unreadCount ?? 0,
          lastMessageTime: conv.lastMessage?.createdAt ?? null,
        }))
      );
    } catch {
      if (!silent) {
        setError('Erreur lors du chargement des conversations');
        toast.error('Chargement des conversations échoué');
      }
    } finally {
      if (!silent) {
        setLoading(false);
      }
    }
  }, []);

  useEffect(() => {
    initConversations();
  }, [initConversations]);

  useEffect(() => {
    const intervalId = window.setInterval(() => {
      initConversations({ silent: true });
      if (selectedConversation) {
        loadMessagesWithUser(selectedConversation);
      }
    }, AUTO_REFRESH_MS);

    return () => window.clearInterval(intervalId);
  }, [initConversations, loadMessagesWithUser, selectedConversation]);

  const sortedMessages = useMemo(() => {
    const list = [...messages];
    list.sort((a, b) => new Date(a.createdAt || 0).getTime() - new Date(b.createdAt || 0).getTime());
    return list;
  }, [messages]);

  const currentConversation = useMemo(
    () => conversations.find((c) => c.partnerId === selectedConversation),
    [conversations, selectedConversation]
  );

  const filteredConversations = useMemo(() => {
    if (activeFilter === 'unread') {
      return conversations.filter((c) => Number(c.unreadCount || 0) > 0);
    }
    if (activeFilter === 'reclamation') {
      return conversations.filter((c) => c.category === 'reclamation');
    }
    if (activeFilter === 'help') {
      return conversations.filter((c) => c.category === 'help');
    }
    return conversations;
  }, [conversations, activeFilter]);

  const filterStats = useMemo(
    () => ({
      all: conversations.length,
      unread: conversations.filter((c) => Number(c.unreadCount || 0) > 0).length,
      reclamation: conversations.filter((c) => c.category === 'reclamation').length,
      help: conversations.filter((c) => c.category === 'help').length,
    }),
    [conversations]
  );

  useEffect(() => {
    if (!selectedConversation) return;
    const stillVisible = filteredConversations.some((c) => c.partnerId === selectedConversation);
    if (!stillVisible) {
      setSelectedConversation(null);
      setMessages([]);
    }
  }, [filteredConversations, selectedConversation]);

  const handleSendReply = useCallback(async () => {
    if (!selectedConversation) return;
    if (!text.trim()) {
      toast.warning('Saisissez votre réponse');
      return;
    }

    try {
      setSending(true);
      await sendMessageTo(selectedConversation, text);
      setText('');
      await loadMessagesWithUser(selectedConversation);
      await initConversations();
      toast.success('Réponse envoyée');
    } catch {
      toast.error('Envoi échoué');
    } finally {
      setSending(false);
    }
  }, [selectedConversation, loadMessagesWithUser, text, initConversations]);

  return (
    <DashboardContent maxWidth="xl" sx={sx}>
      <Stack spacing={2}>
        <Stack direction="row" alignItems="center" justifyContent="space-between">
          <Typography variant="h4">Messagerie</Typography>
          <Button size="small" startIcon={<Iconify icon="solar:refresh-bold" />} onClick={initConversations} disabled={loading}>
            Rafraîchir
          </Button>
        </Stack>

        {error ? <Alert severity="error">{error}</Alert> : null}

        <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} sx={{ height: 600 }}>
          {/* Liste des conversations */}
          <Card sx={{ flex: '0 0 280px', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
            <CardHeader title="Messages" subheader={`${filteredConversations.length} conversation(s)`} />
            <Stack direction="row" spacing={1} sx={{ px: 2, pb: 1.5, overflowX: 'auto' }}>
              {FILTER_OPTIONS.map((option) => {
                const count = filterStats[option.key];
                const isActive = activeFilter === option.key;

                return (
                  <Chip
                    key={option.key}
                    size="small"
                    icon={<Iconify icon={option.icon} width={16} />}
                    label={`${option.label} (${count})`}
                    color={isActive ? option.color : 'default'}
                    variant={isActive ? 'filled' : 'outlined'}
                    onClick={() => setActiveFilter(option.key)}
                    sx={{
                      borderRadius: 2,
                      fontWeight: isActive ? 700 : 500,
                      px: 0.25,
                      boxShadow: isActive ? 2 : 0,
                    }}
                  />
                );
              })}
            </Stack>
            <Divider />

            {loading ? (
              <Stack alignItems="center" justifyContent="center" sx={{ py: 4, flex: 1 }}>
                <CircularProgress size={32} />
              </Stack>
            ) : filteredConversations.length ? (
              <Stack spacing={0.5} sx={{ overflow: 'auto', flex: 1, p: 1 }}>
                {filteredConversations.map((conv) => (
                  <Button
                    key={conv.partnerId}
                    fullWidth
                    variant={selectedConversation === conv.partnerId ? 'contained' : 'text'}
                    onClick={() => loadMessagesWithUser(conv.partnerId)}
                    sx={{
                      justifyContent: 'flex-start',
                      textAlign: 'left',
                      p: 1.5,
                      borderRadius: 1,
                    }}
                  >
                    <Stack spacing={0.5} sx={{ flex: 1, minWidth: 0 }}>
                      <Stack direction="row" spacing={1} alignItems="center">
                        <Avatar src={conv.partnerAvatar} sx={{ width: 32, height: 32 }} />
                        <Box sx={{ flex: 1, minWidth: 0 }}>
                          <Typography variant="subtitle2" noWrap>
                            {conv.partnerName}
                          </Typography>
                          <Typography variant="caption" color="text.secondary" noWrap>
                            {conv.lastMessage || 'Aucun message'}
                          </Typography>
                          <Typography
                            variant="caption"
                            color={
                              conv.category === 'reclamation'
                                ? 'error.main'
                                : conv.category === 'help'
                                  ? 'info.main'
                                  : 'text.disabled'
                            }
                            noWrap
                          >
                            {conv.category === 'reclamation'
                              ? 'Reclamation'
                              : conv.category === 'help'
                                ? 'Demande d\'aide'
                                : 'General'}
                          </Typography>
                        </Box>
                        {conv.unreadCount ? (
                          <Typography variant="caption" sx={{ bgcolor: 'error.main', color: 'white', px: 0.75, borderRadius: 0.75 }}>
                            {conv.unreadCount}
                          </Typography>
                        ) : null}
                      </Stack>
                    </Stack>
                  </Button>
                ))}
              </Stack>
            ) : (
              <Stack alignItems="center" justifyContent="center" sx={{ py: 6, flex: 1 }}>
                <Typography color="text.secondary">Aucune conversation pour ce filtre</Typography>
              </Stack>
            )}
          </Card>

          {/* Conversation active */}
          <Card sx={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
            {selectedConversation && currentConversation ? (
              <>
                <CardHeader
                  avatar={<Avatar src={currentConversation.partnerAvatar} />}
                  title={currentConversation.partnerName}
                  subheader={`${sortedMessages.length} message(s)`}
                />
                <Divider />

                {/* Messages */}
                <Stack spacing={1} sx={{ overflow: 'auto', flex: 1, p: 2 }}>
                  {sortedMessages.length ? (
                    sortedMessages.map((msg) => {
                      const isAdminMessage = String(msg.receiverId) === String(selectedConversation);
                      return (
                        <Stack
                          key={msg.id || `${msg.senderId}-${msg.createdAt}`}
                          alignItems={isAdminMessage ? 'flex-end' : 'flex-start'}
                        >
                          <Box
                            sx={{
                              px: 1.5,
                              py: 1,
                              borderRadius: 1.5,
                              bgcolor: isAdminMessage ? 'primary.light' : 'grey.100',
                              color: isAdminMessage ? 'primary.contrastText' : 'text.primary',
                              maxWidth: '70%',
                            }}
                          >
                            <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
                              {msg.content}
                            </Typography>
                          </Box>
                          <Typography variant="caption" color="text.secondary" sx={{ mt: 0.25 }}>
                            {formatDateTime(msg.createdAt)}
                          </Typography>
                        </Stack>
                      );
                    })
                  ) : (
                    <Typography variant="body2" color="text.secondary" sx={{ py: 4, textAlign: 'center' }}>
                      Aucun message dans cette conversation.
                    </Typography>
                  )}
                </Stack>

                <Divider />

                {/* Formulaire réponse */}
                <Stack direction={{ xs: 'column', sm: 'row' }} spacing={1} sx={{ p: 2 }}>
                  <TextField
                    fullWidth
                    multiline
                    minRows={2}
                    maxRows={4}
                    placeholder="Votre réponse..."
                    value={text}
                    onChange={(event) => setText(event.target.value)}
                    onKeyDown={(event) => {
                      if (event.key === 'Enter' && !event.shiftKey) {
                        event.preventDefault();
                        if (!sending && text.trim()) {
                          handleSendReply();
                        }
                      }
                    }}
                    disabled={sending}
                  />
                  <Button
                    variant="contained"
                    color="primary"
                    onClick={handleSendReply}
                    disabled={!text.trim() || sending}
                    endIcon={
                      sending ? <CircularProgress size={16} color="inherit" /> : <Iconify icon="solar:send-bold" />
                    }
                    sx={{
                      minWidth: { xs: '100%', sm: 130 },
                      height: { xs: 44, sm: 'fit-content' },
                      borderRadius: 2,
                      fontWeight: 700,
                    }}
                  >
                    Envoyer
                  </Button>
                </Stack>
              </>
            ) : (
              <Stack alignItems="center" justifyContent="center" sx={{ flex: 1 }}>
                <Typography color="text.secondary">Sélectionnez une conversation</Typography>
              </Stack>
            )}
          </Card>
        </Stack>
      </Stack>
    </DashboardContent>
  );
}
