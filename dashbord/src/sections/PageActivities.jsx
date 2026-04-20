import { useSetState } from 'minimal-shared/hooks';
import { useMemo, useState, useEffect, useCallback } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Chip from '@mui/material/Chip';
import Avatar from '@mui/material/Avatar';
import Stack from '@mui/material/Stack';
import Table from '@mui/material/Table';
import Dialog from '@mui/material/Dialog';
import Button from '@mui/material/Button';
import Tooltip from '@mui/material/Tooltip';
import Divider from '@mui/material/Divider';
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
import {
  getActivitesAdmin,
  createActiviteAdmin,
  deleteActiviteAdmin,
} from 'src/Controller/actions';

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
  { id: 'titre', label: 'Titre' },
  { id: 'organisateur', label: 'Organisateur' },
  { id: 'lieu', label: 'Lieu' },
  { id: 'prix', label: 'Prix' },
  { id: 'statut', label: 'Statut' },
  { id: 'date_debut', label: 'Début' },
  { id: 'actions', label: '', align: 'right' },
];

const TYPE_OPTIONS = ['Guided Tour', 'Excursion', 'Hiking', 'Adventure', 'Culture', 'Gastronomy', 'Sport', 'Other'];
const DIFFICULTY_OPTIONS = ['Easy', 'Moderate', 'Difficult', 'Expert'];
const STATUS_OPTIONS = ['active', 'inactive', 'archived', 'completed'];

function mapActivity(item) {
  return {
    id: item?._id ?? item?.id,
    titre: item?.titre ?? '',
    description: item?.description ?? '',
    type_activite: item?.type_activite ?? 'Other',
    categorie: item?.categorie ?? 'Other',
    organisateur_id: item?.organisateur_id?._id ?? item?.organisateur_id ?? '',
    organisateur_name: item?.organisateur_id?.fullname ?? '-',
    lieu: item?.lieu ?? '',
    duree: item?.duree ?? 0,
    prix: item?.prix ?? 0,
    capacite_max: item?.capacite_max ?? 1,
    niveau_difficulte: item?.niveau_difficulte ?? 'Easy',
    statut: item?.statut ?? 'active',
    date_debut: item?.date_debut ?? null,
    date_fin: item?.date_fin ?? null,
    photos: Array.isArray(item?.photos) ? item.photos : [],
    createdAt: item?.createdAt ?? null,
    updatedAt: item?.updatedAt ?? null,
  };
}

function formatDate(value) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return date.toLocaleString('fr-FR');
}

function getInitial(value) {
  return String(value || '?').trim().charAt(0).toUpperCase();
}

function statusColor(status) {
  const normalized = String(status || '').toLowerCase();
  if (normalized === 'active') return 'success';
  if (normalized === 'inactive') return 'warning';
  if (normalized === 'archived') return 'default';
  if (normalized === 'completed') return 'info';
  return 'default';
}

function difficultyColor(value) {
  const normalized = String(value || '').toLowerCase();
  if (normalized === 'easy') return 'success';
  if (normalized === 'moderate') return 'info';
  if (normalized === 'difficult') return 'warning';
  if (normalized === 'expert') return 'error';
  return 'default';
}

function applyFilter({ inputData, comparator, filters }) {
  const { query, type, status } = filters;

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
      (row) =>
        row.titre.toLowerCase().includes(q) ||
        row.lieu.toLowerCase().includes(q) ||
        row.organisateur_name.toLowerCase().includes(q)
    );
  }

  if (type !== 'all') {
    data = data.filter((row) => row.type_activite === type);
  }

  if (status !== 'all') {
    data = data.filter((row) => row.statut === status);
  }

  return data;
}

export function ActivitiesView({ sx }) {
  const table = useTable({ defaultOrderBy: 'date_debut' });

  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [rows, setRows] = useState([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [openDetailsDialog, setOpenDetailsDialog] = useState(false);
  const [detailsRow, setDetailsRow] = useState(null);
  const [form, setForm] = useState({
    titre: '',
    description: '',
    type_activite: 'Other',
    categorie: 'Other',
    organisateur_id: '',
    lieu: '',
    duree: '1',
    prix: '0',
    capacite_max: '1',
    niveau_difficulte: 'Easy',
    statut: 'active',
    date_debut: '',
    date_fin: '',
    photos: '',
  });

  const filters = useSetState({
    query: '',
    type: 'all',
    status: 'all',
  });
  const { state: currentFilters, setState: updateFilters } = filters;

  const loadRows = useCallback(async () => {
    try {
      setLoading(true);
      setError('');
      const activites = await getActivitesAdmin();
      setRows(activites.map(mapActivity));
    } catch {
      setError('Erreur lors du chargement des activités');
      toast.error('Impossible de charger les activités');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadRows();
  }, [loadRows]);

  const filteredRows = useMemo(
    () =>
      applyFilter({
        inputData: rows,
        comparator: getComparator(table.order, table.orderBy),
        filters: currentFilters,
      }),
    [currentFilters, rows, table.order, table.orderBy]
  );

  const dataInPage = rowInPage(filteredRows, table.page, table.rowsPerPage);
  const notFound = filteredRows.length === 0;
  const canReset =
    currentFilters.query.trim() !== '' || currentFilters.type !== 'all' || currentFilters.status !== 'all';

  const handleFilterQuery = useCallback(
    (event) => {
      table.onResetPage();
      updateFilters({ query: event.target.value });
    },
    [table, updateFilters]
  );

  const handleFilterType = useCallback(
    (event) => {
      table.onResetPage();
      updateFilters({ type: event.target.value });
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
    updateFilters({ query: '', type: 'all', status: 'all' });
  }, [table, updateFilters]);

  const openCreateDialog = useCallback(() => {
    setForm({
      titre: '',
      description: '',
      type_activite: 'Other',
      categorie: 'Other',
      organisateur_id: '',
      lieu: '',
      duree: '1',
      prix: '0',
      capacite_max: '1',
      niveau_difficulte: 'Easy',
      statut: 'active',
      date_debut: '',
      date_fin: '',
      photos: '',
    });
    setOpenDialog(true);
  }, []);

  const closeDialog = useCallback(() => {
    if (submitting) return;
    setOpenDialog(false);
  }, [submitting]);

  const openDetails = useCallback((row) => {
    setDetailsRow(row);
    setOpenDetailsDialog(true);
  }, []);

  const closeDetails = useCallback(() => {
    setOpenDetailsDialog(false);
    setDetailsRow(null);
  }, []);

  const handleChangeForm = useCallback((field, value) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  }, []);

  const handleSubmit = useCallback(async () => {
    if (!form.titre.trim() || !form.description.trim() || !form.lieu.trim()) {
      toast.error('Titre, description et lieu sont obligatoires');
      return;
    }

    if (!form.organisateur_id.trim()) {
      toast.error('organisateur_id est obligatoire');
      return;
    }

    if (!form.date_debut || !form.date_fin) {
      toast.error('Date début et date fin sont obligatoires');
      return;
    }

    const payload = {
      titre: form.titre.trim(),
      description: form.description.trim(),
      type_activite: form.type_activite,
      categorie: form.categorie.trim() || 'Other',
      organisateur_id: form.organisateur_id.trim(),
      lieu: form.lieu.trim(),
      duree: Number(form.duree),
      prix: Number(form.prix),
      capacite_max: Number(form.capacite_max),
      niveau_difficulte: form.niveau_difficulte,
      statut: form.statut,
      date_debut: new Date(form.date_debut).toISOString(),
      date_fin: new Date(form.date_fin).toISOString(),
      photos: form.photos
        .split(/\r?\n|,/)
        .map((item) => item.trim())
        .filter(Boolean),
    };

    try {
      setSubmitting(true);
      await createActiviteAdmin(payload);
      toast.success('Activité créée');
      setOpenDialog(false);
      await loadRows();
    } catch {
      toast.error('Échec de sauvegarde de l\'activité');
    } finally {
      setSubmitting(false);
    }
  }, [form, loadRows]);

  const handleDelete = useCallback(
    async (row) => {
      const confirmed = window.confirm('Supprimer cette activité ?');
      if (!confirmed) return;

      try {
        await deleteActiviteAdmin(row.id);
        toast.success('Activité supprimée');
        await loadRows();
      } catch {
        toast.error('Échec de suppression de l\'activité');
      }
    },
    [loadRows]
  );

  return (
    <DashboardContent maxWidth="xl" sx={sx}>
      <Stack spacing={2}>
        <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} justifyContent="space-between">
          <Typography variant="h4">Activités</Typography>
          <Button variant="contained" onClick={openCreateDialog}>
            Nouvelle activité
          </Button>
        </Stack>

        <Card sx={{ p: 2 }}>
            <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} sx={{ p: 2 }}>
              <TextField
                fullWidth
                value={currentFilters.query}
                onChange={handleFilterQuery}
                placeholder="Rechercher par titre, lieu ou organisateur..."
              />
              <TextField
                select
                value={currentFilters.type}
                onChange={handleFilterType}
                label="Type"
                sx={{ minWidth: 180 }}
              >
                <MenuItem value="all">Tous les types</MenuItem>
                {Array.from(new Set(rows.map((item) => item.type_activite).filter(Boolean))).map((type) => (
                  <MenuItem key={type} value={type}>
                    {type}
                  </MenuItem>
                ))}
              </TextField>
              <TextField
                select
                value={currentFilters.status}
                onChange={handleFilterStatus}
                label="Statut"
                sx={{ minWidth: 180 }}
              >
                <MenuItem value="all">Tous</MenuItem>
                <MenuItem value="active">active</MenuItem>
                <MenuItem value="inactive">inactive</MenuItem>
                <MenuItem value="archived">archived</MenuItem>
                <MenuItem value="completed">completed</MenuItem>
              </TextField>
              {canReset && (
                <Button color="inherit" onClick={handleResetFilters} startIcon={<Iconify icon="solar:restart-bold" />}>
                  Reinitialiser
                </Button>
              )}
            </Stack>
        </Card>

        <Card>
          {loading ? (
            <Stack alignItems="center" justifyContent="center" sx={{ py: 8 }}>
              <CircularProgress />
            </Stack>
          ) : (
            <>
              {!!error && (
                <Box sx={{ p: 2 }}>
                  <Typography color="error.main">{error}</Typography>
                </Box>
              )}

              <Scrollbar>
                <TableContainer>
                  <Table>
                    <TableHeadCustom
                      order={table.order}
                      orderBy={table.orderBy}
                      headCells={TABLE_HEAD}
                      onSort={table.onSort}
                    />
                    <TableBody>
                      {dataInPage.map((row) => (
                        <TableRow key={row.id} hover>
                          <TableCell>{row.titre}</TableCell>
                          <TableCell>{row.organisateur_name}</TableCell>
                          <TableCell>{row.lieu}</TableCell>
                          <TableCell>{row.prix}</TableCell>
                          <TableCell>
                            <Chip size="small" label={row.statut} />
                          </TableCell>
                          <TableCell>{formatDate(row.date_debut)}</TableCell>
                          <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                            <Tooltip title="Voir détails">
                              <IconButton color="info" onClick={() => openDetails(row)}>
                                <Iconify icon="solar:eye-bold" />
                              </IconButton>
                            </Tooltip>
                            <Tooltip title="Supprimer">
                              <IconButton color="error" onClick={() => handleDelete(row)}>
                                <Iconify icon="solar:trash-bin-trash-bold" />
                              </IconButton>
                            </Tooltip>
                          </TableCell>
                        </TableRow>
                      ))}

                      <TableEmptyRows
                        height={table.dense ? 56 : 76}
                        emptyRows={emptyRows(table.page, table.rowsPerPage, filteredRows.length)}
                      />

                      {notFound ? (
                        <TableRow>
                          <TableCell colSpan={7} align="center">
                            Aucune activité trouvée
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
                count={filteredRows.length}
                rowsPerPage={table.rowsPerPage}
                onPageChange={table.onChangePage}
                onChangeDense={table.onChangeDense}
                onRowsPerPageChange={table.onChangeRowsPerPage}
              />
            </>
          )}
        </Card>

        <Dialog open={openDialog} onClose={closeDialog} fullWidth maxWidth="sm">
          <DialogTitle>Créer activité</DialogTitle>
          <DialogContent dividers>
            <Stack spacing={2}>
              <TextField
                label="Titre"
                value={form.titre}
                onChange={(event) => handleChangeForm('titre', event.target.value)}
              />

              <TextField
                multiline
                minRows={4}
                label="Description"
                value={form.description}
                onChange={(event) => handleChangeForm('description', event.target.value)}
              />

              <TextField
                label="organisateur_id"
                placeholder="ObjectId organisateur"
                value={form.organisateur_id}
                onChange={(event) => handleChangeForm('organisateur_id', event.target.value)}
              />

              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
                <TextField
                  select
                  label="Type"
                  value={form.type_activite}
                  onChange={(event) => handleChangeForm('type_activite', event.target.value)}
                  fullWidth
                >
                  {TYPE_OPTIONS.map((option) => (
                    <MenuItem key={option} value={option}>
                      {option}
                    </MenuItem>
                  ))}
                </TextField>
                <TextField
                  select
                  label="Difficulté"
                  value={form.niveau_difficulte}
                  onChange={(event) => handleChangeForm('niveau_difficulte', event.target.value)}
                  fullWidth
                >
                  {DIFFICULTY_OPTIONS.map((option) => (
                    <MenuItem key={option} value={option}>
                      {option}
                    </MenuItem>
                  ))}
                </TextField>
              </Stack>

              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
                <TextField
                  label="Catégorie"
                  value={form.categorie}
                  onChange={(event) => handleChangeForm('categorie', event.target.value)}
                  fullWidth
                />
                <TextField
                  select
                  label="Statut"
                  value={form.statut}
                  onChange={(event) => handleChangeForm('statut', event.target.value)}
                  fullWidth
                >
                  {STATUS_OPTIONS.map((option) => (
                    <MenuItem key={option} value={option}>
                      {option}
                    </MenuItem>
                  ))}
                </TextField>
              </Stack>

              <TextField
                label="Lieu"
                value={form.lieu}
                onChange={(event) => handleChangeForm('lieu', event.target.value)}
              />

              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
                <TextField
                  type="number"
                  label="Durée (h)"
                  value={form.duree}
                  onChange={(event) => handleChangeForm('duree', event.target.value)}
                  fullWidth
                />
                <TextField
                  type="number"
                  label="Prix"
                  value={form.prix}
                  onChange={(event) => handleChangeForm('prix', event.target.value)}
                  fullWidth
                />
                <TextField
                  type="number"
                  label="Capacité"
                  value={form.capacite_max}
                  onChange={(event) => handleChangeForm('capacite_max', event.target.value)}
                  fullWidth
                />
              </Stack>

              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
                <TextField
                  type="datetime-local"
                  label="Date début"
                  value={form.date_debut}
                  onChange={(event) => handleChangeForm('date_debut', event.target.value)}
                  fullWidth
                  InputLabelProps={{ shrink: true }}
                />
                <TextField
                  type="datetime-local"
                  label="Date fin"
                  value={form.date_fin}
                  onChange={(event) => handleChangeForm('date_fin', event.target.value)}
                  fullWidth
                  InputLabelProps={{ shrink: true }}
                />
              </Stack>

              <TextField
                multiline
                minRows={3}
                label="Photos URLs (une par ligne)"
                value={form.photos}
                onChange={(event) => handleChangeForm('photos', event.target.value)}
              />
            </Stack>
          </DialogContent>
          <DialogActions>
            <Button color="inherit" onClick={closeDialog} disabled={submitting}>
              Annuler
            </Button>
            <Button variant="contained" onClick={handleSubmit} disabled={submitting}>
              Créer
            </Button>
          </DialogActions>
        </Dialog>

        <Dialog open={openDetailsDialog} onClose={closeDetails} fullWidth maxWidth="lg">
          <DialogTitle sx={{ pb: 1.5 }}>
            <Stack
              direction={{ xs: 'column', md: 'row' }}
              spacing={1.5}
              justifyContent="space-between"
              alignItems={{ md: 'center' }}
            >
              <Stack direction="row" spacing={1.25} alignItems="center">
                <Avatar
                  sx={{
                    width: 40,
                    height: 40,
                    bgcolor: 'primary.main',
                  }}
                >
                  <Iconify icon="solar:map-point-bold" width={20} />
                </Avatar>
                <Box>
                  <Typography variant="h6">Détails activité</Typography>
                  <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                    Vue complète de l’activité et de ses informations clés
                  </Typography>
                </Box>
              </Stack>

              <Stack direction="row" spacing={1} flexWrap="wrap">
                <Chip size="small" color="primary" variant="soft" label={detailsRow?.type_activite ?? '-'} />
                <Chip size="small" color={statusColor(detailsRow?.statut)} variant="soft" label={detailsRow?.statut ?? '-'} />
                <Chip size="small" color={difficultyColor(detailsRow?.niveau_difficulte)} variant="soft" label={detailsRow?.niveau_difficulte ?? '-'} />
                <Chip size="small" color="info" variant="soft" label={`${detailsRow?.prix ?? 0} DT`} />
              </Stack>
            </Stack>
          </DialogTitle>

          <DialogContent dividers sx={{ pt: 2 }}>
            <Stack spacing={2.5}>
              {(detailsRow?.photos ?? []).length > 0 ? (
                <Box
                  sx={{
                    borderRadius: 2,
                    overflow: 'hidden',
                    border: '1px solid',
                    borderColor: 'divider',
                    bgcolor: 'background.neutral',
                  }}
                >
                  <Box
                    component="img"
                    src={detailsRow?.photos?.[0]}
                    alt="Activity cover"
                    sx={{ width: '100%', height: { xs: 180, md: 240 }, objectFit: 'cover' }}
                  />
                </Box>
              ) : null}

              <Card
                variant="outlined"
                sx={{
                  p: 2,
                  borderRadius: 2,
                  background: (theme) =>
                    `linear-gradient(135deg, ${theme.palette.primary.main}12 0%, ${theme.palette.info.main}10 100%)`,
                }}
              >
                <Stack
                  direction={{ xs: 'column', md: 'row' }}
                  spacing={1.5}
                  justifyContent="space-between"
                  alignItems={{ md: 'center' }}
                >
                  <Box>
                    <Typography variant="subtitle2" sx={{ color: 'text.secondary' }}>
                      Titre
                    </Typography>
                    <Typography variant="h5" sx={{ fontWeight: 700 }}>
                      {detailsRow?.titre ?? '-'}
                    </Typography>
                    <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                      Créée le {formatDate(detailsRow?.createdAt)} • modifiée le {formatDate(detailsRow?.updatedAt)}
                    </Typography>
                  </Box>

                  <Stack direction="row" spacing={1} flexWrap="wrap">
                    <Chip size="small" color="success" variant="soft" label={`Durée: ${detailsRow?.duree ?? '-'} h`} />
                    <Chip size="small" color="warning" variant="soft" label={`Capacité: ${detailsRow?.capacite_max ?? '-'}`} />
                  </Stack>
                </Stack>
              </Card>

              <Box
                sx={{
                  display: 'grid',
                  gap: 1.5,
                  gridTemplateColumns: { xs: '1fr', md: 'repeat(3, minmax(0, 1fr))' },
                }}
              >
                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Organisateur
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {detailsRow?.organisateur_name ?? '-'}
                  </Typography>
                </Card>

                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Lieu
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {detailsRow?.lieu ?? '-'}
                  </Typography>
                </Card>

                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Prix
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {detailsRow?.prix ?? '-'} DT
                  </Typography>
                </Card>

                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Type
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {detailsRow?.type_activite ?? '-'}
                  </Typography>
                </Card>

                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Catégorie
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {detailsRow?.categorie ?? '-'}
                  </Typography>
                </Card>

                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Difficulte
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {detailsRow?.niveau_difficulte ?? '-'}
                  </Typography>
                </Card>
              </Box>

              <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                <Typography variant="subtitle2" sx={{ mb: 0.75 }}>
                  Description
                </Typography>
                <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap', lineHeight: 1.7 }}>
                  {detailsRow?.description ?? '-'}
                </Typography>
              </Card>

              <Box
                sx={{
                  display: 'grid',
                  gap: 1.5,
                  gridTemplateColumns: { xs: '1fr', md: 'repeat(2, minmax(0, 1fr))' },
                }}
              >
                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Date début
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {formatDate(detailsRow?.date_debut)}
                  </Typography>
                </Card>

                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Date fin
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {formatDate(detailsRow?.date_fin)}
                  </Typography>
                </Card>
              </Box>

              <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                <Typography variant="subtitle2" sx={{ mb: 1 }}>
                  Photos
                </Typography>
                {(detailsRow?.photos ?? []).length ? (
                  <Box
                    sx={{
                      display: 'grid',
                      gap: 1,
                      gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, minmax(0, 1fr))' },
                    }}
                  >
                    {detailsRow.photos.map((url, index) => (
                      <Box
                        key={url}
                        sx={{ border: '1px solid', borderColor: 'divider', borderRadius: 1.5, p: 1 }}
                      >
                        <Box
                          component="img"
                          src={url}
                          alt={`Activity ${index + 1}`}
                          sx={{ width: '100%', height: 160, objectFit: 'cover', borderRadius: 1 }}
                        />
                        <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 1 }} noWrap>
                          {url}
                        </Typography>
                      </Box>
                    ))}
                  </Box>
                ) : (
                  <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                    Aucune photo
                  </Typography>
                )}
              </Card>

              <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                <Typography variant="subtitle2" sx={{ mb: 0.75 }}>
                  Informations techniques
                </Typography>
                <Stack spacing={0.75} divider={<Divider flexItem />}>
                  <Stack direction="row" justifyContent="space-between" spacing={2}>
                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>organisateur_id</Typography>
                    <Typography variant="body2" sx={{ fontWeight: 600 }} noWrap>
                      {detailsRow?.organisateur_id ?? '-'}
                    </Typography>
                  </Stack>
                  <Stack direction="row" justifyContent="space-between" spacing={2}>
                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>Capacité max</Typography>
                    <Typography variant="body2" sx={{ fontWeight: 600 }}>
                      {detailsRow?.capacite_max ?? '-'}
                    </Typography>
                  </Stack>
                </Stack>
              </Card>
            </Stack>
          </DialogContent>
          <DialogActions>
            <Button onClick={closeDetails} color="inherit">
              Fermer
            </Button>
          </DialogActions>
        </Dialog>
      </Stack>
    </DashboardContent>
  );
}
