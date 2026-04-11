import { useMemo, useState, useEffect } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Chip from '@mui/material/Chip';
import List from '@mui/material/List';
import Alert from '@mui/material/Alert';
import Stack from '@mui/material/Stack';
import Divider from '@mui/material/Divider';
import { alpha } from '@mui/material/styles';
import ListItem from '@mui/material/ListItem';
import Typography from '@mui/material/Typography';
import CardContent from '@mui/material/CardContent';
import ListItemText from '@mui/material/ListItemText';
import ToggleButton from '@mui/material/ToggleButton';
import CircularProgress from '@mui/material/CircularProgress';
import ToggleButtonGroup from '@mui/material/ToggleButtonGroup';

import { DashboardContent } from 'src/layouts/dashboard';
import { getLieux, getUsers, getUrgences } from 'src/Controller/actions';

import { toast } from 'src/components/snackbar';
import { Iconify } from 'src/components/iconify';

function formatDate(value) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return date.toLocaleString('fr-FR');
}

const RANGE_OPTIONS = [
  { value: '7d', label: '7 jours', days: 7 },
  { value: '30d', label: '30 jours', days: 30 },
  { value: '90d', label: '90 jours', days: 90 },
  { value: 'all', label: 'Tout' },
];

function isWithinRange(value, rangeValue) {
  if (!value || rangeValue === 'all') return true;

  const range = RANGE_OPTIONS.find((item) => item.value === rangeValue);
  if (!range?.days) return true;

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return false;

  const threshold = Date.now() - range.days * 24 * 60 * 60 * 1000;
  return date.getTime() >= threshold;
}

function StatCard({ title, value, subtitle, icon, color }) {
  return (
    <Card
      sx={{
        border: '1px solid',
        borderColor: alpha(color, 0.2),
        background: `linear-gradient(135deg, ${alpha(color, 0.12)} 0%, ${alpha(color, 0.04)} 100%)`,
      }}
    >
      <CardContent>
        <Stack direction="row" spacing={2} alignItems="center" justifyContent="space-between">
          <Stack spacing={0.5}>
            <Typography variant="overline" sx={{ color: 'text.secondary' }}>
              {title}
            </Typography>
            <Typography variant="h4">{value}</Typography>
            <Typography variant="caption" sx={{ color: 'text.secondary' }}>
              {subtitle}
            </Typography>
          </Stack>
          <Iconify icon={icon} width={28} sx={{ color }} />
        </Stack>
      </CardContent>
    </Card>
  );
}

export function HomeFeedView({ sx }) {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [users, setUsers] = useState([]);
  const [lieux, setLieux] = useState([]);
  const [urgences, setUrgences] = useState([]);
  const [timeRange, setTimeRange] = useState('30d');

  useEffect(() => {
    const fetchData = async () => {
      try {
        setLoading(true);
        setError('');

        const [usersResult, lieuxResult, urgencesResult] = await Promise.allSettled([
          getUsers(),
          getLieux(),
          getUrgences(),
        ]);

        const usersData = usersResult.status === 'fulfilled' ? usersResult.value : [];
        const lieuxData = lieuxResult.status === 'fulfilled' ? lieuxResult.value : [];
        const urgencesData = urgencesResult.status === 'fulfilled' ? urgencesResult.value : [];

        setUsers(Array.isArray(usersData) ? usersData : []);
        setLieux(Array.isArray(lieuxData) ? lieuxData : []);
        setUrgences(Array.isArray(urgencesData) ? urgencesData : []);

        const failedSources = [
          usersResult.status === 'rejected' ? 'utilisateurs' : null,
          lieuxResult.status === 'rejected' ? 'lieux' : null,
          urgencesResult.status === 'rejected' ? 'urgences' : null,
        ].filter(Boolean);

        if (failedSources.length) {
          setError(`Certaines donnees n'ont pas pu etre chargees: ${failedSources.join(', ')}`);
        }
      } catch {
        setError("Erreur lors du chargement de la feed generale");
        toast.error('Impossible de charger la feed generale');
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  const stats = useMemo(() => {
    const totalUsers = users.length;
    const totalLieux = lieux.length;
    const totalUrgences = urgences.length;
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
    const usersInRange = users.filter((user) =>
      isWithinRange(user?.date_inscription ?? user?.createdAt, timeRange)
    ).length;
    const lieuxInRange = lieux.filter((lieu) => isWithinRange(lieu?.createdAt, timeRange)).length;
    const urgencesInRange = urgences.filter((urgence) => isWithinRange(urgence?.createdAt, timeRange))
      .length;

    return {
      totalUsers,
      totalLieux,
      totalUrgences,
      totalOrganisateurs,
      totalAdmins,
      demandesEnAttente,
      usersInRange,
      lieuxInRange,
      urgencesInRange,
    };
  }, [users, lieux, urgences, timeRange]);

  const feedItems = useMemo(() => {
    const usersFeed = users.map((user) => ({
      id: user?._id ?? user?.id,
      type: 'user',
      typeLabel: 'Utilisateur',
      title: user?.fullname ?? 'Utilisateur sans nom',
      subtitle: user?.email ?? '-',
      date: user?.date_inscription ?? user?.createdAt ?? null,
      icon: 'solar:user-bold',
    }));

    const lieuxFeed = lieux.map((lieu) => ({
      id: lieu?._id ?? lieu?.id,
      type: 'lieu',
      typeLabel: 'Lieu',
      title: lieu?.nom ?? 'Lieu sans nom',
      subtitle: lieu?.position?.ville ?? lieu?.ville ?? '-',
      date: lieu?.createdAt ?? null,
      icon: 'solar:map-point-bold',
    }));

    const urgencesFeed = urgences.map((urgence) => ({
      id: urgence?._id ?? urgence?.id,
      type: 'urgence',
      typeLabel: 'Urgence',
      title: urgence?.nom ?? 'Urgence sans nom',
      subtitle: urgence?.numTel ?? '-',
      date: urgence?.createdAt ?? null,
      icon: 'solar:danger-bold',
    }));

    return [...usersFeed, ...lieuxFeed, ...urgencesFeed]
      .filter((item) => !!item.date)
      .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())
      .slice(0, 30);
  }, [users, lieux, urgences]);

  const filteredFeedItems = useMemo(
    () => feedItems.filter((item) => isWithinRange(item?.date, timeRange)).slice(0, 12),
    [feedItems, timeRange]
  );

  const selectedRangeLabel = useMemo(
    () => RANGE_OPTIONS.find((item) => item.value === timeRange)?.label ?? 'Tout',
    [timeRange]
  );

  const handleChangeRange = (_, value) => {
    if (!value) return;
    setTimeRange(value);
  };

  return (
    <DashboardContent maxWidth="xl" sx={sx}>
      <Stack spacing={3}>
        <Stack
          direction={{ xs: 'column', md: 'row' }}
          spacing={2}
          alignItems={{ xs: 'flex-start', md: 'center' }}
          justifyContent="space-between"
        >
          <Stack spacing={0.5}>
            <Typography variant="h4">Feed generale</Typography>
            <Typography variant="body2" sx={{ color: 'text.secondary' }}>
              Vue globale de l&apos;activite de la plateforme
            </Typography>
          </Stack>

          <ToggleButtonGroup
            size="small"
            color="primary"
            value={timeRange}
            exclusive
            onChange={handleChangeRange}
          >
            {RANGE_OPTIONS.map((item) => (
              <ToggleButton key={item.value} value={item.value}>
                {item.label}
              </ToggleButton>
            ))}
          </ToggleButtonGroup>
        </Stack>

        {!!error && <Alert severity="error">{error}</Alert>}

        {loading ? (
          <Stack alignItems="center" justifyContent="center" sx={{ py: 8 }}>
            <CircularProgress />
          </Stack>
        ) : (
          <>
            <Box
              sx={{
                display: 'grid',
                gap: 2,
                gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, 1fr)', lg: 'repeat(3, 1fr)' },
              }}
            >
              <StatCard
                title="Total utilisateurs"
                value={stats.totalUsers}
                subtitle={`${stats.usersInRange} nouveaux sur ${selectedRangeLabel.toLowerCase()}`}
                icon="solar:users-group-rounded-bold"
                color="#1D4ED8"
              />

              <StatCard
                title="Total lieux"
                value={stats.totalLieux}
                subtitle={`${stats.lieuxInRange} ajoutes sur ${selectedRangeLabel.toLowerCase()}`}
                icon="solar:map-point-wave-bold"
                color="#047857"
              />

              <StatCard
                title="Urgences"
                value={stats.totalUrgences}
                subtitle={`${stats.urgencesInRange} signalees sur ${selectedRangeLabel.toLowerCase()}`}
                icon="solar:shield-warning-bold"
                color="#B45309"
              />

              <StatCard
                title="Demandes organisateur"
                value={stats.demandesEnAttente}
                subtitle="Demandes en attente"
                icon="solar:document-add-bold"
                color="#7C3AED"
              />

              <StatCard
                title="Organisateurs"
                value={stats.totalOrganisateurs}
                subtitle={`${stats.totalAdmins} admins actifs`}
                icon="solar:medal-ribbons-star-bold"
                color="#0E7490"
              />
            </Box>

            <Card>
              <CardContent>
                <Stack spacing={2}>
                  <Stack
                    direction={{ xs: 'column', sm: 'row' }}
                    spacing={1}
                    alignItems={{ xs: 'flex-start', sm: 'center' }}
                    justifyContent="space-between"
                  >
                    <Typography variant="h6">Activite recente</Typography>
                    <Chip
                      size="small"
                      color="info"
                      label={`${filteredFeedItems.length} elements sur ${selectedRangeLabel.toLowerCase()}`}
                    />
                  </Stack>
                  <List disablePadding>
                    {filteredFeedItems.map((item, index) => (
                      <Box key={`${item.type}_${item.id}_${index}`}>
                        <ListItem disableGutters>
                          <Stack direction="row" spacing={1.5} alignItems="center" sx={{ width: 1 }}>
                            <Iconify icon={item.icon} width={20} />
                            <ListItemText
                              primary={item.title}
                              secondary={`${item.subtitle} • ${item.typeLabel} • ${formatDate(item.date)}`}
                            />
                          </Stack>
                        </ListItem>
                        {index < filteredFeedItems.length - 1 ? <Divider /> : null}
                      </Box>
                    ))}
                    {!filteredFeedItems.length ? (
                      <ListItem disableGutters>
                        <ListItemText primary="Aucune activite recente pour cette periode" />
                      </ListItem>
                    ) : null}
                  </List>
                </Stack>
              </CardContent>
            </Card>
          </>
        )}
      </Stack>
    </DashboardContent>
  );
}
