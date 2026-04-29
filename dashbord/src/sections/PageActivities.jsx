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
  getActivityParticipants,
  getUserById,
  getUserReviews,
  getUserPosts,
  deleteReview,
  getPostComments,
  deleteComment,
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
  const [participants, setParticipants] = useState([]);
  const [loadingParticipants, setLoadingParticipants] = useState(false);
  const [userProfileOpen, setUserProfileOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);
  const [loadingUser, setLoadingUser] = useState(false);
  const [userActivities, setUserActivities] = useState([]);
  const [userReviews, setUserReviews] = useState([]);
  const [userPosts, setUserPosts] = useState([]);
  const [loadingUserDetails, setLoadingUserDetails] = useState(false);
  const [expandedPosts, setExpandedPosts] = useState(new Set());
  const [postComments, setPostComments] = useState({});
  const [loadingPostComments, setLoadingPostComments] = useState(new Set());
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

  const openDetails = useCallback(async (row) => {
    setDetailsRow(row);
    setOpenDetailsDialog(true);
    setLoadingParticipants(true);
    try {
      const participantsData = await getActivityParticipants(row.id);
      setParticipants(participantsData);
    } catch {
      toast.error('Erreur lors du chargement des participants');
      setParticipants([]);
    } finally {
      setLoadingParticipants(false);
    }
  }, []);

  const closeDetails = useCallback(() => {
    setOpenDetailsDialog(false);
    setDetailsRow(null);
  }, []);

  const handleOpenUserProfile = useCallback(async (userId) => {
    if (!userId) return;
    setLoadingUser(true);
    setLoadingUserDetails(true);
    try {
      const user = await getUserById(userId);
      setSelectedUser(user);
      setUserProfileOpen(true);

      // Fetch user reviews and posts in parallel
      const [reviews, posts] = await Promise.all([
        getUserReviews(userId),
        getUserPosts(userId),
      ]);

      setUserReviews(reviews);
      setUserPosts(posts);

      // For activities, we'll use the inscriptions data from the participants
      // Filter participants to get activities for this specific user
      const userInscriptions = participants.filter(
        (p) => p.touriste_id?._id === userId || p.touriste_id === userId
      );
      setUserActivities(userInscriptions.map((insc) => insc.activite_id).filter(Boolean));
    } catch {
      toast.error('Erreur lors du chargement du profil utilisateur');
    } finally {
      setLoadingUser(false);
      setLoadingUserDetails(false);
    }
  }, [participants]);

  const closeUserProfile = useCallback(() => {
    setUserProfileOpen(false);
    setSelectedUser(null);
  }, []);

  const handleDeleteReview = useCallback(async (reviewId) => {
    if (!reviewId || !selectedUser) return;

    try {
      await deleteReview(reviewId);
      toast.success('Avis supprimé avec succès');
      // Refresh reviews
      const reviews = await getUserReviews(selectedUser._id);
      setUserReviews(reviews);
    } catch {
      toast.error('Erreur lors de la suppression de l\'avis');
    }
  }, [selectedUser, getUserReviews]);

  const handleTogglePostExpansion = useCallback(async (postId) => {
    const newExpanded = new Set(expandedPosts);
    if (newExpanded.has(postId)) {
      newExpanded.delete(postId);
    } else {
      newExpanded.add(postId);
      // Fetch comments if not already loaded
      if (!postComments[postId]) {
        setLoadingPostComments(prev => new Set([...prev, postId]));
        try {
          const comments = await getPostComments(postId);
          setPostComments(prev => ({ ...prev, [postId]: comments }));
        } catch {
          toast.error('Erreur lors du chargement des commentaires');
        } finally {
          setLoadingPostComments(prev => {
            const newSet = new Set(prev);
            newSet.delete(postId);
            return newSet;
          });
        }
      }
    }
    setExpandedPosts(newExpanded);
  }, [expandedPosts, postComments]);

  const handleDeleteComment = useCallback(async (commentId, postId) => {
    try {
      await deleteComment(commentId);
      toast.success('Commentaire supprimé avec succès');
      // Refresh comments for this post
      const comments = await getPostComments(postId);
      setPostComments(prev => ({ ...prev, [postId]: comments }));
    } catch {
      toast.error('Erreur lors de la suppression du commentaire');
    }
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
                <Typography variant="subtitle2" sx={{ mb: 1 }}>
                  Participants ({participants.length})
                </Typography>
                {loadingParticipants ? (
                  <Stack alignItems="center" justifyContent="center" sx={{ py: 3 }}>
                    <CircularProgress size={24} />
                  </Stack>
                ) : participants.length === 0 ? (
                  <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                    Aucun participant
                  </Typography>
                ) : (
                  <Box sx={{ maxHeight: 400, overflow: 'auto' }}>
                    <Table size="small">
                      <TableBody>
                        {participants.map((participant) => {
                          const isPaid = participant.payment_id || participant.statut === 'approuvee' || participant.statut === 'verifie';
                          const isCheckedIn = !!participant.qr_used_at;
                          
                          return (
                            <TableRow key={participant._id}>
                              <TableCell>
                                <Stack direction="row" spacing={1.5} alignItems="center">
                                  <Avatar
                                    src={participant.touriste_id?.avatar}
                                    sx={{ width: 32, height: 32 }}
                                  >
                                    {getInitial(participant.touriste_id?.fullname)}
                                  </Avatar>
                                  <Box>
                                    <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                      {participant.touriste_id?.fullname || '-'}
                                    </Typography>
                                    <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                                      {participant.touriste_id?.email || '-'}
                                    </Typography>
                                  </Box>
                                </Stack>
                              </TableCell>
                              <TableCell align="center">
                                <Tooltip title="Voir le profil">
                                  <IconButton
                                    size="small"
                                    color="info"
                                    onClick={() => handleOpenUserProfile(participant.touriste_id?._id)}
                                    disabled={loadingUser}
                                  >
                                    <Iconify icon="solar:user-circle-bold" width={18} />
                                  </IconButton>
                                </Tooltip>
                              </TableCell>
                              <TableCell align="center">
                                <Typography variant="body2">
                                  {participant.nombre_participants || 1}
                                </Typography>
                              </TableCell>
                              <TableCell align="center">
                                <Stack direction="row" spacing={0.5} justifyContent="center">
                                  <Chip
                                    size="small"
                                    label={isPaid ? 'Payé' : 'Non payé'}
                                    color={isPaid ? 'success' : 'warning'}
                                    variant="outlined"
                                  />
                                  <Chip
                                    size="small"
                                    label={isCheckedIn ? 'Check-in' : 'Non check-in'}
                                    color={isCheckedIn ? 'info' : 'default'}
                                    variant="outlined"
                                  />
                                </Stack>
                              </TableCell>
                              <TableCell align="right">
                                <Chip
                                  size="small"
                                  label={participant.statut}
                                  color={
                                    participant.statut === 'approuvee' ? 'success' :
                                    participant.statut === 'verifie' ? 'info' :
                                    participant.statut === 'annulee' ? 'error' :
                                    participant.statut === 'PAID_PENDING_CONFIRMATION' ? 'warning' :
                                    'default'
                                  }
                                />
                              </TableCell>
                            </TableRow>
                          );
                        })}
                      </TableBody>
                    </Table>
                  </Box>
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

        <Dialog open={userProfileOpen} onClose={closeUserProfile} fullWidth maxWidth="md">
          <DialogTitle>
            <Stack spacing={0.5}>
              <Typography variant="h6">Profil utilisateur</Typography>
              <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                Vue complète du profil et de l'état du compte
              </Typography>
            </Stack>
          </DialogTitle>
          <DialogContent dividers>
            {loadingUser ? (
              <Stack alignItems="center" justifyContent="center" sx={{ py: 8 }}>
                <CircularProgress />
              </Stack>
            ) : (
              <Stack spacing={2}>
                <Card
                  variant="outlined"
                  sx={{
                    p: 2,
                    borderRadius: 2,
                    background: (theme) =>
                      `linear-gradient(135deg, ${theme.palette.primary.main}12 0%, ${theme.palette.info.main}10 100%)`,
                  }}
                >
                  <Stack direction="row" spacing={2} alignItems="center">
                    <Avatar
                      src={selectedUser?.avatar}
                      sx={{ width: 64, height: 64 }}
                    >
                      {getInitial(selectedUser?.fullname)}
                    </Avatar>
                    <Box>
                      <Typography variant="h5" sx={{ fontWeight: 700 }}>
                        {selectedUser?.fullname || '-'}
                      </Typography>
                      <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                        {selectedUser?.email || '-'}
                      </Typography>
                      <Stack direction="row" spacing={1} sx={{ mt: 1 }}>
                        <Chip size="small" label={selectedUser?.userType || '-'} color="primary" variant="soft" />
                        <Chip
                          size="small"
                          label={selectedUser?.accountStatus || '-'}
                          color={
                            selectedUser?.accountStatus === 'active' ? 'success' :
                            selectedUser?.accountStatus === 'suspended' ? 'warning' :
                            selectedUser?.accountStatus === 'banned' ? 'error' :
                            'default'
                          }
                          variant="soft"
                        />
                      </Stack>
                    </Box>
                  </Stack>
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
                      Téléphone
                    </Typography>
                    <Typography variant="body2" sx={{ fontWeight: 600 }}>
                      {selectedUser?.num_tel || '-'}
                    </Typography>
                  </Card>

                  <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                    <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                      Date d'inscription
                    </Typography>
                    <Typography variant="body2" sx={{ fontWeight: 600 }}>
                      {selectedUser?.date_inscription ? formatDate(selectedUser.date_inscription) : selectedUser?.createdAt ? formatDate(selectedUser.createdAt) : '-'}
                    </Typography>
                  </Card>

                  <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                    <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                      Dernière connexion
                    </Typography>
                    <Typography variant="body2" sx={{ fontWeight: 600 }}>
                      {selectedUser?.derniere_connexion ? formatDate(selectedUser.derniere_connexion) : selectedUser?.lastActive ? formatDate(selectedUser.lastActive) : '-'}
                    </Typography>
                  </Card>
                </Box>

                <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                  <Typography variant="subtitle2" sx={{ mb: 1 }}>
                    Informations de compte
                  </Typography>
                  <Stack spacing={0.75} divider={<Divider flexItem />}>
                    <Stack direction="row" justifyContent="space-between" spacing={2}>
                      <Typography variant="body2" sx={{ color: 'text.secondary' }}>ID utilisateur</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 600 }} noWrap>
                        {selectedUser?._id || '-'}
                      </Typography>
                    </Stack>
                    <Stack direction="row" justifyContent="space-between" spacing={2}>
                      <Typography variant="body2" sx={{ color: 'text.secondary' }}>Type d'utilisateur</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 600 }}>
                        {selectedUser?.userType || '-'}
                      </Typography>
                    </Stack>
                    <Stack direction="row" justifyContent="space-between" spacing={2}>
                      <Typography variant="body2" sx={{ color: 'text.secondary' }}>Statut du compte</Typography>
                      <Typography variant="body2" sx={{ fontWeight: 600 }}>
                        {selectedUser?.accountStatus || '-'}
                      </Typography>
                    </Stack>
                    {selectedUser?.accountStatus === 'suspended' && (
                      <>
                        <Stack direction="row" justifyContent="space-between" spacing={2}>
                          <Typography variant="body2" sx={{ color: 'text.secondary' }}>Suspendu jusqu'au</Typography>
                          <Typography variant="body2" sx={{ fontWeight: 600 }}>
                            {selectedUser?.suspendedUntil ? formatDate(selectedUser.suspendedUntil) : '-'}
                          </Typography>
                        </Stack>
                        <Stack direction="row" justifyContent="space-between" spacing={2}>
                          <Typography variant="body2" sx={{ color: 'text.secondary' }}>Raison de suspension</Typography>
                          <Typography variant="body2" sx={{ fontWeight: 600 }}>
                            {selectedUser?.suspendReason || '-'}
                          </Typography>
                        </Stack>
                      </>
                    )}
                    {selectedUser?.accountStatus === 'banned' && (
                      <Stack direction="row" justifyContent="space-between" spacing={2}>
                        <Typography variant="body2" sx={{ color: 'text.secondary' }}>Raison de bannissement</Typography>
                        <Typography variant="body2" sx={{ fontWeight: 600 }}>
                          {selectedUser?.banReason || '-'}
                        </Typography>
                      </Stack>
                    )}
                  </Stack>
                </Card>

                <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                  <Typography variant="subtitle2" sx={{ mb: 1 }}>
                    Activités participées ({userActivities.length})
                  </Typography>
                  {loadingUserDetails ? (
                    <Stack alignItems="center" justifyContent="center" sx={{ py: 3 }}>
                      <CircularProgress size={24} />
                    </Stack>
                  ) : userActivities.length === 0 ? (
                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                      Aucune activité participée
                    </Typography>
                  ) : (
                    <Box sx={{ maxHeight: 200, overflow: 'auto' }}>
                      <Stack spacing={1}>
                        {userActivities.map((activity) => (
                          <Card key={activity._id} variant="outlined" sx={{ p: 1.5 }}>
                            <Typography variant="body2" sx={{ fontWeight: 600 }}>
                              {activity.titre}
                            </Typography>
                            <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                              {formatDate(activity.date_debut)}
                            </Typography>
                          </Card>
                        ))}
                      </Stack>
                    </Box>
                  )}
                </Card>

                <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                  <Typography variant="subtitle2" sx={{ mb: 1 }}>
                    Avis soumis ({userReviews.length})
                  </Typography>
                  {loadingUserDetails ? (
                    <Stack alignItems="center" justifyContent="center" sx={{ py: 3 }}>
                      <CircularProgress size={24} />
                    </Stack>
                  ) : userReviews.length === 0 ? (
                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                      Aucun avis soumis
                    </Typography>
                  ) : (
                    <Box sx={{ maxHeight: 300, overflow: 'auto' }}>
                      <Stack spacing={1}>
                        {userReviews.map((review) => (
                          <Card key={review._id} variant="outlined" sx={{ p: 1.5 }}>
                            <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={1}>
                              <Box sx={{ flex: 1 }}>
                                <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 0.5 }}>
                                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                    Note: {review.note}/5
                                  </Typography>
                                  <Chip size="small" label={review.type || 'activite'} color="default" variant="outlined" />
                                </Stack>
                                {review.activite_id && (
                                  <Typography variant="caption" sx={{ color: 'primary.main', display: 'block' }}>
                                    Activité: {review.activite_id.titre || '-'}
                                  </Typography>
                                )}
                                {review.organisateur_id && (
                                  <Typography variant="caption" sx={{ color: 'primary.main', display: 'block' }}>
                                    Organisateur: {review.organisateur_id.fullname || '-'}
                                  </Typography>
                                )}
                                <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mt: 0.5 }}>
                                  {formatDate(review.createdAt)}
                                </Typography>
                                <Typography variant="body2" sx={{ mt: 0.5 }}>
                                  {review.commentaire || '-'}
                                </Typography>
                              </Box>
                              <Tooltip title="Supprimer l'avis">
                                <IconButton
                                  size="small"
                                  color="error"
                                  onClick={() => handleDeleteReview(review._id)}
                                >
                                  <Iconify icon="solar:trash-bin-trash-bold" width={18} />
                                </IconButton>
                              </Tooltip>
                            </Stack>
                          </Card>
                        ))}
                      </Stack>
                    </Box>
                  )}
                </Card>

                <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                  <Typography variant="subtitle2" sx={{ mb: 1 }}>
                    Posts ({userPosts.length})
                  </Typography>
                  {loadingUserDetails ? (
                    <Stack alignItems="center" justifyContent="center" sx={{ py: 3 }}>
                      <CircularProgress size={24} />
                    </Stack>
                  ) : userPosts.length === 0 ? (
                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                      Aucun post
                    </Typography>
                  ) : (
                    <Box sx={{ maxHeight: 500, overflow: 'auto' }}>
                      <Stack spacing={1.5}>
                        {userPosts.map((post) => (
                          <Card key={post._id} variant="outlined" sx={{ p: 1.5 }}>
                            <Stack spacing={1}>
                              <Stack direction="row" justifyContent="space-between" alignItems="flex-start">
                                <Box sx={{ flex: 1 }}>
                                  <Typography variant="body2" sx={{ fontWeight: 600, mb: 0.5 }}>
                                    {post.content || post.contenu || '-'}
                                  </Typography>
                                  <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                                    {formatDate(post.createdAt)}
                                  </Typography>
                                </Box>
                              </Stack>
                              
                              {/* Images */}
                              {(post.imageUrl || (post.imageUrls && post.imageUrls.length > 0)) && (
                                <Box
                                  sx={{
                                    display: 'grid',
                                    gap: 0.5,
                                    gridTemplateColumns: post.imageUrls?.length > 1 ? 'repeat(2, 1fr)' : '1fr',
                                    maxWidth: 300,
                                  }}
                                >
                                  {post.imageUrl && (
                                    <Box
                                      component="img"
                                      src={post.imageUrl}
                                      alt="Post image"
                                      sx={{ width: '100%', height: 150, objectFit: 'cover', borderRadius: 1 }}
                                    />
                                  )}
                                  {post.imageUrls && post.imageUrls.map((url, idx) => (
                                    <Box
                                      key={idx}
                                      component="img"
                                      src={url}
                                      alt={`Post image ${idx + 1}`}
                                      sx={{ width: '100%', height: 150, objectFit: 'cover', borderRadius: 1 }}
                                    />
                                  ))}
                                </Box>
                              )}

                              {/* Reactions - Clickable to expand */}
                              <Stack direction="row" spacing={1} sx={{ mt: 0.5 }}>
                                <Chip 
                                  size="small" 
                                  label={`❤️ ${post.likes_count || 0}`} 
                                  variant="outlined"
                                  onClick={() => handleTogglePostExpansion(post._id)}
                                  sx={{ cursor: 'pointer' }}
                                />
                                <Chip 
                                  size="small" 
                                  label={`💬 ${post.comments_count || 0}`} 
                                  variant="outlined"
                                  onClick={() => handleTogglePostExpansion(post._id)}
                                  sx={{ cursor: 'pointer' }}
                                />
                                {post.total_reactions && (
                                  <Chip 
                                    size="small" 
                                    label={`👍 ${post.total_reactions}`} 
                                    variant="outlined"
                                    onClick={() => handleTogglePostExpansion(post._id)}
                                    sx={{ cursor: 'pointer' }}
                                  />
                                )}
                              </Stack>

                              {/* Expanded Comments Section */}
                              {expandedPosts.has(post._id) && (
                                <Box sx={{ mt: 1, pt: 1, borderTop: '1px solid', borderColor: 'divider' }}>
                                  {loadingPostComments.has(post._id) ? (
                                    <Stack alignItems="center" justifyContent="center" sx={{ py: 2 }}>
                                      <CircularProgress size={20} />
                                    </Stack>
                                  ) : postComments[post._id] && postComments[post._id].length > 0 ? (
                                    <Stack spacing={1}>
                                      <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', mb: 0.5 }}>
                                        Commentaires ({postComments[post._id].length}):
                                      </Typography>
                                      {postComments[post._id].map((comment) => (
                                        <Box key={comment._id || comment.id} sx={{ p: 1, bgcolor: 'background.paper', borderRadius: 1 }}>
                                          <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={1}>
                                            <Box sx={{ flex: 1 }}>
                                              <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 0.5 }}>
                                                <Avatar
                                                  src={comment.author_id?.avatar}
                                                  sx={{ width: 24, height: 24 }}
                                                >
                                                  {getInitial(comment.author_id?.fullname || 'A')}
                                                </Avatar>
                                                <Typography variant="caption" sx={{ fontWeight: 600 }}>
                                                  {comment.author_id?.fullname || 'Anonyme'}
                                                </Typography>
                                              </Stack>
                                              <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', ml: 3.5 }}>
                                                {comment.content || comment.commentaire || '-'}
                                              </Typography>
                                              <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block', ml: 3.5 }}>
                                                {formatDate(comment.createdAt)}
                                              </Typography>
                                            </Box>
                                            <Tooltip title="Supprimer le commentaire">
                                              <IconButton
                                                size="small"
                                                color="error"
                                                onClick={() => handleDeleteComment(comment._id || comment.id, post._id)}
                                              >
                                                <Iconify icon="solar:trash-bin-trash-bold" width={16} />
                                              </IconButton>
                                            </Tooltip>
                                          </Stack>
                                        </Box>
                                      ))}
                                    </Stack>
                                  ) : (
                                    <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                                      Aucun commentaire
                                    </Typography>
                                  )}
                                </Box>
                              )}
                            </Stack>
                          </Card>
                        ))}
                      </Stack>
                    </Box>
                  )}
                </Card>

                {selectedUser?.bio && (
                  <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                    <Typography variant="subtitle2" sx={{ mb: 0.75 }}>
                      Bio
                    </Typography>
                    <Typography variant="body2">{selectedUser.bio}</Typography>
                  </Card>
                )}
              </Stack>
            )}
          </DialogContent>
          <DialogActions>
            <Button onClick={closeUserProfile} color="inherit">
              Fermer
            </Button>
          </DialogActions>
        </Dialog>
      </Stack>
    </DashboardContent>
  );
}
