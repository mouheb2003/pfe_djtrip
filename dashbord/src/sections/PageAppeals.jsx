import { useCallback, useEffect, useMemo, useState } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Stack from '@mui/material/Stack';
import Table from '@mui/material/Table';
import Button from '@mui/material/Button';
import Tooltip from '@mui/material/Tooltip';
import TableRow from '@mui/material/TableRow';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import IconButton from '@mui/material/IconButton';
import Typography from '@mui/material/Typography';
import TableContainer from '@mui/material/TableContainer';
import CircularProgress from '@mui/material/CircularProgress';
import Avatar from '@mui/material/Avatar';
import StackMui from '@mui/material/Stack';
import TextField from '@mui/material/TextField';
import MenuItem from '@mui/material/MenuItem';
import InputAdornment from '@mui/material/InputAdornment';
import Menu from '@mui/material/Menu';

import { Iconify } from 'src/components/iconify';
import { toast } from 'src/components/snackbar';
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

import { appealService } from 'src/services/appealService';

const TABLE_HEAD = [
  { id: 'selection', label: '', align: 'center', disableSort: true, width: 56 },
  { id: 'user', label: 'User' },
  { id: 'subject', label: 'Subject' },
  { id: 'message', label: 'Message' },
  { id: 'status', label: 'Status' },
  { id: 'submitted', label: 'Submitted' },
  { id: 'actions', label: '', align: 'right' },
];

function normalize(appeal) {
  return {
    id: appeal?._id || appeal?.id,
    user: appeal?.user_id?.fullname || appeal?.user?.fullname || 'Unknown',
    userEmail: appeal?.user_id?.email || appeal?.user?.email || '-',
    subject: appeal?.subject || appeal?.title || '-',
    message: appeal?.message || appeal?.body || '-',
    status: appeal?.status || 'pending',
    submitted: appeal?.created_at || appeal?.createdAt || appeal?.createdAtISO || null,
    raw: appeal,
  };
}

export function AppealsView() {
  const table = useTable({ defaultOrderBy: 'submitted' });

  const [loading, setLoading] = useState(true);
  const [appeals, setAppeals] = useState([]);
  const [filters, setFilters] = useState({ query: '', status: 'all' });
  const [selected, setSelected] = useState([]);
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [current, setCurrent] = useState(null);
  const [busyId, setBusyId] = useState(null);
  const [statusMenuAnchor, setStatusMenuAnchor] = useState(null);
  const [statusMenuId, setStatusMenuId] = useState(null);

  const fetchAppeals = useCallback(async () => {
    try {
      setLoading(true);
      const res = await appealService.getAllAppeals({ limit: 100, page: 1 });
      const list = res?.appeals ?? res?.data ?? res?.items ?? [];
      setAppeals(Array.isArray(list) ? list.map(normalize) : []);
    } catch (err) {
      console.error('Failed to fetch appeals', err);
      toast.error('Impossible de récupérer les appeals');
      setAppeals([]);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchAppeals();
  }, [fetchAppeals]);

  const dataFiltered = useMemo(() => {
    const comparator = getComparator(table.order, table.orderBy);
    const stabilized = appeals.map((el, idx) => [el, idx]);
    stabilized.sort((a, b) => {
      const order = comparator(a[0], b[0]);
      if (order !== 0) return order;
      return a[1] - b[1];
    });
    return stabilized.map((el) => el[0]);
  }, [appeals, table.order, table.orderBy]);

  const finalData = useMemo(() => {
    let data = dataFiltered;

    if (filters.query && String(filters.query).trim()) {
      const q = String(filters.query).toLowerCase();
      data = data.filter(
        (r) =>
          (r.user || '').toLowerCase().includes(q) ||
          (r.userEmail || '').toLowerCase().includes(q) ||
          (r.subject || '').toLowerCase().includes(q) ||
          (r.message || '').toLowerCase().includes(q)
      );
    }

    if (filters.status && filters.status !== 'all') {
      data = data.filter((r) => String(r.status || '').toLowerCase() === String(filters.status).toLowerCase());
    }

    return data;
  }, [dataFiltered, filters]);

  const denseHeight = 64;

  const handleView = (row) => {
    setCurrent(row);
    setDetailsOpen(true);
  };

  const handleFilterChange = (key, value) => {
    setFilters((p) => ({ ...p, [key]: value }));
    // reset page when filters change
    if (table.setPage) table.setPage(0);
  };

  const handleDeleteAppeal = useCallback(
    async (id) => {
      console.log('[DEBUG] handleDeleteAppeal called with id:', id);
      const confirmed = window.confirm('Are you sure you want to delete this appeal?');
      if (!confirmed) return;

      try {
        setBusyId(id);
        console.log('[DEBUG] Calling appealService.deleteAppeal...');

        if (appealService.deleteAppeal) {
          const result = await appealService.deleteAppeal(id);
          console.log('[DEBUG] Delete successful:', result);
        } else {
          console.warn('[DEBUG] deleteAppeal not implemented in appealService');
          throw new Error('deleteAppeal not implemented');
        }

        toast.success('Appeal deleted successfully');
        setAppeals((prev) => prev.filter((a) => a.id !== id));
      } catch (err) {
        console.error('[DEBUG] Failed to delete appeal:', err);
        console.error('[DEBUG] Error response:', err.response?.data);
        console.error('[DEBUG] Error status:', err.response?.status);
        const errorMsg = err.response?.data?.message || err.message || 'Unknown error';
        toast.error(`Failed to delete appeal: ${errorMsg}`);
      } finally {
        setBusyId(null);
      }
    },
    []
  );
  const handleOpenStatusMenu = useCallback((event, id) => {
    setStatusMenuAnchor(event.currentTarget);
    setStatusMenuId(id);
  }, []);

  const handleCloseStatusMenu = useCallback(() => {
    setStatusMenuAnchor(null);
    setStatusMenuId(null);
  }, []);

  const handleUpdateStatus = useCallback(
    async (id, newStatus) => {
      try {
        setBusyId(id);
        await appealService.updateAppealStatus(id, newStatus);
        toast.success(`Appeal status updated to ${newStatus}`);
        setAppeals((prev) =>
          prev.map((a) => (a.id === id ? { ...a, status: newStatus } : a))
        );
        handleCloseStatusMenu();
      } catch (err) {
        console.error('[DEBUG] Failed to update appeal status:', err);
        const errorMsg = err.response?.data?.message || err.message || 'Unknown error';
        toast.error(`Failed to update status: ${errorMsg}`);
      } finally {
        setBusyId(null);
      }
    },
    [handleCloseStatusMenu]
  );
  return (
    <Card sx={{ maxWidth: '100%' }}>
      <Box sx={{ p: 2, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h3">Appeals</Typography>
        <Button startIcon={<Iconify icon="eva:refresh-fill" />} onClick={fetchAppeals}>Refresh</Button>
      </Box>

      {/* Search & Filters */}
      <Box sx={{ px: 2, pb: 2 }}>
        <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2} alignItems="center">
          <TextField
            size="small"
            placeholder="Search by user, email, subject or message..."
            value={filters.query}
            onChange={(e) => handleFilterChange('query', e.target.value)}
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <Iconify icon="eva:search-fill" />
                </InputAdornment>
              ),
            }}
            sx={{ minWidth: 320 }}
          />

          <TextField
            select
            size="small"
            value={filters.status}
            onChange={(e) => handleFilterChange('status', e.target.value)}
            sx={{ width: 180 }}
          >
            <MenuItem value="all">All statuses</MenuItem>
            <MenuItem value="pending">Pending</MenuItem>
            <MenuItem value="reviewed">Reviewed</MenuItem>
            <MenuItem value="accepted">Accepted</MenuItem>
            <MenuItem value="rejected">Rejected</MenuItem>
          </TextField>

        </Stack>
      </Box>

      <Scrollbar>
        <TableContainer sx={{ minWidth: '100%' }}>
          <Table size={table.size}>
            <TableHeadCustom
              order={table.order}
              orderBy={table.orderBy}
              onSort={table.onSort}
              headCells={TABLE_HEAD}
              rowCount={finalData.length}
              numSelected={table.selected?.length || 0}
              onSelectAllRows={(checked) => table.onSelectAllRows(checked, finalData.map((r) => r.id))}
            />

            <TableBody>
              {loading ? (
                <TableRow>
                  <TableCell colSpan={TABLE_HEAD.length} align="center">
                    <CircularProgress />
                  </TableCell>
                </TableRow>
              ) : (
                rowInPage(finalData, table.page, table.rowsPerPage).map((row) => (
                  <TableRow hover key={row.id}>
                    <TableCell align="center">{/* selection placeholder */}</TableCell>
                    <TableCell>
                      <StackMui direction="row" alignItems="center" spacing={2}>
                        <Avatar>{(row.user || 'U').charAt(0)}</Avatar>
                        <div>
                          <div style={{ fontWeight: 700 }}>{row.user}</div>
                          <div style={{ fontSize: 12, color: 'gray' }}>{row.userEmail}</div>
                        </div>
                      </StackMui>
                    </TableCell>
                    <TableCell>{row.subject}</TableCell>
                    <TableCell style={{ maxWidth: 320, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{row.message}</TableCell>
                    <TableCell>
                      <TagStatus status={row.status} />
                    </TableCell>
                    <TableCell>{row.submitted ? new Date(row.submitted).toLocaleString() : '-'}</TableCell>
                    <TableCell align="right">
                      <Stack direction="row" spacing={0.5}>
                        <Tooltip title="View Details">
                          <IconButton onClick={() => handleView(row)} size="small">
                            <Iconify icon="eva:eye-fill" />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Update Status">
                          <IconButton
                            onClick={(e) => handleOpenStatusMenu(e, row.id)}
                            size="small"
                            sx={{ color: 'info.main' }}
                          >
                            <Iconify icon="eva:edit-2-outline" />
                          </IconButton>
                        </Tooltip>
                        <Tooltip title="Delete">
                          <IconButton
                            onClick={() => handleDeleteAppeal(row.id)}
                            disabled={busyId === row.id}
                            size="small"
                            sx={{ color: 'error.main' }}
                          >
                            <Iconify icon="eva:trash-2-outline" />
                          </IconButton>
                        </Tooltip>
                      </Stack>
                    </TableCell>
                  </TableRow>
                ))
              )}

              <TableEmptyRows height={denseHeight} emptyRows={emptyRows(table.page, table.rowsPerPage, finalData.length)} />
            </TableBody>
          </Table>
        </TableContainer>
      </Scrollbar>

      <Box sx={{ p: 2 }}>
        <TablePaginationCustom
          page={table.page}
          dense={table.dense}
          count={finalData.length}
          rowsPerPage={table.rowsPerPage}
          onPageChange={table.onChangePage}
          onChangeDense={table.onChangeDense}
          onRowsPerPageChange={table.onChangeRowsPerPage}
        />
      </Box>

      {/* Details modal simple */}
      {detailsOpen && current && (
        <SimpleDetailsDialog open={detailsOpen} row={current} onClose={() => setDetailsOpen(false)} />
      )}

      {/* Status Update Menu */}
      <Menu
        open={Boolean(statusMenuAnchor)}
        anchorEl={statusMenuAnchor}
        onClose={handleCloseStatusMenu}
      >
        <MenuItem onClick={() => handleUpdateStatus(statusMenuId, 'pending')}>
          Pending
        </MenuItem>
        <MenuItem onClick={() => handleUpdateStatus(statusMenuId, 'reviewed')}>
          Reviewed
        </MenuItem>
        <MenuItem onClick={() => handleUpdateStatus(statusMenuId, 'accepted')}>
          Accepted
        </MenuItem>
        <MenuItem onClick={() => handleUpdateStatus(statusMenuId, 'rejected')}>
          Rejected
        </MenuItem>
      </Menu>
    </Card>
  );
}

function TagStatus({ status }) {
  const map = {
    pending: { color: 'warning', label: 'Pending' },
    reviewed: { color: 'info', label: 'Reviewed' },
    accepted: { color: 'success', label: 'Accepted' },
    rejected: { color: 'error', label: 'Rejected' },
  };
  const meta = map[status] || { color: 'default', label: status };
  return (
    <Box component="span" sx={{ px: 1, py: 0.5, borderRadius: 1, bgcolor: `${meta.color}.100`, color: `${meta.color}.700`, fontWeight: 700 }}>{meta.label}</Box>
  );
}

function SimpleDetailsDialog({ open, row, onClose }) {
  return (
    <div role="dialog" aria-modal>
      <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.3)' }} onClick={onClose} />
      <div style={{ position: 'fixed', left: '50%', top: '50%', transform: 'translate(-50%,-50%)', background: '#fff', padding: 20, borderRadius: 12, width: 640 }}>
        <h3>Appeal Details</h3>
        <div style={{ marginBottom: 12 }}><strong>User:</strong> {row.user} &lt;{row.userEmail}&gt;</div>
        <div style={{ marginBottom: 12 }}><strong>Subject:</strong> {row.subject}</div>
        <div style={{ marginBottom: 12 }}><strong>Message:</strong><div style={{ marginTop: 6 }}>{row.message}</div></div>
        <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 8 }}>
          <Button variant="contained" onClick={onClose}>Close</Button>
        </div>
      </div>
    </div>
  );
}
