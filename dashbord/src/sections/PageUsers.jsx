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

import { DashboardContent } from 'src/layouts/dashboard';
import { useSearchParams } from 'src/routes/hooks';
import {
  getUsers,
  deleteUser,
  getUserById,
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
  { id: 'statutOrganisateur', label: 'Statut organisateur' },
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
  const searchParams = useSearchParams();
  const selectedUserIdFromQuery = searchParams.get('userId') ?? '';

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [users, setUsers] = useState([]);
  const [busyUserId, setBusyUserId] = useState('');
  const [detailsOpen, setDetailsOpen] = useState(false);
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
  const [openedFromQueryUserId, setOpenedFromQueryUserId] = useState('');

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

  useEffect(() => {
    if (!selectedUserIdFromQuery) return;
    if (loading) return;
    if (openedFromQueryUserId === selectedUserIdFromQuery) return;

    setOpenedFromQueryUserId(selectedUserIdFromQuery);
    handleViewDetails(selectedUserIdFromQuery);
  }, [handleViewDetails, loading, openedFromQueryUserId, selectedUserIdFromQuery]);

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
                          <TableCell>{user.statutOrganisateur}</TableCell>
                          <TableCell>
                            {user.dateInscription
                              ? new Date(user.dateInscription).toLocaleDateString('fr-FR')
                              : '-'}
                          </TableCell>
                          <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                            <Tooltip title="Voir détails">
                              <span>
                                <IconButton
                                  color="info"
                                  onClick={() => handleViewDetails(user.id)}
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

        <Dialog open={detailsOpen} onClose={() => setDetailsOpen(false)} fullWidth maxWidth="sm">
          <DialogTitle>Détails utilisateur</DialogTitle>
          <DialogContent dividers>
            <Stack spacing={1.25}>
              <Typography variant="body2">
                <strong>Nom:</strong> {selectedUser?.fullname ?? '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Email:</strong> {selectedUser?.email ?? '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Rôle:</strong> {selectedUser?.role ?? '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Statut compte:</strong> {selectedUser?.status ?? '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Suspendu jusqu au:</strong>{' '}
                {selectedUser?.suspendedUntil
                  ? new Date(selectedUser.suspendedUntil).toLocaleString('fr-FR')
                  : '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Statut organisateur:</strong> {selectedUser?.statutOrganisateur ?? '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Téléphone:</strong> {selectedUser?.numTel ?? '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Age:</strong> {selectedUser?.age ?? '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Bio:</strong> {selectedUser?.bio ?? '-'}
              </Typography>
            </Stack>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setDetailsOpen(false)} color="inherit">
              Fermer
            </Button>
            <Button
              color="inherit"
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
              onClick={() => handleDeleteUser(selectedUser)}
              disabled={
                !selectedUser || selectedUser.role === 'admin' || busyUserId === selectedUser.id
              }
            >
              Supprimer
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
