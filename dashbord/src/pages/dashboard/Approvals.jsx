import { useState, useEffect, useCallback, useMemo } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Paper from '@mui/material/Paper';
import Stack from '@mui/material/Stack';
import Table from '@mui/material/Table';
import Button from '@mui/material/Button';
import Dialog from '@mui/material/Dialog';
import Tooltip from '@mui/material/Tooltip';
import MenuItem from '@mui/material/MenuItem';
import TableRow from '@mui/material/TableRow';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import TextField from '@mui/material/TextField';
import IconButton from '@mui/material/IconButton';
import Typography from '@mui/material/Typography';
import DialogTitle from '@mui/material/DialogTitle';
import DialogActions from '@mui/material/DialogActions';
import DialogContent from '@mui/material/DialogContent';
import TableContainer from '@mui/material/TableContainer';
import Grid from '@mui/material/Grid';

import { DashboardContent } from 'src/layouts/dashboard';
import { onboardingService } from 'src/services/onboardingService';

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
  TablePaginationCustom,
} from 'src/components/table';

const TABLE_HEAD = [
  { id: 'fullname', label: 'Nom complet' },
  { id: 'email', label: 'Email' },
  { id: 'signup_method', label: "Méthode d'inscription" },
  { id: 'country', label: 'Pays' },
  { id: 'submitted_for_approval', label: 'Soumis le' },
  { id: 'wait_days', label: "Jours d'attente" },
  { id: 'actions', label: 'Actions', align: 'right' },
];

const flattenObject = (obj, prefix = '') => {
  if (!obj) return {};
  return Object.keys(obj).reduce((acc, k) => {
    const pre = prefix.length ? prefix + '.' : '';
    if (typeof obj[k] === 'object' && obj[k] !== null && !Array.isArray(obj[k])) {
      Object.assign(acc, flattenObject(obj[k], pre + k));
    } else {
      acc[pre + k] = Array.isArray(obj[k]) ? JSON.stringify(obj[k]) : obj[k];
    }
    return acc;
  }, {});
};

function normalizeApproval(org) {
  return {
    id: org?._id || org?.id,
    fullname: org?.fullname || '-',
    email: org?.email || '-',
    signup_method: org?.signup_method || 'email',
    country: org?.country || '-',
    submitted_for_approval: org?.onboarding_status?.submitted_at || org?.createdAt || null,
    wait_days: org?.onboarding_status?.wait_days || 0,
    phone:
      org?.phone ||
      org?.num_tel ||
      org?.onboarding_data?.phone ||
      org?.onboarding_data?.num_tel ||
      org?.onboarding_data?.phoneNumber ||
      '—',
    language:
      org?.language ||
      org?.langue_preferee ||
      org?.preferred_language ||
      org?.onboarding_data?.language ||
      org?.onboarding_data?.langue_preferee ||
      org?.onboarding_data?.preferred_language ||
      '—',
    description: org?.description || org?.onboarding_data?.description || '',
    experience: org?.experience || org?.onboarding_data?.experience || '',
    website: org?.website || org?.onboarding_data?.website || '',
    raw: org,
  };
}

function statusColor(waitDays) {
  if (waitDays > 7) return 'error';
  if (waitDays > 3) return 'warning';
  return 'info';
}

export default function ApprovalsPage() {
  const table = useTable();
  const [organizers, setOrganizers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [signupMethodFilter, setSignupMethodFilter] = useState('all');

  const [selectedOrg, setSelectedOrg] = useState(null);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [confirmApproveOpen, setConfirmApproveOpen] = useState(false);
  const [rejectOpen, setRejectOpen] = useState(false);
  const [rejectionReason, setRejectionReason] = useState('');

  const loadApprovals = useCallback(async () => {
    try {
      setLoading(true);
      const data = await onboardingService.getPendingApprovals();
      const rows = Array.isArray(data) ? data : (data?.organizers || []);
      setOrganizers(rows.map(normalizeApproval));
    } catch (err) {
      toast.error('Erreur lors du chargement des approbations');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadApprovals();
  }, [loadApprovals]);

  const handleApprove = useCallback(async () => {
    try {
      if (!selectedOrg) return;
      await onboardingService.approveOrganizer(selectedOrg.id);
      toast.success('Organisateur approuvé');
      setConfirmApproveOpen(false);
      loadApprovals();
    } catch (err) {
      toast.error("Erreur lors de l'approbation");
    }
  }, [selectedOrg, loadApprovals]);

  const handleReject = useCallback(async () => {
    try {
      if (!selectedOrg) return;
      if (!rejectionReason.trim()) {
        toast.warning('Veuillez saisir une raison de rejet');
        return;
      }
      await onboardingService.rejectOrganizer(selectedOrg.id, rejectionReason);
      toast.success('Organisateur rejeté');
      setRejectOpen(false);
      setRejectionReason('');
      loadApprovals();
    } catch (err) {
      toast.error('Erreur lors du rejet');
    }
  }, [selectedOrg, rejectionReason, loadApprovals]);

  const dataFiltered = useMemo(() => {
    const comparator = getComparator(table.order, table.orderBy);
    const stabilized = organizers.map((el, idx) => [el, idx]);
    stabilized.sort((a, b) => {
      const order = comparator(a[0], b[0]);
      if (order !== 0) return order;
      return a[1] - b[1];
    });

    let data = stabilized.map((el) => el[0]);

    if (searchQuery) {
      const query = searchQuery.toLowerCase();
      data = data.filter((row) => row.fullname.toLowerCase().includes(query) || row.email.toLowerCase().includes(query));
    }

    if (signupMethodFilter !== 'all') {
      data = data.filter((row) => row.signup_method === signupMethodFilter);
    }

    return data;
  }, [organizers, searchQuery, signupMethodFilter, table.order, table.orderBy]);

  return (
    <DashboardContent maxWidth="xl">
      <Typography variant="h4" sx={{ mb: { xs: 3, md: 5 } }}>
        Approbations en attente
      </Typography>

      <Stack spacing={3}>
        <Card sx={{ p: 2.5 }}>
          <Stack direction={{ xs: 'column', md: 'row' }} spacing={2}>
            <TextField
              fullWidth
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="Rechercher par nom ou email..."
              InputProps={{
                startAdornment: <Iconify icon="eva:search-fill" sx={{ color: 'text.disabled', mr: 1 }} />,
              }}
            />
            <TextField
              select
              label="Méthode d'inscription"
              value={signupMethodFilter}
              onChange={(e) => setSignupMethodFilter(e.target.value)}
              sx={{ minWidth: 200 }}
            >
              <MenuItem value="all">Toutes</MenuItem>
              <MenuItem value="email">Email</MenuItem>
              <MenuItem value="google">Google</MenuItem>
              <MenuItem value="facebook">Facebook</MenuItem>
            </TextField>
          </Stack>
        </Card>

        <Card>
          <Scrollbar>
            <TableContainer component={Paper}>
              <Table size={table.dense ? 'small' : 'medium'}>
                <TableHeadCustom
                  order={table.order}
                  orderBy={table.orderBy}
                  onSort={table.onSort}
                  headCells={TABLE_HEAD}
                  rowCount={dataFiltered.length}
                />

                <TableBody>
                  {rowInPage(dataFiltered, table.page, table.rowsPerPage).map((row) => (
                    <TableRow key={row.id} hover>
                      <TableCell>{row.fullname}</TableCell>
                      <TableCell>{row.email}</TableCell>
                      <TableCell>
                        <Label color="default">{row.signup_method}</Label>
                      </TableCell>
                      <TableCell>{row.country}</TableCell>
                      <TableCell>{row.submitted_for_approval ? new Date(row.submitted_for_approval).toLocaleDateString() : '-'}</TableCell>
                      <TableCell>
                        <Label color={statusColor(row.wait_days)}>{row.wait_days} jours</Label>
                      </TableCell>
                      <TableCell align="right">
                        <Tooltip title="Voir détails">
                          <IconButton
                            onClick={() => {
                              setSelectedOrg(row);
                              setDetailsOpen(true);
                            }}
                          >
                            <Iconify icon="eva:eye-fill" />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Approuver">
                          <IconButton
                            color="success"
                            onClick={() => {
                              setSelectedOrg(row);
                              setConfirmApproveOpen(true);
                            }}
                          >
                            <Iconify icon="eva:checkmark-circle-2-fill" />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Rejeter">
                          <IconButton
                            color="error"
                            onClick={() => {
                              setSelectedOrg(row);
                              setRejectOpen(true);
                            }}
                          >
                            <Iconify icon="eva:close-circle-fill" />
                          </IconButton>
                        </Tooltip>
                      </TableCell>
                    </TableRow>
                  ))}

                  <TableEmptyRows
                    height={table.dense ? 56 : 76}
                    emptyRows={emptyRows(table.page, table.rowsPerPage, dataFiltered.length)}
                  />
                </TableBody>
              </Table>
            </TableContainer>
          </Scrollbar>

          <Box sx={{ p: 2 }}>
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
        </Card>
      </Stack>

      <Dialog open={detailsOpen} onClose={() => setDetailsOpen(false)} fullWidth maxWidth="sm">
        <DialogTitle>Détails de l'organisateur</DialogTitle>
        <DialogContent dividers>
          <Stack spacing={2}>
            <Typography variant="subtitle2">
              Nom: <Typography variant="body2" component="span">{selectedOrg?.fullname}</Typography>
            </Typography>
            <Typography variant="subtitle2">
              Email: <Typography variant="body2" component="span">{selectedOrg?.email}</Typography>
            </Typography>
            <Typography variant="subtitle2">
              Pays: <Typography variant="body2" component="span">{selectedOrg?.country}</Typography>
            </Typography>
            <Typography variant="subtitle2">
              Téléphone: <Typography variant="body2" component="span">{selectedOrg?.phone}</Typography>
            </Typography>
            <Typography variant="subtitle2">
              Langue: <Typography variant="body2" component="span">{selectedOrg?.language}</Typography>
            </Typography>
            {selectedOrg?.website ? (
              <Typography variant="subtitle2">
                Site: <Typography variant="body2" component="a" href={selectedOrg.website} target="_blank" rel="noreferrer">{selectedOrg.website}</Typography>
              </Typography>
            ) : null}
            {selectedOrg?.description ? (
              <Typography variant="subtitle2">
                Description: <Typography variant="body2" component="span">{selectedOrg.description}</Typography>
              </Typography>
            ) : null}
            {selectedOrg?.experience ? (
              <Typography variant="subtitle2">
                Expérience: <Typography variant="body2" component="span">{selectedOrg.experience}</Typography>
              </Typography>
            ) : null}

            <Box sx={{ mt: 3, pt: 2, borderTop: '1px dashed', borderColor: 'divider' }}>
              <Typography variant="subtitle1" sx={{ mb: 2, fontWeight: 700 }}>
                Données Brutes (Toutes les informations)
              </Typography>
              <Box sx={{ maxHeight: 400, overflow: 'auto', p: 1 }}>
                <Grid container spacing={2}>
                  {Object.entries(flattenObject(selectedOrg?.raw || {})).map(([key, value]) => (
                    <Grid item xs={12} sm={6} key={key}>
                      <TextField
                        fullWidth
                        label={key}
                        value={String(value ?? '—')}
                        InputProps={{ readOnly: true }}
                        variant="filled"
                        size="small"
                        multiline={String(value).length > 50}
                        maxRows={4}
                      />
                    </Grid>
                  ))}
                </Grid>
              </Box>
            </Box>
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDetailsOpen(false)}>Fermer</Button>
        </DialogActions>
      </Dialog>

      <Dialog open={confirmApproveOpen} onClose={() => setConfirmApproveOpen(false)}>
        <DialogTitle>Confirmer l'approbation</DialogTitle>
        <DialogContent>
          Êtes-vous sûr de vouloir approuver <b>{selectedOrg?.fullname}</b> ?
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setConfirmApproveOpen(false)}>Annuler</Button>
          <Button variant="contained" color="success" onClick={handleApprove}>Approuver</Button>
        </DialogActions>
      </Dialog>

      <Dialog open={rejectOpen} onClose={() => setRejectOpen(false)} fullWidth maxWidth="xs">
        <DialogTitle>Rejeter l'organisateur</DialogTitle>
        <DialogContent>
          <Typography sx={{ mb: 2 }}>
            Veuillez indiquer la raison du rejet pour <b>{selectedOrg?.fullname}</b> :
          </Typography>
          <TextField
            fullWidth
            multiline
            rows={3}
            value={rejectionReason}
            onChange={(e) => setRejectionReason(e.target.value)}
            placeholder="Ex: Documents incomplets, informations invalides..."
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setRejectOpen(false)}>Annuler</Button>
          <Button variant="contained" color="error" onClick={handleReject}>Rejeter</Button>
        </DialogActions>
      </Dialog>
    </DashboardContent>
  );
}
