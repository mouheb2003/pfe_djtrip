import { useSetState } from 'minimal-shared/hooks';
import { useMemo, useState, useEffect, useCallback } from 'react';

import Card from '@mui/material/Card';
import Box from '@mui/material/Box';
import Dialog from '@mui/material/Dialog';
import Button from '@mui/material/Button';
import MenuItem from '@mui/material/MenuItem';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import DialogTitle from '@mui/material/DialogTitle';
import DialogActions from '@mui/material/DialogActions';
import DialogContent from '@mui/material/DialogContent';
import { AdapterDayjs } from '@mui/x-date-pickers/AdapterDayjs';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';

import { getLieux, createLieu, uploadLieuImages } from 'src/Controller/actions';
import { DashboardContent } from 'src/layouts/dashboard';

import { toast } from 'src/components/snackbar';
import { useTable, rowInPage, getComparator } from 'src/components/table';

import { PageHeader } from './Page1/Header';
import { InvoiceTable } from './Page1/Tableau';
import { InvoiceFilters } from './Page1/Filter';
import { LieuDetailsDialog } from './Page1/Components/LieuDetails';

// ----------------------------------------------------------------------

const TABLE_HEAD = [
  { id: 'checkbox', label: '', disableSort: true, align: 'center' },
  { id: 'nom', label: 'Nom' },
  { id: 'categorie', label: 'Catégorie' },
  { id: 'ville', label: 'Ville' },
  { id: 'prix', label: 'Prix' },
  { id: 'telephone', label: 'Téléphone' },
  { id: 'horaires', label: 'Horaires' },
  { id: 'note', label: 'Note', align: 'center' },
  { id: 'actions', label: '' },
];

function categorieColor(categorie) {
  switch (categorie) {
    case 'plage':
      return 'info';
    case 'musee':
      return 'secondary';
    case 'hotel':
      return 'success';
    case 'restaurant':
      return 'warning';
    case 'monument':
      return 'error';
    default:
      return 'default';
  }
}

function calculateAverageNote(avis) {
  if (!Array.isArray(avis) || avis.length === 0) return 0;
  const sum = avis.reduce((acc, item) => acc + (item.note ?? item.rating ?? 0), 0);
  return (sum / avis.length).toFixed(1);
}

function applyFilter({ inputData, comparator, filters }) {
  if (!Array.isArray(inputData)) return [];

  const { categorie, name, ville } = filters;

  const stabilizedThis = inputData.map((el, index) => [el, index]);

  stabilizedThis.sort((a, b) => {
    const order = comparator(a[0], b[0]);
    if (order !== 0) return order;
    return a[1] - b[1];
  });

  let data = stabilizedThis.map((el) => el[0]);

  if (categorie !== 'all') {
    data = data.filter((row) => row.categorie === categorie);
  }

  if (name) {
    const q = name.toLowerCase();
    data = data.filter(
      (row) => row.nom?.toLowerCase().includes(q) || row.description?.toLowerCase().includes(q)
    );
  }

  if (ville?.length) {
    data = data.filter((row) => ville.includes(row.ville));
  }

  return data;
}

function parseImageUrls(value) {
  if (!value) return [];

  return value
    .split(/\r?\n|,/)
    .map((item) => item.trim())
    .filter(Boolean);
}

function mapLieuToRow(lieu) {
  return {
    id: lieu._id ?? lieu.id,
    nom: lieu.nom ?? lieu.name ?? '',
    description: lieu.description ?? '',
    categorie: (lieu.categorie ?? lieu.type ?? 'autre').toString().toLowerCase(),
    ville: lieu.position?.ville ?? lieu.ville ?? '',
    adresse: lieu.position?.adresse ?? lieu.position?.description ?? lieu.adresse ?? '',
    latitude: lieu.position?.localisation?.latitude ?? lieu.position?.latitude ?? lieu.latitude ?? 0,
    longitude:
      lieu.position?.localisation?.longitude ?? lieu.position?.longitude ?? lieu.longitude ?? 0,
    prix: lieu.prix ?? 0,
    horaires:
      lieu.horaires ??
      (lieu.horaire
        ? `${lieu.horaire.ouverture ?? '--:--'} - ${lieu.horaire.fermeture ?? '--:--'}`
        : ''),
    telephone: lieu.telephone ?? '',
    siteWeb: lieu.siteWeb ?? lieu.site ?? '',
    galerieImages: lieu.galerieImages ?? lieu.images ?? [],
    avis: Array.isArray(lieu.avis)
      ? lieu.avis.map((item) => ({
          ...item,
          note: item.note ?? item.rating ?? 0,
        }))
      : [],
    createdAt: lieu.createdAt,
  };
}

// ----------------------------------------------------------------------

export function BlankView({ title = 'Lieux', sx }) {
  const table = useTable({ defaultOrderBy: 'nom' });
  const [tableData, setTableData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openAddDialog, setOpenAddDialog] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [uploadingImages, setUploadingImages] = useState(false);
  const [pendingFiles, setPendingFiles] = useState([]);
  const [selectedLieu, setSelectedLieu] = useState(null);
  const [openLieuDetails, setOpenLieuDetails] = useState(false);
  const [addForm, setAddForm] = useState({
    nom: '',
    type: 'Hebergement',
    ville: '',
    adresse: '',
    latitude: '',
    longitude: '',
    telephone: '',
    email: '',
    siteWeb: '',
    description: '',
    photos: '',
  });

  const filters = useSetState({
    name: '',
    ville: [],
    categorie: 'all',
  });
  const { state: currentFilters, setState: updateFilters } = filters;

  // Fetch lieux from API
  useEffect(() => {
    const fetchLieux = async () => {
      try {
        setLoading(true);
        const lieux = await getLieux();
        const lieuxData = lieux.map(mapLieuToRow);
        setTableData(lieuxData);
      } catch (error) {
        console.error('Erreur lors du chargement des lieux:', error);
        toast.error('Erreur lors du chargement des lieux');
      } finally {
        setLoading(false);
      }
    };

    fetchLieux();
  }, []);

  const handleOpenAddDialog = useCallback(() => {
    setOpenAddDialog(true);
  }, []);

  const handleOpenLieuDetails = useCallback((lieu) => {
    setSelectedLieu(lieu);
    setOpenLieuDetails(true);
  }, []);

  const handleCloseLieuDetails = useCallback(() => {
    setOpenLieuDetails(false);
  }, []);

  const handleCloseAddDialog = useCallback(() => {
    if (submitting || uploadingImages) return;
    setOpenAddDialog(false);
  }, [submitting, uploadingImages]);

  const handleChangeAddForm = useCallback((field, value) => {
    setAddForm((prev) => ({ ...prev, [field]: value }));
  }, []);

  const handleSelectImages = useCallback((event) => {
    const files = Array.from(event.target.files ?? []);
    setPendingFiles(files);
  }, []);

  const handleUploadSelectedImages = useCallback(async () => {
    if (!pendingFiles.length) {
      toast.info('Sélectionnez au moins une image');
      return;
    }

    try {
      setUploadingImages(true);
      const uploadedUrls = await uploadLieuImages(pendingFiles);

      setAddForm((prev) => {
        const existing = parseImageUrls(prev.photos);
        const merged = [...new Set([...existing, ...uploadedUrls])];
        return { ...prev, photos: merged.join('\n') };
      });

      setPendingFiles([]);
      toast.success(`${uploadedUrls.length} image(s) uploadée(s)`);
    } catch (error) {
      console.error('Erreur upload images lieu:', error);
      toast.error(error?.response?.data?.message ?? 'Erreur upload images');
    } finally {
      setUploadingImages(false);
    }
  }, [pendingFiles]);

  const handleSubmitAddLieu = useCallback(async () => {
    if (!addForm.nom.trim()) {
      toast.error('Le nom est obligatoire');
      return;
    }

    if (!addForm.type) {
      toast.error('Le type est obligatoire');
      return;
    }

    const lat = addForm.latitude === '' ? undefined : Number(addForm.latitude);
    const lng = addForm.longitude === '' ? undefined : Number(addForm.longitude);

    if (lat !== undefined && Number.isNaN(lat)) {
      toast.error('Latitude invalide');
      return;
    }

    if (lng !== undefined && Number.isNaN(lng)) {
      toast.error('Longitude invalide');
      return;
    }

    try {
      setSubmitting(true);

      const payload = {
        nom: addForm.nom.trim(),
        type: addForm.type,
        description: addForm.description.trim(),
        telephone: addForm.telephone.trim(),
        email: addForm.email.trim(),
        siteWeb: addForm.siteWeb.trim(),
        images: parseImageUrls(addForm.photos),
        position: {
          ville: addForm.ville.trim(),
          adresse: addForm.adresse.trim(),
          description: [addForm.adresse.trim(), addForm.ville.trim()].filter(Boolean).join(', '),
          ...(lat !== undefined ? { latitude: lat } : {}),
          ...(lng !== undefined ? { longitude: lng } : {}),
        },
      };

      const createdLieu = await createLieu(payload);
      const newRow = mapLieuToRow({
        ...(createdLieu ?? payload),
        position: {
          ...(createdLieu?.position ?? payload.position),
          ville: createdLieu?.position?.ville ?? payload.position.ville,
          adresse: createdLieu?.position?.adresse ?? payload.position.adresse,
        },
      });

      setTableData((prev) => [newRow, ...prev]);
      setOpenAddDialog(false);
      setAddForm({
        nom: '',
        type: 'Hebergement',
        ville: '',
        adresse: '',
        latitude: '',
        longitude: '',
        telephone: '',
        email: '',
        siteWeb: '',
        description: '',
        photos: '',
      });
      setPendingFiles([]);
      toast.success('Lieu ajouté avec succès');
    } catch (error) {
      console.error('Erreur ajout lieu:', error);
      toast.error(error?.response?.data?.message ?? "Impossible d'ajouter le lieu");
    } finally {
      setSubmitting(false);
    }
  }, [addForm]);

  const dataFiltered = useMemo(() => {
    const result = applyFilter({
      inputData: tableData ?? [],
      comparator: getComparator(table.order, table.orderBy),
      filters: currentFilters,
    });

    return Array.isArray(result) ? result : [];
  }, [currentFilters, table.order, table.orderBy, tableData]);

  const safeFiltered = Array.isArray(dataFiltered) ? dataFiltered : [];

  const dataInPage = rowInPage(safeFiltered, table.page, table.rowsPerPage);
  const notFound = safeFiltered.length === 0;

  const getLengthByCategorie = useCallback(
    (categorie) => tableData.filter((item) => item.categorie === categorie).length,
    [tableData]
  );

  const TABS = useMemo(
    () => [
      { value: 'all', label: 'Tous', color: 'default', count: tableData.length },
      { value: 'plage', label: 'Plage', color: 'info', count: getLengthByCategorie('plage') },
      { value: 'musee', label: 'Musée', color: 'secondary', count: getLengthByCategorie('musee') },
      { value: 'hotel', label: 'Hôtel', color: 'success', count: getLengthByCategorie('hotel') },
      {
        value: 'restaurant',
        label: 'Restaurant',
        color: 'warning',
        count: getLengthByCategorie('restaurant'),
      },
      {
        value: 'monument',
        label: 'Monument',
        color: 'error',
        count: getLengthByCategorie('monument'),
      },
    ],
    [getLengthByCategorie, tableData.length]
  );

  const handleFilterCategorie = useCallback(
    (event, newValue) => {
      table.onResetPage();
      updateFilters({ categorie: newValue });
    },
    [table, updateFilters]
  );

  const handleDeleteRow = useCallback(
    (id) => {
      const next = tableData.filter((row) => row.id !== id);
      setTableData(next);
      toast.success('Suppression effectuée');
      table.onUpdatePageDeleteRow(dataInPage?.length ?? 0);
    },
    [dataInPage?.length, table, tableData]
  );

  const handleDeleteRows = useCallback(() => {
    const next = tableData.filter((row) => !table.selected.includes(row.id));
    setTableData(next);
    toast.success('Suppression effectuée');
    table.onUpdatePageDeleteRows(dataInPage?.length ?? 0, safeFiltered.length);
  }, [dataInPage?.length, safeFiltered.length, table, tableData]);

  const canReset =
    currentFilters.categorie !== 'all' || !!currentFilters.name || currentFilters.ville.length > 0;

  const handleResetFilters = useCallback(() => {
    table.onResetPage();
    updateFilters({ name: '', ville: [], categorie: 'all' });
  }, [table, updateFilters]);

  const villeOptions = useMemo(() => {
    const villes = tableData.map((item) => item.ville).filter(Boolean);
    return [...new Set(villes)];
  }, [tableData]);

  return (
    <LocalizationProvider dateAdapter={AdapterDayjs}>
      <DashboardContent maxWidth="xl" sx={sx}>
        <PageHeader title={String(title)} onAdd={handleOpenAddDialog} />

        <Card>
          <InvoiceFilters
            tabs={TABS}
            filters={filters}
            options={{ villes: villeOptions }}
            canReset={canReset}
            onResetPage={table.onResetPage}
            onFilterStatus={handleFilterCategorie}
            onResetFilters={handleResetFilters}
          />

          <InvoiceTable
            table={table}
            rows={safeFiltered}
            tableHead={TABLE_HEAD}
            notFound={notFound}
            loading={loading}
            categorieColor={categorieColor}
            calculateAverageNote={calculateAverageNote}
            onDeleteRow={handleDeleteRow}
            onDeleteSelected={handleDeleteRows}
            onViewDetails={handleOpenLieuDetails}
          />
        </Card>

        <LieuDetailsDialog open={openLieuDetails} onClose={handleCloseLieuDetails} lieu={selectedLieu} />

        <Dialog open={openAddDialog} onClose={handleCloseAddDialog} fullWidth maxWidth="sm">
          <DialogTitle>Ajouter un lieu</DialogTitle>

          <DialogContent>
            <Box
              sx={{
                mt: 1,
                gap: 2,
                display: 'grid',
                gridTemplateColumns: { xs: '1fr', sm: 'repeat(2, 1fr)' },
              }}
            >
              <TextField
                label="Nom"
                value={addForm.nom}
                onChange={(e) => handleChangeAddForm('nom', e.target.value)}
                required
                fullWidth
              />

              <TextField
                select
                label="Type"
                value={addForm.type}
                onChange={(e) => handleChangeAddForm('type', e.target.value)}
                fullWidth
              >
                <MenuItem value="Hebergement">Hebergement</MenuItem>
                <MenuItem value="Mosquee">Mosquee</MenuItem>
                <MenuItem value="Comercial">Comercial</MenuItem>
                <MenuItem value="RestauCafe">RestauCafe</MenuItem>
                <MenuItem value="Plage">Plage</MenuItem>
                <MenuItem value="Sante">Sante</MenuItem>
              </TextField>

              <TextField
                label="Ville"
                value={addForm.ville}
                onChange={(e) => handleChangeAddForm('ville', e.target.value)}
                fullWidth
              />

              <TextField
                label="Adresse"
                value={addForm.adresse}
                onChange={(e) => handleChangeAddForm('adresse', e.target.value)}
                fullWidth
              />

              <TextField
                label="Latitude"
                value={addForm.latitude}
                onChange={(e) => handleChangeAddForm('latitude', e.target.value)}
                fullWidth
              />

              <TextField
                label="Longitude"
                value={addForm.longitude}
                onChange={(e) => handleChangeAddForm('longitude', e.target.value)}
                fullWidth
              />

              <TextField
                label="Telephone"
                value={addForm.telephone}
                onChange={(e) => handleChangeAddForm('telephone', e.target.value)}
                fullWidth
              />

              <TextField
                label="Email"
                type="email"
                value={addForm.email}
                onChange={(e) => handleChangeAddForm('email', e.target.value)}
                fullWidth
              />

              <TextField
                label="Site web"
                value={addForm.siteWeb}
                onChange={(e) => handleChangeAddForm('siteWeb', e.target.value)}
                fullWidth
              />

              <TextField
                label="Description"
                value={addForm.description}
                onChange={(e) => handleChangeAddForm('description', e.target.value)}
                multiline
                minRows={3}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />

              <TextField
                label="Photos (URLs)"
                placeholder="https://... (une URL par ligne ou séparée par virgule)"
                value={addForm.photos}
                onChange={(e) => handleChangeAddForm('photos', e.target.value)}
                multiline
                minRows={3}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />

              <Box sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}>
                <Box sx={{ display: 'flex', gap: 1, alignItems: 'center', flexWrap: 'wrap' }}>
                  <Button variant="outlined" component="label" disabled={uploadingImages}>
                    Choisir des photos
                    <input hidden type="file" multiple accept="image/*" onChange={handleSelectImages} />
                  </Button>

                  <Button
                    variant="contained"
                    onClick={handleUploadSelectedImages}
                    disabled={uploadingImages || !pendingFiles.length}
                  >
                    {uploadingImages ? 'Upload...' : 'Uploader les photos'}
                  </Button>

                  <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                    {pendingFiles.length ? `${pendingFiles.length} fichier(s) prêt(s)` : ''}
                  </Typography>
                </Box>
              </Box>

              {parseImageUrls(addForm.photos).length ? (
                <Box
                  sx={{
                    gap: 1,
                    display: 'flex',
                    flexWrap: 'wrap',
                    gridColumn: { xs: '1 / -1', sm: '1 / -1' },
                  }}
                >
                  {parseImageUrls(addForm.photos)
                    .slice(0, 8)
                    .map((image, index) => (
                      <Box
                        key={`preview_${index}`}
                        component="img"
                        src={image}
                        alt={`preview-${index + 1}`}
                        sx={{
                          width: 56,
                          height: 56,
                          borderRadius: 1,
                          objectFit: 'cover',
                          border: (theme) => `1px solid ${theme.palette.divider}`,
                        }}
                      />
                    ))}
                </Box>
              ) : null}
            </Box>
          </DialogContent>

          <DialogActions>
            <Button onClick={handleCloseAddDialog} disabled={submitting || uploadingImages}>
              Annuler
            </Button>
            <Button
              variant="contained"
              onClick={handleSubmitAddLieu}
              disabled={submitting || uploadingImages}
            >
              {submitting ? 'Ajout...' : 'Ajouter'}
            </Button>
          </DialogActions>
        </Dialog>
      </DashboardContent>
    </LocalizationProvider>
  );
}
