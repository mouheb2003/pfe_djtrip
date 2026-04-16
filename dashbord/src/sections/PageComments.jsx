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
import TextField from '@mui/material/TextField';
import TableRow from '@mui/material/TableRow';
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
  getAdminComments,
  adminDeleteComment,
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
  { id: 'content', label: 'Commentaire' },
  { id: 'post', label: 'Post' },
  { id: 'createdAt', label: 'Date' },
  { id: 'actions', label: '', align: 'right' },
];

function mapComment(comment) {
  const user = comment.user_id || {};
  const post = comment.post_id || {};

  return {
    id: comment?._id ?? comment?.id,
    author: user.fullname ?? user.email ?? 'Unknown',
    authorEmail: user.email ?? '',
    content: String(comment?.content ?? '').substring(0, 200) + (comment?.content?.length > 200 ? '...' : ''),
    fullContent: comment?.content ?? '',
    postContent: String(post?.content ?? '').substring(0, 100) + (post?.content?.length > 100 ? '...' : ''),
    postId: post?._id ?? '',
    createdAt: comment?.created_at ?? comment?.createdAt ?? null,
  };
}

function formatDate(value) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return date.toLocaleString('fr-FR');
}

function applyFilter({ inputData, comparator, filters }) {
  const { query, postId } = filters;

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
        row.content.toLowerCase().includes(q) ||
        row.author.toLowerCase().includes(q) ||
        row.authorEmail.toLowerCase().includes(q)
    );
  }

  if (postId) {
    data = data.filter((row) => row.postId === postId);
  }

  return data;
}

export default function CommentsView({ sx }) {
  const table = useTable({ defaultOrderBy: 'createdAt' });
  const searchParams = useSearchParams();
  const selectedPostId = searchParams.get('postId') ?? '';

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [rows, setRows] = useState([]);
  const [openDeleteDialog, setOpenDeleteDialog] = useState(false);
  const [deleteRow, setDeleteRow] = useState(null);
  const [openDetailsDialog, setOpenDetailsDialog] = useState(false);
  const [detailsRow, setDetailsRow] = useState(null);

  const filters = useSetState({
    query: '',
    postId: selectedPostId,
  });
  const { state: currentFilters, setState: updateFilters } = filters;

  useEffect(() => {
    if (selectedPostId !== currentFilters.postId) {
      table.onResetPage();
      updateFilters({ postId: selectedPostId });
    }
  }, [currentFilters.postId, selectedPostId, table, updateFilters]);

  const loadRows = useCallback(async () => {
    try {
      setLoading(true);
      setError('');
      const result = await getAdminComments({ search: currentFilters.query, postId: currentFilters.postId });
      console.log('Comments loaded:', result);
      setRows(result.map(mapComment));
    } catch (err) {
      console.error('Error loading comments:', err);
      setError('Erreur lors du chargement des commentaires');
      toast.error('Impossible de charger les commentaires');
    } finally {
      setLoading(false);
    }
  }, [currentFilters]);

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
  const canReset = currentFilters.query.trim() !== '' || currentFilters.postId.trim() !== '';

  const handleFilterQuery = useCallback(
    (event) => {
      table.onResetPage();
      updateFilters({ query: event.target.value });
    },
    [table, updateFilters]
  );

  const handleFilterPostId = useCallback(
    (event) => {
      table.onResetPage();
      updateFilters({ postId: event.target.value });
    },
    [table, updateFilters]
  );

  const handleResetFilters = useCallback(() => {
    table.onResetPage();
    updateFilters({ query: '', postId: '' });
  }, [table, updateFilters]);

  const handleDelete = useCallback(
    async (row) => {
      setDeleteRow(row);
      setOpenDeleteDialog(true);
    },
    []
  );

  const confirmDelete = useCallback(async () => {
    if (!deleteRow) return;

    try {
      await adminDeleteComment(deleteRow.id);
      toast.success('Commentaire supprimé');
      setOpenDeleteDialog(false);
      setDeleteRow(null);
      await loadRows();
    } catch {
      toast.error('Échec de suppression du commentaire');
    }
  }, [deleteRow, loadRows]);

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
          <Typography variant="h4">Gestion des Commentaires</Typography>
          {currentFilters.postId ? (
            <Chip
              color="info"
              variant="soft"
              label={`Publication: ${currentFilters.postId}`}
              sx={{ alignSelf: { xs: 'flex-start', md: 'center' } }}
            />
          ) : null}
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
              fullWidth
              label="ID Post"
              placeholder="Filtrer par post ID"
              value={currentFilters.postId}
              onChange={handleFilterPostId}
            />

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
                          <TableCell>
                            <Stack>
                              <Typography variant="body2" fontWeight="medium">
                                {row.author}
                              </Typography>
                              <Typography variant="caption" color="text.secondary">
                                {row.authorEmail}
                              </Typography>
                            </Stack>
                          </TableCell>
                          <TableCell sx={{ maxWidth: 400 }}>
                            <Typography variant="body2" noWrap>
                              {row.content}
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Typography variant="body2" noWrap>
                              {row.postContent}
                            </Typography>
                          </TableCell>
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
                          <TableCell colSpan={5} align="center">
                            Aucun commentaire trouvé
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

        <Dialog open={openDeleteDialog} onClose={() => setOpenDeleteDialog(false)}>
          <DialogTitle>Supprimer le commentaire</DialogTitle>
          <DialogContent>
            <Typography>Êtes-vous sûr de vouloir supprimer ce commentaire ?</Typography>
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setOpenDeleteDialog(false)} color="inherit">
              Annuler
            </Button>
            <Button variant="contained" color="error" onClick={confirmDelete}>
              Supprimer
            </Button>
          </DialogActions>
        </Dialog>

        <Dialog open={openDetailsDialog} onClose={closeDetails} fullWidth maxWidth="md">
          <DialogTitle>Détails du commentaire</DialogTitle>
          <DialogContent dividers>
            <Stack spacing={1.25}>
              <Typography variant="body2">
                <strong>Auteur:</strong> {detailsRow?.author ?? '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Email:</strong> {detailsRow?.authorEmail ?? '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Post ID:</strong> {detailsRow?.postId ?? '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Post:</strong> {detailsRow?.postContent ?? '-'}
              </Typography>
              <Typography variant="body2">
                <strong>Date création:</strong> {formatDate(detailsRow?.createdAt)}
              </Typography>
              <Typography variant="body2">
                <strong>Commentaire:</strong>
              </Typography>
              <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
                {detailsRow?.fullContent || '-'}
              </Typography>
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
