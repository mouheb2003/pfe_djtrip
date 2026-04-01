import { useState, useCallback } from 'react';
import { useBoolean } from 'minimal-shared/hooks';

import Box from '@mui/material/Box';
import Paper from '@mui/material/Paper';
import Stack from '@mui/material/Stack';
import Table from '@mui/material/Table';
import Button from '@mui/material/Button';
import Tooltip from '@mui/material/Tooltip';
import Divider from '@mui/material/Divider';
import Collapse from '@mui/material/Collapse';
import Checkbox from '@mui/material/Checkbox';
import TableRow from '@mui/material/TableRow';
import TableBody from '@mui/material/TableBody';
import TableCell from '@mui/material/TableCell';
import IconButton from '@mui/material/IconButton';
import Typography from '@mui/material/Typography';

import { paths } from 'src/routes/paths';
import { useRouter } from 'src/routes/hooks';

import { Label } from 'src/components/label';
import { Iconify } from 'src/components/iconify';
import { Scrollbar } from 'src/components/scrollbar';
import { ConfirmDialog } from 'src/components/custom-dialog';
import {
  emptyRows,
  TableNoData,
  TableEmptyRows,
  TableHeadCustom,
  TableSelectedAction,
  TablePaginationCustom,
} from 'src/components/table';

export function InvoiceTable({
  table,
  rows,
  tableHead,
  notFound,
  loading,
  categorieColor,
  calculateAverageNote,
  onDeleteRow,
  onDeleteSelected,
}) {
  const confirmDialog = useBoolean();
  const router = useRouter();

  const [expandedRows, setExpandedRows] = useState({}); // { [id]: boolean }

  const handleToggleExpanded = useCallback((id) => {
    setExpandedRows((prev) => ({ ...prev, [id]: !prev?.[id] }));
  }, []);

  const handleViewDetails = useCallback(
    (lieu) => {
      router.push(paths.dashboard.lieux.details(lieu.id));
    },
    [router]
  );

  const renderSecondaryRow = useCallback(
    (row) => {
      const open = !!expandedRows?.[row.id];

      return (
        <TableRow key={`${row.id}__details`}>
          <TableCell sx={{ p: 0, border: 'none' }} colSpan={11}>
            <Collapse in={open} timeout="auto" unmountOnExit sx={{ bgcolor: 'background.neutral' }}>
              <Paper sx={{ m: 1.5, p: 2 }}>
                <Stack
                  direction={{ xs: 'column', md: 'row' }}
                  spacing={2}
                  divider={<Divider flexItem orientation="vertical" />}
                >
                  <Stack spacing={0.75} sx={{ minWidth: 240 }}>
                    <Typography variant="subtitle2">Description</Typography>
                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                      {row.description || 'Aucune description disponible'}
                    </Typography>
                  </Stack>

                  <Stack spacing={0.75} sx={{ minWidth: 240 }}>
                    <Typography variant="subtitle2">Localisation</Typography>
                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                      {row.adresse}
                    </Typography>
                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                      Lat: {row.latitude.toFixed(4)}, Long: {row.longitude.toFixed(4)}
                    </Typography>
                  </Stack>

                  <Stack spacing={0.75} sx={{ flexGrow: 1 }}>
                    <Typography variant="subtitle2">Informations</Typography>
                    {row.siteWeb && (
                      <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                        Site web: {row.siteWeb}
                      </Typography>
                    )}
                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                      Images: {row.galerieImages?.length || 0} • Avis: {row.avis?.length || 0}
                    </Typography>
                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                      Note moyenne: {calculateAverageNote(row.avis)} / 5
                    </Typography>

                    {row.galerieImages?.length ? (
                      <Stack direction="row" spacing={1} sx={{ pt: 0.5, flexWrap: 'wrap' }}>
                        {row.galerieImages.slice(0, 6).map((image, imageIndex) => (
                          <Box
                            key={`${row.id}_img_${imageIndex}`}
                            component="img"
                            src={image}
                            alt={`${row.nom} ${imageIndex + 1}`}
                            sx={{
                              width: 56,
                              height: 56,
                              objectFit: 'cover',
                              borderRadius: 1,
                              border: (theme) => `1px solid ${theme.palette.divider}`,
                            }}
                          />
                        ))}
                      </Stack>
                    ) : null}
                  </Stack>
                </Stack>
              </Paper>
            </Collapse>
          </TableCell>
        </TableRow>
      );
    },
    [expandedRows, calculateAverageNote]
  );

  return (
    <>
      <Box sx={{ position: 'relative' }}>
        <TableSelectedAction
          dense={table.dense}
          numSelected={table.selected.length}
          rowCount={rows.length}
          onSelectAllRows={(checked) =>
            table.onSelectAllRows(
              checked,
              rows.map((row) => row.id)
            )
          }
          action={
            <Tooltip title="Supprimer">
              <IconButton color="primary" onClick={confirmDialog.onTrue}>
                <Iconify icon="solar:trash-bin-trash-bold" />
              </IconButton>
            </Tooltip>
          }
        />

        <Scrollbar sx={{ minHeight: 444 }}>
          <Table size={table.dense ? 'small' : 'medium'} sx={{ minWidth: 900 }}>
            <TableHeadCustom
              order={table.order}
              orderBy={table.orderBy}
              headCells={tableHead}
              rowCount={rows.length}
              numSelected={table.selected.length}
              onSort={table.onSort}
              onSelectAllRows={(checked) =>
                table.onSelectAllRows(
                  checked,
                  rows.map((row) => row.id)
                )
              }
            />

            <TableBody>
              {rows
                .slice(
                  table.page * table.rowsPerPage,
                  table.page * table.rowsPerPage + table.rowsPerPage
                )
                .flatMap((row) => {
                  const selected = table.selected.includes(row.id);
                  const expanded = !!expandedRows?.[row.id];

                  return [
                    <TableRow key={row.id} hover selected={selected}>
                      <TableCell padding="checkbox">
                        <Checkbox checked={selected} onClick={() => table.onSelectRow(row.id)} />
                      </TableCell>

                      <TableCell>{row.nom}</TableCell>
                      <TableCell>
                        <Label variant="soft" color={categorieColor(row.categorie)}>
                          {row.categorie}
                        </Label>
                      </TableCell>
                      <TableCell>{row.ville}</TableCell>
                      <TableCell>{row.prix === 0 ? 'Gratuit' : `${row.prix} TND`}</TableCell>
                      <TableCell>{row.telephone || '-'}</TableCell>
                      <TableCell
                        sx={{
                          maxWidth: 200,
                          whiteSpace: 'nowrap',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                        }}
                      >
                        {row.horaires || '-'}
                      </TableCell>

                      <TableCell align="center">
                        <Stack
                          direction="row"
                          alignItems="center"
                          justifyContent="center"
                          spacing={0.5}
                        >
                          <Iconify icon="eva:star-fill" width={16} sx={{ color: 'warning.main' }} />
                          <Typography variant="body2">{calculateAverageNote(row.avis)}</Typography>
                        </Stack>
                      </TableCell>

                      <TableCell align="right" sx={{ whiteSpace: 'nowrap' }}>
                        <Tooltip title="Voir détails">
                          <IconButton color="info" onClick={() => handleViewDetails(row)}>
                            <Iconify icon="solar:eye-bold" />
                          </IconButton>
                        </Tooltip>

                        <Tooltip title={expanded ? 'Fermer' : 'Ouvrir'}>
                          <IconButton
                            aria-label={expanded ? 'collapse-row' : 'expand-row'}
                            color={expanded ? 'inherit' : 'default'}
                            onClick={() => handleToggleExpanded(row.id)}
                          >
                            <Iconify icon="eva:arrow-ios-downward-fill" />
                          </IconButton>
                        </Tooltip>

                        <Tooltip title="Supprimer">
                          <IconButton color="primary" onClick={() => onDeleteRow(row.id)}>
                            <Iconify icon="solar:trash-bin-trash-bold" />
                          </IconButton>
                        </Tooltip>
                      </TableCell>
                    </TableRow>,
                    renderSecondaryRow(row),
                  ];
                })}

              <TableEmptyRows
                height={table.dense ? 56 : 56 + 20}
                emptyRows={emptyRows(table.page, table.rowsPerPage, rows.length)}
              />

              <TableNoData notFound={notFound} />
            </TableBody>
          </Table>
        </Scrollbar>
      </Box>

      <TablePaginationCustom
        page={table.page}
        dense={table.dense}
        count={rows.length}
        rowsPerPage={table.rowsPerPage}
        onPageChange={table.onChangePage}
        onChangeDense={table.onChangeDense}
        onRowsPerPageChange={table.onChangeRowsPerPage}
      />

      <ConfirmDialog
        open={confirmDialog.value}
        onClose={confirmDialog.onFalse}
        title="Supprimer"
        content={
          <>
            Voulez-vous supprimer <strong>{table.selected.length}</strong> élément(s) ?
          </>
        }
        action={
          <Button
            variant="contained"
            color="error"
            onClick={() => {
              onDeleteSelected();
              confirmDialog.onFalse();
            }}
          >
            Supprimer
          </Button>
        }
      />
    </>
  );
}
