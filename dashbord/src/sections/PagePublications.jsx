import { useSetState } from 'minimal-shared/hooks';
import { useMemo, useState, useEffect, useCallback } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Chip from '@mui/material/Chip';
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
import List from '@mui/material/List';
import ListItem from '@mui/material/ListItem';
import Divider from '@mui/material/Divider';
import ListItemText from '@mui/material/ListItemText';
import ListItemButton from '@mui/material/ListItemButton';

import { DashboardContent } from 'src/layouts/dashboard';
import { paths } from 'src/routes/paths';
import { useRouter } from 'src/routes/hooks';
import {
  getPublications,
  createPublication,
  deletePublication,
  getAdminComments,
  getAdminCommentsPage,
  getPostCommentsByPostId,
  getPostCommentsByPostRoute,
  getPublicationById,
  getUserById,
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
    likedBy: Array.isArray(post?.liked_by)
      ? post.liked_by
      : Array.isArray(post?.likedBy)
        ? post.likedBy
        : [],
    commentsCount: post?.comments_count ?? 0,
    createdAt: post?.createdAt ?? null,
    updatedAt: post?.updatedAt ?? null,
    rawPost: post,
  };
}

function formatDate(value) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return date.toLocaleString('fr-FR');
}

function isVideoMedia(url) {
  const value = String(url ?? '').toLowerCase();
  return /\.(mp4|webm|ogg|mov|m4v)(\?|$)/.test(value) || value.includes('/video/upload/');
}

function toLikeUser(item, index) {
  if (typeof item === 'string') {
    return {
      id: item,
      name: `Utilisateur ${index + 1}`,
      email: '',
      likedAt: null,
    };
  }

  const rawUser = item?.user_id ?? item?.user ?? item;

  return {
    id: rawUser?._id ?? rawUser?.id ?? item?._id ?? item?.id ?? `user-${index}`,
    name:
      rawUser?.fullname ??
      rawUser?.name ??
      rawUser?.username ??
      rawUser?.email ??
      `Utilisateur ${index + 1}`,
    email: rawUser?.email ?? '',
    likedAt: item?.liked_at ?? item?.likedAt ?? item?.createdAt ?? item?.date ?? null,
  };
}

function extractLikeUsers(post) {
  const candidates = [
    post?.likes,
    post?.likes_users,
    post?.likedBy,
    post?.liked_by,
    post?.rawPost?.liked_by,
    post?.rawPost?.likedBy,
    post?.likesDetails,
  ];

  const list = candidates.find((value) => Array.isArray(value)) ?? [];
  return list.map(toLikeUser);
}

function mapCommentAuthor(comment, index) {
  const user = comment?.user_id ?? comment?.author_id ?? comment?.user ?? null;
  const name = user?.fullname ?? user?.name ?? user?.username ?? user?.email ?? `Utilisateur ${index + 1}`;
  const email = user?.email ?? '';
  const content = String(comment?.content ?? comment?.text ?? '').trim();

  return {
    id: comment?._id ?? comment?.id ?? `comment-${index}`,
    name,
    email,
    content: content || '-',
    createdAt: comment?.created_at ?? comment?.createdAt ?? null,
  };
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
  const router = useRouter();

  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [rows, setRows] = useState([]);
  const [openDialog, setOpenDialog] = useState(false);
  const [openDetailsDialog, setOpenDetailsDialog] = useState(false);
  const [detailsRow, setDetailsRow] = useState(null);
  const [likesDialogOpen, setLikesDialogOpen] = useState(false);
  const [commentsDialogOpen, setCommentsDialogOpen] = useState(false);
  const [likesLoading, setLikesLoading] = useState(false);
  const [commentsLoading, setCommentsLoading] = useState(false);
  const [likesUsers, setLikesUsers] = useState([]);
  const [postComments, setPostComments] = useState([]);
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

  const openDetails = useCallback(async (row) => {
    if (!row?.id) return;

    setDetailsRow(row);
    setOpenDetailsDialog(true);

    try {
      const freshPost = await getPublicationById(row.id);
      if (freshPost) {
        setDetailsRow(mapPost(freshPost));
      }
    } catch {
      // Keep existing row data if fetching fresh details fails.
    }
  }, []);

  const closeDetails = useCallback(() => {
    setOpenDetailsDialog(false);
    setDetailsRow(null);
    setLikesDialogOpen(false);
    setCommentsDialogOpen(false);
    setLikesUsers([]);
    setPostComments([]);
  }, []);

  const handleOpenLikesDialog = useCallback(async () => {
    if (!detailsRow?.id) return;

    setLikesDialogOpen(true);
    setLikesLoading(true);

    try {
      const localPost = rows.find((row) => String(row.id) === String(detailsRow.id));
      const freshPost = await getPublicationById(detailsRow.id);
      const postData = freshPost ? mapPost(freshPost) : localPost ?? detailsRow;
      if (freshPost) setDetailsRow(postData);

      const users = extractLikeUsers(postData);
      if (users.length > 0) {
        const enriched = await Promise.all(
          users.map(async (user) => {
            if (!user?.id) return user;

            const looksGenericName = /^Utilisateur\s+\d+$/i.test(String(user.name ?? ''));
            if (!looksGenericName && user.email) return user;

            try {
              const fullUser = await getUserById(user.id);
              return {
                ...user,
                name:
                  fullUser?.fullname ??
                  fullUser?.name ??
                  fullUser?.username ??
                  user.name,
                email: fullUser?.email ?? user.email,
              };
            } catch {
              return user;
            }
          })
        );

        const uniqueUsers = Array.from(
          new Map(enriched.map((item) => [String(item.id), item])).values()
        );
        setLikesUsers(uniqueUsers);
      } else {
        const fallbackCount = Number(postData?.likesCount ?? 0);
        setLikesUsers(
          fallbackCount > 0
            ? Array.from({ length: fallbackCount }, (_, index) => ({
                id: `like-${index + 1}`,
                name: `Utilisateur ${index + 1}`,
                email: '',
                likedAt: null,
              }))
            : []
        );
      }
    } catch {
      setLikesUsers([]);
      toast.error('Impossible de charger les likes');
    } finally {
      setLikesLoading(false);
    }
  }, [detailsRow, rows]);

  const handleOpenLikedUserProfile = useCallback(
    (user) => {
      if (!user?.id) return;

      setLikesDialogOpen(false);
      setOpenDetailsDialog(false);
      router.push(`${paths.dashboard.three}?userId=${encodeURIComponent(user.id)}`);
    },
    [router]
  );

  const handleOpenCommentsDialog = useCallback(async () => {
    if (!detailsRow?.id) return;

    setCommentsDialogOpen(true);
    setCommentsLoading(true);

    try {
      const collected = [];

      try {
        const adminByPost = await getAdminComments({ postId: detailsRow.id, limit: 200 });
        if (Array.isArray(adminByPost) && adminByPost.length) collected.push(...adminByPost);
      } catch {
        // Ignore source failure and continue with other sources.
      }

      try {
        const commentsModule = await getPostCommentsByPostId(detailsRow.id, { limit: 200 });
        if (Array.isArray(commentsModule) && commentsModule.length) collected.push(...commentsModule);
      } catch {
        // Ignore source failure and continue with other sources.
      }

      try {
        const postsModule = await getPostCommentsByPostRoute(detailsRow.id, { limit: 200 });
        if (Array.isArray(postsModule) && postsModule.length) collected.push(...postsModule);
      } catch {
        // Ignore source failure and continue with other sources.
      }

      try {
        const allComments = await getAdminComments({ limit: 500 });
        const filtered = (allComments ?? []).filter((comment) => {
          const commentPostId =
            comment?.post_id?._id ?? comment?.post_id?.id ?? comment?.post_id ?? comment?.postId;
          return String(commentPostId ?? '') === String(detailsRow.id);
        });
        if (filtered.length) collected.push(...filtered);
      } catch {
        // Ignore source failure and continue.
      }

      if (collected.length === 0) {
        try {
          const pageSize = 100;
          let page = 1;
          let totalPages = 1;

          while (page <= totalPages) {
            const result = await getAdminCommentsPage({ page, limit: pageSize });
            const filtered = (result?.comments ?? []).filter((comment) => {
              const commentPostId =
                comment?.post_id?._id ??
                comment?.post_id?.id ??
                comment?.post_id ??
                comment?.postId;
              return String(commentPostId ?? '') === String(detailsRow.id);
            });

            if (filtered.length) {
              collected.push(...filtered);
            }

            totalPages = Number(result?.pagination?.totalPages ?? 1);
            page += 1;

            if ((detailsRow?.commentsCount ?? 0) > 0 && collected.length >= detailsRow.commentsCount) {
              break;
            }
          }
        } catch {
          // Ignore source failure.
        }
      }

      const mapped = collected.map(mapCommentAuthor);
      const uniqueById = Array.from(new Map(mapped.map((item) => [item.id, item])).values());
      setPostComments(uniqueById);
    } catch {
      setPostComments([]);
      toast.error('Impossible de charger les commentaires');
    } finally {
      setCommentsLoading(false);
    }
  }, [detailsRow]);

  const handleOpenComments = useCallback(
    (row) => {
      if (!row?.id) return;
      router.push(`${paths.dashboard.comments}?postId=${encodeURIComponent(row.id)}`);
    },
    [router]
  );

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
                            <Tooltip title="Voir commentaires">
                              <IconButton color="primary" onClick={() => handleOpenComments(row)}>
                                <Iconify icon="solar:chat-round-dots-bold" />
                              </IconButton>
                            </Tooltip>
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
            <Stack spacing={2}>
              <Stack direction="row" spacing={1} flexWrap="wrap" useFlexGap>
                <Chip size="small" label={`Auteur: ${detailsRow?.author ?? '-'}`} />
                <Chip size="small" label={`Type: ${detailsRow?.postType ?? '-'}`} />
                <Chip size="small" label={`Audience: ${detailsRow?.audience ?? '-'}`} />
                <Chip
                  size="small"
                  color="primary"
                  label={`Likes: ${detailsRow?.likesCount ?? 0}`}
                  onClick={handleOpenLikesDialog}
                  sx={{ cursor: 'pointer' }}
                />
                <Chip
                  size="small"
                  color="info"
                  label={`Commentaires: ${detailsRow?.commentsCount ?? 0}`}
                  onClick={handleOpenCommentsDialog}
                  sx={{ cursor: 'pointer' }}
                />
              </Stack>

              <Card variant="outlined" sx={{ p: 2 }}>
                <Typography variant="subtitle2" sx={{ mb: 1 }}>
                  Contenu
                </Typography>
                <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
                  {detailsRow?.content || '-'}
                </Typography>
              </Card>

              <Stack spacing={0.75}>
                <Typography variant="subtitle2">Médias</Typography>
                {(detailsRow?.imageUrls ?? []).length ? (
                  <Box
                    sx={{
                      display: 'grid',
                      gridTemplateColumns: { xs: '1fr', sm: '1fr 1fr' },
                      gap: 1,
                    }}
                  >
                    {detailsRow.imageUrls.map((url, index) => (
                      <Box
                        key={`${url}-${index}`}
                        sx={{
                          borderRadius: 1.5,
                          overflow: 'hidden',
                          bgcolor: 'grey.100',
                          border: (theme) => `1px solid ${theme.palette.divider}`,
                          minHeight: 220,
                        }}
                      >
                        {isVideoMedia(url) ? (
                          <Box
                            component="video"
                            src={url}
                            controls
                            sx={{ width: '100%', height: '100%', maxHeight: 360, objectFit: 'cover' }}
                          />
                        ) : (
                          <Box
                            component="img"
                            src={url}
                            alt={`media-${index + 1}`}
                            sx={{ width: '100%', height: '100%', maxHeight: 360, objectFit: 'cover' }}
                          />
                        )}
                      </Box>
                    ))}
                  </Box>
                ) : (
                  <Typography variant="body2" color="text.secondary">
                    Aucun média
                  </Typography>
                )}
              </Stack>

              <Card variant="outlined" sx={{ p: 2 }}>
                <Stack spacing={0.75}>
                  <Typography variant="body2">
                    <strong>Lieu:</strong> {detailsRow?.locationLabel || '-'}
                  </Typography>
                  <Typography variant="body2">
                    <strong>Hashtags:</strong> {detailsRow?.hashtags || '-'}
                  </Typography>
                  <Typography variant="body2">
                    <strong>Date création:</strong> {formatDate(detailsRow?.createdAt)}
                  </Typography>
                  <Typography variant="body2">
                    <strong>Date modification:</strong> {formatDate(detailsRow?.updatedAt)}
                  </Typography>
                  <Typography variant="body2">
                    <strong>Trip link:</strong> {detailsRow?.tripLink || '-'}
                  </Typography>
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

        <Dialog
          open={likesDialogOpen}
          onClose={() => setLikesDialogOpen(false)}
          fullWidth
          maxWidth="xs"
        >
          <DialogTitle>Utilisateurs qui ont liké</DialogTitle>
          <DialogContent dividers>
            {likesLoading ? (
              <Stack alignItems="center" justifyContent="center" sx={{ py: 4 }}>
                <CircularProgress size={24} />
              </Stack>
            ) : likesUsers.length ? (
              <List disablePadding>
                {likesUsers.map((user, index) => (
                  <Box key={user.id}>
                    <ListItem disablePadding sx={{ px: 0 }}>
                      <ListItemButton onClick={() => handleOpenLikedUserProfile(user)}>
                        <ListItemText
                          primary={user.name}
                          secondary={`${user.email || user.id} • Like: ${user.likedAt ? formatDate(user.likedAt) : 'Date non disponible'}`}
                          primaryTypographyProps={{ variant: 'body2', fontWeight: 600 }}
                          secondaryTypographyProps={{ variant: 'caption' }}
                        />
                      </ListItemButton>
                    </ListItem>
                    {index < likesUsers.length - 1 ? <Divider /> : null}
                  </Box>
                ))}
              </List>
            ) : (
              <Typography variant="body2" color="text.secondary">
                Aucun détail utilisateur pour les likes.
              </Typography>
            )}
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setLikesDialogOpen(false)} color="inherit">
              Fermer
            </Button>
          </DialogActions>
        </Dialog>

        <Dialog
          open={commentsDialogOpen}
          onClose={() => setCommentsDialogOpen(false)}
          fullWidth
          maxWidth="sm"
        >
          <DialogTitle>Commentaires de la publication</DialogTitle>
          <DialogContent dividers>
            {commentsLoading ? (
              <Stack alignItems="center" justifyContent="center" sx={{ py: 4 }}>
                <CircularProgress size={24} />
              </Stack>
            ) : postComments.length ? (
              <List disablePadding>
                {postComments.map((comment, index) => (
                  <Box key={comment.id} sx={{ py: 1 }}>
                    <Typography variant="body2" fontWeight={600}>
                      {comment.name}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                      {comment.email || '-'}
                      {' • '}
                      {formatDate(comment.createdAt)}
                    </Typography>
                    <Typography variant="body2" sx={{ mt: 0.75, whiteSpace: 'pre-wrap' }}>
                      {comment.content}
                    </Typography>
                    {index < postComments.length - 1 ? <Divider sx={{ mt: 1.25 }} /> : null}
                  </Box>
                ))}
              </List>
            ) : (
              <Typography variant="body2" color="text.secondary">
                Aucun commentaire trouvé.
              </Typography>
            )}
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setCommentsDialogOpen(false)} color="inherit">
              Fermer
            </Button>
          </DialogActions>
        </Dialog>
      </Stack>
    </DashboardContent>
  );
}
