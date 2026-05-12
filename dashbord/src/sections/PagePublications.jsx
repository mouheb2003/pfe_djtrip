import { useSetState } from 'minimal-shared/hooks';
import { useMemo, useState, useEffect, useCallback } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Chip from '@mui/material/Chip';
import Link from '@mui/material/Link';
import Stack from '@mui/material/Stack';
import Table from '@mui/material/Table';
import Avatar from '@mui/material/Avatar';
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
import Tabs from '@mui/material/Tabs';
import Tab from '@mui/material/Tab';
import InputLabel from '@mui/material/InputLabel';
import Select from '@mui/material/Select';
import FormControl from '@mui/material/FormControl';

import { DashboardContent } from 'src/layouts/dashboard';
import {
  getPublications,
  createPublication,
  updatePublication,
  deletePublication,
  getAdminComments,
  adminDeleteComment,
  getLieux,
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
  { id: 'author', label: 'Auteur' },
  { id: 'content', label: 'Contenu' },
  { id: 'type', label: 'Type' },
  { id: 'audience', label: 'Audience' },
  { id: 'createdAt', label: 'Date' },
  { id: 'actions', label: '', align: 'right' },
];

function mapPost(post) {
  return {
    id: post?._id ?? post?.id,
    author: post?.author_id?.fullname ?? 'Unknown',
    content: String(post?.content ?? ''),
    postType: post?.post_type ?? 'post',
    audience: post?.audience ?? 'public',
    hashtags: Array.isArray(post?.hashtags) ? post.hashtags.join(', ') : '',
    locationLabel: post?.location_label ?? '',
    imageUrls: Array.isArray(post?.image_urls)
      ? post.image_urls
      : post?.image_url
        ? [post.image_url]
        : [],
    tripLink: post?.trip_link ?? '',
    likesCount: post?.likes_count ?? 0,
    likedByUsers: Array.isArray(post?.liked_by)
      ? post.liked_by.map((user) => ({
          id: user?._id ?? user?.id,
          fullname: user?.fullname ?? 'Unknown',
          avatar: user?.avatar ?? '',
          userType: user?.userType ?? '',
        }))
      : [],
    commentsCount: post?.comments_count ?? 0,
    createdAt: post?.createdAt ?? null,
    updatedAt: post?.updatedAt ?? null,
  };
}

function mapPublicationComment(comment) {
  const author = comment?.user_id ?? {};

  return {
    id: comment?._id ?? comment?.id,
    content: String(comment?.content ?? ''),
    authorName: author?.fullname ?? author?.email ?? 'Unknown',
    createdAt: comment?.created_at ?? comment?.createdAt ?? null,
    parent_comment_id: comment?.parent_comment_id ?? null,
    user_id: comment?.user_id ?? null,
  };
}

function getInitial(name) {
  return String(name || '?').trim().charAt(0).toUpperCase();
}

function getUserSubtitle(userType) {
  const normalized = String(userType || '').toLowerCase();
  if (normalized === 'admin') return 'Admin';
  if (normalized === 'organisator' || normalized === 'organisateur') return 'Organisateur';
  if (normalized === 'touriste') return 'Touriste';
  return 'Utilisateur';
}

function typeChipColor(type) {
  if (type === 'activity') return 'warning';
  return 'primary';
}

function audienceChipColor(audience) {
  if (audience === 'followers') return 'secondary';
  return 'default';
}

function formatDate(value) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return date.toLocaleString('fr-FR');
}

function applyFilter({ inputData, comparator, filters }) {
  const { query, postType, audience } = filters;

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
      (row) => row.content.toLowerCase().includes(q) || row.author.toLowerCase().includes(q)
    );
  }

  if (postType !== 'all') {
    data = data.filter((row) => row.postType === postType);
  }

  if (audience !== 'all') {
    data = data.filter((row) => row.audience === audience);
  }

  return data;
}

export function PublicationsView({ sx }) {
  const table = useTable({ defaultOrderBy: 'createdAt' });

  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [rows, setRows] = useState([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [openDetailsDialog, setOpenDetailsDialog] = useState(false);
  const [detailsRow, setDetailsRow] = useState(null);
  const [detailsComments, setDetailsComments] = useState([]);
  const [detailsCommentsLoading, setDetailsCommentsLoading] = useState(false);
  const [detailsCommentsError, setDetailsCommentsError] = useState('');
  const [form, setForm] = useState({
    content: '',
    postType: 'post',
    audience: 'public',
    hashtags: '',
    locationLabel: '',
    locationCoords: null,
    locationSource: 'manual', // 'manual', 'map', 'database'
    imageUrls: '',
  });
  const [locationDialogOpen, setLocationDialogOpen] = useState(false);
  const [lieux, setLieux] = useState([]);
  const [loadingLieux, setLoadingLieux] = useState(false);
  const [locationTab, setLocationTab] = useState(0); // 0: manual, 1: database, 2: map
  const [manualLocation, setManualLocation] = useState('');
  const [selectedLieu, setSelectedLieu] = useState(null);
  const [imageUrls, setImageUrls] = useState([]);
  const [imageInputUrl, setImageInputUrl] = useState('');

  const filters = useSetState({
    query: '',
    postType: 'all',
    audience: 'all',
  });
  const { state: currentFilters, setState: updateFilters } = filters;

  const loadRows = useCallback(async () => {
    try {
      setLoading(true);
      setError('');
      const posts = await getPublications();
      setRows(posts.map(mapPost));
    } catch {
      setError('Erreur lors du chargement des publications');
      toast.error('Impossible de charger les publications');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadRows();
  }, [loadRows]);

  const loadLieux = useCallback(async () => {
    try {
      setLoadingLieux(true);
      const lieuxData = await getLieux();
      setLieux(lieuxData);
    } catch {
      toast.error('Impossible de charger les lieux');
    } finally {
      setLoadingLieux(false);
    }
  }, []);

  useEffect(() => {
    if (locationDialogOpen) {
      loadLieux();
    }
  }, [locationDialogOpen, loadLieux]);

  const loadPostComments = useCallback(async (postId) => {
    if (!postId) {
      setDetailsComments([]);
      return;
    }

    try {
      setDetailsCommentsLoading(true);
      setDetailsCommentsError('');
      const comments = await getAdminComments({ postId });
      setDetailsComments(comments.map(mapPublicationComment));
    } catch {
      setDetailsCommentsError('Impossible de charger les commentaires');
      setDetailsComments([]);
    } finally {
      setDetailsCommentsLoading(false);
    }
  }, []);

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
    currentFilters.query.trim() !== '' ||
    currentFilters.postType !== 'all' ||
    currentFilters.audience !== 'all';

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
      updateFilters({ postType: event.target.value });
    },
    [table, updateFilters]
  );

  const handleFilterAudience = useCallback(
    (event) => {
      table.onResetPage();
      updateFilters({ audience: event.target.value });
    },
    [table, updateFilters]
  );

  const handleResetFilters = useCallback(() => {
    table.onResetPage();
    updateFilters({ query: '', postType: 'all', audience: 'all' });
  }, [table, updateFilters]);

  const openCreateDialog = useCallback(() => {
    setForm({
      content: '',
      postType: 'post',
      audience: 'public',
      hashtags: '',
      locationLabel: '',
      locationCoords: null,
      locationSource: 'manual',
      imageUrls: '',
    });
    setImageUrls([]);
    setImageInputUrl('');
    setOpenDialog(true);
  }, []);

  const closeDialog = useCallback(() => {
    if (submitting) return;
    setOpenDialog(false);
    setImageUrls([]);
    setImageInputUrl('');
  }, [submitting]);

  const handleChangeForm = useCallback((field, value) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  }, []);

  const handleSubmit = useCallback(async () => {
    if (!form.content.trim() && imageUrls.length === 0) {
      toast.error('Contenu ou image est requis');
      return;
    }

    const payload = {
      content: form.content.trim(),
      postType: form.postType,
      audience: form.audience,
      locationLabel: form.locationLabel.trim(),
      hashtags: form.hashtags
        .split(',')
        .map((item) => item.trim())
        .filter(Boolean),
      imageUrls: imageUrls,
    };

    try {
      setSubmitting(true);
      await createPublication(payload);
      toast.success('Publication créée');
      setOpenDialog(false);
      await loadRows();
    } catch {
      toast.error('Échec de sauvegarde de la publication');
    } finally {
      setSubmitting(false);
    }
  }, [form, loadRows]);

  const handleDelete = useCallback(
    async (row) => {
      const confirmed = window.confirm('Supprimer cette publication ?');
      if (!confirmed) return;

      try {
        await deletePublication(row.id);
        toast.success('Publication supprimée');
        await loadRows();
      } catch {
        toast.error('Échec de suppression de la publication');
      }
    },
    [loadRows]
  );

  const openDetails = useCallback(async (row) => {
    setDetailsRow(row);
    setOpenDetailsDialog(true);
    await loadPostComments(row?.id);
  }, [loadPostComments]);

  const closeDetails = useCallback(() => {
    setOpenDetailsDialog(false);
    setDetailsRow(null);
    setDetailsComments([]);
    setDetailsCommentsError('');
    setDetailsCommentsLoading(false);
  }, []);

  const handleDeleteCommentFromDetails = useCallback(async (commentId) => {
    if (!commentId || !detailsRow?.id) return;

    const confirmed = window.confirm('Supprimer ce commentaire ?');
    if (!confirmed) return;

    try {
      await adminDeleteComment(commentId);
      setDetailsComments((prev) => prev.filter((comment) => comment.id !== commentId));
      setRows((prev) =>
        prev.map((post) =>
          post.id === detailsRow.id
            ? { ...post, commentsCount: Math.max(0, Number(post.commentsCount || 0) - 1) }
            : post
        )
      );
      setDetailsRow((prev) =>
        prev
          ? { ...prev, commentsCount: Math.max(0, Number(prev.commentsCount || 0) - 1) }
          : prev
      );
      toast.success('Commentaire supprimé');
    } catch {
      toast.error('Échec de suppression du commentaire');
    }
  }, [detailsRow?.id]);

  return (
    <DashboardContent maxWidth="xl" sx={sx}>
      <Stack spacing={2}>
        <Card
          sx={{
            p: { xs: 2, md: 2.5 },
            borderRadius: 2,
            background: (theme) =>
              `linear-gradient(135deg, ${theme.palette.primary.main}14 0%, ${theme.palette.info.main}1F 100%)`,
            border: '1px solid',
            borderColor: 'divider',
          }}
        >
          <Stack
            direction={{ xs: 'column', md: 'row' }}
            spacing={2}
            justifyContent="space-between"
            alignItems={{ md: 'center' }}
          >
            <Box>
              <Typography variant="h4">Publications</Typography>
              <Typography variant="body2" sx={{ color: 'text.secondary', mt: 0.5 }}>
                Gérez vos contenus, médias et commentaires depuis une vue unifiée.
              </Typography>
            </Box>

            <Stack direction="row" spacing={1.25} alignItems="center">
              <Chip
                size="small"
                color="info"
                variant="soft"
                label={`${filteredRows.length} publication(s)`}
              />
              <Button variant="contained" onClick={openCreateDialog} startIcon={<Iconify icon="solar:add-circle-bold" />}>
                Nouvelle publication
              </Button>
            </Stack>
          </Stack>
        </Card>

        <Card sx={{ p: 2, borderRadius: 2 }}>
          <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} alignItems={{ md: 'center' }}>
            <TextField
              fullWidth
              label="Recherche"
              placeholder="Rechercher par auteur ou contenu"
              value={currentFilters.query}
              onChange={handleFilterQuery}
            />

            <TextField
              select
              label="Type"
              value={currentFilters.postType}
              onChange={handleFilterType}
              sx={{ minWidth: 180 }}
            >
              <MenuItem value="all">Tous</MenuItem>
              <MenuItem value="post">post</MenuItem>
              <MenuItem value="activity">activity</MenuItem>
            </TextField>

            <TextField
              select
              label="Audience"
              value={currentFilters.audience}
              onChange={handleFilterAudience}
              sx={{ minWidth: 180 }}
            >
              <MenuItem value="all">Tous</MenuItem>
              <MenuItem value="public">public</MenuItem>
              <MenuItem value="followers">followers</MenuItem>
            </TextField>

            <Button onClick={handleResetFilters} disabled={!canReset}>
              Reset
            </Button>
          </Stack>
        </Card>

        <Card sx={{ borderRadius: 2, overflow: 'hidden' }}>
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
                          <TableCell>
                            <Stack direction="row" spacing={1.25} alignItems="center">
                              <Avatar sx={{ width: 34, height: 34, fontSize: 14 }}>
                                {getInitial(row.author)}
                              </Avatar>
                              <Box>
                                <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                  {row.author}
                                </Typography>
                                <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                                  {row.commentsCount ?? 0} com. • {row.likesCount ?? 0} likes
                                </Typography>
                              </Box>
                            </Stack>
                          </TableCell>
                          <TableCell sx={{ maxWidth: 420 }}>
                            <Typography
                              variant="body2"
                              sx={{
                                display: '-webkit-box',
                                WebkitLineClamp: 2,
                                WebkitBoxOrient: 'vertical',
                                overflow: 'hidden',
                              }}
                            >
                              {row.content || '-'}
                            </Typography>
                            {(row.imageUrls ?? []).length > 0 ? (
                              <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                                {(row.imageUrls ?? []).length} image(s)
                              </Typography>
                            ) : null}
                          </TableCell>
                          <TableCell>
                            <Chip size="small" color={typeChipColor(row.postType)} variant="soft" label={row.postType} />
                          </TableCell>
                          <TableCell>
                            <Chip
                              size="small"
                              color={audienceChipColor(row.audience)}
                              variant="soft"
                              label={row.audience}
                            />
                          </TableCell>
                          <TableCell>
                            <Typography variant="body2">{formatDate(row.createdAt)}</Typography>
                          </TableCell>
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
                          <TableCell colSpan={6} align="center">
                            Aucune publication trouvée
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
          <DialogTitle>Créer une publication</DialogTitle>
          <DialogContent dividers>
            <Stack spacing={2}>
              <TextField
                multiline
                minRows={4}
                label="Contenu"
                value={form.content}
                onChange={(event) => handleChangeForm('content', event.target.value)}
              />

              <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
                <TextField
                  select
                  label="Type"
                  value={form.postType}
                  onChange={(event) => handleChangeForm('postType', event.target.value)}
                  fullWidth
                >
                  <MenuItem value="post">post</MenuItem>
                  <MenuItem value="activity">activity</MenuItem>
                </TextField>

                <TextField
                  select
                  label="Audience"
                  value={form.audience}
                  onChange={(event) => handleChangeForm('audience', event.target.value)}
                  fullWidth
                >
                  <MenuItem value="public">public</MenuItem>
                  <MenuItem value="followers">followers</MenuItem>
                </TextField>
              </Stack>

              <TextField
                label="Hashtags (séparés par des virgules)"
                value={form.hashtags}
                onChange={(event) => handleChangeForm('hashtags', event.target.value)}
              />

              <Stack spacing={1}>
                <Typography variant="subtitle2">Lieu</Typography>
                <Button
                  variant="outlined"
                  startIcon={<Iconify icon="solar:map-point-bold" />}
                  onClick={() => setLocationDialogOpen(true)}
                  fullWidth
                >
                  {form.locationLabel || 'Sélectionner un lieu'}
                </Button>
                {form.locationLabel && (
                  <Chip
                    label={`${form.locationLabel} (${form.locationSource === 'manual' ? 'Manuel' : form.locationSource === 'database' ? 'Base de données' : 'Carte'})`}
                    onDelete={() => handleChangeForm('locationLabel', '')}
                    size="small"
                  />
                )}
              </Stack>

              <Stack spacing={2}>
                <Typography variant="subtitle2">Images</Typography>

                {/* Add image by URL */}
                <Stack direction="row" spacing={1}>
                  <TextField
                    label="URL de l'image"
                    value={imageInputUrl}
                    onChange={(e) => setImageInputUrl(e.target.value)}
                    placeholder="https://..."
                    fullWidth
                    size="small"
                  />
                  <Button
                    variant="outlined"
                    onClick={() => {
                      if (imageInputUrl.trim()) {
                        setImageUrls([...imageUrls, imageInputUrl.trim()]);
                        setImageInputUrl('');
                      }
                    }}
                    disabled={!imageInputUrl.trim()}
                  >
                    Ajouter
                  </Button>
                </Stack>

                {/* Upload button */}
                <Button
                  variant="outlined"
                  startIcon={<Iconify icon="solar:upload-bold" />}
                  component="label"
                  fullWidth
                >
                  Uploader des images (max 2MB par image)
                  <input
                    type="file"
                    accept="image/*"
                    multiple
                    hidden
                    onChange={(e) => {
                      const files = Array.from(e.target.files);
                      files.forEach((file) => {
                        // Check file size (max 2MB)
                        if (file.size > 2 * 1024 * 1024) {
                          toast.error(`L'image ${file.name} est trop grande (max 2MB)`);
                          return;
                        }

                        const reader = new FileReader();
                        reader.onloadend = () => {
                          setImageUrls((prev) => [...prev, reader.result]);
                        };
                        reader.readAsDataURL(file);
                      });
                    }}
                  />
                </Button>

                {/* Display selected images */}
                {imageUrls.length > 0 && (
                  <Stack spacing={1} sx={{ maxHeight: 200, overflow: 'auto' }}>
                    {imageUrls.map((url, index) => (
                      <Card
                        key={index}
                        variant="outlined"
                        sx={{
                          p: 1,
                          display: 'flex',
                          alignItems: 'center',
                          gap: 1,
                        }}
                      >
                        <Box
                          component="img"
                          src={url}
                          alt={`Image ${index + 1}`}
                          sx={{
                            width: 60,
                            height: 60,
                            objectFit: 'cover',
                            borderRadius: 1,
                          }}
                        />
                        <Typography variant="caption" sx={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {url}
                        </Typography>
                        <IconButton
                          size="small"
                          color="error"
                          onClick={() => setImageUrls(imageUrls.filter((_, i) => i !== index))}
                        >
                          <Iconify icon="solar:trash-bin-trash-bold" width={18} />
                        </IconButton>
                      </Card>
                    ))}
                  </Stack>
                )}
              </Stack>
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

        {/* Location Selection Dialog */}
        <Dialog open={locationDialogOpen} onClose={() => setLocationDialogOpen(false)} fullWidth maxWidth="md">
          <DialogTitle>Sélectionner un lieu</DialogTitle>
          <DialogContent>
            <Tabs value={locationTab} onChange={(e, v) => setLocationTab(v)} sx={{ mb: 2 }}>
              <Tab label="Manuel" />
              <Tab label="Base de données" />
              <Tab label="Carte" />
            </Tabs>

            {locationTab === 0 && (
              <Stack spacing={2}>
                <TextField
                  label="Nom du lieu"
                  value={manualLocation}
                  onChange={(e) => setManualLocation(e.target.value)}
                  placeholder="Ex: Plage de Djerba"
                  fullWidth
                />
                <Button
                  variant="contained"
                  onClick={() => {
                    if (manualLocation.trim()) {
                      setForm({
                        ...form,
                        locationLabel: manualLocation,
                        locationSource: 'manual',
                      });
                      setLocationDialogOpen(false);
                      setManualLocation('');
                    }
                  }}
                  disabled={!manualLocation.trim()}
                >
                  Confirmer
                </Button>
              </Stack>
            )}

            {locationTab === 1 && (
              <Stack spacing={2}>
                {loadingLieux ? (
                  <Stack alignItems="center" sx={{ py: 4 }}>
                    <CircularProgress />
                  </Stack>
                ) : lieux.length === 0 ? (
                  <Typography variant="body2" sx={{ color: 'text.secondary', py: 4 }}>
                    Aucun lieu disponible dans la base de données
                  </Typography>
                ) : (
                  <Stack spacing={1.5} sx={{ maxHeight: 400, overflow: 'auto' }}>
                    {lieux.map((lieu) => (
                      <Card
                        key={lieu._id}
                        variant="outlined"
                        sx={{
                          p: 2,
                          cursor: 'pointer',
                          bgcolor: selectedLieu?._id === lieu._id ? 'primary.lighter' : 'background.paper',
                          '&:hover': { bgcolor: 'action.hover' },
                          border: selectedLieu?._id === lieu._id ? '2px solid' : '1px solid',
                          borderColor: selectedLieu?._id === lieu._id ? 'primary.main' : 'divider',
                        }}
                        onClick={() => setSelectedLieu(lieu)}
                      >
                        <Stack spacing={0.5}>
                          <Typography variant="subtitle1" fontWeight={600}>
                            {lieu.name || lieu.nom}
                          </Typography>
                          <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                            {lieu.location || lieu.localisation}
                          </Typography>
                          {lieu.description && (
                            <Typography variant="caption" sx={{ color: 'text.disabled' }}>
                              {lieu.description}
                            </Typography>
                          )}
                        </Stack>
                      </Card>
                    ))}
                  </Stack>
                )}
                <Button
                  variant="contained"
                  onClick={() => {
                    if (selectedLieu) {
                      setForm({
                        ...form,
                        locationLabel: selectedLieu.name || selectedLieu.nom,
                        locationCoords: selectedLieu.coordinates || selectedLieu.coordonnees,
                        locationSource: 'database',
                      });
                      setLocationDialogOpen(false);
                      setSelectedLieu(null);
                    }
                  }}
                  disabled={!selectedLieu}
                >
                  Confirmer
                </Button>
              </Stack>
            )}

            {locationTab === 2 && (
              <Stack spacing={2} sx={{ py: 2 }}>
                <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                  Fonctionnalité de carte à venir. Pour l'instant, utilisez l'option manuelle ou la base de données.
                </Typography>
                <Box
                  sx={{
                    height: 300,
                    bgcolor: 'grey.200',
                    borderRadius: 1,
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                  }}
                >
                  <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                    <Iconify icon="solar:map-bold" width={48} />
                    <br />
                    Carte Google Maps
                  </Typography>
                </Box>
              </Stack>
            )}
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setLocationDialogOpen(false)}>Annuler</Button>
          </DialogActions>
        </Dialog>

        <Dialog open={openDetailsDialog} onClose={closeDetails} fullWidth maxWidth="lg">
          <DialogTitle sx={{ pb: 1.5 }}>
            <Stack
              direction={{ xs: 'column', md: 'row' }}
              spacing={1.25}
              justifyContent="space-between"
              alignItems={{ md: 'center' }}
            >
              <Stack direction="row" spacing={1.25} alignItems="center">
                <Avatar
                  sx={{
                    width: 36,
                    height: 36,
                    bgcolor: 'primary.main',
                  }}
                >
                  <Iconify icon="solar:document-text-bold" width={18} />
                </Avatar>
                <Box>
                  <Typography variant="h6">Détails publication</Typography>
                  <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                    Vue complète du post et de ses commentaires
                  </Typography>
                </Box>
              </Stack>

              <Stack direction="row" spacing={1} flexWrap="wrap">
                <Chip size="small" color="primary" variant="soft" label={detailsRow?.postType ?? '-'} />
                <Chip size="small" color="default" variant="soft" label={detailsRow?.audience ?? '-'} />
                <Chip size="small" color="success" variant="soft" label={`${detailsRow?.likesCount ?? 0} likes`} />
                <Chip size="small" color="info" variant="soft" label={`${detailsRow?.commentsCount ?? 0} com.`} />
              </Stack>
            </Stack>
          </DialogTitle>

          <DialogContent dividers sx={{ pt: 2 }}>
            <Stack spacing={2.5}>
              {(detailsRow?.imageUrls ?? []).length > 0 ? (
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
                    src={detailsRow?.imageUrls?.[0]}
                    alt="Cover publication"
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
                    `linear-gradient(135deg, ${theme.palette.info.main}12 0%, ${theme.palette.primary.main}10 100%)`,
                }}
              >
                <Stack spacing={0.5}>
                  <Typography variant="subtitle2" sx={{ color: 'text.secondary' }}>
                    Auteur
                  </Typography>
                  <Typography variant="h6">{detailsRow?.author ?? '-'}</Typography>
                  <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                    Publiée le {formatDate(detailsRow?.createdAt)} • modifiée le {formatDate(detailsRow?.updatedAt)}
                  </Typography>
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
                    Lieu
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {detailsRow?.locationLabel || '-'}
                  </Typography>
                </Card>

                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Hashtags
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {detailsRow?.hashtags || '-'}
                  </Typography>
                </Card>

                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Lien du trip
                  </Typography>
                  {detailsRow?.tripLink ? (
                    <Link href={detailsRow.tripLink} target="_blank" rel="noopener noreferrer" noWrap>
                      {detailsRow.tripLink}
                    </Link>
                  ) : (
                    <Typography variant="body2">-</Typography>
                  )}
                </Card>
              </Box>

              <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                <Typography variant="subtitle2" sx={{ mb: 0.75 }}>
                  Contenu du post
                </Typography>
                <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap', lineHeight: 1.7 }}>
                  {detailsRow?.content || '-'}
                </Typography>
              </Card>

              <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                <Typography variant="subtitle2" sx={{ mb: 1 }}>
                  Galerie média
                </Typography>
                {(detailsRow?.imageUrls ?? []).length ? (
                  <Box
                    sx={{
                      display: 'grid',
                      gap: 1,
                      gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, minmax(0, 1fr))' },
                    }}
                  >
                    {detailsRow.imageUrls.map((url) => (
                      <Box
                        key={url}
                        sx={{ border: '1px solid', borderColor: 'divider', borderRadius: 1.5, p: 1 }}
                      >
                        <Box
                          component="img"
                          src={url}
                          alt="Publication"
                          sx={{ width: '100%', height: 160, objectFit: 'cover', borderRadius: 1 }}
                        />
                        <Link
                          href={url}
                          target="_blank"
                          rel="noopener noreferrer"
                          noWrap
                          sx={{ display: 'block', mt: 1, fontSize: 12 }}
                        >
                          {url}
                        </Link>
                      </Box>
                    ))}
                  </Box>
                ) : (
                  <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                    Aucune image
                  </Typography>
                )}
              </Card>

              <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                <Stack
                  direction={{ xs: 'column', sm: 'row' }}
                  justifyContent="space-between"
                  spacing={1}
                  sx={{ mb: 1.5 }}
                >
                  <Typography variant="subtitle2">Utilisateurs qui ont liké</Typography>
                  <Chip
                    size="small"
                    color="success"
                    variant="soft"
                    label={`${detailsRow?.likedByUsers?.length ?? 0} utilisateur(s)`}
                  />
                </Stack>

                {(detailsRow?.likedByUsers ?? []).length ? (
                  <Box
                    sx={{
                      display: 'grid',
                      gap: 1,
                      gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, minmax(0, 1fr))' },
                    }}
                  >
                    {detailsRow.likedByUsers.map((user) => (
                      <Stack
                        key={user.id}
                        direction="row"
                        spacing={1.25}
                        alignItems="center"
                        sx={{
                          p: 1.25,
                          borderRadius: 2,
                          border: '1px solid',
                          borderColor: 'divider',
                          bgcolor: 'background.neutral',
                        }}
                      >
                        <Avatar sx={{ width: 34, height: 34, fontSize: 14 }}>
                          {getInitial(user.fullname)}
                        </Avatar>
                        <Box sx={{ minWidth: 0 }}>
                          <Typography variant="body2" sx={{ fontWeight: 600 }} noWrap>
                            {user.fullname}
                          </Typography>
                          <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                            {getUserSubtitle(user.userType)}
                          </Typography>
                        </Box>
                      </Stack>
                    ))}
                  </Box>
                ) : (
                  <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                    Aucun like pour cette publication.
                  </Typography>
                )}
              </Card>

              <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                <Stack
                  direction={{ xs: 'column', sm: 'row' }}
                  justifyContent="space-between"
                  spacing={1}
                  sx={{ mb: 1.5 }}
                >
                  <Typography variant="subtitle2">Commentaires du post</Typography>
                  <Button
                    size="small"
                    startIcon={<Iconify icon="solar:refresh-bold" />}
                    onClick={() => loadPostComments(detailsRow?.id)}
                    disabled={detailsCommentsLoading || !detailsRow?.id}
                  >
                    Actualiser
                  </Button>
                </Stack>

                {detailsCommentsLoading ? (
                  <Stack alignItems="center" justifyContent="center" sx={{ py: 4 }}>
                    <CircularProgress size={24} />
                  </Stack>
                ) : detailsCommentsError ? (
                  <Typography variant="body2" color="error.main">
                    {detailsCommentsError}
                  </Typography>
                ) : detailsComments.length === 0 ? (
                  <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                    Aucun commentaire pour cette publication.
                  </Typography>
                ) : (
                  <Stack spacing={1.5}>
                    {(() => {
                      console.log('DEBUG: All comments received:', detailsComments);
                      console.log('DEBUG: Sample comment structure:', detailsComments[0]);

                      // Organize comments: root comments first, then replies
                      const rootComments = detailsComments.filter(c => !c.parent_comment_id);
                      const repliesMap = {};
                      detailsComments.forEach(c => {
                        if (c.parent_comment_id) {
                          if (!repliesMap[c.parent_comment_id]) {
                            repliesMap[c.parent_comment_id] = [];
                          }
                          repliesMap[c.parent_comment_id].push(c);
                        }
                      });

                      console.log('DEBUG: Root comments count:', rootComments.length);
                      console.log('DEBUG: Replies map:', repliesMap);

                      return rootComments.map((comment) => (
                        <Box key={comment._id || comment.id}>
                          <Card
                            variant="outlined"
                            sx={{
                              p: 1.5,
                              borderRadius: 1.5,
                              bgcolor: 'background.neutral',
                            }}
                          >
                            <Stack direction="row" justifyContent="space-between" spacing={1}>
                              <Stack direction="row" spacing={1.25} alignItems="center">
                                <Avatar
                                  src={comment.user_id?.avatar}
                                  sx={{ width: 30, height: 30, fontSize: 13 }}
                                >
                                  {getInitial(comment.user_id?.fullname || comment.authorName)}
                                </Avatar>
                                <Box>
                                  <Typography variant="subtitle2">
                                    {comment.user_id?.fullname || comment.authorName}
                                  </Typography>
                                  <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                                    {formatDate(comment.created_at || comment.createdAt)}
                                  </Typography>
                                </Box>
                              </Stack>

                              <Tooltip title="Supprimer commentaire">
                                <IconButton
                                  color="error"
                                  size="small"
                                  onClick={() => handleDeleteCommentFromDetails(comment._id || comment.id)}
                                >
                                  <Iconify icon="solar:trash-bin-trash-bold" />
                                </IconButton>
                              </Tooltip>
                            </Stack>

                            <Divider sx={{ my: 1 }} />

                            <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap', lineHeight: 1.65 }}>
                              {comment.content || '-'}
                            </Typography>
                          </Card>

                          {/* Display replies */}
                          {repliesMap[comment._id || comment.id]?.length > 0 && (
                            <Box sx={{ mt: 1.5, ml: 4, pl: 2, borderLeft: '2px dashed', borderLeftColor: 'divider' }}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600, mb: 1, display: 'block' }}>
                                <Iconify icon="solar:reply-bold" width={14} sx={{ mr: 0.5, verticalAlign: 'middle' }} />
                {repliesMap[comment._id || comment.id].length} Réponse(s)
                              </Typography>
                              <Stack spacing={1}>
                                {repliesMap[comment._id || comment.id].map((reply) => (
                                  <Card
                                    key={reply._id || reply.id}
                                    variant="outlined"
                                    sx={{
                                      p: 1,
                                      borderRadius: 1.5,
                                      bgcolor: 'background.paper',
                                      borderLeft: '3px solid',
                                      borderLeftColor: 'primary.main',
                                      boxShadow: '0 1px 2px rgba(0,0,0,0.05)',
                                    }}
                                  >
                                    <Stack direction="row" justifyContent="space-between" spacing={1}>
                                      <Stack direction="row" spacing={1} alignItems="center">
                                        <Avatar
                                          src={reply.user_id?.avatar}
                                          sx={{ width: 24, height: 24, fontSize: 11 }}
                                        >
                                          {getInitial(reply.user_id?.fullname || reply.authorName)}
                                        </Avatar>
                                        <Box>
                                          <Typography variant="caption" sx={{ fontWeight: 600 }}>
                                            {reply.user_id?.fullname || reply.authorName}
                                          </Typography>
                                          <Typography variant="caption" sx={{ color: 'text.secondary', ml: 0.5 }}>
                                            {formatDate(reply.created_at || reply.createdAt)}
                                          </Typography>
                                        </Box>
                                      </Stack>

                                      <Tooltip title="Supprimer réponse">
                                        <IconButton
                                          color="error"
                                          size="small"
                                          onClick={() => handleDeleteCommentFromDetails(reply._id || reply.id)}
                                        >
                                          <Iconify icon="solar:trash-bin-trash-bold" width={16} />
                                        </IconButton>
                                      </Tooltip>
                                    </Stack>

                                    <Typography variant="caption" sx={{ whiteSpace: 'pre-wrap', lineHeight: 1.6, mt: 0.5 }}>
                                      {reply.content || '-'}
                                    </Typography>
                                  </Card>
                                ))}
                              </Stack>
                            </Box>
                          )}
                        </Box>
                      ));
                    })()}
                  </Stack>
                )}
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


