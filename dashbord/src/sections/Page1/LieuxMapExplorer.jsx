import { useEffect, useMemo, useRef, useState } from 'react';

import Box from '@mui/material/Box';
import Alert from '@mui/material/Alert';
import Button from '@mui/material/Button';
import Card from '@mui/material/Card';
import CardContent from '@mui/material/CardContent';
import Chip from '@mui/material/Chip';
import Divider from '@mui/material/Divider';
import Grid from '@mui/material/Grid';
import IconButton from '@mui/material/IconButton';
import InputAdornment from '@mui/material/InputAdornment';
import Stack from '@mui/material/Stack';
import TextField from '@mui/material/TextField';
import Typography from '@mui/material/Typography';
import CircularProgress from '@mui/material/CircularProgress';

import SearchIcon from '@mui/icons-material/Search';
import RefreshIcon from '@mui/icons-material/Refresh';
import StarIcon from '@mui/icons-material/Star';
import PlaceIcon from '@mui/icons-material/Place';
import OpenInNewIcon from '@mui/icons-material/OpenInNew';

import { paths } from 'src/routes/paths';
import { useRouter } from 'src/routes/hooks';
import { lieuService } from 'src/services/lieuService';

import { LieuDetailsDialog } from './Components/LieuDetails';

const GOOGLE_MAPS_API_KEY =
  import.meta.env.VITE_GOOGLE_MAPS_API_KEY ?? 'AIzaSyAKG3yUqz3-9kEdXdKdEMuTxIGN9XypUwE';

const DEFAULT_CENTER = { lat: 33.8076, lng: 10.8451 };

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

const PLACE_TYPES = [
  { value: 'all', label: 'Tous' },
  { value: 'beach', label: 'Plages' },
  { value: 'accommodation', label: 'Accommodation' },
  { value: 'food', label: 'Food' },
  { value: 'activity', label: 'Activites' },
  { value: 'museum', label: 'Museums' },
  { value: 'shopping', label: 'Shopping' },
  { value: 'other', label: 'Other' },
];

let googleMapsLoaderPromise;

function loadGoogleMapsScript() {
  if (typeof window !== 'undefined' && window.google?.maps) {
    return Promise.resolve();
  }

  if (!GOOGLE_MAPS_API_KEY) {
    return Promise.reject(new Error('Missing Google Maps API key'));
  }

  if (!googleMapsLoaderPromise) {
    googleMapsLoaderPromise = new Promise((resolve, reject) => {
      const existingScript = document.querySelector('script[data-dashboard-google-maps="true"]');
      if (existingScript) {
        existingScript.addEventListener('load', () => resolve());
        existingScript.addEventListener('error', () => reject(new Error('Google Maps script failed to load')));
        return;
      }

      window.initDashboardLieuxMap = () => resolve();

      const script = document.createElement('script');
      script.dataset.dashboardGoogleMaps = 'true';
      script.async = true;
      script.defer = true;
      script.src = `https://maps.googleapis.com/maps/api/js?key=${GOOGLE_MAPS_API_KEY}&callback=initDashboardLieuxMap&v=weekly`;
      script.onerror = () => reject(new Error('Google Maps script failed to load'));

      document.head.appendChild(script);
    });
  }

  return googleMapsLoaderPromise;
}

function normalizePlace(place) {
  const coordinates = place.coordinates ?? place.coordonnees ?? place.location ?? {};
  const latitude = Number(
    coordinates.latitude ?? coordinates.lat ?? place.latitude ?? place.lat ?? place.position?.latitude ?? place.position?.lat,
  );
  const longitude = Number(
    coordinates.longitude ?? coordinates.lng ?? place.longitude ?? place.lng ?? place.position?.longitude ?? place.position?.lng,
  );

  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return null;
  }

  const photoUrl =
    place.main_image ??
    place.imagePortrait ??
    (Array.isArray(place.gallery) ? place.gallery[0] : '') ??
    (Array.isArray(place.images) ? place.images[0] : '') ??
    '';

  const galleryImages = Array.isArray(place.galerieImages)
    ? place.galerieImages
    : Array.isArray(place.gallery)
      ? place.gallery
      : Array.isArray(place.images)
        ? place.images
        : [];

  return {
    id: String(place._id ?? place.id ?? `${latitude},${longitude}`),
    name: place.name ?? place.titre ?? place.title ?? place.nom ?? 'Lieu sans nom',
    type: normalizeLieuType(place.type ?? place.categorie ?? place.category ?? 'other'),
    address: place.address ?? place.adresse ?? place.short_description ?? place.description ?? '',
    city: place.city ?? place.ville ?? '',
    country: place.country ?? '',
    rating: Number(place.rating ?? place.noteMoyenne ?? place.review_count ?? 0) || null,
    photoUrl,
    galleryImages,
    shortDescription:
      place.short_description ?? place.sousTitre ?? place.subtitle ?? place.description ?? '',
    position: { lat: latitude, lng: longitude },
  };
}

function markerColor(type) {
  const normalized = normalizeLieuType(type);
  if (normalized === 'beach') return '#0284c7';
  if (normalized === 'accommodation') return '#7c3aed';
  if (normalized === 'food') return '#ea580c';
  if (normalized === 'museum') return '#6b7280';
  if (normalized === 'shopping') return '#d97706';
  if (normalized === 'activity') return '#16a34a';
  return '#0f766e';
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

function buildInfoWindowContent(place) {
  const wrapper = document.createElement('div');
  wrapper.style.minWidth = '220px';
  wrapper.innerHTML = `
    <div style="font-weight:700;font-size:14px;margin-bottom:4px">${escapeHtml(place.name)}</div>
    <div style="font-size:12px;color:#475569;margin-bottom:4px">${escapeHtml(place.type)}</div>
    ${place.city ? `<div style="font-size:12px;color:#64748b">${escapeHtml(place.city)}</div>` : ''}
    ${place.address ? `<div style="font-size:12px;color:#64748b;margin-top:4px">${escapeHtml(place.address)}</div>` : ''}
  `;
  return wrapper;
}

function placeMatchesSearch(place, query) {
  if (!query) return true;
  const haystack = [place.name, place.address, place.city, place.country, place.shortDescription, place.type]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();
  return haystack.includes(query.toLowerCase());
}

export function LieuxMapExplorer() {
  const router = useRouter();
  const mapContainerRef = useRef(null);
  const mapRef = useRef(null);
  const infoWindowRef = useRef(null);
  const markersRef = useRef([]);

  const [places, setPlaces] = useState([]);
  const [selectedPlace, setSelectedPlace] = useState(null);
  const [search, setSearch] = useState('');
  const [selectedType, setSelectedType] = useState('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [mapReady, setMapReady] = useState(false);
  const [detailsOpen, setDetailsOpen] = useState(false);

  const filteredPlaces = useMemo(() => {
    return places.filter((place) => {
      if (selectedType !== 'all' && place.type !== selectedType) {
        return false;
      }
      return placeMatchesSearch(place, search);
    });
  }, [places, search, selectedType]);

  const selected = selectedPlace && filteredPlaces.some((place) => place.id === selectedPlace.id)
    ? selectedPlace
    : filteredPlaces[0] ?? null;

  const clearMarkers = () => {
    markersRef.current.forEach((marker) => marker.setMap(null));
    markersRef.current = [];
  };

  const focusPlace = (place) => {
    const map = mapRef.current;
    if (!map || !window.google?.maps) {
      setSelectedPlace(place);
      return;
    }

    map.panTo(place.position);
    map.setZoom(Math.max(map.getZoom() ?? 12, 14));
    setSelectedPlace(place);
  };

  const openPlaceDetails = (place) => {
    if (!place) return;
    setSelectedPlace(place);
    setDetailsOpen(true);
  };

  const closePlaceDetails = () => {
    setDetailsOpen(false);
  };

  const selectedPlaceDetails = selected
    ? {
        id: selected.id,
        nom: selected.name,
        categorie: selected.type,
        type: selected.type,
        address: selected.address,
        city: selected.city,
        country: selected.country,
        rating: selected.rating ?? 0,
        short_description: selected.shortDescription,
        description: selected.shortDescription,
        main_image: selected.photoUrl,
        galerieImages: selected.galleryImages?.length ? selected.galleryImages : (selected.photoUrl ? [selected.photoUrl] : []),
        latitude: selected.position?.lat,
        longitude: selected.position?.lng,
      }
    : null;

  const renderMarkers = (list) => {
    const map = mapRef.current;
    if (!map || !window.google?.maps) {
      return;
    }

    clearMarkers();

    const bounds = new window.google.maps.LatLngBounds();
    const infoWindow = infoWindowRef.current;

    list.forEach((place) => {
      const marker = new window.google.maps.Marker({
        map,
        position: place.position,
        title: place.name,
        icon: {
          path: window.google.maps.SymbolPath.CIRCLE,
          fillColor: markerColor(place.type),
          fillOpacity: 1,
          strokeColor: '#ffffff',
          strokeWeight: 2,
          scale: 8,
        },
      });

      marker.addListener('click', () => {
        setSelectedPlace(place);
        if (infoWindow) {
          infoWindow.setContent(buildInfoWindowContent(place));
          infoWindow.open({ map, anchor: marker });
        }
        map.panTo(place.position);
      });

      markersRef.current.push(marker);
      bounds.extend(place.position);
    });

    if (list.length === 1) {
      map.setCenter(list[0].position);
      map.setZoom(14);
    } else if (list.length > 1) {
      map.fitBounds(bounds, 48);
    }
  };

  const loadPlaces = async () => {
    setLoading(true);
    setError('');

    try {
      const response = await lieuService.getAllLieux({});
      const rawList = Array.isArray(response)
        ? response
        : response?.lieux ?? response?.data?.lieux ?? response?.items ?? [];
      const normalized = rawList.map(normalizePlace).filter(Boolean);

      setPlaces(normalized);
      if (!selectedPlace && normalized.length > 0) {
        setSelectedPlace(normalized[0]);
      }

      if (mapRef.current) {
        renderMarkers(
          normalized.filter((place) => {
            if (selectedType !== 'all' && place.type !== selectedType) return false;
            return placeMatchesSearch(place, search);
          }),
        );
      }
    } catch (err) {
      setError('Impossible de charger les lieux sur la carte du dashboard.');
      console.error('Dashboard lieux map error:', err);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    let cancelled = false;

    const initMap = async () => {
      try {
        await loadGoogleMapsScript();
        if (cancelled || !mapContainerRef.current || mapRef.current) {
          return;
        }

        const map = new window.google.maps.Map(mapContainerRef.current, {
          center: DEFAULT_CENTER,
          zoom: 12,
          mapTypeControl: false,
          streetViewControl: false,
          fullscreenControl: false,
          clickableIcons: false,
        });

        mapRef.current = map;
        infoWindowRef.current = new window.google.maps.InfoWindow();
        setMapReady(true);
      } catch (err) {
        if (!cancelled) {
          setError(
            'Google Maps ne peut pas se charger dans le dashboard. Vérifiez la clé VITE_GOOGLE_MAPS_API_KEY et les restrictions de referrer.',
          );
          console.error('Google Maps dashboard load error:', err);
        }
      }
    };

    initMap();
    return () => {
      cancelled = true;
      clearMarkers();
      if (mapRef.current) {
        mapRef.current = null;
      }
    };
  }, []);

  useEffect(() => {
    loadPlaces();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (!mapReady) {
      return;
    }
    renderMarkers(filteredPlaces);

    if (selected && mapRef.current) {
      mapRef.current.panTo(selected.position);
    }
  }, [filteredPlaces, mapReady]);

  useEffect(() => {
    if (filteredPlaces.length > 0) {
      const exists = filteredPlaces.some((place) => place.id === selectedPlace?.id);
      if (!exists) {
        setSelectedPlace(filteredPlaces[0]);
      }
    }
  }, [filteredPlaces, selectedPlace]);

  return (
    <Card sx={{ mb: 3 }}>
      <CardContent sx={{ p: { xs: 2, md: 3 } }}>
        <Stack spacing={2}>
          <Stack
            direction={{ xs: 'column', md: 'row' }}
            spacing={2}
            alignItems={{ xs: 'stretch', md: 'center' }}
            justifyContent="space-between"
          >
            <Box>
              <Typography variant="h5" sx={{ fontWeight: 700 }}>
                Carte des lieux
              </Typography>
              <Typography variant="body2" color="text.secondary">
                Même logique que la carte mobile: lieux, types, sélection et détails.
              </Typography>
            </Box>

            <Stack direction="row" spacing={1} alignItems="center" justifyContent="flex-end">
              <Button
                variant="outlined"
                startIcon={<RefreshIcon />}
                onClick={loadPlaces}
                disabled={loading}
              >
                Actualiser
              </Button>
              <Button
                variant="contained"
                onClick={() => router.push(paths.dashboard.lieux.add)}
              >
                Ajouter un lieu
              </Button>
            </Stack>
          </Stack>

          <TextField
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Rechercher un lieu, une ville ou une adresse"
            fullWidth
            size="small"
            InputProps={{
              startAdornment: (
                <InputAdornment position="start">
                  <SearchIcon fontSize="small" />
                </InputAdornment>
              ),
            }}
          />

          <Stack direction="row" spacing={1} useFlexGap flexWrap="wrap">
            {PLACE_TYPES.map((type) => (
              <Chip
                key={type.value}
                label={type.label}
                clickable
                color={selectedType === type.value ? 'primary' : 'default'}
                variant={selectedType === type.value ? 'filled' : 'outlined'}
                onClick={() => setSelectedType(type.value)}
              />
            ))}
          </Stack>

          {error && <Alert severity="error">{error}</Alert>}

          <Grid container spacing={2}>
            <Grid item xs={12} md={8}>
              <Box
                ref={mapContainerRef}
                sx={{
                  height: { xs: 380, md: 560 },
                  width: '100%',
                  borderRadius: 2,
                  overflow: 'hidden',
                  border: '1px solid',
                  borderColor: 'divider',
                  bgcolor: 'grey.100',
                }}
              />
              <Stack
                direction="row"
                spacing={1}
                sx={{ mt: 1.5, alignItems: 'center', flexWrap: 'wrap' }}
              >
                <Typography variant="caption" color="text.secondary">
                  {loading ? 'Chargement des lieux...' : `${filteredPlaces.length} lieux affichés`}
                </Typography>
                {!mapReady && !error && (
                  <Typography variant="caption" color="text.secondary">
                    Initialisation de la carte...
                  </Typography>
                )}
              </Stack>
            </Grid>

            <Grid item xs={12} md={4}>
              <Stack spacing={2}>
                <Card variant="outlined">
                  <CardContent>
                    <Typography variant="subtitle1" sx={{ fontWeight: 700, mb: 1 }}>
                      {selected?.name ?? 'Aucun lieu sélectionné'}
                    </Typography>
                    {selected ? (
                      <Stack spacing={1.25}>
                        {selected.photoUrl ? (
                          <Box
                            component="img"
                            src={selected.photoUrl}
                            alt={selected.name}
                            sx={{
                              width: '100%',
                              height: 180,
                              objectFit: 'cover',
                              borderRadius: 1.5,
                            }}
                          />
                        ) : null}
                        <Stack direction="row" spacing={1} alignItems="center">
                          <Chip size="small" label={selected.type} />
                          {selected.rating ? (
                            <Stack direction="row" spacing={0.5} alignItems="center">
                              <StarIcon sx={{ fontSize: 16, color: 'warning.main' }} />
                              <Typography variant="body2">{selected.rating.toFixed(1)}</Typography>
                            </Stack>
                          ) : null}
                        </Stack>
                        <Stack direction="row" spacing={1} alignItems="flex-start">
                          <PlaceIcon sx={{ fontSize: 18, color: 'primary.main', mt: 0.25 }} />
                          <Typography variant="body2" color="text.secondary">
                            {[selected.address, selected.city, selected.country].filter(Boolean).join(', ')}
                          </Typography>
                        </Stack>
                        {selected.shortDescription ? (
                          <Typography variant="body2" color="text.secondary">
                            {selected.shortDescription}
                          </Typography>
                        ) : null}
                        <Stack direction="row" spacing={1}>
                          <Button
                            fullWidth
                            variant="contained"
                            endIcon={<OpenInNewIcon />}
                            onClick={() => openPlaceDetails(selected)}
                          >
                            Détails
                          </Button>
                        </Stack>
                      </Stack>
                    ) : (
                      <Typography variant="body2" color="text.secondary">
                        Sélectionnez un marqueur pour voir sa fiche.
                      </Typography>
                    )}
                  </CardContent>
                </Card>

                <Card variant="outlined">
                  <CardContent sx={{ pb: '16px !important' }}>
                    <Stack direction="row" spacing={1} alignItems="center" sx={{ mb: 1 }}>
                      <Typography variant="subtitle1" sx={{ fontWeight: 700 }}>
                        Lieux trouvés
                      </Typography>
                      <Chip size="small" label={filteredPlaces.length} />
                    </Stack>
                    <Divider sx={{ mb: 1.5 }} />
                    <Stack spacing={1} sx={{ maxHeight: 280, overflow: 'auto', pr: 0.5 }}>
                      {filteredPlaces.map((place) => (
                        <Box
                          key={place.id}
                          onClick={() => focusPlace(place)}
                          sx={{
                            cursor: 'pointer',
                            p: 1.25,
                            borderRadius: 1.5,
                            border: '1px solid',
                            borderColor:
                              selected?.id === place.id ? 'primary.main' : 'divider',
                            bgcolor:
                              selected?.id === place.id ? 'primary.lighter' : 'background.paper',
                          }}
                        >
                          <Stack direction="row" spacing={1.25} alignItems="flex-start">
                            <Box
                              sx={{
                                width: 44,
                                height: 44,
                                borderRadius: 1,
                                bgcolor: 'grey.100',
                                overflow: 'hidden',
                                flexShrink: 0,
                              }}
                            >
                              {place.photoUrl ? (
                                <Box
                                  component="img"
                                  src={place.photoUrl}
                                  alt={place.name}
                                  sx={{ width: '100%', height: '100%', objectFit: 'cover' }}
                                />
                              ) : null}
                            </Box>
                            <Box sx={{ minWidth: 0, flex: 1 }}>
                              <Typography variant="body2" sx={{ fontWeight: 700 }} noWrap>
                                {place.name}
                              </Typography>
                              <Typography variant="caption" color="text.secondary" noWrap>
                                {place.type}
                              </Typography>
                              <Typography variant="caption" color="text.secondary" display="block" noWrap>
                                {[place.address, place.city].filter(Boolean).join(' - ')}
                              </Typography>
                            </Box>
                          </Stack>
                        </Box>
                      ))}

                      {!loading && filteredPlaces.length === 0 ? (
                        <Typography variant="body2" color="text.secondary">
                          Aucun lieu ne correspond aux filtres.
                        </Typography>
                      ) : null}
                    </Stack>
                  </CardContent>
                </Card>
              </Stack>
            </Grid>
          </Grid>

          {loading ? (
            <Stack direction="row" spacing={1.5} alignItems="center">
              <CircularProgress size={18} />
              <Typography variant="body2" color="text.secondary">
                Chargement des lieux...
              </Typography>
            </Stack>
          ) : null}
        </Stack>
      </CardContent>

      <LieuDetailsDialog
        open={detailsOpen}
        onClose={closePlaceDetails}
        lieu={selectedPlaceDetails}
        onRefresh={loadPlaces}
      />
    </Card>
  );
}
