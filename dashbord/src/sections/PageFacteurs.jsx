import { useState, useEffect, useCallback, useMemo } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Chip from '@mui/material/Chip';
import Dialog from '@mui/material/Dialog';
import DialogTitle from '@mui/material/DialogTitle';
import DialogContent from '@mui/material/DialogContent';
import Stack from '@mui/material/Stack';
import Table from '@mui/material/Table';
import Button from '@mui/material/Button';
import TextField from '@mui/material/TextField';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import IconButton from '@mui/material/IconButton';
import TableRow from '@mui/material/TableRow';
import Typography from '@mui/material/Typography';
import CircularProgress from '@mui/material/CircularProgress';
import Tooltip from '@mui/material/Tooltip';

import { DashboardContent } from 'src/layouts/dashboard';
import { END_POINT } from 'src/Controller/endPoint';
import { Delete, Get } from 'src/Controller/function';
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
  { id: 'paymentId', label: 'Payment ID' },
  { id: 'payerName', label: 'Payeur' },
  { id: 'organizerName', label: 'Organisateur' },
  { id: 'activityTitle', label: 'Activité' },
  { id: 'amount', label: 'Montant' },
  { id: 'paidAt', label: 'Date de paiement' },
  { id: 'status', label: 'Statut' },
  { id: 'actions', label: '', align: 'right' },
];

function formatDate(value) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';

  return date.toLocaleString('fr-FR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function statusColor(status) {
  const normalized = String(status ?? '').toLowerCase();
  if (normalized === 'paid') return 'success';
  if (normalized === 'pending') return 'warning';
  if (normalized === 'failed') return 'error';
  if (normalized === 'cancelled') return 'default';
  if (normalized === 'refunded') return 'info';
  return 'default';
}

function normalizePayment(payment) {
  const activity = payment?.activity_id ?? null;
  const inscription = payment?.inscription_id ?? null;
  const activityId =
    activity?._id ??
    activity?.id ??
    inscription?.activite_id?._id ??
    inscription?.activite_id ??
    null;

  return {
    id: payment?._id ?? payment?.id,
    paymentId: payment?._id ?? payment?.id ?? '-',
    orderId: payment?.order_id ?? '-',
    payerName: payment?.user_id?.fullname ?? payment?.user_id?.email ?? '-',
    payerEmail: payment?.user_id?.email ?? '-',
    activityId,
    activityTitle: activity?.titre ?? inscription?.activite_id?.titre ?? payment?.activity_title ?? '-',
    organizerName: activity?.organisateur_id?.fullname ?? activity?.organisateur_id?.email ?? '-',
    organizerEmail: activity?.organisateur_id?.email ?? '-',
    amount: payment?.amount ?? 0,
    currency: payment?.currency ?? 'TND',
    status: payment?.status ?? 'pending',
    paidAt: payment?.paid_at ?? payment?.paidAt ?? payment?.createdAt ?? null,
    createdAt: payment?.createdAt ?? null,
    inscriptionStatus: inscription?.statut ?? '-',
    description: payment?.description ?? '-',
  };
}

export function FacteursView() {
  const table = useTable({ defaultOrderBy: 'paidAt', defaultOrder: 'desc' });

  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [query, setQuery] = useState('');
  const [detailsOpen, setDetailsOpen] = useState(false);
  const [selectedRow, setSelectedRow] = useState(null);
  const [deletingId, setDeletingId] = useState(null);

  const load = useCallback(async () => {
    try {
      setLoading(true);
      setError('');

      const response = await Get('/api/v1/payments/all?page=1&limit=1000');
      const payments = Array.isArray(response?.payments) ? response.payments : [];

      const mapped = payments.map((payment) => normalizePayment(payment));
      const enriched = await Promise.all(
        mapped.map(async (payment) => {
          if (payment.organizerName && payment.organizerName !== '-') {
            return payment;
          }

          if (!payment.activityId) {
            return payment;
          }

          try {
            const activityResponse = await Get(END_POINT.activiteById(payment.activityId));
            const activity = activityResponse?.activite ?? activityResponse?.activity ?? activityResponse ?? null;

            if (!activity) {
              return payment;
            }

            return {
              ...payment,
              activityTitle: activity.titre ?? payment.activityTitle,
              organizerName: activity.organisateur_id?.fullname ?? activity.organisateur_id?.email ?? payment.organizerName,
              organizerEmail: activity.organisateur_id?.email ?? payment.organizerEmail,
            };
          } catch {
            return payment;
          }
        })
      );

      setRows(enriched);
    } catch {
      setError('Erreur lors du chargement des paiements');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    load();
  }, [load]);

  const filtered = useMemo(() => {
    const stabilized = rows.map((el, index) => [el, index]);

    stabilized.sort((a, b) => {
      const order = getComparator(table.order, table.orderBy)(a[0], b[0]);
      if (order !== 0) return order;
      return a[1] - b[1];
    });

    let data = stabilized.map((el) => el[0]);

    if (query.trim()) {
      const search = query.trim().toLowerCase();
      data = data.filter(
        (row) =>
          String(row.paymentId ?? '').toLowerCase().includes(search) ||
          String(row.orderId ?? '').toLowerCase().includes(search) ||
          String(row.payerName ?? '').toLowerCase().includes(search) ||
          String(row.payerEmail ?? '').toLowerCase().includes(search) ||
          String(row.organizerName ?? '').toLowerCase().includes(search) ||
          String(row.activityTitle ?? '').toLowerCase().includes(search) ||
          String(row.status ?? '').toLowerCase().includes(search)
      );
    }

    return data;
  }, [query, rows, table.order, table.orderBy]);

  const dataInPage = rowInPage(filtered, table.page, table.rowsPerPage);
  const notFound = filtered.length === 0;

  const handleSearch = useCallback(
    (event) => {
      table.onResetPage();
      setQuery(event.target.value);
    },
    [table]
  );

  const openDetails = useCallback((row) => {
    setSelectedRow(row);
    setDetailsOpen(true);
  }, []);

  const closeDetails = useCallback(() => {
    setDetailsOpen(false);
    setSelectedRow(null);
  }, []);

  const handlePrintRow = useCallback((row) => {
    const popup = window.open('', '_blank', 'width=900,height=700');

    if (!popup) {
      return;
    }

    popup.document.write(`
      <html>
        <head>
          <title>Facture ${row.paymentId}</title>
          <style>
            body { font-family: Arial, sans-serif; padding: 32px; color: #111827; }
            h1 { margin: 0 0 24px; font-size: 24px; }
            .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px; }
            .card { border: 1px solid #d1d5db; border-radius: 12px; padding: 16px; }
            .label { font-size: 12px; color: #6b7280; margin-bottom: 6px; }
            .value { font-size: 15px; font-weight: 600; word-break: break-word; }
            .mono { font-family: monospace; }
            @media print { body { padding: 0; } }
          </style>
        </head>
        <body>
          <h1>Facture de paiement</h1>
          <div class="grid">
            <div class="card"><div class="label">Payment ID</div><div class="value mono">${row.paymentId}</div></div>
            <div class="card"><div class="label">Order ID</div><div class="value mono">${row.orderId}</div></div>
            <div class="card"><div class="label">Payeur</div><div class="value">${row.payerName}</div></div>
            <div class="card"><div class="label">Organisateur</div><div class="value">${row.organizerName}</div></div>
            <div class="card"><div class="label">Activité</div><div class="value">${row.activityTitle}</div></div>
            <div class="card"><div class="label">Montant</div><div class="value">${row.amount} ${row.currency}</div></div>
            <div class="card"><div class="label">Date de paiement</div><div class="value">${formatDate(row.paidAt)}</div></div>
            <div class="card"><div class="label">Statut</div><div class="value">${row.status}</div></div>
          </div>
          <script>
            window.onload = function () {
              window.print();
              window.onafterprint = function () { window.close(); };
            };
          </script>
        </body>
      </html>
    `);
    popup.document.close();
  }, []);

  const handleDeleteRow = useCallback(
    async (row) => {
      if (!row?.id) {
        return;
      }

      const confirmed = window.confirm(`Supprimer le paiement ${row.paymentId} ?`);
      if (!confirmed) {
        return;
      }

      try {
        setDeletingId(row.id);
        await Delete(END_POINT.paymentById(row.id));
        setRows((current) => current.filter((item) => item.id !== row.id));
      } catch {
        setError('Impossible de supprimer ce paiement');
      } finally {
        setDeletingId(null);
      }
    },
    []
  );

  return (
    <DashboardContent maxWidth="xl">
      <Stack spacing={2}>
        <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} justifyContent="space-between">
          <Box>
            <Typography variant="h4" sx={{ fontWeight: 700 }}>
              Paiements des activités
            </Typography>
            <Typography variant="body2" sx={{ color: 'text.secondary' }}>
              Id du paiement, payeur, organisateur, activité et date de paiement.
            </Typography>
          </Box>

          <Button variant="outlined" startIcon={<Iconify icon="solar:refresh-bold" />} onClick={load}>
            Rafraichir
          </Button>
        </Stack>

        <Card>
          <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} sx={{ p: 2 }}>
            <TextField
              fullWidth
              value={query}
              onChange={handleSearch}
              placeholder="Rechercher un payment id, un payeur, un organisateur ou une activité..."
            />

            <Button
              color="inherit"
              onClick={() => {
                table.onResetPage();
                setQuery('');
              }}
              startIcon={<Iconify icon="solar:restart-bold" />}
            >
              Réinitialiser
            </Button>
          </Stack>

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
                        <TableCell sx={{ fontFamily: 'monospace' }}>{row.paymentId}</TableCell>
                        <TableCell>
                          <Stack spacing={0.25}>
                            <Typography variant="body2" sx={{ fontWeight: 600 }}>
                              {row.payerName}
                            </Typography>
                            <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                              {row.payerEmail}
                            </Typography>
                          </Stack>
                        </TableCell>
                        <TableCell>
                          <Stack spacing={0.25}>
                            <Typography variant="body2" sx={{ fontWeight: 600 }}>
                              {row.organizerName}
                            </Typography>
                            <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                              {row.organizerEmail}
                            </Typography>
                          </Stack>
                        </TableCell>
                        <TableCell>{row.activityTitle}</TableCell>
                        <TableCell>
                          <Typography variant="body2" sx={{ fontWeight: 600 }}>
                            {row.amount} {row.currency}
                          </Typography>
                        </TableCell>
                        <TableCell>{formatDate(row.paidAt)}</TableCell>
                        <TableCell>
                          <Chip size="small" label={row.status} color={statusColor(row.status)} />
                        </TableCell>
                        <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                          <Stack direction="row" spacing={0.5} justifyContent="flex-end">
                            <Tooltip title="Imprimer">
                              <IconButton color="primary" onClick={() => handlePrintRow(row)}>
                                <Iconify icon="solar:printer-bold" />
                              </IconButton>
                            </Tooltip>

                            <Tooltip title="Détails">
                              <IconButton color="info" onClick={() => openDetails(row)}>
                                <Iconify icon="solar:eye-bold" />
                              </IconButton>
                            </Tooltip>

                            <Tooltip title="Supprimer">
                              <span>
                                <IconButton
                                  color="error"
                                  onClick={() => handleDeleteRow(row)}
                                  disabled={deletingId === row.id}
                                >
                                  <Iconify icon="solar:trash-bin-trash-bold" />
                                </IconButton>
                              </span>
                            </Tooltip>
                          </Stack>
                        </TableCell>
                      </TableRow>
                    ))}

                    <TableEmptyRows
                      height={table.dense ? 56 : 76}
                      emptyRows={emptyRows(table.page, table.rowsPerPage, filtered.length)}
                    />

                    {notFound ? (
                      <TableRow>
                        <TableCell colSpan={8} align="center">
                          Aucun paiement trouvé
                        </TableCell>
                      </TableRow>
                    ) : null}
                  </TableBody>
                </Table>
              </Scrollbar>

              <TablePaginationCustom
                page={table.page}
                dense={table.dense}
                count={filtered.length}
                rowsPerPage={table.rowsPerPage}
                onPageChange={table.onChangePage}
                onChangeDense={table.onChangeDense}
                onRowsPerPageChange={table.onChangeRowsPerPage}
              />
            </>
          )}
        </Card>
      </Stack>

      <Dialog open={detailsOpen} onClose={closeDetails} fullWidth maxWidth="md">
        <DialogTitle sx={{ pb: 1 }}>Détails du paiement</DialogTitle>

        <DialogContent dividers sx={{ pt: 2 }}>
          {selectedRow ? (
            <Stack spacing={2}>
              <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                <Stack spacing={0.5}>
                  <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                    Payment ID
                  </Typography>
                  <Typography variant="h6" sx={{ fontWeight: 700, fontFamily: 'monospace' }}>
                    {selectedRow.paymentId}
                  </Typography>
                  <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                    Order ID: {selectedRow.orderId}
                  </Typography>
                </Stack>
              </Card>

              <Box
                sx={{
                  display: 'grid',
                  gap: 1.5,
                  gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, minmax(0, 1fr))' },
                }}
              >
                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Payeur
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {selectedRow.payerName}
                  </Typography>
                  <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                    {selectedRow.payerEmail}
                  </Typography>
                </Card>

                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Organisateur
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {selectedRow.organizerName}
                  </Typography>
                  <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                    {selectedRow.organizerEmail}
                  </Typography>
                </Card>

                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Activité
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {selectedRow.activityTitle}
                  </Typography>
                </Card>

                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Montant
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {selectedRow.amount} {selectedRow.currency}
                  </Typography>
                </Card>

                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Date de paiement
                  </Typography>
                  <Typography variant="body2" sx={{ fontWeight: 600 }}>
                    {formatDate(selectedRow.paidAt)}
                  </Typography>
                </Card>

                <Card variant="outlined" sx={{ p: 1.5, borderRadius: 2 }}>
                  <Typography variant="caption" sx={{ color: 'text.secondary', display: 'block' }}>
                    Statut
                  </Typography>
                  <Chip size="small" label={selectedRow.status} color={statusColor(selectedRow.status)} />
                </Card>
              </Box>

              <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                <Typography variant="subtitle2" sx={{ mb: 0.75 }}>
                  Description
                </Typography>
                <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap', lineHeight: 1.7 }}>
                  {selectedRow.description}
                </Typography>
              </Card>
            </Stack>
          ) : null}
        </DialogContent>
      </Dialog>
    </DashboardContent>
  );
}
