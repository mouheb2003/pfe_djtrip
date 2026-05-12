import { useSetState } from 'minimal-shared/hooks';
import { useMemo, useState, useEffect, useCallback } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Alert from '@mui/material/Alert';
import Paper from '@mui/material/Paper';
import Stack from '@mui/material/Stack';
import Table from '@mui/material/Table';
import Dialog from '@mui/material/Dialog';
import Button from '@mui/material/Button';
import Tooltip from '@mui/material/Tooltip';
import Checkbox from '@mui/material/Checkbox';
import MenuItem from '@mui/material/MenuItem';
import TableRow from '@mui/material/TableRow';
import TextField from '@mui/material/TextField';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import IconButton from '@mui/material/IconButton';
import Typography from '@mui/material/Typography';
import DialogTitle from '@mui/material/DialogTitle';
import DialogActions from '@mui/material/DialogActions';
import DialogContent from '@mui/material/DialogContent';
import TableContainer from '@mui/material/TableContainer';
import CircularProgress from '@mui/material/CircularProgress';
import Avatar from '@mui/material/Avatar';
import Grid from '@mui/material/Grid';
import Rating from '@mui/material/Rating';

import { DashboardContent } from 'src/layouts/dashboard';
import {
  getUsers,
  deleteUser,
  getUserById,
  getUserOverview,
  toggleUserRole,
  updateUserStatus,
  banUser,
  unbanUser,
  sendMessageTo,
} from 'src/Controller/actions';

import { Label } from 'src/components/label';
import { toast } from 'src/components/snackbar';
import { Iconify } from 'src/components/iconify';
import { Scrollbar } from 'src/components/scrollbar';
import {
  useTable,
  emptyRows,
  rowInPage,
  getComparator,
  TableEmptyRows,
  TableHeadCustom,
  TableSelectedAction,
  TablePaginationCustom,
} from 'src/components/table';

const TABLE_HEAD = [
  { id: 'selection', label: '', align: 'center', disableSort: true, width: 56 },
  { id: 'fullname', label: 'Nom' },
  { id: 'email', label: 'Email' },
  { id: 'role', label: 'Role' },
  { id: 'status', label: 'Statut compte' },
  { id: 'dateInscription', label: 'Date inscription' },
  { id: 'actions', label: '', align: 'right' },
];

function roleColor(role) {
  if (role === 'admin') return 'error';
  if (role === 'organisateur') return 'warning';
  return 'info';
}

function statusColor(status) {
  if (status === 'actif') return 'success';
  if (status === 'suspendu') return 'error';
  return 'default';
}

function normalizeAccountStatus(accountStatus) {
  const normalized = String(accountStatus ?? '').toLowerCase();

  if (normalized === 'active') return 'actif';
  if (normalized === 'suspended') return 'suspendu';
  if (normalized === 'inactive') return 'inactif';
  if (normalized === 'banned') return 'banni';

  return '-';
}

function normalizeUser(user) {
  const normalizedUserType = String(user?.userType ?? '').toLowerCase();

  const computedRole =
    user?.role ??
    (normalizedUserType === 'admin'
      ? 'admin'
      : normalizedUserType === 'organisator'
        ? 'organisateur'
        : normalizedUserType === 'touriste'
          ? 'touriste'
          : '-');

  return {
    id: user?._id ?? user?.id,
    fullname: user?.fullname ?? '-',
    email: user?.email ?? '-',
    role: computedRole,
    status: normalizeAccountStatus(user?.accountStatus ?? user?.status),
    statutOrganisateur: user?.statut_organisateur ?? '-',
    dateInscription: user?.date_inscription ?? user?.createdAt ?? null,
    suspendedUntil: user?.suspendedUntil ?? null,
    numTel: user?.num_tel ?? '-',
    age: user?.age ?? '-',
    bio: user?.bio ?? '-',
  };
}

function applyFilter({ inputData, comparator, filters }) {
  const { query, role, status } = filters;

  const stabilized = inputData.map((el, index) => [el, index]);
  stabilized.sort((a, b) => {
    const order = comparator(a[0], b[0]);
    if (order !== 0) return order;
    return a[1] - b[1];
  });

  let data = stabilized.map((el) => el[0]);

  if (query) {
    const q = query.toLowerCase();
    data = data.filter(
      (row) => row.fullname.toLowerCase().includes(q) || row.email.toLowerCase().includes(q)
    );
  }

  if (role !== 'all') {
    data = data.filter((row) => row.role === role);
  }

  if (status !== 'all') {
    data = data.filter((row) => row.status === status);
  }

  return data;
}

export function UsersView({ sx }) {
  const table = useTable({ defaultOrderBy: 'fullname' });

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [users, setUsers] = useState([]);
  const [busyUserId, setBusyUserId] = useState('');
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [overviewOpen, setOverviewOpen] = useState(false);
  const [overviewLoading, setOverviewLoading] = useState(false);
  const [userOverview, setUserOverview] = useState(null);
  const [suspendDialogOpen, setSuspendDialogOpen] = useState(false);
  const [banDialogOpen, setBanDialogOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);
  const [suspendTargetUser, setSuspendTargetUser] = useState(null);
  const [suspendReason, setSuspendReason] = useState('');
  const [banTargetUser, setBanTargetUser] = useState(null);
  const [banReason, setBanReason] = useState('');
  const [customSuspendUntil, setCustomSuspendUntil] = useState('');
  const [warningDialogOpen, setWarningDialogOpen] = useState(false);
  const [warningTargetUser, setWarningTargetUser] = useState(null);
  const [warningMessage, setWarningMessage] = useState('');

  const filters = useSetState({
    query: '',
    role: 'all',
    status: 'all',
  });
  const { state: currentFilters, setState: updateFilters } = filters;

  const fetchUsers = useCallback(async () => {
    try {
      setLoading(true);
      setError('');

      const response = await getUsers();
      setUsers(response.map((user) => normalizeUser(user)));
    } catch {
      setError('Erreur lors du chargement des utilisateurs');
      toast.error('Impossible de récupérer les utilisateurs');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchUsers();
  }, [fetchUsers]);

  useEffect(() => {
    const onFocus = () => {
      fetchUsers();
    };

    const onVisibilityChange = () => {
      if (!document.hidden) {
        fetchUsers();
      }
    };

    window.addEventListener('focus', onFocus);
    document.addEventListener('visibilitychange', onVisibilityChange);

    return () => {
      window.removeEventListener('focus', onFocus);
      document.removeEventListener('visibilitychange', onVisibilityChange);
    };
  }, [fetchUsers]);

  useEffect(() => {
    const now = Date.now();
    const nearestExpiryMs = users
      .map((user) => {
        const status = String(user?.status ?? '').toLowerCase();
        if (status !== 'suspendu' || !user?.suspendedUntil) return null;

        const expiryMs = new Date(user.suspendedUntil).getTime();
        if (Number.isNaN(expiryMs) || expiryMs <= now) return null;

        return expiryMs;
      })
      .filter(Boolean)
      .sort((a, b) => a - b)[0];

    if (!nearestExpiryMs) return undefined;

    const timeoutMs = Math.max(500, nearestExpiryMs - now + 500);
    const timeoutId = setTimeout(() => {
      fetchUsers();
    }, timeoutMs);

    return () => clearTimeout(timeoutId);
  }, [users, fetchUsers]);

  const handleViewDetails = useCallback(async (id) => {
    try {
      setBusyUserId(id);
      const user = await getUserById(id);
      setSelectedUser(normalizeUser(user));
      setDetailsOpen(true);
    } catch {
      toast.error('Impossible de récupérer les détails utilisateur');
    } finally {
      setBusyUserId('');
    }
  }, []);

  const handleViewOverview = useCallback(async (id) => {
    try {
      setOverviewLoading(true);
      setOverviewOpen(true);
      const overview = await getUserOverview(id);
      setUserOverview(overview);
    } catch {
      toast.error('Impossible de récupérer l\'aperçu utilisateur');
    } finally {
      setOverviewLoading(false);
    }
  }, []);

  const handleOpenWarningDialog = useCallback((user) => {
    setWarningTargetUser(user);
    setWarningMessage('');
    setWarningDialogOpen(true);
  }, []);

  const handleSendWarning = useCallback(async () => {
    if (!warningTargetUser?.id || !warningMessage.trim()) {
      toast.warning('Veuillez saisir un message');
      return;
    }

    try {
      setBusyUserId(warningTargetUser.id);
      await sendMessageTo(warningTargetUser.id, warningMessage, { messageType: 'warning' });
      toast.success('Avertissement envoyé');
      setWarningDialogOpen(false);
      setWarningTargetUser(null);
      setWarningMessage('');
    } catch {
      toast.error('Envoi de l’avertissement échoué');
    } finally {
      setBusyUserId('');
    }
  }, [warningTargetUser, warningMessage]);

  const handleToggleRole = useCallback(
    async (user) => {
      if (!user?.id) return;

      if (user.role === 'admin') {
        toast.error('Le rôle admin ne peut pas être modifié');
        return;
      }

      try {
        setBusyUserId(user.id);
        await toggleUserRole(user.id);
        toast.success('Rôle utilisateur mis à jour');
        await fetchUsers();

        if (selectedUser?.id === user.id) {
          const refreshed = await getUserById(user.id);
          setSelectedUser(normalizeUser(refreshed));
        }
      } catch {
        toast.error('Échec de la modification du rôle');
      } finally {
        setBusyUserId('');
      }
    },
    [fetchUsers, selectedUser?.id]
  );

  const handleDeleteUser = useCallback(
    async (user) => {
      if (!user?.id) return;

      if (user.role === 'admin') {
        toast.error("Suppression d'un compte admin non autorisée");
        return;
      }

      const confirmed = window.confirm(`Supprimer l'utilisateur ${user.fullname} ?`);
      if (!confirmed) return;

      try {
        setBusyUserId(user.id);
        await deleteUser(user.id);
        toast.success('Utilisateur supprimé');

        if (selectedUser?.id === user.id) {
          setDetailsOpen(false);
          setSelectedUser(null);
        }

        await fetchUsers();
      } catch {
        toast.error('Échec de la suppression');
      } finally {
        setBusyUserId('');
      }
    },
    [fetchUsers, selectedUser?.id]
  );

  const closeSuspendDialog = useCallback(() => {
    setSuspendDialogOpen(false);
    setSuspendTargetUser(null);
    setSuspendReason('');
    setCustomSuspendUntil('');
  }, []);

  const closeBanDialog = useCallback(() => {
    setBanDialogOpen(false);
    setBanTargetUser(null);
    setBanReason('');
  }, []);

  const handleOpenSuspendDialog = useCallback((user) => {
    if (!user?.id) return;

    if (user.role === 'admin') {
      toast.error('Le compte admin ne peut pas être suspendu');
      return;
    }

    setSuspendDialogOpen(true);
    setSuspendTargetUser(user);
    setSuspendReason('');
    setCustomSuspendUntil('');
  }, []);

  const handleOpenBanDialog = useCallback((user) => {
    if (!user?.id) return;

    if (user.role === 'admin') {
      toast.error('Le compte admin ne peut pas être banni');
      return;
    }

    setBanDialogOpen(true);
    setBanTargetUser(user);
    setBanReason('');
  }, []);

  const applyStatusUpdate = useCallback(
    async (user, statusPayload, successMessage) => {
      try {
        setBusyUserId(user.id);
        await updateUserStatus(user.id, statusPayload);
        toast.success(successMessage);
        await fetchUsers();

        if (selectedUser?.id === user.id) {
          const refreshed = await getUserById(user.id);
          setSelectedUser(normalizeUser(refreshed));
        }
      } catch {
        toast.error('Échec de la mise à jour du statut');
      } finally {
        setBusyUserId('');
      }
    },
    [fetchUsers, selectedUser?.id]
  );

  const handleApplyCustomSuspendUntil = useCallback(async () => {
    if (!suspendTargetUser?.id) return;

    if (!suspendReason.trim()) {
      toast.error('Veuillez saisir une raison pour la suspension');
      return;
    }

    if (!customSuspendUntil) {
      toast.error('Veuillez choisir une date et une heure valides');
      return;
    }

    const parsedUntil = new Date(customSuspendUntil);
    if (Number.isNaN(parsedUntil.getTime()) || parsedUntil <= new Date()) {
      toast.error('La date de suspension doit être dans le futur');
      return;
    }

    closeSuspendDialog();
    await applyStatusUpdate(
      suspendTargetUser,
      {
        accountStatus: 'suspended',
        suspendedUntil: parsedUntil.toISOString(),
        suspendReason: suspendReason.trim(),
      },
      `Utilisateur suspendu jusqu au ${parsedUntil.toLocaleString('fr-FR')}`
    );
  }, [applyStatusUpdate, closeSuspendDialog, customSuspendUntil, suspendReason, suspendTargetUser]);

  const handleApplyUnsuspend = useCallback(async () => {
    if (!suspendTargetUser?.id) return;

    closeSuspendDialog();
    await applyStatusUpdate(
      suspendTargetUser,
      { accountStatus: 'active' },
      'Utilisateur désuspendu avec succès'
    );
  }, [applyStatusUpdate, closeSuspendDialog, suspendTargetUser]);

  const handleApplyBan = useCallback(async () => {
    if (!banTargetUser?.id || !banReason.trim()) {
      toast.error('Veuillez saisir une raison pour le bannissement');
      return;
    }

    try {
      setBusyUserId(banTargetUser.id);
      await banUser(banTargetUser.id, banReason);
      toast.success('Utilisateur banni et email envoyé');

      closeBanDialog();
      await fetchUsers();

      if (selectedUser?.id === banTargetUser.id) {
        const refreshed = await getUserById(banTargetUser.id);
        setSelectedUser(normalizeUser(refreshed));
      }
    } catch {
      toast.error("Échec du bannissement de l'utilisateur");
    } finally {
      setBusyUserId('');
    }
  }, [banTargetUser, banReason, closeBanDialog, fetchUsers, selectedUser?.id]);

  const handleApplyUnban = useCallback(async () => {
    if (!banTargetUser?.id) return;

    try {
      setBusyUserId(banTargetUser.id);
      await unbanUser(banTargetUser.id);
      toast.success('Utilisateur débanni avec succès');

      closeBanDialog();
      await fetchUsers();

      if (selectedUser?.id === banTargetUser.id) {
        const refreshed = await getUserById(banTargetUser.id);
        setSelectedUser(normalizeUser(refreshed));
      }
    } catch {
      toast.error("Échec du débannissement de l'utilisateur");
    } finally {
      setBusyUserId('');
    }
  }, [banTargetUser?.id, closeBanDialog, fetchUsers, selectedUser?.id]);

  const dataFiltered = useMemo(
    () =>
      applyFilter({
        inputData: users,
        comparator: getComparator(table.order, table.orderBy),
        filters: currentFilters,
      }),
    [currentFilters, table.order, table.orderBy, users]
  );

  useEffect(() => {
    const totalPages = Math.ceil(dataFiltered.length / table.rowsPerPage);
    if (table.page > 0 && table.page >= totalPages) {
      table.onResetPage();
    }
  }, [dataFiltered.length, table]);

  const dataInPage = rowInPage(dataFiltered, table.page, table.rowsPerPage);
  const notFound = dataFiltered.length === 0;
  const filteredIds = dataFiltered.map((item) => item.id);
  const selectedInFiltered = table.selected.filter((id) => filteredIds.includes(id));
  const selectedInFilteredCount = selectedInFiltered.length;
  const canReset =
    currentFilters.query.trim() !== '' ||
    currentFilters.role !== 'all' ||
    currentFilters.status !== 'all';

  const handleFilterQuery = useCallback(
    (event) => {
      table.onResetPage();
      updateFilters({ query: event.target.value });
    },
    [table, updateFilters]
  );

  const handleFilterRole = useCallback(
    (event) => {
      table.onResetPage();
      updateFilters({ role: event.target.value });
    },
    [table, updateFilters]
  );

  const handleFilterStatus = useCallback(
    (event) => {
      table.onResetPage();
      updateFilters({ status: event.target.value });
    },
    [table, updateFilters]
  );

  const handleResetFilters = useCallback(() => {
    table.onResetPage();
    updateFilters({ query: '', role: 'all', status: 'all' });
  }, [table, updateFilters]);

  const handleDeleteSelected = useCallback(async () => {
    const selectedUsers = users.filter((user) => table.selected.includes(user.id));
    const deletableUsers = selectedUsers.filter((user) => user.role !== 'admin');

    if (!deletableUsers.length) {
      toast.error('Aucun utilisateur supprimable sélectionné');
      return;
    }

    const confirmed = window.confirm(
      `Supprimer ${deletableUsers.length} utilisateur(s) sélectionné(s) ?`
    );
    if (!confirmed) return;

    try {
      for (const user of deletableUsers) {
        await deleteUser(user.id);
      }

      toast.success('Utilisateurs supprimés');

      if (selectedUser?.id && deletableUsers.some((user) => user.id === selectedUser.id)) {
        setDetailsOpen(false);
        setSelectedUser(null);
      }

      table.setSelected([]);
      await fetchUsers();
    } catch {
      toast.error('Échec de la suppression multiple');
    }
  }, [fetchUsers, selectedUser?.id, table, users]);

  return (
    <DashboardContent maxWidth="xl" sx={sx}>
      <Stack spacing={2}>
        <Typography variant="h4">Utilisateurs</Typography>

        <Card sx={{ p: 2 }}>
          <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} alignItems={{ md: 'center' }}>
            <TextField
              fullWidth
              label="Recherche"
              placeholder="Nom ou email"
              value={currentFilters.query}
              onChange={handleFilterQuery}
            />

            <TextField
              select
              label="Role"
              value={currentFilters.role}
              onChange={handleFilterRole}
              sx={{ minWidth: 200 }}
            >
              <MenuItem value="all">Tous</MenuItem>
              <MenuItem value="admin">Admin</MenuItem>
              <MenuItem value="organisateur">Organisateur</MenuItem>
              <MenuItem value="touriste">Touriste</MenuItem>
            </TextField>

            <TextField
              select
              label="Statut"
              value={currentFilters.status}
              onChange={handleFilterStatus}
              sx={{ minWidth: 200 }}
            >
              <MenuItem value="all">Tous</MenuItem>
              <MenuItem value="actif">Actif</MenuItem>
              <MenuItem value="inactif">Inactif</MenuItem>
              <MenuItem value="suspendu">Suspendu</MenuItem>
            </TextField>

            <Button onClick={handleResetFilters} disabled={!canReset}>
              Reset
            </Button>
          </Stack>
        </Card>

        <Card>
          {loading ? (
            <Stack alignItems="center" justifyContent="center" sx={{ py: 8 }}>
              <CircularProgress />
            </Stack>
          ) : (
            <Box sx={{ position: 'relative' }}>
              <TableSelectedAction
                dense={table.dense}
                numSelected={selectedInFilteredCount}
                rowCount={dataFiltered.length}
                onSelectAllRows={(checked) =>
                  table.onSelectAllRows(
                    checked,
                    dataFiltered.map((row) => row.id)
                  )
                }
                action={
                  <Tooltip title="Supprimer sélection">
                    <IconButton color="primary" onClick={handleDeleteSelected}>
                      <Iconify icon="solar:trash-bin-trash-bold" />
                    </IconButton>
                  </Tooltip>
                }
              />

              {!!error && (
                <Alert severity="error" sx={{ m: 2 }}>
                  {error}
                </Alert>
              )}

              <Scrollbar>
                <TableContainer component={Paper}>
                  <Table size={table.dense ? 'small' : 'medium'}>
                    <TableHeadCustom
                      order={table.order}
                      orderBy={table.orderBy}
                      headCells={[
                        {
                          id: 'selection',
                          label: (
                            <Checkbox
                              indeterminate={
                                selectedInFilteredCount > 0 &&
                                selectedInFilteredCount < dataFiltered.length
                              }
                              checked={
                                dataFiltered.length > 0 &&
                                selectedInFilteredCount === dataFiltered.length
                              }
                              onChange={(event) =>
                                table.onSelectAllRows(
                                  event.target.checked,
                                  dataFiltered.map((row) => row.id)
                                )
                              }
                            />
                          ),
                          align: 'center',
                          disableSort: true,
                          width: 56,
                        },
                        ...TABLE_HEAD.slice(1),
                      ]}
                      onSort={table.onSort}
                    />

                    <TableBody>
                      {dataInPage.map((user) => (
                        <TableRow key={user.id} hover>
                          <TableCell padding="checkbox">
                            <Checkbox
                              checked={table.selected.includes(user.id)}
                              onClick={() => table.onSelectRow(user.id)}
                            />
                          </TableCell>
                          <TableCell>{user.fullname}</TableCell>
                          <TableCell>{user.email}</TableCell>
                          <TableCell>
                            <Label variant="soft" color={roleColor(user.role)}>
                              {user.role}
                            </Label>
                          </TableCell>
                          <TableCell>
                            <Label variant="soft" color={statusColor(user.status)}>
                              {user.status}
                            </Label>
                          </TableCell>
                          <TableCell>
                            {user.dateInscription
                              ? new Date(user.dateInscription).toLocaleDateString('fr-FR')
                              : '-'}
                          </TableCell>
                          <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                            <Tooltip title="Vue d'ensemble complète">
                              <span>
                                <IconButton
                                  color="primary"
                                  onClick={() => handleViewOverview(user.id)}
                                  disabled={busyUserId === user.id}
                                >
                                  <Iconify icon="solar:eye-bold" />
                                </IconButton>
                              </span>
                            </Tooltip>

                            <Tooltip title="Envoyer avertissement">
                              <span>
                                <IconButton
                                  color="warning"
                                  onClick={() => handleOpenWarningDialog(user)}
                                  disabled={busyUserId === user.id || user.role === 'admin'}
                                >
                                  <Iconify icon="solar:danger-triangle-bold" />
                                </IconButton>
                              </span>
                            </Tooltip>

                            <Tooltip title="Bannir l'utilisateur">
                              <span>
                                <IconButton
                                  color="error"
                                  onClick={() => handleOpenBanDialog(user)}
                                  disabled={busyUserId === user.id || user.role === 'admin'}
                                >
                                  <Iconify icon="solar:forbidden-circle-bold" />
                                </IconButton>
                              </span>
                            </Tooltip>

                            <Tooltip
                              title={
                                user.status === 'suspendu'
                                  ? 'Réactiver le compte'
                                  : 'Suspendre le compte'
                              }
                            >
                              <span>
                                <IconButton
                                  color={user.status === 'suspendu' ? 'success' : 'inherit'}
                                  onClick={() => handleOpenSuspendDialog(user)}
                                  disabled={busyUserId === user.id || user.role === 'admin'}
                                >
                                  <Iconify
                                    icon={
                                      user.status === 'suspendu'
                                        ? 'solar:shield-check-bold'
                                        : 'solar:forbidden-circle-bold'
                                    }
                                  />
                                </IconButton>
                              </span>
                            </Tooltip>

                            <Tooltip title="Supprimer">
                              <span>
                                <IconButton
                                  color="error"
                                  onClick={() => handleDeleteUser(user)}
                                  disabled={busyUserId === user.id || user.role === 'admin'}
                                >
                                  <Iconify icon="solar:trash-bin-trash-bold" />
                                </IconButton>
                              </span>
                            </Tooltip>
                          </TableCell>
                        </TableRow>
                      ))}

                      <TableEmptyRows
                        height={table.dense ? 56 : 76}
                        emptyRows={emptyRows(table.page, table.rowsPerPage, dataFiltered.length)}
                      />

                      {notFound && !error ? (
                        <TableRow>
                          <TableCell colSpan={8} align="center">
                            Aucun utilisateur trouvé
                          </TableCell>
                        </TableRow>
                      ) : null}
                    </TableBody>
                  </Table>
                </TableContainer>
              </Scrollbar>

              <TablePaginationCustom
                page={table.page}
                dense={table.dense}
                count={dataFiltered.length}
                rowsPerPage={table.rowsPerPage}
                onPageChange={table.onChangePage}
                onChangeDense={table.onChangeDense}
                onRowsPerPageChange={table.onChangeRowsPerPage}
              />
            </Box>
          )}
        </Card>

        <Dialog open={detailsOpen} onClose={() => setDetailsOpen(false)} fullWidth maxWidth="lg">
          <DialogTitle sx={{ p: 0 }}>
            <Box
              sx={{
                p: 3,
                position: 'relative',
                overflow: 'hidden',
                color: 'common.white',
                background:
                  'linear-gradient(135deg, rgba(15,23,42,1) 0%, rgba(29,78,216,1) 48%, rgba(56,189,248,1) 100%)',
                '&::before': {
                  content: '""',
                  position: 'absolute',
                  inset: 0,
                  background:
                    'radial-gradient(circle at top right, rgba(255,255,255,0.22), transparent 34%), radial-gradient(circle at bottom left, rgba(255,255,255,0.12), transparent 28%)',
                  pointerEvents: 'none',
                },
              }}
            >
              <Stack direction="row" spacing={2} alignItems="center" sx={{ position: 'relative' }}>
                <Avatar
                  sx={{
                    width: 64,
                    height: 64,
                    bgcolor: 'rgba(255,255,255,0.16)',
                    color: 'common.white',
                    fontWeight: 800,
                    border: '1px solid rgba(255,255,255,0.3)',
                    boxShadow: '0 12px 24px rgba(15,23,42,0.2)',
                  }}
                >
                  {(selectedUser?.fullname?.[0] || selectedUser?.email?.[0] || '?').toUpperCase()}
                </Avatar>

                <Box sx={{ minWidth: 0, flexGrow: 1 }}>
                  <Typography variant="h5" sx={{ fontWeight: 800, lineHeight: 1.1 }} noWrap>
                    {selectedUser?.fullname ?? '-'}
                  </Typography>
                  <Typography variant="body2" sx={{ opacity: 0.9, mt: 0.5 }} noWrap>
                    {selectedUser?.email ?? '-'}
                  </Typography>
                  <Stack direction="row" spacing={1} sx={{ mt: 1.5 }} flexWrap="wrap" useFlexGap>
                    <Label
                      variant="soft"
                      sx={{ bgcolor: 'rgba(255,255,255,0.18)', color: 'common.white', px: 1.2 }}
                    >
                      {selectedUser?.role ?? '-'}
                    </Label>
                    <Label
                      variant="soft"
                      sx={{ bgcolor: 'rgba(255,255,255,0.18)', color: 'common.white', px: 1.2 }}
                    >
                      {selectedUser?.status ?? '-'}
                    </Label>
                    <Label
                      variant="soft"
                      sx={{ bgcolor: 'rgba(255,255,255,0.18)', color: 'common.white', px: 1.2 }}
                    >
                      {selectedUser?.statutOrganisateur ?? '-'}
                    </Label>
                  </Stack>
                </Box>
              </Stack>
            </Box>
          </DialogTitle>
          <DialogContent dividers sx={{ bgcolor: 'background.paper', p: 3 }}>
            <Box
              sx={{
                display: 'grid',
                gap: 2.5,
                gridTemplateColumns: { xs: '1fr', md: '340px 1fr' },
                alignItems: 'start',
              }}
            >
              <Card
                variant="outlined"
                sx={{
                  p: 2.5,
                  borderRadius: 3,
                  bgcolor: 'background.neutral',
                  position: { md: 'sticky' },
                  top: { md: 24 },
                }}
              >
                <Stack spacing={2}>
                  <Box>
                    <Typography variant="overline" sx={{ color: 'text.secondary', letterSpacing: 1.2 }}>
                      Profil
                    </Typography>
                    <Typography variant="h6" sx={{ fontWeight: 800, mt: 0.5 }}>
                      {selectedUser?.fullname ?? '-'}
                    </Typography>
                    <Typography variant="body2" sx={{ color: 'text.secondary', mt: 0.5 }}>
                      {selectedUser?.email ?? '-'}
                    </Typography>
                  </Box>

                  <Box
                    sx={{
                      p: 1.5,
                      borderRadius: 2,
                      bgcolor: 'rgba(255,255,255,0.68)',
                      border: '1px solid',
                      borderColor: 'divider',
                    }}
                  >
                    <Stack direction="row" justifyContent="space-between" alignItems="center">
                      <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                        Compte
                      </Typography>
                      <Label variant="soft" color={statusColor(selectedUser?.status)}>
                        {selectedUser?.status ?? '-'}
                      </Label>
                    </Stack>
                    <Stack direction="row" justifyContent="space-between" alignItems="center" sx={{ mt: 1 }}>
                      <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                        Rôle
                      </Typography>
                      <Label variant="soft" color={roleColor(selectedUser?.role)}>
                        {selectedUser?.role ?? '-'}
                      </Label>
                    </Stack>
                  </Box>

                  <Box sx={{ display: 'grid', gap: 1.25 }}>
                    <Paper
                      variant="outlined"
                      sx={{ p: 1.5, borderRadius: 2.5, bgcolor: 'background.paper' }}
                    >
                      <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                        Date d'inscription
                      </Typography>
                      <Typography variant="body2" sx={{ fontWeight: 700, mt: 0.5 }}>
                        {selectedUser?.dateInscription
                          ? new Date(selectedUser.dateInscription).toLocaleString('fr-FR')
                          : '-'}
                      </Typography>
                    </Paper>

                    <Paper
                      variant="outlined"
                      sx={{ p: 1.5, borderRadius: 2.5, bgcolor: 'background.paper' }}
                    >
                      <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                        Suspendu jusqu'au
                      </Typography>
                      <Typography variant="body2" sx={{ fontWeight: 700, mt: 0.5 }}>
                        {selectedUser?.suspendedUntil
                          ? new Date(selectedUser.suspendedUntil).toLocaleString('fr-FR')
                          : '-'}
                      </Typography>
                    </Paper>
                  </Box>
                </Stack>
              </Card>

              <Stack spacing={2.5}>
                <Box>
                  <Typography variant="overline" sx={{ color: 'text.secondary', letterSpacing: 1.2 }}>
                    Informations principales
                  </Typography>

                  <Box
                    sx={{
                      mt: 1,
                      display: 'grid',
                      gap: 1.5,
                      gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, minmax(0, 1fr))' },
                    }}
                  >
                    <Card variant="outlined" sx={{ p: 1.8, borderRadius: 2.5 }}>
                      <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                        Téléphone
                      </Typography>
                      <Typography variant="body2" sx={{ fontWeight: 700, mt: 0.5 }}>
                        {selectedUser?.numTel ?? '-'}
                      </Typography>
                    </Card>

                    <Card variant="outlined" sx={{ p: 1.8, borderRadius: 2.5 }}>
                      <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                        Âge
                      </Typography>
                      <Typography variant="body2" sx={{ fontWeight: 700, mt: 0.5 }}>
                        {selectedUser?.age ?? '-'}
                      </Typography>
                    </Card>

                    <Card variant="outlined" sx={{ p: 1.8, borderRadius: 2.5, gridColumn: { sm: '1 / -1' } }}>
                      <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                        Statut organisateur
                      </Typography>
                      <Typography variant="body2" sx={{ fontWeight: 700, mt: 0.5 }}>
                        {selectedUser?.statutOrganisateur ?? '-'}
                      </Typography>
                    </Card>

                    <Card variant="outlined" sx={{ p: 1.8, borderRadius: 2.5, gridColumn: { sm: '1 / -1' } }}>
                      <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                        Bio
                      </Typography>
                      <Typography
                        variant="body2"
                        sx={{ fontWeight: 600, mt: 0.75, lineHeight: 1.75, overflowWrap: 'anywhere' }}
                      >
                        {selectedUser?.bio ?? '-'}
                      </Typography>
                    </Card>
                  </Box>
                </Box>
              </Stack>
            </Box>
          </DialogContent>
          <DialogActions
            sx={{
              px: 3,
              py: 2,
              gap: 1,
              flexWrap: 'wrap',
              justifyContent: 'space-between',
              bgcolor: 'background.neutral',
            }}
          >
            <Stack direction="row" spacing={1} sx={{ flexWrap: 'wrap' }}>
              <Button onClick={() => setDetailsOpen(false)} color="inherit" variant="outlined">
                Fermer
              </Button>
            </Stack>
            <Button
              color="inherit"
              variant="outlined"
              onClick={() => handleOpenSuspendDialog(selectedUser)}
              disabled={
                !selectedUser || selectedUser.role === 'admin' || busyUserId === selectedUser.id
              }
            >
              Suspension
            </Button>
            <Button
              color="error"
              onClick={() => handleOpenBanDialog(selectedUser)}
              disabled={
                !selectedUser || selectedUser.role === 'admin' || busyUserId === selectedUser.id
              }
            >
              Bannir
            </Button>
            <Button
              color="error"
              variant="contained"
              onClick={() => handleDeleteUser(selectedUser)}
              disabled={
                !selectedUser || selectedUser.role === 'admin' || busyUserId === selectedUser.id
              }
            >
              Supprimer
            </Button>
          </DialogActions>
        </Dialog>

        <Dialog open={overviewOpen} onClose={() => setOverviewOpen(false)} fullWidth maxWidth="xl" scroll="paper">
          <DialogTitle>
            <Stack spacing={0.5}>
              <Typography variant="h6">Vue d'ensemble complète de l'utilisateur</Typography>
              <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                Toutes les informations liées à cet utilisateur
              </Typography>
            </Stack>
          </DialogTitle>
          <DialogContent dividers>
            {overviewLoading ? (
              <Stack alignItems="center" justifyContent="center" sx={{ py: 8 }}>
                <CircularProgress />
              </Stack>
            ) : userOverview ? (
              <Stack spacing={2}>
                {/* User Info Card */}
                <Card variant="outlined" sx={{ p: 3, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                  <Stack
                    direction={{ xs: 'column', sm: 'row' }}
                    spacing={2.5}
                    alignItems={{ xs: 'flex-start', sm: 'center' }}
                  >
                    <Avatar
                      src={userOverview.user?.avatar}
                      alt={userOverview.user?.fullname}
                      sx={{ width: 80, height: 80, bgcolor: 'primary.lighter', color: 'primary.main', fontSize: 32 }}
                    >
                      {userOverview.user?.fullname?.charAt(0)?.toUpperCase() ?? '?'}
                    </Avatar>
                    <Box sx={{ flex: 1 }}>
                      <Typography variant="h5" sx={{ fontWeight: 700, mb: 0.5 }}>
                        {userOverview.user?.fullname ?? '-'}
                      </Typography>
                      <Typography variant="body2" sx={{ color: 'text.secondary', mb: 1.5 }}>
                        {userOverview.user?.email ?? '-'}
                      </Typography>
                      <Stack direction="row" spacing={1} flexWrap="wrap">
                        <Label variant="soft" color={roleColor(userOverview.user?.userType)}>
                          {userOverview.user?.userType ?? '-'}
                        </Label>
                        <Label variant="soft" color={statusColor(normalizeAccountStatus(userOverview.user?.accountStatus))}>
                          {normalizeAccountStatus(userOverview.user?.accountStatus)}
                        </Label>
                      </Stack>
                    </Box>
                  </Stack>
                </Card>

                {/* Profile Details Section */}
                <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                  <Stack spacing={1.5}>
                    <Stack direction="row" alignItems="center" spacing={1}>
                      <Avatar sx={{ width: 32, height: 32, bgcolor: 'primary.lighter', color: 'primary.main' }}>
                        <Iconify icon="mdi:account" width={16} />
                      </Avatar>
                      <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Profile Information</Typography>
                    </Stack>
                    <Box sx={{ display: 'grid', gap: 1.5, gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, 1fr)' } }}>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                        <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>ID</Typography>
                        <Typography variant="body2" sx={{ fontWeight: 600, mt: 0.5, wordBreak: 'break-all' }}>{userOverview.user?._id ?? userOverview.user?.id ?? '-'}</Typography>
                      </Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                        <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Full Name</Typography>
                        <Typography variant="body2" sx={{ fontWeight: 600, mt: 0.5 }}>{userOverview.user?.fullname ?? '-'}</Typography>
                      </Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                        <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Email</Typography>
                        <Typography variant="body2" sx={{ fontWeight: 600, mt: 0.5 }}>{userOverview.user?.email ?? '-'}</Typography>
                      </Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                        <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Phone</Typography>
                        <Typography variant="body2" sx={{ fontWeight: 600, mt: 0.5 }}>{userOverview.user?.num_tel ?? userOverview.user?.numTel ?? '-'}</Typography>
                      </Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                        <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Age</Typography>
                        <Typography variant="body2" sx={{ fontWeight: 600, mt: 0.5 }}>{userOverview.user?.age ?? '-'}</Typography>
                      </Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                        <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Date of Birth</Typography>
                        <Typography variant="body2" sx={{ fontWeight: 600, mt: 0.5 }}>{userOverview.user?.date_naissance ? new Date(userOverview.user.date_naissance).toLocaleDateString('fr-FR') : '-'}</Typography>
                      </Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2, gridColumn: { sm: '1 / -1' } }}>
                        <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Bio</Typography>
                        <Typography variant="body2" sx={{ fontWeight: 600, mt: 0.5 }}>{userOverview.user?.bio ?? '-'}</Typography>
                      </Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2, gridColumn: { sm: '1 / -1' } }}>
                        <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Address</Typography>
                        <Typography variant="body2" sx={{ fontWeight: 600, mt: 0.5 }}>{userOverview.user?.address ?? '-'}</Typography>
                      </Card>
                    </Box>
                  </Stack>
                </Card>

                {/* Tourist-specific sections */}
                {userOverview.user?.userType === 'Touriste' && (
                  <>
                    {/* Interests Section */}
                    <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Avatar sx={{ width: 32, height: 32, bgcolor: 'warning.lighter', color: 'warning.main' }}>
                            <Iconify icon="mdi:heart" width={16} />
                          </Avatar>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Centres d'intérêt</Typography>
                        </Stack>
                        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                          {userOverview.user?.interests && Array.isArray(userOverview.user.interests) && userOverview.user.interests.length > 0 ? (
                            userOverview.user.interests.map((interest, index) => (
                              <Label key={index} variant="soft" color="info">{interest}</Label>
                            ))
                          ) : (
                            <Typography variant="body2" sx={{ color: 'text.secondary' }}>Aucun centre d'intérêt spécifié</Typography>
                          )}
                        </Box>
                      </Stack>
                    </Card>

                    {/* Languages Section */}
                    <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Avatar sx={{ width: 32, height: 32, bgcolor: 'success.lighter', color: 'success.main' }}>
                            <Iconify icon="mdi:translate" width={16} />
                          </Avatar>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Langues parlées</Typography>
                        </Stack>
                        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                          {userOverview.user?.languages_spoken && Array.isArray(userOverview.user.languages_spoken) && userOverview.user.languages_spoken.length > 0 ? (
                            userOverview.user.languages_spoken.map((lang, index) => (
                              <Label key={index} variant="soft" color="success">{lang}</Label>
                            ))
                          ) : (
                            <Typography variant="body2" sx={{ color: 'text.secondary' }}>Aucune langue spécifiée</Typography>
                          )}
                        </Box>
                      </Stack>
                    </Card>

                    {/* Specialized Activities Section */}
                    <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Avatar sx={{ width: 32, height: 32, bgcolor: 'info.lighter', color: 'info.main' }}>
                            <Iconify icon="mdi:hiking" width={16} />
                          </Avatar>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Activités spécialisées</Typography>
                        </Stack>
                        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                          {userOverview.user?.specialized_activities && Array.isArray(userOverview.user.specialized_activities) && userOverview.user.specialized_activities.length > 0 ? (
                            userOverview.user.specialized_activities.map((activity, index) => (
                              <Label key={index} variant="soft" color="info">{activity}</Label>
                            ))
                          ) : (
                            <Typography variant="body2" sx={{ color: 'text.secondary' }}>Aucune activité spécialisée spécifiée</Typography>
                          )}
                        </Box>
                      </Stack>
                    </Card>
                  </>
                )}

                {/* Organizer-specific sections */}
                {userOverview.user?.userType === 'Organisator' && (
                  <>
                    {/* Business Interests Section */}
                    <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Avatar sx={{ width: 32, height: 32, bgcolor: 'warning.lighter', color: 'warning.main' }}>
                            <Iconify icon="mdi:business" width={16} />
                          </Avatar>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Centres d'intérêt business</Typography>
                        </Stack>
                        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                          {userOverview.user?.business_interests && Array.isArray(userOverview.user.business_interests) && userOverview.user.business_interests.length > 0 ? (
                            userOverview.user.business_interests.map((interest, index) => (
                              <Label key={index} variant="soft" color="info">{interest}</Label>
                            ))
                          ) : (
                            <Typography variant="body2" sx={{ color: 'text.secondary' }}>Aucun centre d'intérêt business spécifié</Typography>
                          )}
                        </Box>
                      </Stack>
                    </Card>

                    {/* Specialties Section */}
                    <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Avatar sx={{ width: 32, height: 32, bgcolor: 'info.lighter', color: 'info.main' }}>
                            <Iconify icon="mdi:star-circle" width={16} />
                          </Avatar>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Spécialités</Typography>
                        </Stack>
                        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                          {userOverview.user?.specialties && Array.isArray(userOverview.user.specialties) && userOverview.user.specialties.length > 0 ? (
                            userOverview.user.specialties.map((specialty, index) => (
                              <Label key={index} variant="soft" color="info">{specialty}</Label>
                            ))
                          ) : (
                            <Typography variant="body2" sx={{ color: 'text.secondary' }}>Aucune spécialité spécifiée</Typography>
                          )}
                        </Box>
                      </Stack>
                    </Card>

                    {/* Languages Section */}
                    <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Avatar sx={{ width: 32, height: 32, bgcolor: 'success.lighter', color: 'success.main' }}>
                            <Iconify icon="mdi:translate" width={16} />
                          </Avatar>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Langues parlées</Typography>
                        </Stack>
                        <Box sx={{ display: 'flex', flexWrap: 'wrap', gap: 1 }}>
                          {userOverview.user?.languages_spoken && Array.isArray(userOverview.user.languages_spoken) && userOverview.user.languages_spoken.length > 0 ? (
                            userOverview.user.languages_spoken.map((lang, index) => (
                              <Label key={index} variant="soft" color="success">{lang}</Label>
                            ))
                          ) : (
                            <Typography variant="body2" sx={{ color: 'text.secondary' }}>Aucune langue spécifiée</Typography>
                          )}
                        </Box>
                      </Stack>
                    </Card>
                  </>
                )}

                {/* Account Status Section */}
                <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                  <Stack spacing={1.5}>
                    <Stack direction="row" alignItems="center" spacing={1}>
                      <Avatar sx={{ width: 32, height: 32, bgcolor: 'success.lighter', color: 'success.main' }}>
                        <Iconify icon="mdi:shield-account" width={16} />
                      </Avatar>
                      <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Account Status</Typography>
                    </Stack>
                    <Box sx={{ display: 'grid', gap: 1.5, gridTemplateColumns: { xs: '1fr', sm: 'repeat(3, 1fr)' } }}>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}><Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>User Type</Typography><Typography variant="body2" sx={{ fontWeight: 700, mt: 0.5 }}>{userOverview.user?.userType ?? userOverview.user?.role ?? '-'}</Typography></Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}><Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Account Status</Typography><Typography variant="body2" sx={{ fontWeight: 700, mt: 0.5 }}>{normalizeAccountStatus(userOverview.user?.accountStatus)}</Typography></Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}><Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Organizer Status</Typography><Typography variant="body2" sx={{ fontWeight: 700, mt: 0.5 }}>{userOverview.user?.statut_organisateur ?? '-'}</Typography></Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}><Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Registration Date</Typography><Typography variant="body2" sx={{ fontWeight: 700, mt: 0.5 }}>{userOverview.user?.date_inscription || userOverview.user?.createdAt ? new Date(userOverview.user.date_inscription || userOverview.user.createdAt).toLocaleDateString('fr-FR') : '-'}</Typography></Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}><Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Suspended Until</Typography><Typography variant="body2" sx={{ fontWeight: 700, mt: 0.5 }}>{userOverview.user?.suspendedUntil ? new Date(userOverview.user.suspendedUntil).toLocaleDateString('fr-FR') : '-'}</Typography></Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}><Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Email Verified</Typography><Typography variant="body2" sx={{ fontWeight: 700, mt: 0.5 }}>{userOverview.user?.isVerified ? 'Yes' : 'No'}</Typography></Card>
                    </Box>
                  </Stack>
                </Card>

                {/* Organizer Specific Section */}
                {userOverview.user?.userType === 'Organisator' && (
                  <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                    <Stack spacing={1.5}>
                      <Stack direction="row" alignItems="center" spacing={1}>
                        <Avatar sx={{ width: 32, height: 32, bgcolor: 'warning.lighter', color: 'warning.main' }}>
                          <Iconify icon="mdi:account-star" width={16} />
                        </Avatar>
                        <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Organizer Details</Typography>
                      </Stack>
                      <Box sx={{ display: 'grid', gap: 1.5, gridTemplateColumns: { xs: '1fr', sm: 'repeat(3, 1fr)' } }}>
                        <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                          <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Company Name</Typography>
                          <Typography variant="body2" sx={{ fontWeight: 700, mt: 0.5 }}>{userOverview.user?.company_name ?? '-'}</Typography>
                        </Card>
                        <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                          <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Business License</Typography>
                          <Typography variant="body2" sx={{ fontWeight: 700, mt: 0.5 }}>{userOverview.user?.business_license ?? '-'}</Typography>
                        </Card>
                        <Card variant="outlined" sx={{ p: 2, borderRadius: 2, gridColumn: { sm: '1 / -1' } }}>
                          <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Business Description</Typography>
                          <Typography variant="body2" sx={{ fontWeight: 700, mt: 0.5 }}>{userOverview.user?.business_description ?? '-'}</Typography>
                        </Card>
                      </Box>
                    </Stack>
                  </Card>
                )}

                {/* Statistics Cards */}
                <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                  <Stack spacing={1.5}>
                    <Stack direction="row" alignItems="center" spacing={1}>
                      <Avatar sx={{ width: 32, height: 32, bgcolor: 'info.lighter', color: 'info.main' }}>
                        <Iconify icon="mdi:chart-line" width={16} />
                      </Avatar>
                      <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Statistics</Typography>
                    </Stack>
                    <Box sx={{ display: 'grid', gap: 1.5, gridTemplateColumns: { xs: '1fr', sm: 'repeat(3, 1fr)' } }}>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}><Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Réservations</Typography><Typography variant="h4" sx={{ fontWeight: 700 }}>{userOverview.stats?.totalInscriptions ?? 0}</Typography></Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}><Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Activités</Typography><Typography variant="h4" sx={{ fontWeight: 700 }}>{userOverview.stats?.totalActivities ?? 0}</Typography></Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}><Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Messages</Typography><Typography variant="h4" sx={{ fontWeight: 700 }}>{userOverview.stats?.totalMessages ?? 0}</Typography></Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}><Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Avis</Typography><Typography variant="h4" sx={{ fontWeight: 700 }}>{userOverview.stats?.totalReviews ?? 0}</Typography></Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}><Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Publications</Typography><Typography variant="h4" sx={{ fontWeight: 700 }}>{userOverview.stats?.totalPublications ?? 0}</Typography></Card>
                      <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}><Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>Paiements</Typography><Typography variant="h4" sx={{ fontWeight: 700 }}>{userOverview.stats?.totalPayments ?? 0}</Typography></Card>
                    </Box>
                  </Stack>
                </Card>

                {/* Inscriptions Section */}
                <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                  <Stack spacing={1.5}>
                    <Stack direction="row" alignItems="center" spacing={1}>
                      <Avatar sx={{ width: 32, height: 32, bgcolor: 'primary.lighter', color: 'primary.main' }}>
                        <Iconify icon="mdi:calendar-check" width={16} />
                      </Avatar>
                      <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Réservations ({userOverview.stats?.totalInscriptions ?? 0})</Typography>
                    </Stack>
                    {userOverview.inscriptions?.length > 0 ? (
                      userOverview.inscriptions.map((inscription) => (
                        <Card key={inscription._id} variant="outlined" sx={{ p: 1.5, mb: 1, borderRadius: 1.5 }}>
                          <Stack direction="row" spacing={2} alignItems="center">
                            <Box sx={{ flex: 1 }}>
                              <Typography variant="body2" sx={{ fontWeight: 600 }}>{inscription.activity_id?.titre ?? 'Activité inconnue'}</Typography>
                              <Typography variant="caption" sx={{ color: 'text.secondary' }}>Statut: {inscription.statut ?? '-'} | Participants: {inscription.nb_participants ?? '-'}</Typography>
                            </Box>
                            <Typography variant="body2" sx={{ fontWeight: 600 }}>{inscription.activity_id?.prix ?? '-'} TND</Typography>
                          </Stack>
                        </Card>
                      ))
                    ) : (
                      <Typography variant="body2" sx={{ color: 'text.secondary' }}>Aucune réservation</Typography>
                    )}
                  </Stack>
                </Card>

                {/* Activities Section (if organizer) */}
                {userOverview.user?.userType === 'Organisator' && (
                  <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                    <Stack spacing={1.5}>
                      <Stack direction="row" alignItems="center" spacing={1}>
                        <Avatar sx={{ width: 32, height: 32, bgcolor: 'warning.lighter', color: 'warning.main' }}>
                          <Iconify icon="mdi:calendar" width={16} />
                        </Avatar>
                        <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Activités créées ({userOverview.stats?.totalActivities ?? 0})</Typography>
                      </Stack>
                      {userOverview.activities?.length > 0 ? (
                        userOverview.activities.map((activity) => (
                          <Card key={activity._id} variant="outlined" sx={{ p: 1.5, mb: 1, borderRadius: 1.5 }}>
                            <Stack direction="row" spacing={2} alignItems="center">
                              <Box sx={{ flex: 1 }}>
                                <Typography variant="body2" sx={{ fontWeight: 600 }}>{activity.titre ?? '-'}</Typography>
                                <Typography variant="caption" sx={{ color: 'text.secondary' }}>{activity.lieu ?? '-'} | {activity.prix ?? '-'} TND</Typography>
                              </Box>
                              <Label variant="soft" color={activity.statut === 'active' ? 'success' : 'default'}>{activity.statut ?? '-'}</Label>
                            </Stack>
                          </Card>
                        ))
                      ) : (
                        <Typography variant="body2" sx={{ color: 'text.secondary' }}>Aucune activité créée</Typography>
                      )}
                    </Stack>
                  </Card>
                )}

                {/* Reviews Section */}
                <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                  <Stack spacing={1.5}>
                    <Stack direction="row" alignItems="center" spacing={1}>
                      <Avatar sx={{ width: 32, height: 32, bgcolor: 'success.lighter', color: 'success.main' }}>
                        <Iconify icon="mdi:star" width={16} />
                      </Avatar>
                      <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                        {userOverview.user?.userType === 'Touriste' ? 'Avis envoyés' : 'Avis reçus'} ({userOverview.stats?.totalReviews ?? 0})
                      </Typography>
                    </Stack>
                    {userOverview.reviews?.length > 0 ? (
                      userOverview.reviews.map((review) => (
                        <Card key={review._id} variant="outlined" sx={{ p: 1.5, mb: 1, borderRadius: 1.5 }}>
                          <Stack spacing={1}>
                            <Stack direction="row" spacing={2} alignItems="center" justifyContent="space-between">
                              <Box sx={{ flex: 1 }}>
                                <Typography variant="body2" sx={{ fontWeight: 600 }}>{review.activity_id?.titre ?? 'Activité inconnue'}</Typography>
                                <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                                  {userOverview.user?.userType === 'Touriste'
                                    ? `Organisateur: ${review.organisateur_id?.fullname ?? review.organisateur_id?.email ?? '-'}`
                                    : `Touriste: ${review.user_id?.fullname ?? review.user_id?.email ?? '-'}`
                                  }
                                </Typography>
                              </Box>
                              <Stack direction="row" spacing={1} alignItems="center">
                                <Typography variant="body2" sx={{ fontWeight: 700, color: 'warning.main' }}>{review.note ?? '-'}/5</Typography>
                                <Rating value={review.note ?? 0} readOnly size="small" precision={0.5} />
                              </Stack>
                            </Stack>
                            {review.comment && (
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontStyle: 'italic' }}>
                                "{review.comment}"
                              </Typography>
                            )}
                            <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                              {new Date(review.createdAt).toLocaleDateString('fr-FR')} à {new Date(review.createdAt).toLocaleTimeString('fr-FR')}
                            </Typography>
                          </Stack>
                        </Card>
                      ))
                    ) : (
                      <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                        {userOverview.user?.userType === 'Touriste' ? 'Aucun avis envoyé' : 'Aucun avis reçu'}
                      </Typography>
                    )}
                  </Stack>
                </Card>

                {/* Publications Section */}
                <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                  <Stack spacing={1.5}>
                    <Stack direction="row" alignItems="center" spacing={1}>
                      <Avatar sx={{ width: 32, height: 32, bgcolor: 'info.lighter', color: 'info.main' }}>
                        <Iconify icon="mdi:newspaper" width={16} />
                      </Avatar>
                      <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Publications ({userOverview.stats?.totalPublications ?? 0})</Typography>
                    </Stack>
                    {userOverview.publications?.length > 0 ? (
                      userOverview.publications.map((publication) => (
                        <Card key={publication._id} variant="outlined" sx={{ p: 1.5, mb: 1, borderRadius: 1.5 }}>
                          <Typography variant="body2" sx={{ fontWeight: 600 }}>{publication.contenu?.substring(0, 100) ?? '-'}...</Typography>
                          <Typography variant="caption" sx={{ color: 'text.secondary' }}>{new Date(publication.createdAt).toLocaleDateString('fr-FR')}</Typography>
                        </Card>
                      ))
                    ) : (
                      <Typography variant="body2" sx={{ color: 'text.secondary' }}>Aucune publication</Typography>
                    )}
                  </Stack>
                </Card>

                {/* Payments Section */}
                <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                  <Stack spacing={1.5}>
                    <Stack direction="row" alignItems="center" spacing={1}>
                      <Avatar sx={{ width: 32, height: 32, bgcolor: 'warning.lighter', color: 'warning.main' }}>
                        <Iconify icon="mdi:cash" width={16} />
                      </Avatar>
                      <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Paiements ({userOverview.stats?.totalPayments ?? 0})</Typography>
                    </Stack>
                    {userOverview.payments?.length > 0 ? (
                      userOverview.payments.map((payment) => (
                        <Card key={payment._id} variant="outlined" sx={{ p: 1.5, mb: 1, borderRadius: 1.5 }}>
                          <Stack direction="row" spacing={2} alignItems="center">
                            <Box sx={{ flex: 1 }}>
                              <Typography variant="body2" sx={{ fontWeight: 600 }}>{payment.montant ?? '-'} TND</Typography>
                              <Typography variant="caption" sx={{ color: 'text.secondary' }}>Méthode: {payment.methode_paiement ?? '-'}</Typography>
                            </Box>
                            <Label variant="soft" color={payment.statut === 'completed' ? 'success' : 'default'}>{payment.statut ?? '-'}</Label>
                          </Stack>
                        </Card>
                      ))
                    ) : (
                      <Typography variant="body2" sx={{ color: 'text.secondary' }}>Aucun paiement</Typography>
                    )}
                  </Stack>
                </Card>
              </Stack>
            ) : (
              <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                Aucune donnée disponible
              </Typography>
            )}
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setOverviewOpen(false)} color="inherit">
              Fermer
            </Button>
          </DialogActions>
        </Dialog>

        <Dialog open={suspendDialogOpen} onClose={closeSuspendDialog} fullWidth maxWidth="xs">
          <DialogTitle>Suspension utilisateur</DialogTitle>
          <DialogContent dividers>
            <Stack spacing={1.25}>
              <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                Utilisateur: <strong>{suspendTargetUser?.fullname ?? '-'}</strong>
              </Typography>

              <TextField
                fullWidth
                multiline
                rows={3}
                label="Raison de la suspension"
                placeholder="Expliquez pourquoi cet utilisateur est suspendu..."
                value={suspendReason}
                onChange={(event) => setSuspendReason(event.target.value)}
                helperText="La raison sera envoyée à l'utilisateur par email"
              />

              {suspendTargetUser?.status === 'suspendu' ? (
                <Button
                  variant="outlined"
                  color="success"
                  onClick={handleApplyUnsuspend}
                  disabled={busyUserId === suspendTargetUser?.id}
                >
                  Désuspendre maintenant
                </Button>
              ) : null}

              <Stack direction="row" spacing={1} alignItems="center" sx={{ pt: 0.5 }}>
                <TextField
                  size="small"
                  type="datetime-local"
                  label="Suspendre jusqu au"
                  value={customSuspendUntil}
                  onChange={(event) => setCustomSuspendUntil(event.target.value)}
                  fullWidth
                  InputLabelProps={{ shrink: true }}
                />
                <Button variant="contained" onClick={handleApplyCustomSuspendUntil}>
                  OK
                </Button>
              </Stack>
            </Stack>
          </DialogContent>
          <DialogActions>
            <Button onClick={closeSuspendDialog} color="inherit">
              Fermer
            </Button>
          </DialogActions>
        </Dialog>

        <Dialog open={banDialogOpen} onClose={closeBanDialog} fullWidth maxWidth="sm">
          <DialogTitle>
            {banTargetUser?.status === 'banni' ? "Débannir l'utilisateur" : "Bannir l'utilisateur"}
          </DialogTitle>
          <DialogContent dividers>
            <Stack spacing={2}>
              <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                Utilisateur: <strong>{banTargetUser?.fullname ?? '-'}</strong>
              </Typography>
              <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                Email: <strong>{banTargetUser?.email ?? '-'}</strong>
              </Typography>

              {banTargetUser?.status === 'banni' ? (
                <Stack spacing={1}>
                  <Typography variant="body2" sx={{ color: 'error.main', fontWeight: 'bold' }}>
                    Cet utilisateur est actuellement banni
                  </Typography>
                  <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                    Raison du bannissement: <strong>{banTargetUser?.banReason ?? '-'}</strong>
                  </Typography>
                </Stack>
              ) : (
                <TextField
                  fullWidth
                  multiline
                  rows={4}
                  label="Raison du bannissement"
                  placeholder="Expliquez pourquoi cet utilisateur est banni..."
                  value={banReason}
                  onChange={(event) => setBanReason(event.target.value)}
                  helperText="Cette raison sera envoyée à l'utilisateur par email"
                />
              )}
            </Stack>
          </DialogContent>
          <DialogActions>
            <Button onClick={closeBanDialog} color="inherit">
              Annuler
            </Button>
            {banTargetUser?.status === 'banni' ? (
              <Button
                variant="contained"
                color="success"
                onClick={handleApplyUnban}
                disabled={busyUserId === banTargetUser?.id}
              >
                Débannir maintenant
              </Button>
            ) : (
              <Button
                variant="contained"
                color="error"
                onClick={handleApplyBan}
                disabled={busyUserId === banTargetUser?.id || !banReason.trim()}
              >
                Confirmer le bannissement
              </Button>
            )}
          </DialogActions>
        </Dialog>

        <Dialog
          open={warningDialogOpen}
          onClose={() => setWarningDialogOpen(false)}
          fullWidth
          maxWidth="sm"
        >
          <DialogTitle>Envoyer un avertissement</DialogTitle>
          <DialogContent dividers>
            <Stack spacing={2}>
              <Typography variant="body2" color="text.secondary">
                L’avertissement sera envoyé dans le chat normal de{' '}
                {warningTargetUser?.fullname ?? 'cet utilisateur'}.
              </Typography>
              <TextField
                autoFocus
                fullWidth
                multiline
                minRows={4}
                label="Message d’avertissement"
                value={warningMessage}
                onChange={(event) => setWarningMessage(event.target.value)}
                placeholder="Rédigez votre avertissement..."
              />
            </Stack>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setWarningDialogOpen(false)} color="inherit">
              Annuler
            </Button>
            <Button
              onClick={handleSendWarning}
              variant="contained"
              color="warning"
              disabled={!warningMessage.trim() || busyUserId === warningTargetUser?.id}
            >
              Envoyer
            </Button>
          </DialogActions>
        </Dialog>
      </Stack>
    </DashboardContent>
  );
}
