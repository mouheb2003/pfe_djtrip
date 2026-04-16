import Box from '@mui/material/Box';
import Stack from '@mui/material/Stack';
import Button from '@mui/material/Button';
import Avatar from '@mui/material/Avatar';
import Typography from '@mui/material/Typography';
import ListItemText from '@mui/material/ListItemText';
import ListItemAvatar from '@mui/material/ListItemAvatar';
import ListItemButton from '@mui/material/ListItemButton';
import IconButton from '@mui/material/IconButton';

import { fToNow } from 'src/utils/format-time';
import { Iconify } from 'src/components/iconify';
import { markNotificationAsRead, deleteNotification } from 'src/Controller/actions';

// ----------------------------------------------------------------------

const notificationTypeIcons = {
  order: 'solar:cart-check-bold',
  chat: 'solar:chat-line-bold',
  mail: 'solar:inbox-in-bold',
  delivery: 'solar:delivery-bold',
  comment: 'solar:chat-round-bold',
  like: 'solar:heart-bold',
  follow: 'solar:user-plus-bold',
  activity: 'solar:lightning-bold',
};

const notificationTypeColors = {
  order: 'info',
  chat: 'success',
  mail: 'warning',
  delivery: 'primary',
  comment: 'info',
  like: 'error',
  follow: 'success',
  activity: 'warning',
};

// Get icon for notification type
function getNotificationIcon(type) {
  return notificationTypeIcons[type] || 'solar:bell-bold';
}

// Get color for notification type
function getNotificationColor(type) {
  return notificationTypeColors[type] || 'default';
}

export function NotificationItem({ notification, onUpdate }) {
  const isRead = notification?.is_read || false;
  const createdAt = notification?.created_at || new Date().toISOString();
  const title = notification?.title || 'Notification';
  const message = notification?.message || '';

  const handleMarkAsRead = async () => {
    if (!isRead) {
      try {
        await markNotificationAsRead(notification._id);
        if (onUpdate) onUpdate();
      } catch (error) {
        console.error('Error marking notification as read:', error);
      }
    }
  };

  const handleDelete = async () => {
    try {
      await deleteNotification(notification._id);
      if (onUpdate) onUpdate();
    } catch (error) {
      console.error('Error deleting notification:', error);
    }
  };

  const renderAvatar = () => (
    <ListItemAvatar>
      <Box
        sx={{
          width: 40,
          height: 40,
          display: 'flex',
          borderRadius: '50%',
          alignItems: 'center',
          justifyContent: 'center',
          bgcolor: `${getNotificationColor(notification?.type)}.lighter`,
          color: `${getNotificationColor(notification?.type)}.main`,
        }}
      >
        <Iconify icon={getNotificationIcon(notification?.type)} width={20} />
      </Box>
    </ListItemAvatar>
  );

  const renderText = () => (
    <ListItemText
      disableTypography
      primary={
        <Typography variant="subtitle2" sx={{ mb: 0.5 }}>
          {title}
        </Typography>
      }
      secondary={
        <Stack direction="row" alignItems="center" spacing={1}>
          <Typography variant="caption" sx={{ color: 'text.secondary' }}>
            {fToNow(createdAt)}
          </Typography>
          {message && (
            <Typography variant="caption" sx={{ color: 'text.disabled', flex: 1 }}>
              {message.substring(0, 50)}
              {message.length > 50 ? '...' : ''}
            </Typography>
          )}
        </Stack>
      }
    />
  );

  const renderUnReadBadge = () =>
    !isRead && (
      <Box
        sx={{
          top: 24,
          right: 16,
          width: 8,
          height: 8,
          borderRadius: '50%',
          bgcolor: 'error.main',
          position: 'absolute',
        }}
      />
    );

  const renderActions = () => (
    <Stack direction="row" spacing={0.5} sx={{ mt: 1 }}>
      {!isRead && (
        <Button size="small" variant="outlined" onClick={handleMarkAsRead}>
          Mark as read
        </Button>
      )}
    </Stack>
  );

  return (
    <ListItemButton
      disableRipple
      onClick={handleMarkAsRead}
      sx={{
        p: 2.5,
        position: 'relative',
        alignItems: 'flex-start',
        borderBottom: (theme) => `dashed 1px ${theme.palette.divider}`,
        opacity: isRead ? 0.6 : 1,
        '&:hover': {
          bgcolor: (theme) => theme.palette.action.hover,
        },
      }}
    >
      {renderUnReadBadge()}
      {renderAvatar()}

      <Box sx={{ flex: '1 1 auto' }}>
        {renderText()}
        {renderActions()}
      </Box>

      <IconButton
        size="small"
        onClick={(e) => {
          e.stopPropagation();
          handleDelete();
        }}
        sx={{ ml: 1, color: 'text.disabled' }}
      >
        <Iconify icon="mingcute:close-line" width={16} />
      </IconButton>
    </ListItemButton>
  );
}
