import { useCallback } from 'react';
import { varAlpha } from 'minimal-shared/utils';
import { usePopover } from 'minimal-shared/hooks';

import Box from '@mui/material/Box';
import Tab from '@mui/material/Tab';
import Tabs from '@mui/material/Tabs';
import Chip from '@mui/material/Chip';
import Button from '@mui/material/Button';
import Select from '@mui/material/Select';
import Checkbox from '@mui/material/Checkbox';
import MenuList from '@mui/material/MenuList';
import MenuItem from '@mui/material/MenuItem';
import TextField from '@mui/material/TextField';
import InputLabel from '@mui/material/InputLabel';
import IconButton from '@mui/material/IconButton';
import FormControl from '@mui/material/FormControl';
import OutlinedInput from '@mui/material/OutlinedInput';
import InputAdornment from '@mui/material/InputAdornment';
import { useTheme, alpha } from '@mui/material/styles';
import { DatePicker } from '@mui/x-date-pickers/DatePicker';

import { Label } from 'src/components/label';
import { Iconify } from 'src/components/iconify';
import { CustomPopover } from 'src/components/custom-popover';

function toTime(value) {
  if (!value) return null;

  const raw =
    value instanceof Date
      ? value
      : typeof value === 'number'
        ? new Date(value)
        : typeof value?.toDate === 'function'
          ? value.toDate()
          : value?.$d instanceof Date
            ? value.$d
            : value;

  const t = new Date(raw).getTime();
  return Number.isNaN(t) ? null : t;
}

function formatFilterDate(value) {
  const t = toTime(value);
  return t ? new Date(t).toLocaleDateString() : '';
}

export function InvoiceFilters({
  tabs,
  filters,
  options,
  canReset,
  onResetPage,
  onFilterStatus,
  onResetFilters,
}) {
  const theme = useTheme();
  const { state: currentFilters } = filters;

  const grey500Channel = theme?.vars?.palette?.grey?.['500Channel'];
  const tabsShadow =
    typeof grey500Channel === 'string'
      ? `inset 0 -2px 0 0 ${varAlpha(grey500Channel, 0.08)}`
      : `inset 0 -2px 0 0 ${alpha(theme.palette.grey[500], 0.08)}`;

  return (
    <>
      <Tabs
        value={currentFilters.status}
        onChange={onFilterStatus}
        sx={{
          px: 2.5,
          boxShadow: tabsShadow,
        }}
      >
        {tabs.map((tab) => (
          <Tab
            key={tab.value}
            value={tab.value}
            label={tab.label}
            iconPosition="end"
            icon={
              <Label
                variant={((tab.value === 'all' || tab.value === currentFilters.status) && 'filled') || 'soft'}
                color={tab.color}
              >
                {tab.count}
              </Label>
            }
          />
        ))}
      </Tabs>

      <InvoiceTableToolbar
        filters={filters}
        options={options}
        onResetPage={onResetPage}
      />

      {canReset && (
        <InvoiceTableFiltersResult
          filters={filters}
          onResetPage={onResetPage}
          onReset={onResetFilters}
          sx={{ px: 2.5, pb: 2.5 }}
        />
      )}
    </>
  );
}

export function InvoiceTableFiltersResult({ filters, onResetPage, onReset, sx }) {
  const { state: currentFilters, setState: updateFilters } = filters;

  const handleRemove = useCallback(
    (patch) => {
      onResetPage();
      updateFilters(patch);
    },
    [onResetPage, updateFilters]
  );

  return (
    <Box sx={{ display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 1, ...sx }}>
      {currentFilters.categorie !== 'all' && (
        <Chip size="small" label={`Catégorie: ${currentFilters.categorie}`} onDelete={() => handleRemove({ categorie: 'all' })} />
      )}

      {!!currentFilters.name && (
        <Chip size="small" label={`Recherche: ${currentFilters.name}`} onDelete={() => handleRemove({ name: '' })} />
      )}

      {currentFilters.ville?.length > 0 && (
        <Chip
          size="small"
          label={`Ville: ${currentFilters.ville.join(', ')}`}
          onDelete={() => handleRemove({ ville: [] })}
        />
      )}

      <Box sx={{ flexGrow: 1 }} />

      <Button
        color="inherit"
        onClick={() => {
          onResetPage();
          onReset();
        }}
        startIcon={<Iconify icon="eva:refresh-fill" />}
      >
        Réinitialiser
      </Button>
    </Box>
  );
}

export function InvoiceTableToolbar({ filters, options, onResetPage }) {
  const menuActions = usePopover();
  const { state: currentFilters, setState: updateFilters } = filters;

  const handleFilterName = useCallback(
    (event) => {
      onResetPage();
      updateFilters({ name: event.target.value });
    },
    [onResetPage, updateFilters]
  );

  const handleFilterVille = useCallback(
    (event) => {
      const newValue =
        typeof event.target.value === 'string' ? event.target.value.split(',') : event.target.value;

      onResetPage();
      updateFilters({ ville: newValue });
    },
    [onResetPage, updateFilters]
  );

  const renderMenuActions = () => (
    <CustomPopover
      open={menuActions.open}
      anchorEl={menuActions.anchorEl}
      onClose={menuActions.onClose}
      slotProps={{ arrow: { placement: 'right-top' } }}
    >
      <MenuList>
        <MenuItem onClick={menuActions.onClose}>
          <Iconify icon="solar:printer-minimalistic-bold" />
          Print
        </MenuItem>

        <MenuItem onClick={menuActions.onClose}>
          <Iconify icon="solar:import-bold" />
          Import
        </MenuItem>

        <MenuItem onClick={menuActions.onClose}>
          <Iconify icon="solar:export-bold" />
          Export
        </MenuItem>
      </MenuList>
    </CustomPopover>
  );

  return (
    <>
      <Box
        sx={{
          p: 2.5,
          gap: 2,
          display: 'flex',
          pr: { xs: 2.5, md: 1 },
          flexDirection: { xs: 'column', md: 'row' },
          alignItems: { xs: 'flex-end', md: 'center' },
        }}
      >
        <FormControl sx={{ flexShrink: 0, width: { xs: 1, md: 180 } }}>
          <InputLabel htmlFor="filter-ville-select">Ville</InputLabel>

          <Select
            multiple
            value={currentFilters.ville}
            onChange={handleFilterVille}
            input={<OutlinedInput label="Ville" />}
            renderValue={(selected) => selected.map((value) => value).join(', ')}
            inputProps={{ id: 'filter-ville-select' }}
            sx={{ textTransform: 'capitalize' }}
          >
            {options.villes.map((option) => (
              <MenuItem key={option} value={option}>
                <Checkbox
                  disableRipple
                  size="small"
                  checked={currentFilters.ville.includes(option)}
                  inputProps={{ id: `${option}-checkbox`, 'aria-label': `${option} checkbox` }}
                />
                {option}
              </MenuItem>
            ))}
          </Select>
        </FormControl>

        <Box sx={{ gap: 2, width: 1, flexGrow: 1, display: 'flex', alignItems: 'center' }}>
          <TextField
            fullWidth
            value={currentFilters.name}
            onChange={handleFilterName}
            placeholder="Rechercher un lieu..."
            slotProps={{
              input: {
                startAdornment: (
                  <InputAdornment position="start">
                    <Iconify icon="eva:search-fill" sx={{ color: 'text.disabled' }} />
                  </InputAdornment>
                ),
              },
            }}
          />

          <IconButton color={menuActions.open ? 'inherit' : 'default'} onClick={menuActions.onOpen}>
            <Iconify icon="eva:more-vertical-fill" />
          </IconButton>
        </Box>
      </Box>

      {renderMenuActions()}
    </>
  );
}
