import { useSetState } from 'minimal-shared/hooks';
import { useMemo, useState, useEffect, useCallback } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Chip from '@mui/material/Chip';
import Link from '@mui/material/Link';
import Stack from '@mui/material/Stack';
import Table from '@mui/material/Table';
import Dialog from '@mui/material/Dialog';
import Button from '@mui/material/Button';
import Tooltip from '@mui/material/Tooltip';
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
  getPublications,
  createPublication,
  deletePublication,
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
    commentsCount: post?.comments_count ?? 0,
    createdAt: post?.createdAt ?? null,
    updatedAt: post?.updatedAt ?? null,
  };
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
  const [form, setForm] = useState({
    content: '',
    postType: 'post',
    audience: 'public',
    hashtags: '',
    locationLabel: '',
    imageUrls: '',
  });

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
      imageUrls: '',
    });
    setOpenDialog(true);
  }, []);

  const closeDialog = useCallback(() => {
    if (submitting) return;
    setOpenDialog(false);
  }, [submitting]);

  const handleChangeForm = useCallback((field, value) => {
    setForm((prev) => ({ ...prev, [field]: value }));
  }, []);

  const handleSubmit = useCallback(async () => {
    if (!form.content.trim() && !form.imageUrls.trim()) {
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
      imageUrls: form.imageUrls
        .split(/\r?\n|,/)
        .map((item) => item.trim())
        .filter(Boolean),
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

  const openDetails = useCallback((row) => {
    setDetailsRow(row);
    setOpenDetailsDialog(true);
  }, []);

  const closeDetails = useCallback(() => {
    setOpenDetailsDialog(false);
    setDetailsRow(null);
  }, []);

  return (
    <DashboardContent maxWidth="xl" sx={sx}>
      <Stack spacing={2}>
        <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} justifyContent="space-between">
          <Typography variant="h4">Publications</Typography>
          <Button variant="contained" onClick={openCreateDialog}>
            Nouvelle publication
          </Button>
        </Stack>

        <Card sx={{ p: 2 }}>
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
                          <TableCell>{row.author}</TableCell>
                          <TableCell sx={{ maxWidth: 420 }}>
                            <Typography variant="body2" noWrap>
                              {row.content || '-'}
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Chip size="small" label={row.postType} />
                          </TableCell>
                          <TableCell>{row.audience}</TableCell>
                          <TableCell>{formatDate(row.createdAt)}</TableCell>
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

              <TextField
                label="Lieu"
                value={form.locationLabel}
                onChange={(event) => handleChangeForm('locationLabel', event.target.value)}
              />

              <TextField
                multiline
                minRows={3}
                label="URLs images (une par ligne)"
                value={form.imageUrls}
                onChange={(event) => handleChangeForm('imageUrls', event.target.value)}
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

        <Dialog open={openDetailsDialog} onClose={closeDetails} fullWidth maxWidth="md">
          <DialogTitle>Détails publication</DialogTitle>
          <DialogContent dividers>
            <Stack spacing={1.25}>
              <Typography variant="body2">
                <strong>Auteur:</strong> {detailsRow?.author ?? '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Type:</strong> {detailsRow?.postType ?? '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Audience:</strong> {detailsRow?.audience ?? '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Lieu:</strong> {detailsRow?.locationLabel || '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Hashtags:</strong> {detailsRow?.hashtags || '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Likes:</strong> {detailsRow?.likesCount ?? 0}
              </Typography>
              <Typography variant="body2">
                <strong>Commentaires:</strong> {detailsRow?.commentsCount ?? 0}
              </Typography>
              <Typography variant="body2">
                <strong>Date création:</strong> {formatDate(detailsRow?.createdAt)}
              </Typography>
              <Typography variant="body2">
                <strong>Date modification:</strong> {formatDate(detailsRow?.updatedAt)}
              </Typography>
              <Typography variant="body2">
                <strong>Trip link:</strong>{' '}
                {detailsRow?.tripLink ? (
                  <Link href={detailsRow.tripLink} target="_blank" rel="noopener noreferrer">
                    {detailsRow.tripLink}
                  </Link>
                ) : (
                  '-'
                )}
              </Typography>
              <Typography variant="body2">
                <strong>Contenu:</strong>
              </Typography>
              <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
                {detailsRow?.content || '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Images:</strong>
              </Typography>
              <Stack spacing={0.5}>
                {(detailsRow?.imageUrls ?? []).length ? (
                  detailsRow.imageUrls.map((url) => (
                    <Link key={url} href={url} target="_blank" rel="noopener noreferrer" noWrap>
                      {url}
                    </Link>
                  ))
                ) : (
                  <Typography variant="body2">-</Typography>
                )}
              </Stack>
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
