import { m } from 'framer-motion';
import { useEffect, useMemo, useState, useCallback } from 'react';

import Box from '@mui/material/Box';
import Chip from '@mui/material/Chip';
import Tab from '@mui/material/Tab';
import Stack from '@mui/material/Stack';
import Badge from '@mui/material/Badge';
import Popover from '@mui/material/Popover';
import SvgIcon from '@mui/material/SvgIcon';
import Tooltip from '@mui/material/Tooltip';
import Divider from '@mui/material/Divider';
import Button from '@mui/material/Button';
import Typography from '@mui/material/Typography';
import IconButton from '@mui/material/IconButton';
import CircularProgress from '@mui/material/CircularProgress';

import { useAuthContext } from 'src/auth/hooks';
import { useRouter } from 'src/routes/hooks';
import { Label } from 'src/components/label';
import { Iconify } from 'src/components/iconify';
import { Scrollbar } from 'src/components/scrollbar';
import { CustomTabs } from 'src/components/custom-tabs';
import { varTap, varHover, transitionTap } from 'src/components/animate';
import { toast } from 'src/components/snackbar';
import { notificationService } from 'src/services/notificationService';

import { NotificationItem } from './notification-item';

const TAB_LABELS = {
  all: 'All',
  unread: 'Unread',
  archived: 'Archived',
};

// Only these notification types are shown
const ALLOWED_NOTIFICATION_TYPES = ['message', 'approval', 'appeal'];

const QUICK_FILTERS = [
  { key: 'all', label: 'All' },
  { key: 'message', label: 'Messages' },
  { key: 'approval', label: 'Approvals' },
  { key: 'appeal', label: 'Appeals' },
];

const DASHBOARD_MESSAGES_PATH = '/dashboard/messages';
const DASHBOARD_APPROVALS_PATH = '/dashboard/approvals';
const DASHBOARD_APPEALS_PATH = '/dashboard/appeals';
const DASHBOARD_ACTIVITIES_PATH = '/dashboard/activites';
const DASHBOARD_PUBLICATIONS_PATH = '/dashboard/publications';
const DASHBOARD_USERS_PATH = '/dashboard/users';
const DASHBOARD_PAYMENTS_PATH = '/dashboard/payments';
const DASHBOARD_ROOT_PATH = '/dashboard';

const toStringId = (value) => {
  if (!value) return '';
  if (typeof value === 'string') return value;
  if (typeof value === 'object') return value?._id || value?.id || '';
  return String(value);
};

const getCurrentUserId = (user) =>
  toStringId(user?._id) || toStringId(user?.id) || toStringId(user?.userId) || '';

const getNotificationOwnerId = (notification) =>
  toStringId(notification?.raw?.user_id?._id) ||
  toStringId(notification?.raw?.user_id?.id) ||
  toStringId(notification?.raw?.user_id) ||
  '';

const getMessagePartnerId = (notification) => {
  const raw = notification?.raw;
  if (!raw) return '';

  return (
    toStringId(raw?.data?.senderId) ||
    toStringId(raw?.data?.sender_id) ||
    toStringId(raw?.sender_id) ||
    toStringId(raw?.senderId) ||
    toStringId(raw?.user_id) ||
    ''
  );
};

const isAdminUser = (user) => {
  const role = String(user?.role || user?.userType || '').toLowerCase();
  return role.includes('admin');
};

const toNormalizedType = (type, title) => {
  const normalizedType = String(type || '').toLowerCase();
  const normalizedTitle = String(title || '').toLowerCase();

  if (normalizedType.includes('appeal')) return 'appeal';
  if (normalizedType.includes('approval')) return 'approval';
  if (normalizedType === 'booking' && normalizedTitle.includes('approved')) return 'approval';
  if (normalizedType === 'message') return 'message';

  // Return null for types we don't want to display
  return null;
};

const shouldDisplayNotification = (item) => {
  const normalizedType = toNormalizedType(item?.type, item?.title);
  if (normalizedType !== 'appeal') return true;

  const rawType = String(item?.data?.type || item?.notificationType || '').toLowerCase();
  const rawStatus = String(item?.data?.status || '').toLowerCase();
  const title = String(item?.title || '').toLowerCase();

  if (rawType === 'appeal_resolved' && rawStatus === 'rejected') return false;
  if (title.includes('appeal rejected')) return false;

  return true;
};

const getDerivedActionUrl = (rawItem) => {
  const normalizedType = toNormalizedType(rawItem?.type, rawItem?.title);

  if (normalizedType === 'appeal' || rawItem?.related_entity_type === 'appeal') {
    return DASHBOARD_APPEALS_PATH;
  }

  if (normalizedType === 'approval') {
    return DASHBOARD_APPROVALS_PATH;
  }

  return rawItem?.action_url || rawItem?.actionUrl || '';
};

// Extract entity ID from notification for targeted navigation
const getEntityIdFromNotification = (notification) => {
  const raw = notification?.raw;
  if (!raw) return null;

  // Check related_entity_id first (primary)
  if (raw.related_entity_id) {
    return raw.related_entity_id?._id || raw.related_entity_id?.id || raw.related_entity_id;
  }

  // Check data object for entity IDs
  if (raw.data) {
    return (
      raw.data.appeal_id ||
      raw.data.appealId ||
      raw.data.approval_id ||
      raw.data.approvalId ||
      raw.data.booking_id ||
      raw.data.bookingId ||
      raw.data.entity_id ||
      raw.data.entityId ||
      null
    );
  }

  return null;
};


const resolveDestinationPath = (notification) => {
  const actionUrl = String(notification?.actionUrl || '').trim();
  const normalizedType = toNormalizedType(notification?.raw?.type, notification?.raw?.title);
  const lowerActionUrl = actionUrl.toLowerCase();

  if (!actionUrl) {
    if (normalizedType === 'approval') return DASHBOARD_APPROVALS_PATH;
    if (normalizedType === 'appeal') return DASHBOARD_APPEALS_PATH;
    if (normalizedType === 'payment') return DASHBOARD_PAYMENTS_PATH;
    if (normalizedType === 'activity') return DASHBOARD_ACTIVITIES_PATH;
    return '';
  }

  if (lowerActionUrl.startsWith('/dashboard/')) return actionUrl;

  if (lowerActionUrl.startsWith('/messages')) return DASHBOARD_MESSAGES_PATH;
  if (lowerActionUrl.startsWith('/appeals') || lowerActionUrl.includes('appeal')) {
    return DASHBOARD_APPEALS_PATH;
  }
  if (
    lowerActionUrl.startsWith('/approvals') ||
    lowerActionUrl.startsWith('/bookings') ||
    lowerActionUrl.startsWith('/booking') ||
    lowerActionUrl.includes('approved')
  ) {
    return DASHBOARD_APPROVALS_PATH;
  }
  if (lowerActionUrl.startsWith('/payments') || lowerActionUrl.includes('payment')) {
    return DASHBOARD_PAYMENTS_PATH;
  }
  if (
    lowerActionUrl.startsWith('/activities') ||
    lowerActionUrl.startsWith('/activity') ||
    lowerActionUrl.includes('activite')
  ) {
    return DASHBOARD_ACTIVITIES_PATH;
  }
  if (
    lowerActionUrl.startsWith('/posts') ||
    lowerActionUrl.startsWith('/publications') ||
    lowerActionUrl.startsWith('/reviews') ||
    lowerActionUrl.startsWith('/comments')
  ) {
    return DASHBOARD_PUBLICATIONS_PATH;
  }
  if (
    lowerActionUrl.startsWith('/users') ||
    lowerActionUrl.startsWith('/profile') ||
    lowerActionUrl.startsWith('/follows')
  ) {
    return DASHBOARD_USERS_PATH;
  }

  if (actionUrl.startsWith('/')) return DASHBOARD_ROOT_PATH;

  return actionUrl;
};

export function NotificationsDrawer({ data, sx, ...other }) {
  const { user } = useAuthContext();
  const currentUserId = getCurrentUserId(user);
  const router = useRouter();
  const [anchorEl, setAnchorEl] = useState(null);
  const [currentTab, setCurrentTab] = useState('all');
  const [quickFilter, setQuickFilter] = useState('all');
  const [notifications, setNotifications] = useState(() => (Array.isArray(data) ? data : []));
  const [unreadCount, setUnreadCount] = useState(() =>
    Array.isArray(data) ? data.filter((item) => item.isUnRead === true).length : 0
  );
  const [loading, setLoading] = useState(false);
  const [clearingAll, setClearingAll] = useState(false);

  const [prevUnreadCount, setPrevUnreadCount] = useState(0);

  useEffect(() => {
    if (Array.isArray(data)) {
      setNotifications(data);
      setUnreadCount(data.filter((item) => item.isUnRead === true).length);
    }
  }, [data]);

  const open = Boolean(anchorEl);

  const counts = useMemo(
    () => ({
      all: notifications.length,
      unread: notifications.filter((item) => item.isUnRead === true).length,
      archived: notifications.filter((item) => item.isUnRead !== true).length,
    }),
    [notifications]
  );

  const visibleNotifications = useMemo(() => {
    let base = notifications;

    if (currentTab === 'unread') base = base.filter((item) => item.isUnRead === true);
    if (currentTab === 'archived') base = base.filter((item) => item.isUnRead !== true);

    if (quickFilter !== 'all') {
      base = base.filter((item) => item.kind === quickFilter);
    }

    return base;
  }, [currentTab, notifications, quickFilter]);

  const handleOpen = useCallback((event) => {
    setAnchorEl(event.currentTarget);
  }, []);

  const handleClose = useCallback(() => {
    setAnchorEl(null);
  }, []);

  const handleChangeTab = useCallback((event, newValue) => {
    setCurrentTab(newValue);
  }, []);

  const handleMarkAllAsRead = useCallback(() => {
    setNotifications((prev) => prev.map((notification) => ({ ...notification, isUnRead: false })));
    setUnreadCount(0);

    if (isAdminUser(user)) return;

    notificationService.markAllAsRead().catch((error) => {
      console.error('Error marking all notifications as read:', error);
    });
  }, [user]);

  const normalizeType = (type) => {
    if (!type) return 'mail';

    const map = {
      booking: 'order',
      approval: 'order',
      appeal: 'mail',
      message: 'chat',
      system: 'mail',
      publication: 'mail',
      activity: 'delivery',
      alert: 'delivery',
      payment: 'payment',
    };

    return map[type] || (['order', 'chat', 'mail', 'delivery', 'payment'].includes(type) ? type : 'mail');
  };

  const escapeHtml = (value = '') =>
    String(value)
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');

  const normalizeNotification = (item) => {
    const title = item?.title || 'Notification';
    const message = item?.message || '';
    const normalizedType = toNormalizedType(item?.type, title);

    return {
      id: item?._id || item?.id,
      kind: normalizedType,
      avatarUrl:
        item?.user_id?.avatar || item?.user_id?.avatarUrl || item?.user_id?.profileImage || null,
      type: normalizeType(normalizedType),
      category:
        (normalizedType === 'approval' && 'Approval') ||
        (normalizedType === 'appeal' && 'Appeal') ||
        item?.priority ||
        item?.target_role ||
        'General',
      isUnRead: item?.isUnRead ?? !Boolean(item?.is_read),
      createdAt: item?.createdAt || item?.created_at || new Date().toISOString(),
      actionUrl: getDerivedActionUrl(item),
      actionText: item?.action_text || item?.actionText || '',
      title: `<p><strong>${escapeHtml(title)}</strong>${message ? ` ${escapeHtml(message)}` : ''}</p>`,
      raw: item,
    };
  };

  const fetchUnreadCount = useCallback(async () => {
    try {
      if (isAdminUser(user)) {
        const response = await notificationService.getAllNotifications({ limit: 100, skip: 0 });
        const rows = Array.isArray(response?.notifications) ? response.notifications : [];
        // Filter to only allowed types, then count unread
        const filtered = rows.filter((item) => {
          const normalizedType = toNormalizedType(item?.type, item?.title);
          return ALLOWED_NOTIFICATION_TYPES.includes(normalizedType) && shouldDisplayNotification(item);
        });
        const newUnread = filtered.filter((item) => item?.is_read !== true).length;
        setUnreadCount((prev) => {
          if (newUnread > prev && prev > 0) {
            toast.info('New message, appeal or approval received!');
          }
          return newUnread;
        });
        return;
      }

      const response = await notificationService.getUnreadCount();
      const count = Number(response?.unread_count ?? response?.count ?? 0);
      
      setUnreadCount((prev) => {
        if (count > prev && prev > 0) {
          toast.info('New message, appeal or approval received!');
        }
        return count;
      });
    } catch (error) {
      console.error('Error fetching unread count:', error);
    }
  }, [user]);

  const fetchNotifications = useCallback(async () => {
    try {
      setLoading(true);
      console.log('[DRAWER DEBUG] Fetching notifications. isAdminUser:', isAdminUser(user));
      const response = isAdminUser(user)
        ? await notificationService.getAllNotifications({ limit: 100, skip: 0 })
        : await notificationService.getUserNotifications({ limit: 50, skip: 0 });
      console.log('[DRAWER DEBUG] Raw response:', response?.notifications?.length, 'notifications');
      const rows = Array.isArray(response?.notifications) ? response.notifications : [];
      // Filter to only allowed types and normalize
      const filtered = rows.filter((item) => {
        const normalizedType = toNormalizedType(item?.type, item?.title);
        const allowed = ALLOWED_NOTIFICATION_TYPES.includes(normalizedType);
        const visible = shouldDisplayNotification(item);
        if (item?.type === 'appeal') {
          console.log('[DRAWER DEBUG] Appeal notification:', item._id, 'normalized:', normalizedType, 'allowed:', allowed, 'visible:', visible);
        }
        return allowed && visible;
      });
      console.log('[DRAWER DEBUG] Filtered to', filtered.length, 'notifications (was', rows.length, ')');

      // Deduplicate by related_entity_id (keep only the most recent per entity)
      const deduped = {};
      filtered.forEach((item) => {
        const entityKey = item.related_entity_id || item._id;
        if (!deduped[entityKey] || new Date(item.createdAt) > new Date(deduped[entityKey].createdAt)) {
          deduped[entityKey] = item;
        }
      });
      const dedupedArray = Object.values(deduped);
      console.log('[DRAWER DEBUG] After dedup:', dedupedArray.length, 'notifications (was', filtered.length, ')');

      const normalized = dedupedArray.map(normalizeNotification);
      console.log('[DRAWER DEBUG] Appeal notifications after normalize:', normalized.filter(n => n.kind === 'appeal').length);
      setNotifications(normalized);
      setUnreadCount(normalized.filter((item) => item.isUnRead === true).length);
    } catch (error) {
      console.error('Error fetching notifications for popover:', error);
      setNotifications([]);
    } finally {
      setLoading(false);
    }
  }, [user]);

  const handleNotificationClick = useCallback(
    async (notification) => {
      if (!notification?.id) return;

      const ownerId = getNotificationOwnerId(notification);
      const canMutate = !ownerId || ownerId === currentUserId;

      setNotifications((prev) =>
        prev.map((item) => (item.id === notification.id ? { ...item, isUnRead: false } : item))
      );
      setUnreadCount((prev) => Math.max(0, prev - 1));

      if (canMutate) {
        try {
          await notificationService.markAsRead(notification.id);
        } catch (error) {
          console.error('Error marking notification as read:', error);
        }
      }

      // Determine normalized type and entity id first
      const normalizedType = toNormalizedType(notification?.raw?.type, notification?.raw?.title);
      const entityId = getEntityIdFromNotification(notification);

      // If it's a message-type notification, prefer message routing
      const messagePartnerId = getMessagePartnerId(notification);
      if (normalizedType === 'message' && messagePartnerId) {
        handleClose();
        router.push(`${DASHBOARD_MESSAGES_PATH}?partnerId=${encodeURIComponent(messagePartnerId)}`);
        return;
      }

      // Handle appeals, approvals with entity ID targeting
      if (normalizedType === 'appeal') {
        handleClose();
        if (entityId) {
          router.push(`${DASHBOARD_APPEALS_PATH}?id=${encodeURIComponent(entityId)}`);
        } else {
          router.push(DASHBOARD_APPEALS_PATH);
        }
        return;
      }

      if (normalizedType === 'approval') {
        handleClose();
        if (entityId) {
          router.push(`${DASHBOARD_APPROVALS_PATH}?id=${encodeURIComponent(entityId)}`);
        } else {
          router.push(DASHBOARD_APPROVALS_PATH);
        }
        return;
      }

      const destination = resolveDestinationPath(notification);
      if (!destination) return;

      handleClose();

      if (destination.startsWith('/')) {
        router.push(destination);
        return;
      }

      window.open(destination, '_blank', 'noopener,noreferrer');
    },
    [currentUserId, handleClose, router]
  );

  const handleDeleteNotification = useCallback(
    async (notification) => {
      if (!notification?.id) return;

      const ownerId = getNotificationOwnerId(notification);
      if (ownerId && ownerId !== currentUserId) return;

      const wasUnread = notification.isUnRead === true;

      setNotifications((prev) => prev.filter((item) => item.id !== notification.id));
      if (wasUnread) {
        setUnreadCount((prev) => Math.max(0, prev - 1));
      }

      try {
        await notificationService.deleteNotification(notification.id);
      } catch (error) {
        console.error('Error deleting notification:', error);
        fetchNotifications();
        fetchUnreadCount();
      }
    },
    [currentUserId, fetchNotifications, fetchUnreadCount]
  );

  const handleClearAllNotifications = useCallback(async () => {
    if (!notifications.length) return;

    const previousNotifications = notifications;

    // Only attempt to delete notifications that belong to the current user
    let deletable = previousNotifications
      .map((item) => {
        const ownerId = getNotificationOwnerId(item);
        const id = item?.id || item?._id || item?.raw?._id || item?.raw?.id || null;
        return { ...item, ownerId, id };
      });

    // Admin can delete all notifications
    if (!isAdminUser(user)) {
      deletable = deletable.filter((item) => item.id && (!item.ownerId || item.ownerId === currentUserId));
    } else {
      deletable = deletable.filter((item) => item.id);
    }

    if (!deletable.length) return;

    // Optimistically remove deletable items from UI
    setNotifications((prev) => prev.filter((n) => !deletable.some((d) => d.id === n.id)));
    setUnreadCount((prev) => Math.max(0, prev - deletable.filter((d) => d.isUnRead === true).length));

    try {
      setClearingAll(true);

      console.log('Attempting to clear notifications, total:', deletable.length, deletable.map((d) => ({ id: d.id, ownerId: d.ownerId })));

      const failures = [];

      for (const item of deletable) {
        try {
          const res = await notificationService.deleteNotification(item.id);
          console.log('Deleted notification', item.id, 'response:', res);
        } catch (err) {
          console.error('Failed to delete notification', item.id, err);
          failures.push({ id: item.id, error: err });
        }
      }

      if (failures.length) {
        console.error('Some deletions failed:', failures);
        // restore state so user sees consistent data
        setNotifications(previousNotifications);
        setUnreadCount(previousNotifications.filter((item) => item.isUnRead === true).length);
        fetchNotifications();
        fetchUnreadCount();
      }
    } catch (error) {
      console.error('Error clearing all notifications (outer):', error);
      setNotifications(previousNotifications);
      setUnreadCount(previousNotifications.filter((item) => item.isUnRead === true).length);
      fetchNotifications();
      fetchUnreadCount();
    } finally {
      setClearingAll(false);
    }
  }, [notifications, fetchNotifications, fetchUnreadCount, currentUserId]);

  useEffect(() => {
    fetchNotifications();
    fetchUnreadCount();
  }, [fetchNotifications, fetchUnreadCount]);

  useEffect(() => {
    const timer = setInterval(() => {
      fetchUnreadCount();
    }, 15000);

    return () => clearInterval(timer);
  }, [fetchUnreadCount]);

  // Reload unread count when drawer is closed to sync badge with latest data
  useEffect(() => {
    if (open === false) {
      fetchUnreadCount();
    }
  }, [open, fetchUnreadCount]);

  useEffect(() => {
    if (!open) return undefined;

    fetchNotifications();

    const timer = setInterval(() => {
      fetchNotifications();
    }, 20000);

    return () => clearInterval(timer);
  }, [fetchNotifications, open]);

  const renderHead = () => (
    <Box
      sx={{
        px: 2,
        py: 1.75,
        minHeight: 72,
        display: 'flex',
        alignItems: 'center',
        gap: 1,
      }}
    >
      <Box sx={{ flexGrow: 1 }}>
        <Typography variant="subtitle1" sx={{ fontWeight: 800 }}>
          Notifications
        </Typography>
        <Typography variant="caption" sx={{ color: 'text.secondary' }}>
          {unreadCount} non lues sur {notifications.length}
        </Typography>
      </Box>

      {!!unreadCount && (
        <Tooltip title="Tout marquer comme lu">
          <IconButton color="primary" onClick={handleMarkAllAsRead}>
            <Iconify icon="eva:done-all-fill" />
          </IconButton>
        </Tooltip>
      )}

      <Tooltip title="Fermer">
        <IconButton onClick={handleClose}>
          <Iconify icon="mingcute:close-line" />
        </IconButton>
      </Tooltip>
    </Box>
  );

  const renderTabs = () => (
    <CustomTabs variant="fullWidth" value={currentTab} onChange={handleChangeTab}>
      {Object.entries(TAB_LABELS).map(([value, label]) => (
        <Tab
          key={value}
          iconPosition="end"
          value={value}
          label={label}
          icon={
            <Label
              variant={((value === 'all' || value === currentTab) && 'filled') || 'soft'}
              color={(value === 'unread' && 'info') || (value === 'archived' && 'success') || 'default'}
            >
              {counts[value]}
            </Label>
          }
        />
      ))}
    </CustomTabs>
  );

  const renderQuickFilters = () => {
    const typeBreakdown = {};
    notifications.forEach((n) => {
      const kind = n?.kind || 'unknown';
      typeBreakdown[kind] = (typeBreakdown[kind] || 0) + 1;
    });
    if (notifications.length > 0) {
      console.log('📊 Notification breakdown:', typeBreakdown, 'Total:', notifications.length);
    }

    return (
    <Stack direction="row" spacing={0.75} sx={{ px: 1.5, py: 1, overflowX: 'auto' }}>
      {QUICK_FILTERS.map((filter) => {
        const count =
          filter.key === 'all'
            ? notifications.length
            : notifications.filter((item) => item.kind === filter.key).length;

        return (
          <Chip
            key={filter.key}
            size="small"
            label={`${filter.label} (${count})`}
            variant={quickFilter === filter.key ? 'filled' : 'outlined'}
            color={quickFilter === filter.key ? 'primary' : 'default'}
            onClick={() => setQuickFilter(filter.key)}
            sx={{ borderRadius: 1.5 }}
          />
        );
      })}
    </Stack>
    );
  };

  const renderList = () => (
    <Scrollbar sx={{ maxHeight: 420 }}>
      <Box component="ul" sx={{ p: 0, m: 0, listStyle: 'none' }}>
        {loading ? (
          <Box sx={{ py: 8, display: 'flex', justifyContent: 'center' }}>
            <CircularProgress size={26} />
          </Box>
        ) : visibleNotifications.length ? (
          visibleNotifications.map((notification) => (
            <Box component="li" key={notification.id} sx={{ display: 'flex' }}>
              <NotificationItem
                notification={notification}
                onClick={() => handleNotificationClick(notification)}
                onDelete={
                  getNotificationOwnerId(notification) === currentUserId
                    ? handleDeleteNotification
                    : undefined
                }
              />
            </Box>
          ))
        ) : (
          <Box sx={{ p: 3, textAlign: 'center', color: 'text.secondary' }}>
            <Typography variant="body2">Aucune notification à afficher</Typography>
          </Box>
        )}
      </Box>
    </Scrollbar>
  );

  return (
    <>
      <IconButton
        component={m.button}
        whileTap={varTap(0.96)}
        whileHover={varHover(1.04)}
        transition={transitionTap()}
        aria-label="Notifications button"
        onClick={handleOpen}
        sx={sx}
        {...other}
      >
        <Badge badgeContent={unreadCount} color="error">
          <SvgIcon>
            <path
              fill="currentColor"
              d="M18.75 9v.704c0 .845.24 1.671.692 2.374l1.108 1.723c1.011 1.574.239 3.713-1.52 4.21a25.794 25.794 0 0 1-14.06 0c-1.759-.497-2.531-2.636-1.52-4.21l1.108-1.723a4.393 4.393 0 0 0 .693-2.374V9c0-3.866 3.022-7 6.749-7s6.75 3.134 6.75 7"
              opacity="0.5"
            />
            <path
              fill="currentColor"
              d="M12.75 6a.75.75 0 0 0-1.5 0v4a.75.75 0 0 0 1.5 0zM7.243 18.545a5.002 5.002 0 0 0 9.513 0c-3.145.59-6.367.59-9.513 0"
            />
          </SvgIcon>
        </Badge>
      </IconButton>

      <Popover
        open={open}
        onClose={handleClose}
        anchorEl={anchorEl}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
        transformOrigin={{ vertical: 'top', horizontal: 'right' }}
        slotProps={{
          paper: {
            sx: {
              width: 1,
              maxWidth: 460,
              mt: 1.5,
              borderRadius: 3,
              overflow: 'hidden',
              boxShadow: (theme) => theme.customShadows?.dropdown ?? theme.shadows[24],
            },
          },
        }}
      >
        {renderHead()}
        <Divider />
        {renderTabs()}
        <Divider />
        {renderQuickFilters()}
        <Divider />
        {renderList()}
        <Divider />
        <Box sx={{ p: 1.5, display: 'flex', gap: 1 }}>
          <Button
            fullWidth
            variant="outlined"
            color="error"
            onClick={handleClearAllNotifications}
            disabled={clearingAll || notifications.length === 0}
          >
            {clearingAll ? 'Clearing...' : 'Clear all'}
          </Button>
          <Button fullWidth variant="outlined" onClick={handleClose}>
            Fermer
          </Button>
        </Box>
      </Popover>
    </>
  );
}
