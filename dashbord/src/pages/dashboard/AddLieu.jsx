import { useState, useRef, useEffect } from 'react';
import { Helmet } from 'react-helmet-async';
import {
  Box,
  Card,
  Stack,
  Button,
  TextField,
  MenuItem,
  Typography,
  CircularProgress,
  Alert,
  Grid,
} from '@mui/material';
import CloudUploadIcon from '@mui/icons-material/CloudUpload';
import DeleteIcon from '@mui/icons-material/Delete';
import { CONFIG } from 'src/global-config';
import { lieuService } from 'src/services/lieuService';
import { useRouter } from 'src/routes/hooks';

const metadata = { title: `Add Lieu | Dashboard - ${CONFIG.appName}` };

const GOOGLE_MAPS_API_KEY = import.meta.env.VITE_GOOGLE_MAPS_API_KEY ?? '';

const LIEU_TYPES = ['beach', 'accommodation', 'food', 'activity', 'museum', 'shopping', 'other'];

const normalizeLieuType = (value) => {
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
    normalized.includes('supermarket') ||
    normalized.includes('clothing_store') ||
    normalized.includes('department_store')
  ) {
    return 'shopping';
  }

  if (normalized.includes('activity') || normalized.includes('activ') || normalized.includes('tourist_attraction')) {
    return 'activity';
  }

  if (normalized.includes('landmark') || normalized.includes('monument') || normalized.includes('site') || normalized.includes('historic')) {
    return 'other';
  }

  if (normalized.includes('beach') || normalized.includes('plage')) {
    return 'beach';
  }

  return 'other';
};

export default function AddLieuPage() {
  const router = useRouter();
  const [formData, setFormData] = useState({
    name: '',
    type: 'activity',
    address: '',
    city: 'Djerba',
    country: 'Tunisia',
    latitude: 33.8076,
    longitude: 10.8451,
    short_description: '',
    long_description: '',
    price_range: '',
    price_level: null,
    opening_hours: '',
    website: '',
    telephone: '',
    main_image: '',
    gallery: [],
    amenities: [],
    activities: [],
    wheelchair_access: false,
  });

  const [images, setImages] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');
  const [places, setPlaces] = useState([]);
  const [placesLoading, setPlacesLoading] = useState(false);
  const [placesError, setPlacesError] = useState('');
  const fileInputRef = useRef(null);
  const mapRef = useRef(null);
  const mapInstanceRef = useRef(null);
  const markerRef = useRef(null);
  const backendMarkersRef = useRef([]);
  const searchInputRef = useRef(null);
  const infoWindowRef = useRef(null);
  const placesServiceRef = useRef(null);
  const geocoderRef = useRef(null);

  const escapeHtml = (str) => {
    if (!str) return '';
    return String(str).replace(/[&<>"']/g, (s) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[s]));
  };

  const fetchNearbyFromProxy = async (lat, lng, radius = 2000) => {
    try {
      const url = `/api/v1/google/nearby?lat=${encodeURIComponent(lat)}&lng=${encodeURIComponent(lng)}&radius=${encodeURIComponent(radius)}`;
      const res = await fetch(url);
      if (!res.ok) return [];
      const data = await res.json();
      // Google Places nearbySearch proxied format: results array
      return data?.results ?? [];
    } catch (e) {
      console.error('Proxy nearby error', e);
      return [];
    }
  };

  const fetchPlaceDetailsFromProxy = async (placeId) => {
    if (!placeId) return null;
    try {
      const url = `/api/v1/google/details?place_id=${encodeURIComponent(placeId)}`;
      const res = await fetch(url);
      if (!res.ok) return null;
      const data = await res.json();
      return data?.result ?? null;
    } catch (e) {
      console.error('Proxy details error', e);
      return null;
    }
  };

  const fetchPlaceDetailsFromGoogle = async (placeId) => {
    if (!placeId || !placesServiceRef.current || !window.google?.maps?.places?.PlacesServiceStatus) {
      return null;
    }

    return new Promise((resolve) => {
      placesServiceRef.current.getDetails(
        {
          placeId,
          fields: ['place_id', 'geometry', 'name', 'formatted_address', 'address_components', 'photos', 'formatted_phone_number', 'website', 'opening_hours', 'price_level', 'types'],
        },
        (result, status) => {
          if (status === window.google.maps.places.PlacesServiceStatus.OK && result) {
            resolve(result);
            return;
          }
          resolve(null);
        },
      );
    });
  };

  const fetchPlaceDetails = async (placeId) => {
    const fromGoogle = await fetchPlaceDetailsFromGoogle(placeId);
    if (fromGoogle) return fromGoogle;
    return fetchPlaceDetailsFromProxy(placeId);
  };

  const extractCityFromAddressComponents = (addressComponents = []) => {
    if (!Array.isArray(addressComponents)) return undefined;
    return (
      addressComponents.find((c) => c.types?.includes('locality'))?.long_name
      || addressComponents.find((c) => c.types?.includes('administrative_area_level_2'))?.long_name
      || addressComponents.find((c) => c.types?.includes('administrative_area_level_1'))?.long_name
      || undefined
    );
  };

  const formatOpeningHours = (openingHours) => {
    if (!openingHours) return undefined;
    if (typeof openingHours === 'string') return openingHours;

    // If has weekday_text array
    if (Array.isArray(openingHours?.weekday_text) && openingHours.weekday_text.length > 0) {
      const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

      // Parse each entry to extract day and hours
      const parsedDays = openingHours.weekday_text.map((text) => {
        const match = text.match(/^([^:]+):\s*(.+)$/);
        if (!match) return null;
        const dayPart = match[1].trim();
        const hourPart = match[2].trim();

        // Find the day index (handles abbreviated day names)
        const dayIndex = dayNames.findIndex(d => dayPart.includes(d));
        return { dayIndex, dayPart, hourPart, fullText: text };
      }).filter(Boolean);

      if (parsedDays.length === 0) {
        return openingHours.weekday_text.join('\n');
      }

      // Group consecutive days with same hours
      const groups = [];
      let currentGroup = [parsedDays[0]];

      for (let i = 1; i < parsedDays.length; i++) {
        if (
          parsedDays[i].hourPart === currentGroup[0].hourPart &&
          parsedDays[i].dayIndex === currentGroup[currentGroup.length - 1].dayIndex + 1
        ) {
          currentGroup.push(parsedDays[i]);
        } else {
          groups.push(currentGroup);
          currentGroup = [parsedDays[i]];
        }
      }
      groups.push(currentGroup);

      // Format groups as "Mon-Fri: 9:00 AM – 5:00 PM"
      return groups.map(group => {
        if (group.length === 1) {
          return `${group[0].dayPart}: ${group[0].hourPart}`;
        } else {
          const firstDay = dayNames[group[0].dayIndex];
          const lastDay = dayNames[group[group.length - 1].dayIndex];
          return `${firstDay}-${lastDay}: ${group[0].hourPart}`;
        }
      }).join('\n');
    }

    // If has open_now flag
    if (typeof openingHours?.open_now === 'boolean') {
      return openingHours.open_now ? 'Open now' : 'Closed now';
    }

    return undefined;
  };

  const formatPriceLevel = (priceLevel) => {
    if (priceLevel === null || priceLevel === undefined) return undefined;
    const value = Number(priceLevel);
    if (!Number.isFinite(value)) return undefined;
    if (value <= 0) return 'Free';
    const clamped = Math.max(1, Math.min(4, Math.round(value)));
    return '$'.repeat(clamped);
  };

  const readPriceLevel = (source) => source?.price_level ?? source?.priceLevel ?? undefined;

  const displayPriceRange = formData.price_range || formatPriceLevel(formData.price_level) || '';

  const extractPhotoUrls = (place) => {
    if (!place) return [];
    const photoUrls = [];

    // Handle Google Place object with photos array (from autocomplete/nearby search)
    if (Array.isArray(place.photos)) {
      place.photos.slice(0, 5).forEach((photo) => {
        try {
          if (typeof photo.getUrl === 'function') {
            const url = photo.getUrl({ maxWidth: 800 });
            if (url) photoUrls.push(url);
          } else if (photo?.url) {
            photoUrls.push(photo.url);
          } else if (photo?.photo_reference || photo?.photoReference) {
            const photoReference = photo.photo_reference ?? photo.photoReference;
            if (GOOGLE_MAPS_API_KEY) {
              photoUrls.push(
                `https://maps.googleapis.com/maps/api/place/photo?maxwidth=1200&photo_reference=${encodeURIComponent(photoReference)}&key=${encodeURIComponent(GOOGLE_MAPS_API_KEY)}`,
              );
            }
          }
        } catch (e) {
          console.error('Error getting photo URL:', e);
        }
      });
    }

    if (typeof place.photo_reference === 'string' && GOOGLE_MAPS_API_KEY) {
      photoUrls.push(
        `https://maps.googleapis.com/maps/api/place/photo?maxwidth=1200&photo_reference=${encodeURIComponent(place.photo_reference)}&key=${encodeURIComponent(GOOGLE_MAPS_API_KEY)}`,
      );
    }

    if (typeof place.photoReference === 'string' && GOOGLE_MAPS_API_KEY) {
      photoUrls.push(
        `https://maps.googleapis.com/maps/api/place/photo?maxwidth=1200&photo_reference=${encodeURIComponent(place.photoReference)}&key=${encodeURIComponent(GOOGLE_MAPS_API_KEY)}`,
      );
    }

    if (typeof place.url === 'string' && place.url.startsWith('http')) {
      photoUrls.push(place.url);
    }

    return photoUrls.slice(0, 5);
  };

  const handleFormChange = (field, value) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
  };

  const handleMapPositionChange = ({ lat, lng }) => {
    setFormData((prev) => ({
      ...prev,
      latitude: lat,
      longitude: lng,
    }));
  };

  const applyPlaceSelection = ({
    lat,
    lng,
    name,
    address,
    city,
    type,
    website,
    telephone,
    photoUrls,
    openingHours,
    priceRange,
    priceLevel,
  }) => {
    if (!Number.isFinite(Number(lat)) || !Number.isFinite(Number(lng))) return;

    const nextLat = Number(lat);
    const nextLng = Number(lng);

    setFormData((prev) => ({
      ...prev,
      latitude: nextLat,
      longitude: nextLng,
      name: name ?? prev.name,
      address: address ?? prev.address,
      city: city ?? prev.city,
      type: normalizeLieuType(type ?? prev.type),
      website: website ?? prev.website,
      telephone: telephone ?? prev.telephone,
      opening_hours: openingHours ?? prev.opening_hours,
      price_range: priceRange ?? (Number.isFinite(Number(priceLevel)) ? formatPriceLevel(priceLevel) : prev.price_range),
      price_level: priceLevel ?? prev.price_level,
      main_image: Array.isArray(photoUrls) && photoUrls.length > 0 ? photoUrls[0] : prev.main_image,
      gallery: Array.isArray(photoUrls) && photoUrls.length > 0 ? photoUrls : prev.gallery,
    }));

    if (Array.isArray(photoUrls) && photoUrls.length > 0) {
      setImages(photoUrls.map((url) => ({ file: null, preview: url })));
    }

    const pos = { lat: nextLat, lng: nextLng };
    if (markerRef.current) {
      if (typeof markerRef.current.setPosition === 'function') {
        markerRef.current.setPosition(pos);
      } else if (typeof markerRef.current.setLatLng === 'function') {
        markerRef.current.setLatLng([nextLat, nextLng]);
      }
    }

    if (mapInstanceRef.current) {
      try {
        if (typeof mapInstanceRef.current.panTo === 'function') {
          mapInstanceRef.current.panTo(pos);
        } else {
          mapInstanceRef.current.panTo([nextLat, nextLng]);
        }
      } catch (e) {}
    }
  };

  const handleImageSelect = (e) => {
    const files = Array.from(e.target.files || []);
    const newImages = files.map((file) => ({
      file,
      preview: URL.createObjectURL(file),
    }));
    setImages((prev) => [...prev, ...newImages].slice(0, 5));
  };

  const handleRemoveImage = (index) => {
    setImages((prev) => {
      const updated = [...prev];
      if (updated[index]?.preview) {
        URL.revokeObjectURL(updated[index].preview);
      }
      updated.splice(index, 1);
      return updated;
    });
  };

  const readPlaceCoordinates = (place) => {
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

    return { latitude, longitude };
  };

  const getPlaceName = (place) =>
    place.name ?? place.titre ?? place.title ?? place.nom ?? 'Lieu sans nom';

  const getPlaceType = (place) => normalizeLieuType(place.type ?? place.categorie ?? place.category ?? 'other');

  const getPlaceCity = (place) => place.city ?? place.ville ?? '';

  const getPlaceDescription = (place) =>
    place.short_description ?? place.sousTitre ?? place.subtitle ?? place.description ?? '';

  const getMarkerColor = (type) => {
    const normalized = normalizeLieuType(type);
    if (normalized === 'beach') return '#0284c7';
    if (normalized === 'accommodation') return '#7c3aed';
    if (normalized === 'food') return '#ea580c';
    if (normalized === 'museum') return '#6b7280';
    if (normalized === 'shopping') return '#d97706';
    if (normalized === 'activity') return '#16a34a';
    return '#0f766e';
  };

  const createMarkerIcon = (type) =>
    L.divIcon({
      className: '',
      html: `
        <div style="
          width: 18px;
          height: 18px;
          border-radius: 999px;
          background: ${getMarkerColor(type)};
          border: 3px solid white;
          box-shadow: 0 2px 10px rgba(15, 23, 42, 0.28);
        "></div>
      `,
      iconSize: [18, 18],
      iconAnchor: [9, 9],
    });

  const refreshPlacesLayer = (map, list) => {
    if (!map) return;

    if (!window.google?.maps || !(map instanceof window.google.maps.Map)) return;

    backendMarkersRef.current.forEach((m) => m.setMap(null));
    backendMarkersRef.current = [];

    const bounds = new window.google.maps.LatLngBounds();

    list.forEach((place) => {
      const coords = readPlaceCoordinates(place);
      if (!coords) return;

      const position = { lat: coords.latitude, lng: coords.longitude };
      const marker = new window.google.maps.Marker({
        map,
        position,
        title: getPlaceName(place),
        icon: {
          path: window.google.maps.SymbolPath.CIRCLE,
          fillColor: getMarkerColor(getPlaceType(place)),
          fillOpacity: 1,
          strokeColor: '#ffffff',
          strokeWeight: 2,
          scale: 8,
        },
      });

      const content = `
        <div style="min-width:180px">
          <strong>${escapeHtml(getPlaceName(place))}</strong><br />
          <span>${escapeHtml(getPlaceType(place))}</span>
          ${getPlaceCity(place) ? `<br /><span>${escapeHtml(getPlaceCity(place))}</span>` : ''}
        </div>
      `;

      marker.addListener('click', () => {
        applyPlaceSelection({
          lat: position.lat,
          lng: position.lng,
          name: getPlaceName(place),
          city: getPlaceCity(place) || undefined,
          type: normalizeLieuType(getPlaceType(place)),
          address: place.address ?? place.vicinity ?? undefined,
          openingHours: place.opening_hours ?? undefined,
          priceRange: place.price_range ?? undefined,
          priceLevel: readPriceLevel(place),
        });

        const backendPlaceId = place.google_place_id ?? place.place_id;
        if (backendPlaceId) {
          fetchPlaceDetails(backendPlaceId).then((details) => {
            if (!details) return;
            applyPlaceSelection({
              lat: details.geometry?.location?.lat ?? position.lat,
              lng: details.geometry?.location?.lng ?? position.lng,
              name: details.name ?? getPlaceName(place),
              address: details.formatted_address ?? place.address ?? place.vicinity ?? undefined,
              city: extractCityFromAddressComponents(details.address_components),
              website: details.website ?? undefined,
              telephone: details.formatted_phone_number ?? undefined,
              photoUrls: extractPhotoUrls(details),
              openingHours: formatOpeningHours(details.opening_hours),
              priceRange: formatPriceLevel(readPriceLevel(details)),
              priceLevel: readPriceLevel(details),
              type: normalizeLieuType(Array.isArray(details.types) && details.types.length > 0 ? details.types[0] : undefined),
            });
          }).catch(() => {});
        }

        if (!infoWindowRef.current) infoWindowRef.current = new window.google.maps.InfoWindow();
        infoWindowRef.current.setContent(content);
        infoWindowRef.current.open({ map, anchor: marker });
      });

      backendMarkersRef.current.push(marker);
      bounds.extend(position);
    });

    if (!bounds.isEmpty()) {
      try { map.fitBounds(bounds, { padding: 40 }); } catch (e) {}
    }
  };

  useEffect(() => {
    let cancelled = false;

    const loadPlaces = async () => {
      setPlacesLoading(true);
      setPlacesError('');

      try {
        const response = await lieuService.getAllLieux({});
        if (cancelled) return;

        const list = Array.isArray(response)
          ? response
          : response?.lieux ?? response?.data?.lieux ?? response?.items ?? [];

        const normalized = list.filter((place) => readPlaceCoordinates(place));
        setPlaces(normalized);

        if (mapInstanceRef.current && window.google?.maps) {
          refreshPlacesLayer(mapInstanceRef.current, normalized);
        }
      } catch (err) {
        if (!cancelled) {
          setPlacesError('Impossible de charger les lieux existants sur la carte.');
          console.error('Error loading places for map:', err);
        }
      } finally {
        if (!cancelled) setPlacesLoading(false);
      }
    };

    loadPlaces();

    return () => { cancelled = true; };
  }, []);

  useEffect(() => {
    if (!mapRef.current || mapInstanceRef.current) return;
    let cancelled = false;
    let loaderPromise;

    const loadGoogleMapsScript = () => {
      if (typeof window !== 'undefined' && window.google?.maps) return Promise.resolve();
      if (!GOOGLE_MAPS_API_KEY) return Promise.reject(new Error('Missing Google Maps API key'));

      if (!loaderPromise) {
        loaderPromise = new Promise((resolve, reject) => {
          const existing = document.querySelector('script[data-dashboard-google-maps="true"]');
          if (existing) {
            existing.addEventListener('load', () => resolve());
            existing.addEventListener('error', () => reject(new Error('Google Maps script failed to load')));
            return;
          }

          window.initDashboardAddLieuMap = () => resolve();

          const script = document.createElement('script');
          script.dataset.dashboardGoogleMaps = 'true';
          script.async = true;
          script.defer = true;
          script.src = `https://maps.googleapis.com/maps/api/js?key=${GOOGLE_MAPS_API_KEY}&libraries=places&callback=initDashboardAddLieuMap&v=weekly`;
          script.onerror = () => reject(new Error('Google Maps script failed to load'));
          document.head.appendChild(script);
        });
      }

      return loaderPromise;
    };

    (async () => {
      try {
        await loadGoogleMapsScript();
        if (cancelled) return;

        const initialPos = { lat: Number(formData.latitude), lng: Number(formData.longitude) };
        const map = new window.google.maps.Map(mapRef.current, {
          center: initialPos,
          zoom: 12,
          mapTypeControl: false,
          streetViewControl: false,
          fullscreenControl: false,
        });

        mapInstanceRef.current = map;
        infoWindowRef.current = new window.google.maps.InfoWindow();
        geocoderRef.current = new window.google.maps.Geocoder();

        const marker = new window.google.maps.Marker({
          position: initialPos,
          map,
          draggable: true,
        });

        marker.addListener('dragend', (e) => {
          const pos = e.latLng;
          handleMapPositionChange({ lat: pos.lat(), lng: pos.lng() });
        });

        map.addListener('click', (e) => {
          const lat = e.latLng.lat();
          const lng = e.latLng.lng();
          handleMapPositionChange({ lat, lng });
          marker.setPosition({ lat, lng });

          if (geocoderRef.current) {
            geocoderRef.current.geocode({ location: { lat, lng } }, (results, status) => {
              if (status === 'OK' && Array.isArray(results) && results.length > 0) {
                const top = results[0];
                applyPlaceSelection({
                  lat,
                  lng,
                  name: top.formatted_address ?? undefined,
                  address: top.formatted_address ?? undefined,
                  city: extractCityFromAddressComponents(top.address_components),
                });

                if (top.place_id) {
                  fetchPlaceDetails(top.place_id).then((details) => {
                    if (!details) return;
                    applyPlaceSelection({
                      lat: details.geometry?.location?.lat ?? lat,
                      lng: details.geometry?.location?.lng ?? lng,
                      name: details.name ?? top.formatted_address ?? undefined,
                      address: details.formatted_address ?? top.formatted_address ?? undefined,
                      city: extractCityFromAddressComponents(details.address_components),
                      website: details.website ?? undefined,
                      telephone: details.formatted_phone_number ?? undefined,
                      photoUrls: extractPhotoUrls(details),
                      openingHours: formatOpeningHours(details.opening_hours),
                      priceRange: formatPriceLevel(readPriceLevel(details)),
                      priceLevel: readPriceLevel(details),
                      type: normalizeLieuType(Array.isArray(details.types) && details.types.length > 0 ? details.types[0] : undefined),
                    });
                  }).catch(() => {});
                }
              }
            });
          }
        });

        markerRef.current = marker;

        placesServiceRef.current = new window.google.maps.places.PlacesService(map);

        if (searchInputRef.current) {
          const autocomplete = new window.google.maps.places.Autocomplete(searchInputRef.current, {
            fields: ['place_id', 'geometry', 'name', 'formatted_address', 'address_components', 'photos', 'rating', 'formatted_phone_number', 'website', 'opening_hours', 'price_level'],
          });

          autocomplete.bindTo('bounds', map);
          autocomplete.addListener('place_changed', () => {
            const place = autocomplete.getPlace();
            if (!place.geometry || !place.geometry.location) return;
            const pos = place.geometry.location;
            const lat = pos.lat();
            const lng = pos.lng();
            applyPlaceSelection({
              lat,
              lng,
              name: place.name ?? undefined,
              address: place.formatted_address ?? undefined,
              city: (place.address_components || []).find((c) => c.types.includes('locality'))?.long_name ?? undefined,
              website: place.website ?? undefined,
              telephone: place.formatted_phone_number ?? undefined,
              photoUrls: extractPhotoUrls(place),
              openingHours: formatOpeningHours(place.opening_hours),
              priceRange: formatPriceLevel(readPriceLevel(place)),
              priceLevel: readPriceLevel(place),
            });
          });
        }

        try {
          const resp = await lieuService.getAllLieux({});
          const list = Array.isArray(resp) ? resp : resp?.lieux ?? resp?.data?.lieux ?? [];
          const normalized = list.filter(p => readPlaceCoordinates(p));
          if (!cancelled) setPlaces(normalized);
          refreshPlacesLayer(map, normalized);

          const proxyResults = await fetchNearbyFromProxy(initialPos.lat, initialPos.lng, 2000);
          if (!cancelled && proxyResults && proxyResults.length > 0) {
            const adapted = proxyResults.map(r => ({
              name: r.name,
              coordinates: { latitude: r.geometry.location.lat, longitude: r.geometry.location.lng },
              vicinity: r.vicinity,
              type: normalizeLieuType(r.types?.[0] ?? 'other'),
            }));
            refreshPlacesLayer(map, adapted);
          }
        } catch (e) {
          console.error('Error loading places:', e);
        }
      } catch (err) {
        console.error('Error initializing Google Maps map:', err);
      }
    })();

    return () => {
      cancelled = true;
      if (backendMarkersRef.current?.length) {
        backendMarkersRef.current.forEach((m) => m.setMap(null));
        backendMarkersRef.current = [];
      }
      if (mapInstanceRef.current) {
        mapInstanceRef.current = null;
      }
      markerRef.current = null;
      infoWindowRef.current = null;
      placesServiceRef.current = null;
      geocoderRef.current = null;
    };
  }, []);

  useEffect(() => {
    if (!mapInstanceRef.current || !markerRef.current) return;
    const pos = { lat: Number(formData.latitude), lng: Number(formData.longitude) };

    if (typeof markerRef.current.setPosition === 'function') {
      markerRef.current.setPosition(pos);
      try { mapInstanceRef.current.panTo(pos); } catch (e) {}
      return;
    }

    if (typeof markerRef.current.setLatLng === 'function') {
      markerRef.current.setLatLng([pos.lat, pos.lng]);
      try { mapInstanceRef.current.panTo([pos.lat, pos.lng]); } catch (e) {}
    }
  }, [formData.latitude, formData.longitude]);

  useEffect(() => {
    if (!mapInstanceRef.current) return;
    refreshPlacesLayer(mapInstanceRef.current, places);
  }, [places]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!formData.name.trim()) {
      setError('Place name is required');
      return;
    }

    setLoading(true);
    setError('');
    setSuccess('');

    try {
      // Prepare lieu data
      const lieuPayload = {
        ...formData,
        coordinates: {
          latitude: formData.latitude,
          longitude: formData.longitude,
        },
        ...(formData.main_image ? { main_image: formData.main_image } : {}),
        ...(Array.isArray(formData.gallery) && formData.gallery.length > 0 ? { gallery: formData.gallery } : {}),
      };
      delete lieuPayload.latitude;
      delete lieuPayload.longitude;

      // Create lieu
      const response = await lieuService.createLieu(lieuPayload);
      const createdId = response.lieu._id;

      // Upload images if any (only actual files, not preview-only URLs)
      const filesToUpload = images.filter((img) => img.file !== null).map((img) => img.file);
      if (filesToUpload.length > 0) {
        const uploadResponse = await lieuService.uploadLieuImages(createdId, filesToUpload);

        // Update lieu with uploaded image URLs (add to gallery, keep main_image from Google)
        if (uploadResponse.images && uploadResponse.images.length > 0) {
          const uploadedUrls = uploadResponse.images.map((img) => img.url);
          const updatePayload = {
            // Keep existing main_image if from Google, otherwise use first uploaded image
            main_image: formData.main_image || uploadedUrls[0],
            // Combine existing gallery with uploaded images
            gallery: [
              ...(Array.isArray(formData.gallery) ? formData.gallery : []),
              ...uploadedUrls,
            ],
          };
          await lieuService.updateLieu(createdId, updatePayload);
        }
      }

      setSuccess('Place added successfully!');
      setTimeout(() => {
        router.push('/dashboard/lieux');
      }, 1500);
    } catch (err) {
      setError(err.response?.data?.message || 'Error adding place');
      console.error('Error:', err);
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <Helmet>
        <title>{metadata.title}</title>
      </Helmet>

      <Box sx={{ py: 4, px: 2 }}>
        <Typography variant="h3" sx={{ mb: 3 }}>
          Add New Place
        </Typography>

        {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}
        {success && <Alert severity="success" sx={{ mb: 2 }}>{success}</Alert>}

        <form onSubmit={handleSubmit}>
          <Grid container spacing={3}>
            {/* Map Section */}
            <Grid item xs={12} md={6}>
              <Card sx={{ p: 2 }}>
                <Typography variant="h6" sx={{ mb: 2 }}>
                  Location on Map
                </Typography>
                <Stack direction="row" spacing={1} sx={{ mb: 1, flexWrap: 'wrap' }}>
                  <Typography variant="caption" color="text.secondary">
                    {placesLoading ? 'Loading places...' : `${places.length} places on the map`}
                  </Typography>
                  {placesError && (
                    <Typography variant="caption" color="error.main">
                      {placesError}
                    </Typography>
                  )}
                </Stack>
                <TextField
                  fullWidth
                  size="small"
                  label="Search place (Google)"
                  placeholder="Type a place name..."
                  inputRef={searchInputRef}
                  sx={{ mb: 2 }}
                />
                <Box
                  ref={mapRef}
                  sx={{
                    width: '100%',
                    height: 400,
                    borderRadius: 1,
                    overflow: 'hidden',
                    mb: 2,
                    '& > div': {
                      width: '100%',
                      height: '100%',
                    },
                  }}
                />
                <Stack spacing={1}>
                  <Typography variant="body2" color="textSecondary">
                    Click on map or drag marker to select location
                  </Typography>
                  <Box sx={{ display: 'flex', gap: 2 }}>
                    <TextField
                      size="small"
                      label="Latitude"
                      type="number"
                      value={formData.latitude}
                      onChange={(e) => handleFormChange('latitude', parseFloat(e.target.value))}
                      fullWidth
                      inputProps={{ step: '0.0001' }}
                    />
                    <TextField
                      size="small"
                      label="Longitude"
                      type="number"
                      value={formData.longitude}
                      onChange={(e) => handleFormChange('longitude', parseFloat(e.target.value))}
                      fullWidth
                      inputProps={{ step: '0.0001' }}
                    />
                  </Box>
                </Stack>
              </Card>
            </Grid>

            {/* Form Section */}
            <Grid item xs={12} md={6}>
              <Card sx={{ p: 3 }}>
                <Stack spacing={2}>
                  {/* Basic Info */}
                  <TextField
                    fullWidth
                    label="Place Name *"
                    value={formData.name}
                    onChange={(e) => handleFormChange('name', e.target.value)}
                    placeholder="e.g., Djerba Beach Resort"
                    required
                  />

                  <TextField
                    select
                    fullWidth
                    label="Type *"
                    value={formData.type}
                    onChange={(e) => handleFormChange('type', e.target.value)}
                    required
                  >
                    {LIEU_TYPES.map((type) => (
                      <MenuItem key={type} value={type}>
                        {type.charAt(0).toUpperCase() + type.slice(1)}
                      </MenuItem>
                    ))}
                  </TextField>

                  <TextField
                    fullWidth
                    label="Address"
                    value={formData.address}
                    onChange={(e) => handleFormChange('address', e.target.value)}
                    multiline
                    rows={2}
                  />

                  <Grid container spacing={2}>
                    <Grid item xs={6}>
                      <TextField
                        fullWidth
                        label="City"
                        value={formData.city}
                        onChange={(e) => handleFormChange('city', e.target.value)}
                      />
                    </Grid>
                    <Grid item xs={6}>
                      <TextField
                        fullWidth
                        label="Country"
                        value={formData.country}
                        onChange={(e) => handleFormChange('country', e.target.value)}
                      />
                    </Grid>
                  </Grid>

                  {/* Contact Info */}
                  <TextField
                    fullWidth
                    label="Telephone"
                    value={formData.telephone}
                    onChange={(e) => handleFormChange('telephone', e.target.value)}
                    placeholder="+216 XXXXXXXX"
                  />

                  <TextField
                    fullWidth
                    label="Website"
                    value={formData.website}
                    onChange={(e) => handleFormChange('website', e.target.value)}
                    placeholder="https://example.com"
                  />

                  {/* Descriptions */}
                  <TextField
                    fullWidth
                    label="Short Description"
                    value={formData.short_description}
                    onChange={(e) => handleFormChange('short_description', e.target.value)}
                    multiline
                    rows={2}
                  />

                  <TextField
                    fullWidth
                    label="Long Description"
                    value={formData.long_description}
                    onChange={(e) => handleFormChange('long_description', e.target.value)}
                    multiline
                    rows={3}
                  />

                  {/* Hours & Pricing */}
                  <Grid container spacing={2}>
                    <Grid item xs={12}>
                      <TextField
                        fullWidth
                        multiline
                        rows={4}
                        label="Opening Hours"
                        value={formData.opening_hours}
                        onChange={(e) => handleFormChange('opening_hours', e.target.value)}
                        placeholder="e.g., Mon-Fri: 08:00 AM – 06:00 PM&#10;Sat-Sun: 09:00 AM – 05:00 PM"
                      />
                    </Grid>
                  </Grid>

                  <TextField
                    fullWidth
                    label="Price Range"
                    value={displayPriceRange}
                    onChange={(e) => handleFormChange('price_range', e.target.value)}
                    placeholder="e.g., $$ - $$$"
                  />
                </Stack>
              </Card>
            </Grid>

            {/* Images Section */}
            <Grid item xs={12}>
              <Card sx={{ p: 3 }}>
                <Typography variant="h6" sx={{ mb: 2 }}>
                  Photos ({images.length}/5)
                </Typography>

                {images.length > 0 && (
                  <Grid container spacing={2} sx={{ mb: 3 }}>
                    {images.map((img, idx) => (
                      <Grid item xs={12} sm={6} md={4} key={idx}>
                        <Box sx={{ position: 'relative' }}>
                          <img
                            src={img.preview}
                            alt={`preview-${idx}`}
                            style={{
                              width: '100%',
                              height: 200,
                              objectFit: 'cover',
                              borderRadius: 8,
                            }}
                          />
                          <Button
                            size="small"
                            color="error"
                            startIcon={<DeleteIcon />}
                            onClick={() => handleRemoveImage(idx)}
                            sx={{
                              position: 'absolute',
                              top: 8,
                              right: 8,
                              backgroundColor: 'rgba(255, 255, 255, 0.9)',
                            }}
                          >
                            Remove
                          </Button>
                        </Box>
                      </Grid>
                    ))}
                  </Grid>
                )}

                {images.length < 5 && (
                  <Button
                    variant="outlined"
                    startIcon={<CloudUploadIcon />}
                    onClick={() => fileInputRef.current?.click()}
                    fullWidth
                  >
                    Upload Photos (Max 5)
                  </Button>
                )}

                <input
                  ref={fileInputRef}
                  type="file"
                  multiple
                  accept="image/*"
                  hidden
                  onChange={handleImageSelect}
                />
              </Card>
            </Grid>

            {/* Submit Button */}
            <Grid item xs={12}>
              <Button
                variant="contained"
                size="large"
                type="submit"
                disabled={loading}
                fullWidth
                sx={{ py: 1.5 }}
              >
                {loading ? <CircularProgress size={24} /> : 'Add Place'}
              </Button>
            </Grid>
          </Grid>
        </form>
      </Box>
    </>
  );
}
