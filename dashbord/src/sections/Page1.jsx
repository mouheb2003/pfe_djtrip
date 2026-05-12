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
import IconButton from '@mui/material/IconButton';
import { AdapterDayjs } from '@mui/x-date-pickers/AdapterDayjs';
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';

import { getLieux, createLieu, updateLieu, deleteLieu, uploadLieuImages } from 'src/Controller/actions';
import { DashboardContent } from 'src/layouts/dashboard';

import { toast } from 'src/components/snackbar';
import { Iconify } from 'src/components/iconify';
import { useTable, rowInPage, getComparator } from 'src/components/table';

import { PageHeader } from './Page1/Header';
import { InvoiceTable } from './Page1/Tableau';
import { InvoiceFilters } from './Page1/Filter';
import { LieuDetailsDialog } from './Page1/Components/LieuDetails';

// ----------------------------------------------------------------------

const TABLE_HEAD = [
  { id: 'checkbox', label: '', disableSort: true, align: 'center' },
  { id: 'nom', label: 'Nom' },
  { id: 'type', label: 'Type' },
  { id: 'city', label: 'Ville' },
  { id: 'country', label: 'Pays' },
  { id: 'price_per_adult', label: 'Prix' },
  { id: 'telephone', label: 'Téléphone' },
  { id: 'website', label: 'Site Web' },
  { id: 'rating', label: 'Note', align: 'center' },
  { id: 'is_featured', label: 'En vedette', align: 'center' },
  { id: 'popularity_score', label: 'Popularité', align: 'center' },
  { id: 'actions', label: '' },
];

function categorieColor(categorie) {
  const normalized = String(categorie ?? '').toLowerCase();

  switch (normalized) {
    case 'beach':
      return 'info';
    case 'accommodation':
    case 'hotel':
      return 'success';
    case 'food':
    case 'restaurant':
      return 'warning';
    case 'museum':
    case 'musee':
      return 'secondary';
    case 'shopping':
      return 'primary';
    case 'monument':
      return 'default';
    default:
      if (normalized.includes('hotel') || normalized.includes('heberg')) return 'success';
      if (normalized.includes('restaurant') || normalized.includes('food')) return 'warning';
      if (normalized.includes('museum') || normalized.includes('musee')) return 'secondary';
      if (normalized.includes('shopping') || normalized.includes('shop') || normalized.includes('store') || normalized.includes('mall') || normalized.includes('market')) return 'primary';
      return 'default';
  }
}

function normalizeLieuType(value) {
  const normalized = String(value ?? '').toLowerCase();

  if (
    normalized.includes('accommodation') ||
    normalized.includes('hotel') ||
    normalized.includes('lodging') ||
    normalized.includes('motel') ||
    normalized.includes('hostel') ||
    normalized.includes('resort') ||
    normalized.includes('guest') ||
    normalized.includes('heberg')
  ) {
    return 'accommodation';
  }

  if (
    normalized.includes('food') ||
    normalized.includes('restaurant') ||
    normalized.includes('cafe') ||
    normalized.includes('bakery') ||
    normalized.includes('bar') ||
    normalized.includes('meal_takeaway') ||
    normalized.includes('meal_delivery') ||
    normalized.includes('fast_food')
  ) {
    return 'food';
  }

  if (normalized.includes('museum') || normalized.includes('musee')) {
    return 'museum';
  }

  if (
    normalized.includes('shopping') ||
    normalized.includes('shop') ||
    normalized.includes('store') ||
    normalized.includes('mall') ||
    normalized.includes('market') ||
    normalized.includes('supermarket')
  ) {
    return 'shopping';
  }

  if (normalized.includes('beach') || normalized.includes('plage')) {
    return 'beach';
  }

  if (normalized.includes('activity') || normalized.includes('activ') || normalized.includes('tourist_attraction')) {
    return 'activity';
  }

  if (normalized.includes('landmark') || normalized.includes('monument') || normalized.includes('site') || normalized.includes('historic')) {
    return 'other';
  }

  return 'other';
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
    data = data.filter((row) => row.categorie === categorie || row.type === categorie);
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
  const type = normalizeLieuType(lieu.categorie ?? lieu.type ?? 'other');
  const opening = lieu.opening_hours ?? lieu.openingHours ?? lieu.horaire?.ouverture ?? '';
  const closing = lieu.closing_hours ?? lieu.closingHours ?? lieu.horaire?.fermeture ?? '';
  const horaires = (opening && closing) ? `${opening} - ${closing}` : opening || closing || '';
  const telephone = lieu.telephone ?? '';
  const siteWeb = lieu.website ?? lieu.site ?? lieu.siteWeb ?? lieu.booking_link ?? '';

  // Handle images from backend model (main_image and gallery)
  const images = [];
  if (lieu.main_image) images.push(lieu.main_image);
  if (Array.isArray(lieu.gallery)) images.push(...lieu.gallery);
  if (Array.isArray(lieu.galerieImages)) images.push(...lieu.galerieImages);
  if (Array.isArray(lieu.images)) images.push(...lieu.images);

  return {
    id: lieu._id ?? lieu.id,
    nom: lieu.nom ?? lieu.name ?? '',
    slug: lieu.slug ?? '',
    type: type,
    categorie: type,
    address: lieu.address ?? lieu.adresse ?? lieu.position?.adresse ?? lieu.position?.description ?? '',
    city: lieu.city ?? lieu.ville ?? lieu.position?.ville ?? '',
    country: lieu.country ?? '',
    zipcode: lieu.zipcode ?? '',
    coordinates: lieu.coordinates ?? {
      latitude: lieu.position?.localisation?.latitude ?? lieu.position?.latitude ?? lieu.latitude ?? 0,
      longitude: lieu.position?.localisation?.longitude ?? lieu.position?.longitude ?? lieu.longitude ?? 0,
    },
    latitude: lieu.position?.localisation?.latitude ?? lieu.position?.latitude ?? lieu.coordinates?.latitude ?? lieu.latitude ?? 0,
    longitude: lieu.position?.localisation?.longitude ?? lieu.position?.longitude ?? lieu.coordinates?.longitude ?? lieu.longitude ?? 0,
    main_image: lieu.main_image ?? '',
    gallery: images,
    video: lieu.video ?? '',
    short_description: lieu.short_description ?? lieu.description ?? '',
    long_description: lieu.long_description ?? '',
    experience_description: lieu.experience_description ?? '',
    heritage_history: lieu.heritage_history ?? '',
    history: lieu.history ?? '',
    highlights: Array.isArray(lieu.highlights) ? lieu.highlights.join(', ') : '',
    experience_highlights: Array.isArray(lieu.experience_highlights) ? lieu.experience_highlights.join(', ') : '',
    amenities: Array.isArray(lieu.amenities) ? lieu.amenities.join(', ') : '',
    activities: Array.isArray(lieu.activities) ? lieu.activities.join(', ') : '',
    languages_spoken: Array.isArray(lieu.languages_spoken) ? lieu.languages_spoken.join(', ') : '',
    wheelchair_access: lieu.wheelchair_access ?? false,
    opening_hours: opening,

    horaires: horaires,

    price_range: lieu.price_range ?? '',
    price_per_adult: lieu.price_per_adult ?? lieu.prix ?? 0,
    min_price: lieu.min_price ?? 0,
    max_price: lieu.max_price ?? 0,
    currency: lieu.currency ?? 'TND',
    discounts: lieu.discounts ?? '',
    booking_link: lieu.booking_link ?? lieu.website ?? lieu.site ?? lieu.siteWeb ?? '',
    telephone: telephone,
    siteWeb: siteWeb,
    rating: lieu.rating ?? 0,
    review_count: lieu.review_count ?? lieu.reviews?.length ?? 0,
    reviews: Array.isArray(lieu.reviews) ? lieu.reviews : [],
    popularity_score: lieu.popularity_score ?? 0,
    is_featured: lieu.is_featured ?? false,
    tags: Array.isArray(lieu.tags) ? lieu.tags.join(', ') : '',
    galerieImages: images,
    avis: Array.isArray(lieu.avis)
      ? lieu.avis.map((item) => ({
          ...item,
          note: item.note ?? item.rating ?? 0,
        }))
      : (Array.isArray(lieu.reviews) ? lieu.reviews.map((item) => ({
          ...item,
          note: item.rating ?? 0,
        })) : []),
    createdAt: lieu.createdAt,
    updatedAt: lieu.updatedAt,
  };
}

// ----------------------------------------------------------------------

export function BlankView({ title = 'Lieux', sx }) {
  const table = useTable({ defaultOrderBy: 'nom' });
  const [tableData, setTableData] = useState([]);
  const [loading, setLoading] = useState(true);
  const [openAddDialog, setOpenAddDialog] = useState(false);
  const [openEditDialog, setOpenEditDialog] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [uploadingImages, setUploadingImages] = useState(false);
  const [pendingFiles, setPendingFiles] = useState([]);
  const [selectedLieu, setSelectedLieu] = useState(null);
  const [openLieuDetails, setOpenLieuDetails] = useState(false);
  const [deleteDialogOpen, setDeleteDialogOpen] = useState(false);
  const [deleteTarget, setDeleteTarget] = useState(null); // 'single' or 'multiple'
  const [deleteId, setDeleteId] = useState(null);
  const [editForm, setEditForm] = useState({
    id: '',
    nom: '',
    slug: '',
    type: 'accommodation',
    address: '',
    city: '',
    country: '',
    zipcode: '',
    latitude: '',
    longitude: '',
    telephone: '',
    main_image: '',
    gallery: '',
    video: '',
    short_description: '',
    long_description: '',
    experience_description: '',
    heritage_history: '',
    history: '',
    highlights: '',
    experience_highlights: '',
    amenities: '',
    activities: '',
    languages_spoken: '',
    wheelchair_access: false,
    opening_hours: '',
    price_range: '',
    price_per_adult: '',
    min_price: '',
    max_price: '',
    currency: 'TND',
    discounts: '',
    booking_link: '',
    website: '',
    rating: 0,
    tags: '',
  });
  const [editPendingFiles, setEditPendingFiles] = useState([]);
  const [addForm, setAddForm] = useState({
    nom: '',
    slug: '',
    type: 'accommodation',
    address: '',
    city: '',
    country: '',
    zipcode: '',
    latitude: '',
    longitude: '',
    telephone: '',
    main_image: '',
    gallery: '',
    video: '',
    short_description: '',
    long_description: '',
    experience_description: '',
    heritage_history: '',
    history: '',
    highlights: '',
    experience_highlights: '',
    amenities: '',
    activities: '',
    languages_spoken: '',
    wheelchair_access: false,
    opening_hours: '',
    price_range: '',
    price_per_adult: '',
    min_price: '',
    max_price: '',
    currency: 'TND',
    discounts: '',
    booking_link: '',
    website: '',
    rating: 0,
    tags: '',
  });

  const filters = useSetState({
    name: '',
    ville: [],
    categorie: 'all',
  });
  const { state: currentFilters, setState: updateFilters } = filters;

  // Reset categorie filter if it's no longer valid (e.g., after removing 'activity')
  useEffect(() => {
    const validCategories = TABS.map(tab => tab.value);
    if (currentFilters.categorie && !validCategories.includes(currentFilters.categorie)) {
      updateFilters({ categorie: 'all' });
    }
  }, [currentFilters.categorie, updateFilters]);

  // Fetch lieux from API
  const fetchLieux = useCallback(async () => {
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
  }, []);

  useEffect(() => {
    fetchLieux();
  }, [fetchLieux]);

  const handleOpenEditDialog = useCallback((row) => {
    setEditForm({
      id: row.id,
      nom: row.nom,
      slug: row.slug || '',
      type: row.type || row.categorie || 'accommodation',
      address: row.address || row.adresse || '',
      city: row.city || row.ville || '',
      country: row.country || '',
      zipcode: row.zipcode || '',
      latitude: row.latitude || '',
      longitude: row.longitude || '',
      telephone: row.telephone || '',
      main_image: row.main_image || '',
      gallery: Array.isArray(row.gallery) ? row.gallery.join('\n') : row.galerieImages?.join('\n') || '',
      video: row.video || '',
      short_description: row.short_description || row.description || '',
      long_description: row.long_description || '',
      experience_description: row.experience_description || '',
      heritage_history: row.heritage_history || '',
      history: row.history || '',
      highlights: row.highlights || '',
      experience_highlights: row.experience_highlights || '',
      amenities: row.amenities || '',
      activities: row.activities || '',
      languages_spoken: row.languages_spoken || '',
      wheelchair_access: row.wheelchair_access || false,
      opening_hours: row.opening_hours || row.openingHours || '',
      price_range: row.price_range || '',
      price_per_adult: row.price_per_adult || row.prix || '',
      min_price: row.min_price || '',
      max_price: row.max_price || '',
      currency: row.currency || 'TND',
      discounts: row.discounts || '',
      booking_link: row.booking_link || row.siteWeb || '',
      website: row.siteWeb || '',
      rating: row.rating || 0,
      tags: row.tags || '',
    });
    setOpenEditDialog(true);
  }, []);

  const handleCloseEditDialog = useCallback(() => {
    setOpenEditDialog(false);
    setEditForm({
      id: '',
      nom: '',
      slug: '',
      type: 'accommodation',
      address: '',
      city: '',
      country: '',
      zipcode: '',
      latitude: '',
      longitude: '',
      telephone: '',
      main_image: '',
      gallery: '',
      video: '',
      short_description: '',
      long_description: '',
      experience_description: '',
      heritage_history: '',
      history: '',
      highlights: '',
      experience_highlights: '',
      amenities: '',
      activities: '',
      languages_spoken: '',
      wheelchair_access: false,
      opening_hours: '',
      price_range: '',
      price_per_adult: '',
      min_price: '',
      max_price: '',
      currency: 'TND',
      discounts: '',
      booking_link: '',
      website: '',
      rating: 0,
      tags: '',
    });
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

  const handleChangeEditForm = useCallback((field, value) => {
    setEditForm((prev) => ({ ...prev, [field]: value }));
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
        const existing = parseImageUrls(prev.gallery);
        const merged = [...new Set([...existing, ...uploadedUrls])];
        return { ...prev, gallery: merged.join('\n') };
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

  const handleSelectEditImages = useCallback((event) => {
    const files = Array.from(event.target.files ?? []);
    setEditPendingFiles(files);
  }, []);

  const handleUploadEditImages = useCallback(async () => {
    if (!editPendingFiles.length) {
      toast.info('Sélectionnez au moins une image');
      return;
    }

    try {
      setUploadingImages(true);
      const uploadedUrls = await uploadLieuImages(editPendingFiles);

      setEditForm((prev) => {
        const existing = parseImageUrls(prev.gallery);
        const merged = [...new Set([...existing, ...uploadedUrls])];
        return { ...prev, gallery: merged.join('\n') };
      });

      setEditPendingFiles([]);
      toast.success(`${uploadedUrls.length} image(s) uploadée(s)`);
    } catch (error) {
      console.error('Erreur upload images lieu:', error);
      toast.error(error?.response?.data?.message ?? 'Erreur upload images');
    } finally {
      setUploadingImages(false);
    }
  }, [editPendingFiles]);

  const handleDeleteEditImage = useCallback((index) => {
    setEditForm((prev) => {
      const images = parseImageUrls(prev.gallery);
      const newImages = images.filter((_, i) => i !== index);
      return { ...prev, gallery: newImages.join('\n') };
    });
  }, []);

  const handleSubmitAddLieu = useCallback(async () => {
    if (!addForm.nom.trim()) {
      toast.error('Le nom est requis');
      return;
    }

    if (!addForm.type) {
      toast.error('Le type est requis');
      return;
    }

    const lat = addForm.latitude ? parseFloat(addForm.latitude) : undefined;
    const lng = addForm.longitude ? parseFloat(addForm.longitude) : undefined;

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
        name: addForm.nom.trim(),
        slug: addForm.slug.trim() || undefined,
        type: addForm.type,
        ...(addForm.address.trim() ? { address: addForm.address.trim() } : {}),
        ...(addForm.city.trim() ? { city: addForm.city.trim() } : {}),
        ...(addForm.country.trim() ? { country: addForm.country.trim() } : {}),
        ...(addForm.zipcode.trim() ? { zipcode: addForm.zipcode.trim() } : {}),
        ...(lat !== undefined || lng !== undefined ? {
          coordinates: {
            ...(lat !== undefined ? { latitude: lat } : {}),
            ...(lng !== undefined ? { longitude: lng } : {}),
          }
        } : {}),
        ...(addForm.telephone.trim() ? { telephone: addForm.telephone.trim() } : {}),
        ...(addForm.main_image.trim() ? { main_image: addForm.main_image.trim() } : {}),
        ...(parseImageUrls(addForm.gallery).length > 0 ? { gallery: parseImageUrls(addForm.gallery) } : {}),
        ...(addForm.video.trim() ? { video: addForm.video.trim() } : {}),
        ...(addForm.short_description.trim() ? { short_description: addForm.short_description.trim() } : {}),
        ...(addForm.long_description.trim() ? { long_description: addForm.long_description.trim() } : {}),
        ...(addForm.experience_description.trim() ? { experience_description: addForm.experience_description.trim() } : {}),
        ...(addForm.heritage_history.trim() ? { heritage_history: addForm.heritage_history.trim() } : {}),
        ...(addForm.history.trim() ? { history: addForm.history.trim() } : {}),
        ...(addForm.highlights.trim() ? { highlights: addForm.highlights.split(',').map(h => h.trim()).filter(Boolean) } : {}),
        ...(addForm.experience_highlights.trim() ? { experience_highlights: addForm.experience_highlights.split(',').map(h => h.trim()).filter(Boolean) } : {}),
        ...(addForm.amenities.trim() ? { amenities: addForm.amenities.split(',').map(a => a.trim()).filter(Boolean) } : {}),
        ...(addForm.activities.trim() ? { activities: addForm.activities.split(',').map(a => a.trim()).filter(Boolean) } : {}),
        ...(addForm.languages_spoken.trim() ? { languages_spoken: addForm.languages_spoken.split(',').map(l => l.trim()).filter(Boolean) } : {}),
        wheelchair_access: addForm.wheelchair_access,
        ...(addForm.opening_hours.trim() ? { opening_hours: addForm.opening_hours.trim() } : {}),
        ...(addForm.price_range.trim() ? { price_range: addForm.price_range.trim() } : {}),
        ...(addForm.price_per_adult ? { price_per_adult: parseFloat(addForm.price_per_adult) } : {}),
        ...(addForm.min_price ? { min_price: parseFloat(addForm.min_price) } : {}),
        ...(addForm.max_price ? { max_price: parseFloat(addForm.max_price) } : {}),
        ...(addForm.currency.trim() ? { currency: addForm.currency.trim() } : {}),
        ...(addForm.discounts.trim() ? { discounts: addForm.discounts.trim() } : {}),
        ...(addForm.website.trim() ? { website: addForm.website.trim() } : {}),
        ...(addForm.booking_link.trim() ? { booking_link: addForm.booking_link.trim() } : {}),
        ...(addForm.tags.trim() ? { tags: addForm.tags.split(',').map(t => t.trim()).filter(Boolean) } : {}),
      };

      const createdLieu = await createLieu(payload);
      const newRow = mapLieuToRow(createdLieu ?? payload);

      setTableData((prev) => [newRow, ...prev]);
      setOpenAddDialog(false);
      setAddForm({
        nom: '',
        slug: '',
        type: 'accommodation',
        address: '',
        city: '',
        country: '',
        zipcode: '',
        latitude: '',
        longitude: '',
        telephone: '',
        main_image: '',
        gallery: '',
        video: '',
        short_description: '',
        long_description: '',
        experience_description: '',
        heritage_history: '',
        history: '',
        highlights: '',
        experience_highlights: '',
        amenities: '',
        activities: '',
        languages_spoken: '',
        wheelchair_access: false,
        opening_hours: '',
        price_range: '',
        price_per_adult: '',
        min_price: '',
        max_price: '',
        currency: 'TND',
        discounts: '',
        booking_link: '',
        website: '',
        rating: 0,
        tags: '',
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

  const handleSubmitEditLieu = useCallback(async () => {
    if (!editForm.nom.trim()) {
      toast.error('Le nom est requis');
      return;
    }

    if (!editForm.type) {
      toast.error('Le type est requis');
      return;
    }

    const lat = editForm.latitude ? parseFloat(editForm.latitude) : undefined;
    const lng = editForm.longitude ? parseFloat(editForm.longitude) : undefined;

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
        name: editForm.nom.trim(),
        slug: editForm.slug.trim() || undefined,
        type: editForm.type,
        ...(editForm.address.trim() ? { address: editForm.address.trim() } : {}),
        ...(editForm.city.trim() ? { city: editForm.city.trim() } : {}),
        ...(editForm.country.trim() ? { country: editForm.country.trim() } : {}),
        ...(editForm.zipcode.trim() ? { zipcode: editForm.zipcode.trim() } : {}),
        ...(lat !== undefined || lng !== undefined ? {
          coordinates: {
            ...(lat !== undefined ? { latitude: lat } : {}),
            ...(lng !== undefined ? { longitude: lng } : {}),
          }
        } : {}),
        ...(editForm.telephone.trim() ? { telephone: editForm.telephone.trim() } : {}),
        ...(editForm.main_image.trim() ? { main_image: editForm.main_image.trim() } : {}),
        ...(parseImageUrls(editForm.gallery).length > 0 ? { gallery: parseImageUrls(editForm.gallery) } : {}),
        ...(editForm.video.trim() ? { video: editForm.video.trim() } : {}),
        ...(editForm.short_description.trim() ? { short_description: editForm.short_description.trim() } : {}),
        ...(editForm.long_description.trim() ? { long_description: editForm.long_description.trim() } : {}),
        ...(editForm.experience_description.trim() ? { experience_description: editForm.experience_description.trim() } : {}),
        ...(editForm.heritage_history.trim() ? { heritage_history: editForm.heritage_history.trim() } : {}),
        ...(editForm.history.trim() ? { history: editForm.history.trim() } : {}),
        ...(editForm.highlights.trim() ? { highlights: editForm.highlights.split(',').map(h => h.trim()).filter(Boolean) } : {}),
        ...(editForm.experience_highlights.trim() ? { experience_highlights: editForm.experience_highlights.split(',').map(h => h.trim()).filter(Boolean) } : {}),
        ...(editForm.amenities.trim() ? { amenities: editForm.amenities.split(',').map(a => a.trim()).filter(Boolean) } : {}),
        ...(editForm.activities.trim() ? { activities: editForm.activities.split(',').map(a => a.trim()).filter(Boolean) } : {}),
        ...(editForm.languages_spoken.trim() ? { languages_spoken: editForm.languages_spoken.split(',').map(l => l.trim()).filter(Boolean) } : {}),
        wheelchair_access: editForm.wheelchair_access,
        ...(editForm.opening_hours.trim() ? { opening_hours: editForm.opening_hours.trim() } : {}),
        ...(editForm.price_range.trim() ? { price_range: editForm.price_range.trim() } : {}),
        ...(editForm.price_per_adult ? { price_per_adult: parseFloat(editForm.price_per_adult) } : {}),
        ...(editForm.min_price ? { min_price: parseFloat(editForm.min_price) } : {}),
        ...(editForm.max_price ? { max_price: parseFloat(editForm.max_price) } : {}),
        ...(editForm.currency.trim() ? { currency: editForm.currency.trim() } : {}),
        ...(editForm.discounts.trim() ? { discounts: editForm.discounts.trim() } : {}),
        ...(editForm.website.trim() ? { website: editForm.website.trim() } : {}),
        ...(editForm.booking_link.trim() ? { booking_link: editForm.booking_link.trim() } : {}),
        ...(editForm.tags.trim() ? { tags: editForm.tags.split(',').map(t => t.trim()).filter(Boolean) } : {}),
      };

      const updatedLieu = await updateLieu(editForm.id, payload);
      const updatedRow = mapLieuToRow(updatedLieu ?? payload);

      setTableData((prev) => prev.map((row) => (row.id === editForm.id ? updatedRow : row)));
      setOpenEditDialog(false);
      setEditForm({
        id: '',
        nom: '',
        slug: '',
        type: 'accommodation',
        address: '',
        city: '',
        country: '',
        zipcode: '',
        latitude: '',
        longitude: '',
        telephone: '',
        main_image: '',
        gallery: '',
        video: '',
        short_description: '',
        long_description: '',
        experience_description: '',
        heritage_history: '',
        history: '',
        highlights: '',
        experience_highlights: '',
        amenities: '',
        activities: '',
        languages_spoken: '',
        wheelchair_access: false,
        opening_hours: '',
        price_range: '',
        price_per_adult: '',
        min_price: '',
        max_price: '',
        currency: 'TND',
        discounts: '',
        booking_link: '',
        website: '',
        rating: 0,
        tags: '',
      });
      setEditPendingFiles([]);
      toast.success('Lieu modifié avec succès');
    } catch (error) {
      console.error('Erreur modification lieu:', error);
      toast.error(error?.response?.data?.message ?? "Impossible de modifier le lieu");
    } finally {
      setSubmitting(false);
    }
  }, [editForm]);

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
    (categorie) => tableData.filter((item) => item.categorie === categorie || item.type === categorie).length,
    [tableData]
  );

  const TABS = useMemo(
    () => [
      { value: 'all', label: 'All', color: 'default', count: tableData.length },
      { value: 'beach', label: 'Beach', color: 'info', count: getLengthByCategorie('beach') },
      { value: 'accommodation', label: 'Accommodation', color: 'success', count: getLengthByCategorie('accommodation') },
      { value: 'food', label: 'Food', color: 'warning', count: getLengthByCategorie('food') },
      { value: 'museum', label: 'Museum', color: 'secondary', count: getLengthByCategorie('museum') },
      { value: 'shopping', label: 'Shopping', color: 'primary', count: getLengthByCategorie('shopping') },
      { value: 'other', label: 'Other', color: 'default', count: getLengthByCategorie('other') },
    ],
    [getLengthByCategorie, tableData.length]
  );

  const handleFilterCategorie = useCallback(
    (event, newValue) => {
      table.onResetPage();
      updateFilters({ categorie: newValue ?? 'all' });
    },
    [table, updateFilters]
  );

  const handleDeleteRow = useCallback(
    (id) => {
      setDeleteTarget('single');
      setDeleteId(id);
      setDeleteDialogOpen(true);
    },
    []
  );

  const handleDeleteRows = useCallback(() => {
    setDeleteTarget('multiple');
    setDeleteDialogOpen(true);
  }, []);

  const handleConfirmDelete = useCallback(async () => {
    try {
      if (deleteTarget === 'single' && deleteId) {
        await deleteLieu(deleteId);
        table.onUpdatePageDeleteRow(dataInPage?.length ?? 0);
      } else if (deleteTarget === 'multiple') {
        const deletableIds = [...table.selected];
        await Promise.all(deletableIds.map((id) => deleteLieu(id)));
        table.onUpdatePageDeleteRows(dataInPage?.length ?? 0, safeFiltered.length);
      } else {
        return;
      }

      await fetchLieux();
      toast.success('Suppression effectuée');
    } catch (error) {
      console.error('Erreur lors de la suppression du lieu:', error);
      toast.error('Échec de la suppression');
    } finally {
      setDeleteDialogOpen(false);
      setDeleteTarget(null);
      setDeleteId(null);
    }
  }, [deleteTarget, deleteId, table, dataInPage?.length, safeFiltered.length, fetchLieux]);

  const handleCancelDelete = useCallback(() => {
    setDeleteDialogOpen(false);
    setDeleteTarget(null);
    setDeleteId(null);
  }, []);

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
        <PageHeader title={String(title)} />

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
            onEdit={handleOpenEditDialog}
          />
        </Card>

        <LieuDetailsDialog open={openLieuDetails} onClose={handleCloseLieuDetails} lieu={selectedLieu} onRefresh={fetchLieux} />

        <Dialog open={deleteDialogOpen} onClose={handleCancelDelete} maxWidth="sm" fullWidth>
          <DialogTitle>Confirmer la suppression</DialogTitle>
          <DialogContent>
            <Typography variant="body2" sx={{ mt: 2 }}>
              {deleteTarget === 'single'
                ? 'Êtes-vous sûr de vouloir supprimer ce lieu ?'
                : `Êtes-vous sûr de vouloir supprimer ${table.selected.length} lieu(s) sélectionné(s) ?`}
            </Typography>
          </DialogContent>
          <DialogActions>
            <Button onClick={handleCancelDelete}>Annuler</Button>
            <Button onClick={handleConfirmDelete} variant="contained" color="error">
              Supprimer
            </Button>
          </DialogActions>
        </Dialog>

        <Dialog open={openEditDialog} onClose={handleCloseEditDialog} fullWidth maxWidth="lg">
          <DialogTitle>Modifier un lieu</DialogTitle>

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
                value={editForm.nom}
                onChange={(e) => handleChangeEditForm('nom', e.target.value)}
                required
                fullWidth
              />

              <TextField
                label="Slug"
                value={editForm.slug}
                onChange={(e) => handleChangeEditForm('slug', e.target.value)}
                fullWidth
                helperText="URL-friendly name"
              />

              <TextField
                select
                label="Type"
                value={editForm.type}
                onChange={(e) => handleChangeEditForm('type', e.target.value)}
                fullWidth
              >
                <MenuItem value="accommodation">Accommodation</MenuItem>
                <MenuItem value="beach">Beach</MenuItem>
                <MenuItem value="food">Food</MenuItem>
                <MenuItem value="activity">Activity</MenuItem>
                <MenuItem value="museum">Museum</MenuItem>
                <MenuItem value="shopping">Shopping</MenuItem>
                <MenuItem value="other">Other</MenuItem>
              </TextField>

              <TextField
                label="Adresse"
                value={editForm.address}
                onChange={(e) => handleChangeEditForm('address', e.target.value)}
                fullWidth
              />

              <TextField
                label="Ville"
                value={editForm.city}
                onChange={(e) => handleChangeEditForm('city', e.target.value)}
                fullWidth
              />

              <TextField
                label="Pays"
                value={editForm.country}
                onChange={(e) => handleChangeEditForm('country', e.target.value)}
                fullWidth
              />

              <TextField
                label="Code postal"
                value={editForm.zipcode}
                onChange={(e) => handleChangeEditForm('zipcode', e.target.value)}
                fullWidth
              />

              <TextField
                label="Latitude"
                value={editForm.latitude}
                onChange={(e) => handleChangeEditForm('latitude', e.target.value)}
                fullWidth
                type="number"
              />

              <TextField
                label="Longitude"
                value={editForm.longitude}
                onChange={(e) => handleChangeEditForm('longitude', e.target.value)}
                fullWidth
                type="number"
              />

              <TextField
                label="Téléphone"
                value={editForm.telephone}
                onChange={(e) => handleChangeEditForm('telephone', e.target.value)}
                fullWidth
              />

              <TextField
                label="Image principale (URL)"
                value={editForm.main_image}
                onChange={(e) => handleChangeEditForm('main_image', e.target.value)}
                fullWidth
              />

              <TextField
                label="Galerie (URLs)"
                placeholder="Une URL par ligne"
                value={editForm.gallery}
                onChange={(e) => handleChangeEditForm('gallery', e.target.value)}
                multiline
                minRows={2}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />

              <TextField
                label="Vidéo (URL)"
                value={editForm.video}
                onChange={(e) => handleChangeEditForm('video', e.target.value)}
                fullWidth
              />

              <TextField
                label="Site web"
                value={editForm.website}
                onChange={(e) => handleChangeEditForm('website', e.target.value)}
                fullWidth
              />

              <TextField
                label="Description courte"
                value={editForm.short_description}
                onChange={(e) => handleChangeEditForm('short_description', e.target.value)}
                multiline
                minRows={2}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />

              <TextField
                label="Description longue"
                value={editForm.long_description}
                onChange={(e) => handleChangeEditForm('long_description', e.target.value)}
                multiline
                minRows={3}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />

              <TextField
                label="Description expérience"
                value={editForm.experience_description}
                onChange={(e) => handleChangeEditForm('experience_description', e.target.value)}
                multiline
                minRows={2}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />

              <TextField
                label="Histoire et patrimoine"
                value={editForm.heritage_history}
                onChange={(e) => handleChangeEditForm('heritage_history', e.target.value)}
                multiline
                minRows={2}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />

              <TextField
                label="Histoire"
                value={editForm.history}
                onChange={(e) => handleChangeEditForm('history', e.target.value)}
                multiline
                minRows={2}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />

              <TextField
                label="Points forts (séparés par virgules)"
                value={editForm.highlights}
                onChange={(e) => handleChangeEditForm('highlights', e.target.value)}
                fullWidth
              />

              <TextField
                label="Points forts expérience (séparés par virgules)"
                value={editForm.experience_highlights}
                onChange={(e) => handleChangeEditForm('experience_highlights', e.target.value)}
                fullWidth
              />

              <TextField
                label="Équipements (séparés par virgules)"
                value={editForm.amenities}
                onChange={(e) => handleChangeEditForm('amenities', e.target.value)}
                fullWidth
              />

              <TextField
                label="Activités (séparées par virgules)"
                value={editForm.activities}
                onChange={(e) => handleChangeEditForm('activities', e.target.value)}
                fullWidth
              />

              <TextField
                label="Langues parlées (séparées par virgules)"
                value={editForm.languages_spoken}
                onChange={(e) => handleChangeEditForm('languages_spoken', e.target.value)}
                fullWidth
              />

              <TextField
                label="Heures d'ouverture"
                placeholder="e.g., 09:00"
                value={editForm.opening_hours}
                onChange={(e) => handleChangeEditForm('opening_hours', e.target.value)}
                fullWidth
              />


              <TextField
                label="Gamme de prix"
                value={editForm.price_range}
                onChange={(e) => handleChangeEditForm('price_range', e.target.value)}
                fullWidth
              />

              <TextField
                label="Prix par adulte"
                value={editForm.price_per_adult}
                onChange={(e) => handleChangeEditForm('price_per_adult', e.target.value)}
                fullWidth
                type="number"
              />

              <TextField
                label="Prix minimum"
                value={editForm.min_price}
                onChange={(e) => handleChangeEditForm('min_price', e.target.value)}
                fullWidth
                type="number"
              />

              <TextField
                label="Prix maximum"
                value={editForm.max_price}
                onChange={(e) => handleChangeEditForm('max_price', e.target.value)}
                fullWidth
                type="number"
              />

              <TextField
                label="Devise"
                value={editForm.currency}
                onChange={(e) => handleChangeEditForm('currency', e.target.value)}
                fullWidth
              />

              <TextField
                label="Réductions"
                value={editForm.discounts}
                onChange={(e) => handleChangeEditForm('discounts', e.target.value)}
                fullWidth
              />

              <TextField
                label="Lien de réservation"
                value={editForm.booking_link}
                onChange={(e) => handleChangeEditForm('booking_link', e.target.value)}
                fullWidth
              />

              <TextField
                label="Tags (séparés par virgules)"
                value={editForm.tags}
                onChange={(e) => handleChangeEditForm('tags', e.target.value)}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />
            </Box>
          </DialogContent>

          <DialogActions>
            <Button onClick={handleCloseEditDialog} disabled={submitting}>
              Annuler
            </Button>
            <Button
              variant="contained"
              onClick={handleSubmitEditLieu}
              disabled={submitting}
            >
              {submitting ? 'Modification...' : 'Modifier'}
            </Button>
          </DialogActions>
        </Dialog>

        <Dialog open={openAddDialog} onClose={handleCloseAddDialog} fullWidth maxWidth="lg">
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
                label="Slug"
                value={addForm.slug}
                onChange={(e) => handleChangeAddForm('slug', e.target.value)}
                fullWidth
                helperText="URL-friendly name (auto-generated if empty)"
              />

              <TextField
                select
                label="Type"
                value={addForm.type}
                onChange={(e) => handleChangeAddForm('type', e.target.value)}
                fullWidth
              >
                <MenuItem value="accommodation">Accommodation</MenuItem>
                <MenuItem value="beach">Beach</MenuItem>
                <MenuItem value="food">Food</MenuItem>
                <MenuItem value="activity">Activity</MenuItem>
                <MenuItem value="museum">Museum</MenuItem>
                <MenuItem value="shopping">Shopping</MenuItem>
                <MenuItem value="other">Other</MenuItem>
              </TextField>

              <TextField
                label="Adresse"
                value={addForm.address}
                onChange={(e) => handleChangeAddForm('address', e.target.value)}
                fullWidth
              />

              <TextField
                label="Ville"
                value={addForm.city}
                onChange={(e) => handleChangeAddForm('city', e.target.value)}
                fullWidth
              />

              <TextField
                label="Pays"
                value={addForm.country}
                onChange={(e) => handleChangeAddForm('country', e.target.value)}
                fullWidth
              />

              <TextField
                label="Code postal"
                value={addForm.zipcode}
                onChange={(e) => handleChangeAddForm('zipcode', e.target.value)}
                fullWidth
              />

              <TextField
                label="Latitude"
                value={addForm.latitude}
                onChange={(e) => handleChangeAddForm('latitude', e.target.value)}
                fullWidth
                type="number"
              />

              <TextField
                label="Longitude"
                value={addForm.longitude}
                onChange={(e) => handleChangeAddForm('longitude', e.target.value)}
                fullWidth
                type="number"
              />

              <TextField
                label="Téléphone"
                value={addForm.telephone}
                onChange={(e) => handleChangeAddForm('telephone', e.target.value)}
                fullWidth
              />

              <TextField
                label="Image principale (URL)"
                value={addForm.main_image}
                onChange={(e) => handleChangeAddForm('main_image', e.target.value)}
                fullWidth
              />

              <TextField
                label="Galerie (URLs)"
                placeholder="Une URL par ligne"
                value={addForm.gallery}
                onChange={(e) => handleChangeAddForm('gallery', e.target.value)}
                multiline
                minRows={2}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />

              <TextField
                label="Vidéo (URL)"
                value={addForm.video}
                onChange={(e) => handleChangeAddForm('video', e.target.value)}
                fullWidth
              />

              <TextField
                label="Site web"
                value={addForm.website}
                onChange={(e) => handleChangeAddForm('website', e.target.value)}
                fullWidth
              />

              <TextField
                label="Description courte"
                value={addForm.short_description}
                onChange={(e) => handleChangeAddForm('short_description', e.target.value)}
                multiline
                minRows={2}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />

              <TextField
                label="Description longue"
                value={addForm.long_description}
                onChange={(e) => handleChangeAddForm('long_description', e.target.value)}
                multiline
                minRows={3}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />

              <TextField
                label="Description expérience"
                value={addForm.experience_description}
                onChange={(e) => handleChangeAddForm('experience_description', e.target.value)}
                multiline
                minRows={2}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />

              <TextField
                label="Histoire et patrimoine"
                value={addForm.heritage_history}
                onChange={(e) => handleChangeAddForm('heritage_history', e.target.value)}
                multiline
                minRows={2}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />

              <TextField
                label="Histoire"
                value={addForm.history}
                onChange={(e) => handleChangeAddForm('history', e.target.value)}
                multiline
                minRows={2}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />

              <TextField
                label="Points forts (séparés par virgules)"
                value={addForm.highlights}
                onChange={(e) => handleChangeAddForm('highlights', e.target.value)}
                fullWidth
              />

              <TextField
                label="Points forts expérience (séparés par virgules)"
                value={addForm.experience_highlights}
                onChange={(e) => handleChangeAddForm('experience_highlights', e.target.value)}
                fullWidth
              />

              <TextField
                label="Équipements (séparés par virgules)"
                value={addForm.amenities}
                onChange={(e) => handleChangeAddForm('amenities', e.target.value)}
                fullWidth
              />

              <TextField
                label="Activités (séparées par virgules)"
                value={addForm.activities}
                onChange={(e) => handleChangeAddForm('activities', e.target.value)}
                fullWidth
              />

              <TextField
                label="Langues parlées (séparées par virgules)"
                value={addForm.languages_spoken}
                onChange={(e) => handleChangeAddForm('languages_spoken', e.target.value)}
                fullWidth
              />

              <TextField
                label="Heures d'ouverture"
                placeholder="e.g., 09:00"
                value={addForm.opening_hours}
                onChange={(e) => handleChangeAddForm('opening_hours', e.target.value)}
                fullWidth
              />


              <TextField
                label="Gamme de prix"
                value={addForm.price_range}
                onChange={(e) => handleChangeAddForm('price_range', e.target.value)}
                fullWidth
              />

              <TextField
                label="Prix par adulte"
                value={addForm.price_per_adult}
                onChange={(e) => handleChangeAddForm('price_per_adult', e.target.value)}
                fullWidth
                type="number"
              />

              <TextField
                label="Prix minimum"
                value={addForm.min_price}
                onChange={(e) => handleChangeAddForm('min_price', e.target.value)}
                fullWidth
                type="number"
              />

              <TextField
                label="Prix maximum"
                value={addForm.max_price}
                onChange={(e) => handleChangeAddForm('max_price', e.target.value)}
                fullWidth
                type="number"
              />

              <TextField
                label="Devise"
                value={addForm.currency}
                onChange={(e) => handleChangeAddForm('currency', e.target.value)}
                fullWidth
              />

              <TextField
                label="Réductions"
                value={addForm.discounts}
                onChange={(e) => handleChangeAddForm('discounts', e.target.value)}
                fullWidth
              />

              <TextField
                label="Lien de réservation"
                value={addForm.booking_link}
                onChange={(e) => handleChangeAddForm('booking_link', e.target.value)}
                fullWidth
              />

              <TextField
                label="Tags (séparés par virgules)"
                value={addForm.tags}
                onChange={(e) => handleChangeAddForm('tags', e.target.value)}
                fullWidth
                sx={{ gridColumn: { xs: '1 / -1', sm: '1 / -1' } }}
              />
            </Box>
          </DialogContent>

          <DialogActions>
            <Button onClick={handleCloseAddDialog} disabled={submitting}>
              Annuler
            </Button>
            <Button
              variant="contained"
              onClick={handleSubmitAddLieu}
              disabled={submitting}
            >
              {submitting ? 'Ajout...' : 'Ajouter'}
            </Button>
          </DialogActions>
        </Dialog>
      </DashboardContent>
    </LocalizationProvider>
  );
}
