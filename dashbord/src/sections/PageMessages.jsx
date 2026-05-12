/* eslint-disable perfectionist/sort-imports */
/* eslint-disable perfectionist/sort-named-imports */
import { useMemo, useState, useEffect, useCallback } from 'react';

import Alert from '@mui/material/Alert';
import Avatar from '@mui/material/Avatar';
import Badge from '@mui/material/Badge';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Card from '@mui/material/Card';
import CardHeader from '@mui/material/CardHeader';
import Chip from '@mui/material/Chip';
import CircularProgress from '@mui/material/CircularProgress';
import Dialog from '@mui/material/Dialog';
import DialogActions from '@mui/material/DialogActions';
import DialogContent from '@mui/material/DialogContent';
import DialogTitle from '@mui/material/DialogTitle';
import Divider from '@mui/material/Divider';
import Stack from '@mui/material/Stack';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';

import { DashboardContent } from 'src/layouts/dashboard';
import { useSearchParams } from 'src/routes/hooks';
import {
  deleteMessageById,
  editMessageById,
  getMessageConversations,
  getMessagesWith,
  sendMessageTo,
} from 'src/Controller/actions';

import { toast } from 'src/components/snackbar';
import { Iconify } from 'src/components/iconify';

const FILTER_OPTIONS = [
  { key: 'all', label: 'Tous', color: 'default', icon: 'solar:chat-round-dots-bold' },
  { key: 'unread', label: 'Non lus', color: 'warning', icon: 'solar:letter-unread-bold' },
  { key: 'reclamation', label: 'Reclamations', color: 'error', icon: 'solar:danger-bold' },
  { key: 'help', label: "Demandes d'aide", color: 'info', icon: 'solar:help-bold' },
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

const HELP_KEYWORDS = ['aide', 'help', 'assistance', 'urgent', 'urgence', 'sos', 'svp', 'besoin'];

const AUTO_REFRESH_MS = 10000;
const APP_ADMIN_NAME = 'DJTrip admin';

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

function isAdminConversation(conv) {
  const role = String(conv?.partnerType ?? '').toLowerCase();
  const name = String(conv?.partnerName ?? '').toLowerCase();
  return role.includes('admin') || name === 'administrator';
}

function getConversationIdentity(conv) {
  const isAdmin = isAdminConversation(conv);
  return {
    isAdmin,
    displayName: isAdmin ? APP_ADMIN_NAME : conv.partnerName,
    avatarSrc: isAdmin ? '/logo/app_logo.png' : conv.partnerAvatar,
  };
}

function ConversationAvatar({ conv, size = 32 }) {
  const identity = getConversationIdentity(conv);

  return (
    <Badge
      overlap="circular"
      anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
      badgeContent={
        identity.isAdmin ? (
          <Box
            sx={{
              width: 14,
              height: 14,
              borderRadius: '50%',
              bgcolor: 'primary.main',
              border: '2px solid #fff',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
            }}
          >
            <Iconify icon="solar:shield-check-bold" width={9} sx={{ color: 'white' }} />
          </Box>
        ) : null
      }
    >
      <Avatar src={identity.avatarSrc} sx={{ width: size, height: size }} />
    </Badge>
  );
}

export function MessagesView({ sx }) {
  const searchParams = useSearchParams();
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [conversations, setConversations] = useState([]);
  const [activeFilter, setActiveFilter] = useState('all');
  const [selectedConversation, setSelectedConversation] = useState(null);
  const [messages, setMessages] = useState([]);
  const [text, setText] = useState('');
  const [error, setError] = useState('');
  const [messageActionOpen, setMessageActionOpen] = useState(false);
  const [editDialogOpen, setEditDialogOpen] = useState(false);
  const [activeMessage, setActiveMessage] = useState(null);
  const [editingText, setEditingText] = useState('');

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
          partnerType: conv.partner?.userType ?? '',
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
    const partnerId = String(searchParams.get('partnerId') || '').trim();
    if (!partnerId) return;
    loadMessagesWithUser(partnerId);
  }, [searchParams, loadMessagesWithUser]);

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
    list.sort(
      (a, b) => new Date(a.createdAt || 0).getTime() - new Date(b.createdAt || 0).getTime()
    );
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

  const openMessageActions = useCallback((msg) => {
    if (!msg?.id) return;
    setActiveMessage(msg);
    setEditingText(msg.content || '');
    setMessageActionOpen(true);
  }, []);

  const handleDeleteMessage = useCallback(async () => {
    if (!activeMessage?.id || !selectedConversation) return;

    try {
      await deleteMessageById(activeMessage.id);
      setMessageActionOpen(false);
      setActiveMessage(null);
      await loadMessagesWithUser(selectedConversation);
      await initConversations();
      toast.success('Message supprimé');
    } catch {
      toast.error('Suppression échouée');
    }
  }, [activeMessage, selectedConversation, loadMessagesWithUser, initConversations]);

  const handleStartEdit = useCallback(() => {
    setMessageActionOpen(false);
    setEditDialogOpen(true);
  }, []);

  const handleSaveEdit = useCallback(async () => {
    if (!activeMessage?.id || !selectedConversation || !editingText.trim()) {
      toast.warning('Saisissez un message');
      return;
    }

    try {
      await editMessageById(activeMessage.id, editingText);
      setEditDialogOpen(false);
      setActiveMessage(null);
      setEditingText('');
      await loadMessagesWithUser(selectedConversation);
      await initConversations();
      toast.success('Message modifié');
    } catch {
      toast.error('Modification échouée');
    }
  }, [activeMessage, selectedConversation, editingText, loadMessagesWithUser, initConversations]);

  return (
    <DashboardContent maxWidth="xl" sx={sx}>
      <Stack spacing={2}>
        <Stack direction="row" alignItems="center" justifyContent="space-between">
          <Typography variant="h4">Messagerie</Typography>
          <Button
            size="small"
            startIcon={<Iconify icon="solar:refresh-bold" />}
            onClick={initConversations}
            disabled={loading}
          >
            Rafraîchir
          </Button>
        </Stack>

        {error ? <Alert severity="error">{error}</Alert> : null}

        <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} sx={{ height: 600 }}>
          {/* Liste des conversations */}
          <Card
            sx={{ flex: '0 0 280px', display: 'flex', flexDirection: 'column', overflow: 'hidden' }}
          >
            <CardHeader
              title="Messages"
              subheader={`${filteredConversations.length} conversation(s)`}
            />
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
                {filteredConversations.map((conv) =>
                  (() => {
                    const identity = getConversationIdentity(conv);
                    return (
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
                            <ConversationAvatar conv={conv} size={32} />
                            <Box sx={{ flex: 1, minWidth: 0 }}>
                              <Typography variant="subtitle2" noWrap>
                                {identity.displayName}
                              </Typography>
                              <Typography variant="caption" color="text.secondary" noWrap>
                                {conv.lastMessage || 'Aucun message'}
                              </Typography>
                              {conv.category !== 'other' ? (
                                <Typography
                                  variant="caption"
                                  color={
                                    conv.category === 'reclamation' ? 'error.main' : 'info.main'
                                  }
                                  noWrap
                                >
                                  {conv.category === 'reclamation'
                                    ? 'Reclamation'
                                    : "Demande d'aide"}
                                </Typography>
                              ) : null}
                            </Box>
                            {conv.unreadCount ? (
                              <Typography
                                variant="caption"
                                sx={{
                                  bgcolor: 'error.main',
                                  color: 'white',
                                  px: 0.75,
                                  borderRadius: 0.75,
                                }}
                              >
                                {conv.unreadCount}
                              </Typography>
                            ) : null}
                          </Stack>
                        </Stack>
                      </Button>
                    );
                  })()
                )}
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
                {(() => {
                  const identity = getConversationIdentity(currentConversation);
                  return (
                    <CardHeader
                      avatar={<ConversationAvatar conv={currentConversation} size={40} />}
                      title={identity.displayName}
                      subheader={`${sortedMessages.length} message(s)`}
                    />
                  );
                })()}
                <Divider />

                {/* Messages */}
                <Stack spacing={1} sx={{ overflow: 'auto', flex: 1, p: 2 }}>
                  {sortedMessages.length ? (
                    sortedMessages.map((msg) => {
                      const isAdminMessage =
                        String(msg.receiverId) === String(selectedConversation);
                      return (
                        <Stack
                          key={msg.id || `${msg.senderId}-${msg.createdAt}`}
                          alignItems={isAdminMessage ? 'flex-end' : 'flex-start'}
                        >
                          <Box
                            onClick={isAdminMessage ? () => openMessageActions(msg) : undefined}
                            sx={{
                              px: 1.5,
                              py: 1,
                              borderRadius: 1.5,
                              bgcolor: isAdminMessage ? 'primary.light' : 'grey.100',
                              color: isAdminMessage ? 'primary.contrastText' : 'text.primary',
                              maxWidth: '70%',
                              cursor: isAdminMessage ? 'pointer' : 'default',
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
                    <Typography
                      variant="body2"
                      color="text.secondary"
                      sx={{ py: 4, textAlign: 'center' }}
                    >
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
                      sending ? (
                        <CircularProgress size={16} color="inherit" />
                      ) : (
                        <Iconify icon="solar:send-bold" />
                      )
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

      <Dialog
        open={messageActionOpen}
        onClose={() => setMessageActionOpen(false)}
        maxWidth="xs"
        fullWidth
      >
        <DialogTitle>Actions du message</DialogTitle>
        <DialogContent dividers>
          <Typography variant="body2" color="text.secondary">
            Choisissez une action pour ce message.
          </Typography>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setMessageActionOpen(false)} color="inherit">
            Annuler
          </Button>
          <Button onClick={handleStartEdit} color="primary">
            Edit
          </Button>
          <Button onClick={handleDeleteMessage} color="error" variant="contained">
            Delete
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog
        open={editDialogOpen}
        onClose={() => setEditDialogOpen(false)}
        maxWidth="sm"
        fullWidth
      >
        <DialogTitle>Modifier le message</DialogTitle>
        <DialogContent dividers>
          <TextField
            fullWidth
            multiline
            minRows={3}
            value={editingText}
            onChange={(event) => setEditingText(event.target.value)}
            placeholder="Écrivez le nouveau texte..."
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEditDialogOpen(false)} color="inherit">
            Annuler
          </Button>
          <Button onClick={handleSaveEdit} variant="contained" disabled={!editingText.trim()}>
            Enregistrer
          </Button>
        </DialogActions>
      </Dialog>
    </DashboardContent>
  );
}
