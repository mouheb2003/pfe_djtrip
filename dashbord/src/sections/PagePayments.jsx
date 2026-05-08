import { useSetState } from 'minimal-shared/hooks';
import { useMemo, useState, useEffect, useCallback } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Alert from '@mui/material/Alert';
import Paper from '@mui/material/Paper';
import Stack from '@mui/material/Stack';
import Table from '@mui/material/Table';
import Button from '@mui/material/Button';
import Tooltip from '@mui/material/Tooltip';
import MenuItem from '@mui/material/MenuItem';
import TableRow from '@mui/material/TableRow';
import TextField from '@mui/material/TextField';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import IconButton from '@mui/material/IconButton';
import Typography from '@mui/material/Typography';
import TableContainer from '@mui/material/TableContainer';
import CircularProgress from '@mui/material/CircularProgress';
import InputLabel from '@mui/material/InputLabel';
import FormControl from '@mui/material/FormControl';
import Select from '@mui/material/Select';
import Dialog from '@mui/material/Dialog';
import DialogTitle from '@mui/material/DialogTitle';
import DialogContent from '@mui/material/DialogContent';
import DialogActions from '@mui/material/DialogActions';

import { DashboardContent } from 'src/layouts/dashboard';
import { Get, Post } from 'src/Controller/function';

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
  { id: 'order_id', label: 'Order ID' },
  { id: 'user', label: 'User' },
  { id: 'amount', label: 'Amount' },
  { id: 'currency', label: 'Currency' },
  { id: 'status', label: 'Status' },
  { id: 'activity', label: 'Activity' },
  { id: 'inscription_status', label: 'Booking Status' },
  { id: 'created_at', label: 'Date' },
  { id: 'paid_at', label: 'Paid At' },
  { id: 'actions', label: '', align: 'right' },
];

function statusColor(status) {
  if (status === 'paid') return 'success';
  if (status === 'pending') return 'warning';
  if (status === 'failed') return 'error';
  if (status === 'cancelled') return 'default';
  if (status === 'refunded') return 'info';
  return 'default';
}

function normalizePayment(payment) {
  return {
    id: payment._id,
    order_id: payment.order_id || '-',
    user: payment.user_id ? {
      id: payment.user_id._id,
      fullname: payment.user_id.fullname || payment.user_id.email || '-',
      email: payment.user_id.email || '-',
    } : { fullname: '-', email: '-' },
    amount: payment.amount || 0,
    currency: payment.currency || 'USD',
    status: payment.status || 'pending',
    activity: payment.activity_id ? {
      id: payment.activity_id._id,
      titre: payment.activity_id.titre || payment.activity_title || '-',
    } : { titre: payment.activity_title || '-' },
    inscription_status: payment.inscription_id ? payment.inscription_id.statut : '-',
    created_at: payment.createdAt || null,
    paid_at: payment.paid_at || null,
    failed_at: payment.failed_at || null,
    refunded_at: payment.refunded_at || null,
    stripe_session_id: payment.stripe_session_id || '-',
    stripe_payment_intent_id: payment.stripe_payment_intent_id || '-',
    description: payment.description || '-',
  };
}

function applyFilter({ inputData, comparator, filters }) {
  const { query, status } = filters;

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
        row.order_id.toLowerCase().includes(q) ||
        row.user.fullname.toLowerCase().includes(q) ||
        row.user.email.toLowerCase().includes(q) ||
        row.activity.titre.toLowerCase().includes(q)
    );
  }

  if (status !== 'all') {
    data = data.filter((row) => row.status === status);
  }

  return data;
}

export function PaymentsView({ sx }) {
  const table = useTable({ defaultOrderBy: 'created_at', defaultOrder: 'desc' });

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [payments, setPayments] = useState([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const [refundDialogOpen, setRefundDialogOpen] = useState(false);
  const [selectedPayment, setSelectedPayment] = useState(null);
  const [refundReason, setRefundReason] = useState('');
  const [refunding, setRefunding] = useState(false);

  const filters = useSetState({
    query: '',
    status: 'all',
  });
  const { state: currentFilters, setState: updateFilters } = filters;

  const fetchPayments = useCallback(async () => {
    try {
      setLoading(true);
      setError('');

      const data = await Get(
        `/api/v1/payments/all?page=${page}&limit=${rowsPerPage}${currentFilters.status !== 'all' ? `&status=${currentFilters.status}` : ''}`
      );

      setPayments(data.payments.map((payment) => normalizePayment(payment)));
      setTotal(data.total || 0);
    } catch (err) {
      setError('Erreur lors du chargement des paiements');
      toast.error('Impossible de récupérer les paiements');
      console.error('Error fetching payments:', err);
    } finally {
      setLoading(false);
    }
  }, [page, rowsPerPage, currentFilters.status]);

  useEffect(() => {
    fetchPayments();
  }, [fetchPayments]);

  const dataFiltered = useMemo(
    () => applyFilter({ inputData: payments, comparator: getComparator(table.order, table.orderBy), filters: currentFilters }),
    [payments, table.order, table.orderBy, currentFilters]
  );

  const denseHeight = table.dense ? 52 : 72;

  const handleChangePage = useCallback((newPage) => {
    setPage(newPage);
  }, []);

  const handleChangeRowsPerPage = useCallback((event) => {
    setRowsPerPage(parseInt(event.target.value, 10));
    setPage(1);
  }, []);

  const handleFilterStatus = useCallback((event) => {
    updateFilters({ status: event.target.value });
    setPage(1);
  }, [updateFilters]);

  const handleFilterName = useCallback((event) => {
    updateFilters({ query: event.target.value });
  }, [updateFilters]);

  const handleRefundClick = useCallback((payment) => {
    setSelectedPayment(payment);
    setRefundReason('');
    setRefundDialogOpen(true);
  }, []);

  const handleRefundConfirm = useCallback(async () => {
    if (!selectedPayment) return;

    try {
      setRefunding(true);
      await Post(`/api/v1/payments/${selectedPayment.id}/refund`, { reason: refundReason });
      toast.success('Payment refunded successfully');
      setRefundDialogOpen(false);
      setSelectedPayment(null);
      setRefundReason('');
      fetchPayments();
    } catch (err) {
      toast.error('Failed to refund payment');
      console.error('Error refunding payment:', err);
    } finally {
      setRefunding(false);
    }
  }, [selectedPayment, refundReason, fetchPayments]);

  const handleRefundCancel = useCallback(() => {
    setRefundDialogOpen(false);
    setSelectedPayment(null);
    setRefundReason('');
  }, []);

  return (
    <DashboardContent>
      <Box
        sx={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          mb: 5,
        }}
      >
        <Typography variant="h4">Payments</Typography>

        <Button
          variant="contained"
          color="primary"
          startIcon={<Iconify icon="eva:refresh-fill" />}
          onClick={fetchPayments}
          disabled={loading}
        >
          Refresh
        </Button>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 3 }}>
          {error}
        </Alert>
      )}

      <Card sx={{ ...sx }}>
        <Stack
          spacing={2}
          alignItems={{ xs: 'flex-end', md: 'center' }}
          direction={{
            xs: 'column',
            md: 'row',
          }}
          sx={{
            p: 2.5,
          }}
        >
          <FormControl sx={{ width: { xs: '100%', md: 200 } }}>
            <InputLabel>Status</InputLabel>
            <Select
              value={currentFilters.status}
              onChange={handleFilterStatus}
              label="Status"
              size="small"
            >
              <MenuItem value="all">All</MenuItem>
              <MenuItem value="paid">Paid</MenuItem>
              <MenuItem value="pending">Pending</MenuItem>
              <MenuItem value="failed">Failed</MenuItem>
              <MenuItem value="cancelled">Cancelled</MenuItem>
              <MenuItem value="refunded">Refunded</MenuItem>
            </Select>
          </FormControl>

          <TextField
            fullWidth
            value={currentFilters.query}
            onChange={handleFilterName}
            placeholder="Search payments..."
            size="small"
            InputProps={{
              startAdornment: (
                <Iconify icon="eva:search-fill" sx={{ mr: 1, color: 'text.disabled' }} />
              ),
            }}
            sx={{ width: { xs: '100%', md: 300 } }}
          />
        </Stack>

        <TableContainer sx={{ position: 'relative', overflow: 'unset' }}>
          <Scrollbar>
            <Table size={table.dense ? 'small' : 'medium'} sx={{ minWidth: 800 }}>
              <TableHeadCustom
                order={table.order}
                orderBy={table.orderBy}
                headCells={TABLE_HEAD}
                rowCount={dataFiltered.length}
                onSort={table.onSort}
              />

              <TableBody>
                {loading ? (
                  <TableRow>
                    <TableCell colSpan={TABLE_HEAD.length} align="center" sx={{ py: 5 }}>
                      <CircularProgress />
                    </TableCell>
                  </TableRow>
                ) : dataFiltered.length === 0 ? (
                  <TableEmptyRows height={denseHeight} emptyRows={emptyRows(table.page, table.rowsPerPage, dataFiltered.length)} />
                ) : (
                  dataFiltered
                    .slice(
                      table.page * table.rowsPerPage,
                      table.page * table.rowsPerPage + table.rowsPerPage
                    )
                    .map((row) => (
                      <TableRow hover key={row.id}>
                        <TableCell>
                          <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                            {row.order_id}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Stack direction="column">
                            <Typography variant="body2" fontWeight="medium">
                              {row.user.fullname}
                            </Typography>
                            <Typography variant="caption" color="text.secondary">
                              {row.user.email}
                            </Typography>
                          </Stack>
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2" fontWeight="medium">
                            {row.amount.toFixed(2)}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2">{row.currency}</Typography>
                        </TableCell>
                        <TableCell>
                          <Label color={statusColor(row.status)} variant="soft">
                            {row.status.toUpperCase()}
                          </Label>
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2" noWrap sx={{ maxWidth: 200 }}>
                            {row.activity.titre}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          {row.inscription_status !== '-' ? (
                            <Label
                              color={
                                row.inscription_status === 'approuvee'
                                  ? 'success'
                                  : row.inscription_status === 'refusee'
                                    ? 'error'
                                    : row.inscription_status === 'pending'
                                      ? 'warning'
                                      : 'default'
                              }
                              variant="soft"
                            >
                              {row.inscription_status.toUpperCase()}
                            </Label>
                          ) : (
                            <Typography variant="caption" color="text.secondary">
                              -
                            </Typography>
                          )}
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2">
                            {row.created_at
                              ? new Date(row.created_at).toLocaleDateString('fr-FR', {
                                  day: '2-digit',
                                  month: '2-digit',
                                  year: 'numeric',
                                  hour: '2-digit',
                                  minute: '2-digit',
                                })
                              : '-'}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2">
                            {row.paid_at
                              ? new Date(row.paid_at).toLocaleDateString('fr-FR', {
                                  day: '2-digit',
                                  month: '2-digit',
                                  year: 'numeric',
                                  hour: '2-digit',
                                  minute: '2-digit',
                                })
                              : row.failed_at
                                ? new Date(row.failed_at).toLocaleDateString('fr-FR', {
                                    day: '2-digit',
                                    month: '2-digit',
                                    year: 'numeric',
                                    hour: '2-digit',
                                    minute: '2-digit',
                                  })
                                : row.refunded_at
                                  ? new Date(row.refunded_at).toLocaleDateString('fr-FR', {
                                      day: '2-digit',
                                      month: '2-digit',
                                      year: 'numeric',
                                      hour: '2-digit',
                                      minute: '2-digit',
                                    })
                                  : '-'}
                          </Typography>
                        </TableCell>
                        <TableCell align="right">
                          {row.status === 'paid' && (
                            <Tooltip title="Refund Payment">
                              <IconButton
                                onClick={() => handleRefundClick(row)}
                                color="error"
                                size="small"
                              >
                                <Iconify icon="eva:arrow-undo-fill" width={20} />
                              </IconButton>
                            </Tooltip>
                          )}
                        </TableCell>
                      </TableRow>
                    ))
                )}

                <TableEmptyRows
                  height={denseHeight}
                  emptyRows={emptyRows(table.page, table.rowsPerPage, dataFiltered.length)}
                />
              </TableBody>
            </Table>
          </Scrollbar>
        </TableContainer>

        <TablePaginationCustom
          count={total}
          page={page - 1}
          rowsPerPage={rowsPerPage}
          onPageChange={handleChangePage}
          onRowsPerPageChange={handleChangeRowsPerPage}
          dense={table.dense}
          onChangeDense={table.onChangeDense}
        />
      </Card>

      <Dialog open={refundDialogOpen} onClose={handleRefundCancel} maxWidth="sm" fullWidth>
        <DialogTitle>Refund Payment</DialogTitle>
        <DialogContent>
          <Stack spacing={2} sx={{ mt: 2 }}>
            <Typography variant="body2">
              Are you sure you want to refund <strong>{selectedPayment?.amount.toFixed(2)} {selectedPayment?.currency}</strong> to <strong>{selectedPayment?.user.fullname}</strong>?
            </Typography>
            <TextField
              fullWidth
              label="Refund Reason (optional)"
              multiline
              rows={3}
              value={refundReason}
              onChange={(e) => setRefundReason(e.target.value)}
              placeholder="Enter reason for refund..."
            />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={handleRefundCancel} disabled={refunding}>
            Cancel
          </Button>
          <Button
            onClick={handleRefundConfirm}
            variant="contained"
            color="error"
            disabled={refunding}
            startIcon={refunding ? <CircularProgress size={20} /> : <Iconify icon="eva:arrow-undo-fill" />}
          >
            {refunding ? 'Refunding...' : 'Confirm Refund'}
          </Button>
        </DialogActions>
      </Dialog>
    </DashboardContent>
  );
}
