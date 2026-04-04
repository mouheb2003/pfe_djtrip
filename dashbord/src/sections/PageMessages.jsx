import { useMemo, useState, useEffect, useCallback } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Stack from '@mui/material/Stack';
import Alert from '@mui/material/Alert';
import Button from '@mui/material/Button';
import Avatar from '@mui/material/Avatar';
import Divider from '@mui/material/Divider';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import CardHeader from '@mui/material/CardHeader';
import IconButton from '@mui/material/IconButton';
import CircularProgress from '@mui/material/CircularProgress';

import { DashboardContent } from 'src/layouts/dashboard';
import { sendMessageTo, getMessagesWith } from 'src/Controller/actions';

import { toast } from 'src/components/snackbar';
import { Iconify } from 'src/components/iconify';

import { JWT_STORAGE_KEY } from 'src/auth/context/jwt/constant';

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
  const initConversations = useCallback(async () => {
    try {
      setLoading(true);
      setError('');

      // Appel direct à l'API conversations
      const token = sessionStorage.getItem(JWT_STORAGE_KEY);
      if (!token) {
        setError('Non authentifié');
        return;
      }

      const res = await fetch('http://localhost:3000/api/messages/conversations', {
        headers: { Authorization: `Bearer ${token}` },
      });

      if (!res.ok) {
        setError('Impossible de charger les conversations');
        return;
      }

      const data = await res.json();
      const convList = Array.isArray(data) ? data : data?.conversations ?? [];

      setConversations(
        convList.map((conv) => ({
          partnerId: conv.partner?._id ?? conv.partner?.id ?? '',
          partnerName: conv.partner?.fullname ?? conv.partner?.email ?? 'Utilisateur',
          partnerAvatar: conv.partner?.avatar ?? '',
          lastMessage: conv.lastMessage?.content ?? '',
          unreadCount: conv.unreadCount ?? 0,
          lastMessageTime: conv.lastMessage?.createdAt ?? null,
        }))
      );
    } catch {
      setError('Erreur lors du chargement des conversations');
      toast.error('Chargement des conversations échoué');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    initConversations();
  }, [initConversations]);

  const sortedMessages = useMemo(() => {
    const list = [...messages];
    list.sort((a, b) => new Date(a.createdAt || 0).getTime() - new Date(b.createdAt || 0).getTime());
    return list;
  }, [messages]);

  const currentConversation = useMemo(
    () => conversations.find((c) => c.partnerId === selectedConversation),
    [conversations, selectedConversation]
  );

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
      toast.success('Réponse envoyée');
    } catch {
      toast.error('Envoi échoué');
    } finally {
      setSending(false);
    }
  }, [selectedConversation, loadMessagesWithUser, text]);

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
            <CardHeader title="Messages" subheader={`${conversations.length} conversation(s)`} />
            <Divider />

            {loading ? (
              <Stack alignItems="center" justifyContent="center" sx={{ py: 4, flex: 1 }}>
                <CircularProgress size={32} />
              </Stack>
            ) : conversations.length ? (
              <Stack spacing={0.5} sx={{ overflow: 'auto', flex: 1, p: 1 }}>
                {conversations.map((conv) => (
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
                <Typography color="text.secondary">Aucun message</Typography>
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
                    disabled={sending}
                  />
                  <IconButton
                    color="primary"
                    onClick={handleSendReply}
                    disabled={!text.trim() || sending}
                    sx={{ height: 'fit-content' }}
                  >
                    <Iconify icon="solar:send-bold" />
                  </IconButton>
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
