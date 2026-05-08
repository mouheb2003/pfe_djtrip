import { m } from 'framer-motion';
import { useEffect, useMemo, useState, useCallback } from 'react';

import Box from '@mui/material/Box';
import Tab from '@mui/material/Tab';
import Badge from '@mui/material/Badge';
import Popover from '@mui/material/Popover';
import SvgIcon from '@mui/material/SvgIcon';
import Tooltip from '@mui/material/Tooltip';
import Divider from '@mui/material/Divider';
import Button from '@mui/material/Button';
import Typography from '@mui/material/Typography';
import IconButton from '@mui/material/IconButton';
import CircularProgress from '@mui/material/CircularProgress';

import { Label } from 'src/components/label';
import { Iconify } from 'src/components/iconify';
import { Scrollbar } from 'src/components/scrollbar';
import { CustomTabs } from 'src/components/custom-tabs';
import { varTap, varHover, transitionTap } from 'src/components/animate';
import { notificationService } from 'src/services/notificationService';

import { NotificationItem } from './notification-item';

const TAB_LABELS = {
  all: 'All',
  unread: 'Unread',
  archived: 'Archived',
};

export function NotificationsDrawer({ data, sx, ...other }) {
  const [anchorEl, setAnchorEl] = useState(null);
  const [currentTab, setCurrentTab] = useState('all');
  const [notifications, setNotifications] = useState(() => (Array.isArray(data) ? data : []));
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (Array.isArray(data)) {
      setNotifications(data);
    }
  }, [data]);

  const open = Boolean(anchorEl);

  const totalUnRead = notifications.filter((item) => item.isUnRead === true).length;

  const counts = useMemo(
    () => ({
      all: notifications.length,
      unread: notifications.filter((item) => item.isUnRead === true).length,
      archived: notifications.filter((item) => item.isUnRead !== true).length,
    }),
    [notifications]
  );

  const visibleNotifications = useMemo(() => {
    if (currentTab === 'unread') return notifications.filter((item) => item.isUnRead === true);
    if (currentTab === 'archived') return notifications.filter((item) => item.isUnRead !== true);
    return notifications;
  }, [currentTab, notifications]);

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
    setNotifications((prev) => prev.map((notification) => ({ ...notification, isUnRead: false }))); // optimistic
    notificationService.markAllAsRead().catch((error) => {
      console.error('Error marking all notifications as read:', error);
    });
  }, []);

  const normalizeType = (type) => {
    if (!type) return 'mail';

    const map = {
      booking: 'order',
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

    return {
      id: item?._id || item?.id,
      avatarUrl:
        item?.user_id?.avatar || item?.user_id?.avatarUrl || item?.user_id?.profileImage || null,
      type: normalizeType(item?.type),
      category: item?.priority || item?.target_role || 'General',
      isUnRead: item?.isUnRead ?? !Boolean(item?.is_read),
      createdAt: item?.createdAt || item?.created_at || new Date().toISOString(),
      title: `<p><strong>${escapeHtml(title)}</strong>${message ? ` ${escapeHtml(message)}` : ''}</p>`,
      raw: item,
    };
  };

  const fetchNotifications = useCallback(async () => {
    try {
      setLoading(true);
      const response = await notificationService.getAllNotifications({ limit: 30, skip: 0 });
      const rows = Array.isArray(response?.notifications) ? response.notifications : [];
      setNotifications(rows.map(normalizeNotification));
    } catch (error) {
      console.error('Error fetching notifications for popover:', error);
      setNotifications([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchNotifications();
  }, [fetchNotifications]);

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
          {totalUnRead} non lues sur {notifications.length}
        </Typography>
      </Box>

      {!!totalUnRead && (
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
              <NotificationItem notification={notification} />
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
        <Badge badgeContent={totalUnRead} color="error">
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
        {renderList()}
        <Divider />
        <Box sx={{ p: 1.5 }}>
          <Button fullWidth variant="outlined" onClick={handleClose}>
            Fermer
          </Button>
        </Box>
      </Popover>
    </>
  );
}
