import { useMemo, useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Alert from '@mui/material/Alert';
import Stack from '@mui/material/Stack';
import { alpha } from '@mui/material/styles';
import Typography from '@mui/material/Typography';
import CardContent from '@mui/material/CardContent';
import CircularProgress from '@mui/material/CircularProgress';
import LinearProgress from '@mui/material/LinearProgress';
import { useTheme } from '@mui/material/styles';

import { DashboardContent } from 'src/layouts/dashboard';
import { getLieux, getUsers, getActivitesAdmin, getPublications } from 'src/Controller/actions';
import { appealService } from 'src/services/appealService';
import { paths } from 'src/routes/paths';

import { toast } from 'src/components/snackbar';
import { Iconify } from 'src/components/iconify';

// Animated Background Component
function AnimatedBackground() {
  const theme = useTheme();
  return (
    <Box
      sx={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        zIndex: -1,
        background: `linear-gradient(135deg, ${alpha(theme.palette.background.default, 1)} 0%, ${alpha(theme.palette.background.paper, 0.5)} 50%, ${alpha(theme.palette.background.default, 1)} 100%)`,
        '&::before': {
          content: '""',
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: `radial-gradient(circle at 20% 50%, ${alpha(theme.palette.primary.main, 0.05)} 0%, transparent 50%)`,
          animation: 'pulse 8s ease-in-out infinite',
        },
        '&::after': {
          content: '""',
          position: 'absolute',
          top: 0,
          left: 0,
          right: 0,
          bottom: 0,
          background: `radial-gradient(circle at 80% 80%, ${alpha(theme.palette.secondary.main, 0.05)} 0%, transparent 50%)`,
          animation: 'pulse 8s ease-in-out infinite 4s',
        },
        '@keyframes pulse': {
          '0%, 100%': { opacity: 0.5, transform: 'scale(1)' },
          '50%': { opacity: 1, transform: 'scale(1.1)' },
        },
      }}
    />
  );
}

// Glassmorphism Card
function GlassCard({ children, sx, ...props }) {
  const theme = useTheme();
  return (
    <Card
      sx={{
        background: alpha(theme.palette.background.paper, 0.8),
        backdropFilter: 'blur(20px)',
        border: `1px solid ${alpha(theme.palette.divider, 0.1)}`,
        borderRadius: 3,
        transition: 'all 0.3s ease',
        '&:hover': {
          transform: 'translateY(-4px)',
          boxShadow: `0 20px 40px ${alpha(theme.palette.primary.main, 0.15)}`,
          border: `1px solid ${alpha(theme.palette.primary.main, 0.2)}`,
        },
        ...sx,
      }}
      {...props}
    >
      {children}
    </Card>
  );
}

// Live Status Indicator
function LiveStatus({ label, value, icon, color, isOnline }) {
  const theme = useTheme();
  const colorValue = typeof color === 'function' ? color(theme) : color;
  return (
    <GlassCard sx={{ p: 2 }}>
      <Stack direction="row" spacing={2} alignItems="center">
        <Box
          sx={{
            width: 48,
            height: 48,
            borderRadius: 2,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            background: alpha(colorValue, 0.2),
            position: 'relative',
          }}
        >
          {isOnline && (
            <Box
              sx={{
                position: 'absolute',
                top: 4,
                right: 4,
                width: 12,
                height: 12,
                borderRadius: '50%',
                background: theme.palette.success.main,
                animation: 'blink 2s ease-in-out infinite',
                '@keyframes blink': {
                  '0%, 100%': { opacity: 1 },
                  '50%': { opacity: 0.5 },
                },
              }}
            />
          )}
          <Iconify icon={icon} width={24} sx={{ color: colorValue }} />
        </Box>
        <Box>
          <Typography variant="body2" sx={{ color: 'text.secondary' }}>
            {label}
          </Typography>
          <Typography variant="h5" sx={{ fontWeight: 700, color: colorValue }}>
            {value}
          </Typography>
        </Box>
      </Stack>
    </GlassCard>
  );
}

// Modern Stat Card with Gradient
function ModernStatCard({ title, value, subtitle, icon, color, trend }) {
  const theme = useTheme();
  const colorValue = typeof color === 'function' ? color(theme) : color;
  return (
    <GlassCard>
      <CardContent sx={{ p: 3 }}>
        <Stack spacing={2}>
          <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
            <Box
              sx={{
                width: 56,
                height: 56,
                borderRadius: 3,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                background: `linear-gradient(135deg, ${alpha(colorValue, 0.3)} 0%, ${alpha(colorValue, 0.1)} 100%)`,
                boxShadow: `0 8px 16px ${alpha(colorValue, 0.2)}`,
              }}
            >
              <Iconify icon={icon} width={32} sx={{ color: colorValue }} />
            </Box>
            {trend && (
              <Box
                sx={{
                  px: 1.5,
                  py: 0.5,
                  borderRadius: 1,
                  background: alpha(trend > 0 ? theme.palette.success.main : theme.palette.error.main, 0.2),
                  color: trend > 0 ? theme.palette.success.main : theme.palette.error.main,
                  fontSize: 12,
                  fontWeight: 600,
                }}
              >
                {trend > 0 ? '+' : ''}{trend}%
              </Box>
            )}
          </Stack>
          <Box>
            <Typography variant="h3" sx={{ fontWeight: 700, mb: 0.5 }}>
              {value}
            </Typography>
            <Typography variant="body2" sx={{ color: 'text.secondary' }}>
              {title}
            </Typography>
            <Typography variant="caption" sx={{ color: 'text.disabled' }}>
              {subtitle}
            </Typography>
          </Box>
        </Stack>
      </CardContent>
    </GlassCard>
  );
}

// Quick Action Card
function QuickActionCard({ icon, label, color, path }) {
  const theme = useTheme();
  const navigate = useNavigate();
  const colorValue = typeof color === 'function' ? color(theme) : color;

  const handleClick = () => {
    if (path) {
      navigate(path);
    }
  };

  return (
    <GlassCard
      onClick={handleClick}
      sx={{
        p: 3,
        cursor: 'pointer',
        textAlign: 'center',
        transition: 'all 0.3s ease',
        '&:hover': {
          transform: 'scale(1.05)',
        },
      }}
    >
      <Box
        sx={{
          width: 64,
          height: 64,
          borderRadius: '50%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          margin: '0 auto 12px',
          background: `linear-gradient(135deg, ${alpha(colorValue, 0.3)} 0%, ${alpha(colorValue, 0.1)} 100%)`,
          transition: 'all 0.3s ease',
        }}
      >
        <Iconify icon={icon} width={32} sx={{ color: colorValue }} />
      </Box>
      <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
        {label}
      </Typography>
    </GlassCard>
  );
}

// System Health Bar
function HealthBar({ label, value, color }) {
  const theme = useTheme();
  const colorValue = typeof color === 'function' ? color(theme) : color;
  return (
    <Box sx={{ mb: 2 }}>
      <Stack direction="row" justifyContent="space-between" sx={{ mb: 1 }}>
        <Typography variant="body2" sx={{ color: 'text.secondary' }}>
          {label}
        </Typography>
        <Typography variant="body2" sx={{ color: colorValue, fontWeight: 600 }}>
          {value}%
        </Typography>
      </Stack>
      <LinearProgress
        variant="determinate"
        value={value}
        sx={{
          height: 8,
          borderRadius: 4,
          background: alpha(colorValue, 0.1),
          '& .MuiLinearProgress-bar': {
            background: `linear-gradient(90deg, ${colorValue} 0%, ${alpha(colorValue, 0.7)} 100%)`,
            borderRadius: 4,
          },
        }}
      />
    </Box>
  );
}

// Activity Distribution Chart
function ActivityDistribution({ users, lieux, appeals, activites, publications, approvals }) {
  const theme = useTheme();
  const total = users + lieux + appeals + activites + publications + approvals;

  const data = [
    { label: 'Users', value: users, color: theme.palette.primary.main },
    { label: 'Places', value: lieux, color: theme.palette.success.main },
    { label: 'Appeals', value: appeals, color: theme.palette.warning.main },
    { label: 'Activities', value: activites, color: theme.palette.info.main },
    { label: 'Publications', value: publications, color: theme.palette.secondary.main },
    { label: 'Approvals', value: approvals, color: theme.palette.error.main },
  ];

  const maxValue = Math.max(...data.map(d => d.value));

  return (
    <GlassCard sx={{ p: 3 }}>
      <Typography variant="h6" sx={{ mb: 3, fontWeight: 600 }}>
        Platform Distribution
      </Typography>
      <Stack spacing={3}>
        {data.map((item) => (
          <Box key={item.label}>
            <Stack direction="row" justifyContent="space-between" sx={{ mb: 1 }}>
              <Typography variant="body2" sx={{ fontWeight: 500 }}>
                {item.label}
              </Typography>
              <Typography variant="body2" sx={{ color: item.color, fontWeight: 600 }}>
                {item.value} ({total > 0 ? Math.round((item.value / total) * 100) : 0}%)
              </Typography>
            </Stack>
            <Box
              sx={{
                height: 8,
                borderRadius: 4,
                background: alpha(theme.palette.divider, 0.2),
                overflow: 'hidden',
              }}
            >
              <Box
                sx={{
                  height: '100%',
                  width: `${maxValue > 0 ? (item.value / maxValue) * 100 : 0}%`,
                  background: item.color,
                  borderRadius: 4,
                  transition: 'width 0.5s ease',
                }}
              />
            </Box>
          </Box>
        ))}
      </Stack>
    </GlassCard>
  );
}

export function HomeFeedView({ sx }) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [users, setUsers] = useState([]);
  const [lieux, setLieux] = useState([]);
  const [appeals, setAppeals] = useState([]);
  const [activites, setActivites] = useState([]);
  const [publications, setPublications] = useState([]);

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        setError('');

        const [usersResult, lieuxResult, appealsResult, activitesResult, publicationsResult] = await Promise.allSettled([
          getUsers(),
          getLieux(),
          appealService.getAppealStats(),
          getActivitesAdmin(),
          getPublications(),
        ]);

        const usersData = usersResult.status === 'fulfilled' ? usersResult.value : [];
        const lieuxData = lieuxResult.status === 'fulfilled' ? lieuxResult.value : [];
        const appealsData = appealsResult.status === 'fulfilled' ? appealsResult.value : [];
        const activitesData = activitesResult.status === 'fulfilled' ? activitesResult.value : [];
        const publicationsData = publicationsResult.status === 'fulfilled' ? publicationsResult.value : [];

        setUsers(Array.isArray(usersData) ? usersData : []);
        setLieux(Array.isArray(lieuxData) ? lieuxData : []);
        setAppeals(Array.isArray(appealsData) ? appealsData : []);
        setActivites(Array.isArray(activitesData) ? activitesData : []);
        setPublications(Array.isArray(publicationsData) ? publicationsData : []);
      } catch {
        setError("Error loading general feed");
        toast.error('Unable to load general feed');
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  const stats = useMemo(() => {
    const totalUsers = users.length;
    const totalLieux = lieux.length;
    const totalAppeals = appeals.length;
    const totalOrganisateurs = users.filter(
      (user) =>
        String(user?.role ?? '').toLowerCase() === 'organisateur' ||
        String(user?.userType ?? '').toLowerCase() === 'organisator'
    ).length;
    const totalAdmins = users.filter(
      (user) =>
        String(user?.role ?? '').toLowerCase() === 'admin' ||
        String(user?.userType ?? '').toLowerCase() === 'admin'
    ).length;
    const demandesEnAttente = users.filter(
      (user) => user?.statut_organisateur === 'en_attente'
    ).length;
    const totalPublications = publications.length;

    return {
      totalUsers,
      totalLieux,
      totalAppeals,
      totalOrganisateurs,
      totalAdmins,
      demandesEnAttente,
      totalPublications,
    };
  }, [users, lieux, appeals, publications]);


  return (
    <>
      <AnimatedBackground />
      <DashboardContent maxWidth="xl" sx={sx}>
        <Stack spacing={4}>
          {/* Header */}
          <Stack spacing={1}>
            <Typography variant="h3" sx={{ fontWeight: 700 }}>
              DJTrip Command Center
            </Typography>
            <Typography variant="body1" sx={{ color: 'text.secondary' }}>
              Real-time platform monitoring and management
            </Typography>
          </Stack>

          {!!error && <Alert severity="error">{error}</Alert>}

          {loading ? (
            <Box sx={{ display: 'flex', justifyContent: 'center', py: 8 }}>
              <CircularProgress />
            </Box>
          ) : (
            <>
              {/* Quick Actions */}
              <Box>
                <Typography variant="h6" sx={{ mb: 3, fontWeight: 600 }}>
                  Quick Actions
                </Typography>
                <Box
                  sx={{
                    display: 'grid',
                    gap: 2,
                    gridTemplateColumns: { xs: 'repeat(2, 1fr)', sm: 'repeat(4, 1fr)' },
                  }}
                >
                  <QuickActionCard
                    icon="solar:user-plus-bold"
                    label="Users"
                    color={(theme) => theme.palette.primary.main}
                    path={paths.dashboard.users.root}
                  />
                  <QuickActionCard
                    icon="solar:map-point-wave-bold"
                    label="Places"
                    color={(theme) => theme.palette.success.main}
                    path={paths.dashboard.lieux.root}
                  />
                  <QuickActionCard
                    icon="solar:calendar-bold"
                    label="Activities"
                    color={(theme) => theme.palette.info.main}
                    path={paths.dashboard.activites}
                  />
                  <QuickActionCard
                    icon="solar:document-text-bold"
                    label="Publications"
                    color={(theme) => theme.palette.secondary.main}
                    path={paths.dashboard.publications}
                  />
                </Box>
              </Box>

              {/* Stats Grid */}
              <Box
                sx={{
                  display: 'grid',
                  gap: 2,
                  gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, 1fr)', lg: 'repeat(3, 1fr)' },
                }}
              >
                <ModernStatCard
                  title="Total Users"
                  value={stats.totalUsers}
                  subtitle="Registered users"
                  icon="solar:users-group-rounded-bold"
                  color={(theme) => theme.palette.primary.main}
                  trend={12}
                />
                <ModernStatCard
                  title="Total Places"
                  value={stats.totalLieux}
                  subtitle="Locations listed"
                  icon="solar:map-point-wave-bold"
                  color={(theme) => theme.palette.success.main}
                  trend={8}
                />
                <ModernStatCard
                  title="Activities"
                  value={activites.length}
                  subtitle="Total activities"
                  icon="solar:calendar-bold"
                  color={(theme) => theme.palette.info.main}
                  trend={10}
                />
              </Box>

              {/* Activity Distribution */}
              <ActivityDistribution
                users={stats.totalUsers}
                lieux={stats.totalLieux}
                appeals={stats.totalAppeals}
                activites={activites.length}
                publications={stats.totalPublications}
                approvals={stats.demandesEnAttente}
              />
            </>
          )}
        </Stack>
      </DashboardContent>
    </>
  );
}
