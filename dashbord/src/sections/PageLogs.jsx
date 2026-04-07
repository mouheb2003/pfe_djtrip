import { useMemo, useState, useEffect, useCallback } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Chip from '@mui/material/Chip';
import Alert from '@mui/material/Alert';
import Stack from '@mui/material/Stack';
import Table from '@mui/material/Table';
import Button from '@mui/material/Button';
import MenuItem from '@mui/material/MenuItem';
import TableRow from '@mui/material/TableRow';
import TextField from '@mui/material/TextField';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import Typography from '@mui/material/Typography';
import TableContainer from '@mui/material/TableContainer';
import CircularProgress from '@mui/material/CircularProgress';

import { getSystemLogs } from 'src/Controller/actions';
import { DashboardContent } from 'src/layouts/dashboard';

import { Iconify } from 'src/components/iconify';
import { Scrollbar } from 'src/components/scrollbar';
import {
  useTable,
  rowInPage,
  emptyRows,
  TableEmptyRows,
  TableHeadCustom,
  TablePaginationCustom,
} from 'src/components/table';

const TABLE_HEAD = [
  { id: 'timestamp', label: 'Date', width: 220 },
  { id: 'level', label: 'Niveau', width: 120 },
  { id: 'source', label: 'Source', width: 140 },
  { id: 'action', label: 'Action', width: 180 },
  { id: 'actor', label: 'Utilisateur', width: 190 },
  { id: 'message', label: 'Message' },
];

const AUTO_REFRESH_MS = 10000;

function levelColor(level) {
  const value = String(level || '').toLowerCase();
  if (value === 'error') return 'error';
  if (value === 'warn') return 'warning';
  if (value === 'info') return 'info';
  return 'default';
}

function formatDateTime(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return date.toLocaleString('fr-FR');
}

export function LogsView({ sx }) {
  const table = useTable({ defaultRowsPerPage: 25 });

  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [rows, setRows] = useState([]);
  const [totalRows, setTotalRows] = useState(0);

  const [search, setSearch] = useState('');
  const [debouncedSearch, setDebouncedSearch] = useState('');
  const [level, setLevel] = useState('all');
  const [source, setSource] = useState('');
  const [start, setStart] = useState('');
  const [end, setEnd] = useState('');

  useEffect(() => {
    const timer = window.setTimeout(() => {
      setDebouncedSearch(search.trim());
      table.onResetPage();
    }, 350);

    return () => window.clearTimeout(timer);
  }, [search, table]);

  const loadLogs = useCallback(
    async ({ silent = false } = {}) => {
      try {
        if (!silent) setLoading(true);
        setError('');

        const response = await getSystemLogs({
          level,
          source,
          search: debouncedSearch,
          start,
          end,
          page: table.page + 1,
          limit: table.rowsPerPage,
        });

        setRows(response.logs);
        setTotalRows(response.total);
      } catch (err) {
        setError(err?.response?.data?.message || 'Impossible de charger les logs systeme');
      } finally {
        if (!silent) setLoading(false);
      }
    },
    [level, source, debouncedSearch, start, end, table.page, table.rowsPerPage]
  );

  useEffect(() => {
    loadLogs();
  }, [loadLogs]);

  useEffect(() => {
    const intervalId = window.setInterval(() => {
      loadLogs({ silent: true });
    }, AUTO_REFRESH_MS);

    return () => window.clearInterval(intervalId);
  }, [loadLogs]);

  const sources = useMemo(() => {
    const set = new Set(rows.map((item) => item.source).filter(Boolean));
    return Array.from(set).sort();
  }, [rows]);

  return (
    <DashboardContent maxWidth="xl" sx={sx}>
      <Stack spacing={3}>
        <Stack direction={{ xs: 'column', md: 'row' }} spacing={1.5} justifyContent="space-between">
          <Stack spacing={0.5}>
            <Typography variant="h4">Activity Logs</Typography>
            <Typography variant="body2" sx={{ color: 'text.secondary' }}>
              Historique lisible des actions utilisateurs (publication, reservation, approbation)
              avec filtres et mise a jour automatique.
            </Typography>
          </Stack>

          <Button
            variant="outlined"
            startIcon={<Iconify icon="solar:refresh-bold" />}
            onClick={() => loadLogs()}
          >
            Actualiser
          </Button>
        </Stack>

        <Card sx={{ p: 2.5 }}>
          <Stack direction={{ xs: 'column', md: 'row' }} spacing={1.5}>
            <TextField
              fullWidth
              label="Recherche"
              placeholder="Ahmed, reservation, publication..."
              value={search}
              onChange={(event) => setSearch(event.target.value)}
            />

            <TextField
              select
              label="Niveau"
              value={level}
              onChange={(event) => {
                table.onResetPage();
                setLevel(event.target.value);
              }}
              sx={{ minWidth: 160 }}
            >
              <MenuItem value="all">Tous</MenuItem>
              <MenuItem value="info">Info</MenuItem>
              <MenuItem value="warn">Warn</MenuItem>
              <MenuItem value="error">Error</MenuItem>
            </TextField>

            <TextField
              select
              label="Source"
              value={source}
              onChange={(event) => {
                table.onResetPage();
                setSource(event.target.value);
              }}
              sx={{ minWidth: 170 }}
            >
              <MenuItem value="">Toutes</MenuItem>
              {sources.map((item) => (
                <MenuItem key={item} value={item}>
                  {item}
                </MenuItem>
              ))}
            </TextField>

            <TextField
              label="Du"
              type="datetime-local"
              value={start}
              onChange={(event) => {
                table.onResetPage();
                setStart(event.target.value);
              }}
              InputLabelProps={{ shrink: true }}
              sx={{ minWidth: 210 }}
            />

            <TextField
              label="Au"
              type="datetime-local"
              value={end}
              onChange={(event) => {
                table.onResetPage();
                setEnd(event.target.value);
              }}
              InputLabelProps={{ shrink: true }}
              sx={{ minWidth: 210 }}
            />
          </Stack>
        </Card>

        {error && <Alert severity="error">{error}</Alert>}

        <Card>
          <TableContainer sx={{ position: 'relative', overflow: 'unset' }}>
            <Scrollbar>
              <Table size={table.dense ? 'small' : 'medium'} sx={{ minWidth: 980 }}>
                <TableHeadCustom
                  order={table.order}
                  orderBy={table.orderBy}
                  headCells={TABLE_HEAD}
                  rowCount={rows.length}
                  numSelected={0}
                  onSort={() => {}}
                />

                <TableBody>
                  {loading ? (
                    <TableRow>
                      <TableCell colSpan={6}>
                        <Box sx={{ py: 8, display: 'flex', justifyContent: 'center' }}>
                          <CircularProgress />
                        </Box>
                      </TableCell>
                    </TableRow>
                  ) : (
                    rowInPage(rows, table.page, table.rowsPerPage).map((row) => (
                      <TableRow hover key={row.id}>
                        <TableCell sx={{ whiteSpace: 'nowrap' }}>
                          {formatDateTime(row.timestamp)}
                        </TableCell>
                        <TableCell>
                          <Chip
                            size="small"
                            label={String(row.level || '-').toUpperCase()}
                            color={levelColor(row.level)}
                            variant={row.level === 'info' ? 'outlined' : 'filled'}
                          />
                        </TableCell>
                        <TableCell>
                          <Chip size="small" label={row.source || '-'} variant="outlined" />
                        </TableCell>
                        <TableCell>
                          <Chip
                            size="small"
                            label={row.action || '-'}
                            variant={row.action ? 'filled' : 'outlined'}
                            color={row.action ? 'primary' : 'default'}
                          />
                        </TableCell>
                        <TableCell sx={{ whiteSpace: 'nowrap' }}>
                          <Typography variant="body2" sx={{ fontWeight: 600 }}>
                            {row.userId || '-'}
                          </Typography>
                          <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                            {row.userType || '-'}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Typography
                            variant="body2"
                            sx={{
                              fontFamily: 'monospace',
                              whiteSpace: 'pre-wrap',
                              wordBreak: 'break-word',
                            }}
                          >
                            {row.message || '-'}
                          </Typography>
                        </TableCell>
                      </TableRow>
                    ))
                  )}

                  <TableEmptyRows
                    height={table.dense ? 56 : 76}
                    emptyRows={emptyRows(table.page, table.rowsPerPage, rows.length)}
                  />
                </TableBody>
              </Table>
            </Scrollbar>
          </TableContainer>

          <TablePaginationCustom
            page={table.page}
            dense={table.dense}
            count={totalRows}
            rowsPerPage={table.rowsPerPage}
            onPageChange={table.onChangePage}
            onChangeDense={table.onChangeDense}
            onRowsPerPageChange={table.onChangeRowsPerPage}
          />
        </Card>
      </Stack>
    </DashboardContent>
  );
}
