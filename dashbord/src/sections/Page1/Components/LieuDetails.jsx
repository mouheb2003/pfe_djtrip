import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Chip from '@mui/material/Chip';
import Link from '@mui/material/Link';
import Grid from '@mui/material/Grid2';
import Stack from '@mui/material/Stack';
import Avatar from '@mui/material/Avatar';
import Dialog from '@mui/material/Dialog';
import Rating from '@mui/material/Rating';
import Divider from '@mui/material/Divider';
import IconButton from '@mui/material/IconButton';
import Typography from '@mui/material/Typography';
import DialogContent from '@mui/material/DialogContent';
import DialogTitle from '@mui/material/DialogTitle';
import CircularProgress from '@mui/material/CircularProgress';
import { useState, useCallback } from 'react';

import { Iconify } from 'src/components/iconify';
import { Carousel, useCarousel, CarouselArrowBasicButtons } from 'src/components/carousel';
import { useAuthContext } from 'src/auth/hooks';
import { toast } from 'src/components/snackbar';
import { Delete } from 'src/Controller/function';
import { END_POINT } from 'src/Controller/endPoint';
import { getUserById, getUserReviews } from 'src/Controller/actions';

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

function categorieIcon(categorie) {
  switch (categorie) {
    case 'plage':
      return 'fluent:beach-20-filled';
    case 'musee':
      return 'mdi:bank';
    case 'hotel':
      return 'fa-solid:hotel';
    case 'restaurant':
      return 'mdi:silverware-fork-knife';
    case 'monument':
      return 'mdi:castle';
    default:
      return 'mdi:map-marker';
  }
}

function calculateAverageNote(avis) {
  if (!Array.isArray(avis) || avis.length === 0) return 0;
  const sum = avis.reduce((acc, item) => acc + (Number(item.note) || 0), 0);
  return sum / avis.length;
}

function getInitial(text) {
  return (text || 'L').trim().charAt(0).toUpperCase();
}

function priceLabel(price) {
  return price === 0 ? 'Gratuit' : `${price} TND`;
}

function normalizeImages(images) {
  const imageArray = Array.isArray(images) ? images : [];
  return imageArray
    .map((image) => {
      if (typeof image === 'string') return image;
      return image?.imageUrl || image?.url || image?.src || '';
    })
    .filter(Boolean);
}

export function LieuDetailsDialog({ open, onClose, lieu, onRefresh }) {
  const carousel = useCarousel({ loop: true });
  const { user } = useAuthContext();
  const isAdmin = user?.role === 'admin';
  const [userProfileOpen, setUserProfileOpen] = useState(false);
  const [selectedUser, setSelectedUser] = useState(null);
  const [loadingUser, setLoadingUser] = useState(false);
  const [userReviews, setUserReviews] = useState([]);

  const handleOpenUserProfile = useCallback(async (userId) => {
    if (!userId) return;
    setLoadingUser(true);
    try {
      const userData = await getUserById(userId);
      setSelectedUser(userData);
      
      const reviews = await getUserReviews(userId);
      setUserReviews(reviews);
      
      setUserProfileOpen(true);
    } catch (error) {
      console.error('Error loading user profile:', error);
      toast.error('Erreur lors du chargement du profil utilisateur');
    } finally {
      setLoadingUser(false);
    }
  }, []);

  const closeUserProfile = useCallback(() => {
    setUserProfileOpen(false);
    setSelectedUser(null);
    setUserReviews([]);
  }, []);

  const handleDeleteReview = useCallback(async (reviewId) => {
    try {
      await Delete(END_POINT.deleteReview(reviewId));
      toast.success('Review deleted successfully');
      if (onRefresh) onRefresh();
    } catch (error) {
      console.error('Error deleting review:', error);
      toast.error('Failed to delete review');
    }
  }, [onRefresh]);

  if (!lieu) return null;

  const images = normalizeImages(lieu.galerieImages || lieu.images || lieu.gallery);
  const hasImages = images.length > 0;
  const averageRating = calculateAverageNote(lieu.avis);
  const totalReviews = lieu.avis?.length || 0;

  const handleImageClick = (index) => {
    carousel.api?.scrollTo(index);
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="lg"
      fullWidth
      scroll="paper"
      PaperProps={{
        sx: {
          borderRadius: 3,
          overflow: 'hidden',
          bgcolor: 'background.default',
        },
      }}
    >
      <Box sx={{ position: 'relative' }}>
        <IconButton
          onClick={onClose}
          sx={{
            position: 'absolute',
            right: 16,
            top: 16,
            zIndex: 9,
            bgcolor: 'background.paper',
            boxShadow: (theme) => theme.shadows[10],
            border: (theme) => `1px solid ${theme.palette.divider}`,
            '&:hover': { bgcolor: 'background.paper' },
          }}
        >
          <Iconify icon="mingcute:close-line" />
        </IconButton>

        <DialogContent sx={{ p: 0 }}>
          <Grid container spacing={0}>
            {hasImages && (
              <Grid size={{ xs: 12, md: 6 }}>
                <Box sx={{ position: 'relative', bgcolor: 'grey.900', height: '100%', minHeight: 520 }}>
                  <Carousel carousel={carousel} sx={{ height: '100%' }}>
                    {images.map((image, index) => (
                      <Box
                        key={`${image}-${index}`}
                        component="img"
                        src={image}
                        alt={`${lieu.nom} ${index + 1}`}
                        sx={{
                          width: '100%',
                          height: { xs: 360, md: 760 },
                          objectFit: 'cover',
                        }}
                      />
                    ))}
                  </Carousel>

                  <Box
                    sx={{
                      position: 'absolute',
                      inset: 0,
                      background:
                        'linear-gradient(180deg, rgba(8,15,25,0.12) 0%, rgba(8,15,25,0.08) 35%, rgba(8,15,25,0.86) 100%)',
                      pointerEvents: 'none',
                    }}
                  />

                  <CarouselArrowBasicButtons
                    {...carousel.arrows}
                    options={carousel.options}
                    sx={{
                      position: 'absolute',
                      top: '50%',
                      left: 0,
                      transform: 'translateY(-50%)',
                    }}
                  />

                  <Box
                    sx={{
                      position: 'absolute',
                      top: 16,
                      left: 16,
                      bgcolor: 'rgba(0,0,0,0.42)',
                      backdropFilter: 'blur(12px)',
                      color: 'white',
                      px: 1.25,
                      py: 0.75,
                      borderRadius: 999,
                      border: '1px solid rgba(255,255,255,0.18)',
                    }}
                  >
                    <Typography variant="caption" sx={{ fontWeight: 700 }}>
                      {carousel.dots.selectedIndex + 1} / {images.length}
                    </Typography>
                  </Box>

                  <Box
                    sx={{
                      position: 'absolute',
                      left: 24,
                      right: 24,
                      bottom: 24,
                      color: 'common.white',
                    }}
                  >
                    <Stack spacing={1.5}>
                      <Stack direction="row" alignItems="center" spacing={1} flexWrap="wrap">
                        <Chip
                          label={`${images.length} photo${images.length > 1 ? 's' : ''}`}
                          sx={{ bgcolor: 'rgba(255,255,255,0.12)', color: 'common.white' }}
                        />
                        <Chip
                          label={lieu.categorie}
                          color={categorieColor(lieu.categorie)}
                          icon={<Iconify icon={categorieIcon(lieu.categorie)} width={16} />}
                          sx={{ bgcolor: 'rgba(255,255,255,0.12)', color: 'common.white' }}
                        />
                      </Stack>

                      <Box>
                        <Typography variant="overline" sx={{ color: 'rgba(255,255,255,0.72)' }}>
                          Place Details
                        </Typography>
                        <Typography variant="h3" sx={{ fontWeight: 800, lineHeight: 1.1 }}>
                          {lieu.nom}
                        </Typography>
                      </Box>

                      <Stack direction="row" alignItems="center" spacing={1.5} flexWrap="wrap">
                        <Stack direction="row" alignItems="center" spacing={0.75}>
                          <Rating value={averageRating} precision={0.1} readOnly size="small" />
                          <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.82)' }}>
                            {averageRating.toFixed(1)} ({totalReviews} review{totalReviews > 1 ? 's' : ''})
                          </Typography>
                        </Stack>
                        <Box sx={{ width: 4, height: 4, borderRadius: '50%', bgcolor: 'rgba(255,255,255,0.45)' }} />
                        <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.82)' }}>
                          {lieu.ville || 'City not specified'}
                        </Typography>
                      </Stack>
                    </Stack>
                  </Box>
                </Box>
              </Grid>
            )}

            <Grid size={{ xs: 12, md: hasImages ? 6 : 12 }}>
              <Box
                sx={{
                  p: { xs: 2.5, md: 4 },
                  height: hasImages ? 760 : 'auto',
                  maxHeight: '80vh',
                  overflowY: 'auto',
                  '&::-webkit-scrollbar': { width: 6 },
                  '&::-webkit-scrollbar-thumb': { bgcolor: 'text.secondary', borderRadius: 3 },
                }}
              >
                <Stack spacing={3}>
                {!hasImages && (
                  <Box
                    sx={{
                      p: 3,
                      borderRadius: 3,
                      color: 'common.white',
                      background:
                        'linear-gradient(135deg, rgba(19, 58, 92, 0.96) 0%, rgba(14, 97, 117, 0.92) 100%)',
                      boxShadow: (theme) => theme.shadows[8],
                    }}
                  >
                    <Stack spacing={1.5}>
                      <Stack direction="row" alignItems="center" spacing={1} flexWrap="wrap">
                        <Chip
                          label={lieu.categorie}
                          color={categorieColor(lieu.categorie)}
                          icon={<Iconify icon={categorieIcon(lieu.categorie)} width={16} />}
                          sx={{ bgcolor: 'rgba(255,255,255,0.14)', color: 'common.white' }}
                        />
                      </Stack>

                      <Typography variant="h4" sx={{ fontWeight: 800 }}>
                        {lieu.nom}
                      </Typography>

                      <Stack direction="row" alignItems="center" spacing={1.25} flexWrap="wrap">
                        <Rating value={averageRating} precision={0.1} readOnly size="small" />
                        <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.82)' }}>
                          {averageRating.toFixed(1)} out of 5, based on {totalReviews} review{totalReviews > 1 ? 's' : ''}
                        </Typography>
                      </Stack>
                    </Stack>
                  </Box>
                )}

                <Box>
                  <Stack spacing={1} sx={{ mb: 2 }}>
                    <Typography variant="overline" sx={{ color: 'text.secondary' }}>
                      Complete Overview
                    </Typography>
                    <Typography variant="h5">All Information</Typography>
                  </Stack>

                  <Stack spacing={2}>
                    {/* Basic Information */}
                    <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Avatar sx={{ width: 32, height: 32, bgcolor: 'primary.lighter', color: 'primary.main' }}>
                            <Iconify icon="mdi:information" width={16} />
                          </Avatar>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Basic Information</Typography>
                        </Stack>
                        <Grid container spacing={2}>
                          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>ID</Typography>
                              <Typography variant="body2" sx={{ wordBreak: 'break-all' }}>{lieu.id || lieu._id || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Name</Typography>
                              <Typography variant="body2">{lieu.nom || lieu.name || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Slug</Typography>
                              <Typography variant="body2">{lieu.slug || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Type</Typography>
                              <Typography variant="body2">{lieu.type || lieu.categorie || '-'}</Typography>
                            </Stack>
                          </Grid>
                        </Grid>
                      </Stack>
                    </Card>

                    {/* Location */}
                    <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Avatar sx={{ width: 32, height: 32, bgcolor: 'error.lighter', color: 'error.main' }}>
                            <Iconify icon="mdi:map-marker" width={16} />
                          </Avatar>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Location</Typography>
                        </Stack>
                        <Grid container spacing={2}>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Address</Typography>
                              <Typography variant="body2">{lieu.address || lieu.adresse || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>City</Typography>
                              <Typography variant="body2">{lieu.city || lieu.ville || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Country</Typography>
                              <Typography variant="body2">{lieu.country || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Zipcode</Typography>
                              <Typography variant="body2">{lieu.zipcode || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Coordinates</Typography>
                              <Typography variant="body2">
                                {lieu.latitude && lieu.longitude 
                                  ? `${lieu.latitude.toFixed(4)}, ${lieu.longitude.toFixed(4)}`
                                  : '-'}
                              </Typography>
                            </Stack>
                          </Grid>
                        </Grid>
                      </Stack>
                    </Card>

                    {/* Media */}
                    <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Avatar sx={{ width: 32, height: 32, bgcolor: 'info.lighter', color: 'info.main' }}>
                            <Iconify icon="mdi:image" width={16} />
                          </Avatar>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Media</Typography>
                        </Stack>
                        <Grid container spacing={2}>
                          <Grid size={{ xs: 12 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Main Image</Typography>
                              <Typography variant="body2" sx={{ wordBreak: 'break-all' }}>{lieu.main_image || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Gallery</Typography>
                              <Typography variant="body2">{Array.isArray(lieu.gallery) ? lieu.gallery.length : 0} images</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Video</Typography>
                              <Typography variant="body2" sx={{ wordBreak: 'break-all' }}>{lieu.video || '-'}</Typography>
                            </Stack>
                          </Grid>
                        </Grid>
                      </Stack>
                    </Card>

                    {/* Descriptions */}
                    <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Avatar sx={{ width: 32, height: 32, bgcolor: 'secondary.lighter', color: 'secondary.main' }}>
                            <Iconify icon="mdi:text" width={16} />
                          </Avatar>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Descriptions</Typography>
                        </Stack>
                        <Grid container spacing={2}>
                          <Grid size={{ xs: 12 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Short Description</Typography>
                              <Typography variant="body2">{lieu.short_description || lieu.description || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Long Description</Typography>
                              <Typography variant="body2">{lieu.long_description || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Experience Description</Typography>
                              <Typography variant="body2">{lieu.experience_description || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Heritage History</Typography>
                              <Typography variant="body2">{lieu.heritage_history || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>History</Typography>
                              <Typography variant="body2">{lieu.history || '-'}</Typography>
                            </Stack>
                          </Grid>
                        </Grid>
                      </Stack>
                    </Card>

                    {/* Features */}
                    <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Avatar sx={{ width: 32, height: 32, bgcolor: 'warning.lighter', color: 'warning.main' }}>
                            <Iconify icon="mdi:star" width={16} />
                          </Avatar>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Features</Typography>
                        </Stack>
                        <Grid container spacing={2}>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Highlights</Typography>
                              <Typography variant="body2">{lieu.highlights || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Experience Highlights</Typography>
                              <Typography variant="body2">{lieu.experience_highlights || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Amenities</Typography>
                              <Typography variant="body2">{lieu.amenities || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Activities</Typography>
                              <Typography variant="body2">{lieu.activities || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Languages Spoken</Typography>
                              <Typography variant="body2">{lieu.languages_spoken || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Wheelchair Access</Typography>
                              <Typography variant="body2">{lieu.wheelchair_access ? 'Yes' : 'No'}</Typography>
                            </Stack>
                          </Grid>
                        </Grid>
                      </Stack>
                    </Card>

                    {/* Hours & Booking */}
                    <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Avatar sx={{ width: 32, height: 32, bgcolor: 'success.lighter', color: 'success.main' }}>
                            <Iconify icon="mdi:clock" width={16} />
                          </Avatar>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Hours & Booking</Typography>
                        </Stack>
                        <Grid container spacing={2}>
                          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Opening Hours</Typography>
                              <Typography variant="body2">{lieu.opening_hours || lieu.openingHours || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Closing Hours</Typography>
                              <Typography variant="body2">{lieu.closing_hours || lieu.closingHours || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Seasonal</Typography>
                              <Typography variant="body2">{lieu.seasonal || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Booking Required</Typography>
                              <Typography variant="body2">{lieu.booking_required ? 'Yes' : 'No'}</Typography>
                            </Stack>
                          </Grid>
                        </Grid>
                      </Stack>
                    </Card>

                    {/* Pricing */}
                    <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Avatar sx={{ width: 32, height: 32, bgcolor: 'warning.lighter', color: 'warning.main' }}>
                            <Iconify icon="mdi:cash" width={16} />
                          </Avatar>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Pricing</Typography>
                        </Stack>
                        <Grid container spacing={2}>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Price Range</Typography>
                              <Typography variant="body2">{lieu.price_range || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Price per Adult</Typography>
                              <Typography variant="body2">{lieu.price_per_adult ? `${lieu.price_per_adult} ${lieu.currency || 'TND'}` : '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Min Price</Typography>
                              <Typography variant="body2">{lieu.min_price ? `${lieu.min_price} ${lieu.currency || 'TND'}` : '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Max Price</Typography>
                              <Typography variant="body2">{lieu.max_price ? `${lieu.max_price} ${lieu.currency || 'TND'}` : '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6, md: 3 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Currency</Typography>
                              <Typography variant="body2">{lieu.currency || 'TND'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Discounts</Typography>
                              <Typography variant="body2">{lieu.discounts || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Booking Link</Typography>
                              <Typography variant="body2" sx={{ wordBreak: 'break-all' }}>{lieu.booking_link || lieu.siteWeb || '-'}</Typography>
                            </Stack>
                          </Grid>
                        </Grid>
                      </Stack>
                    </Card>

                    {/* Metrics */}
                    <Card variant="outlined" sx={{ p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Avatar sx={{ width: 32, height: 32, bgcolor: 'info.lighter', color: 'info.main' }}>
                            <Iconify icon="mdi:chart-line" width={16} />
                          </Avatar>
                          <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>Metrics</Typography>
                        </Stack>
                        <Grid container spacing={2}>
                          <Grid size={{ xs: 12, sm: 6, md: 4 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Rating</Typography>
                              <Typography variant="body2">{lieu.rating || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6, md: 4 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Review Count</Typography>
                              <Typography variant="body2">{lieu.review_count || lieu.reviews?.length || 0}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6, md: 4 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Popularity Score</Typography>
                              <Typography variant="body2">{lieu.popularity_score || '-'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Featured</Typography>
                              <Typography variant="body2">{lieu.is_featured ? 'Yes' : 'No'}</Typography>
                            </Stack>
                          </Grid>
                          <Grid size={{ xs: 12, sm: 6 }}>
                            <Stack spacing={0.5}>
                              <Typography variant="caption" sx={{ color: 'text.secondary', fontWeight: 600 }}>Tags</Typography>
                              <Typography variant="body2">{lieu.tags || '-'}</Typography>
                            </Stack>
                          </Grid>
                        </Grid>
                      </Stack>
                    </Card>
                  </Stack>
                </Box>

                <Divider sx={{ my: 2 }} />

                <Box>
                  <Stack spacing={1} sx={{ mb: 1.5 }}>
                    <Typography variant="overline" sx={{ color: 'text.secondary' }}>
                      Contact Information
                    </Typography>
                    <Typography variant="h5">Contact Details</Typography>
                  </Stack>

                  <Grid container spacing={2}>
                    <Grid size={{ xs: 12, sm: 6 }}>
                      <Card variant="outlined" sx={{ p: 2, height: '100%', borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                        <Stack spacing={1.2}>
                          <Stack direction="row" alignItems="center" spacing={1}>
                            <Avatar sx={{ width: 36, height: 36, bgcolor: 'success.lighter', color: 'success.main' }}>
                              <Iconify icon="mdi:phone" width={18} />
                            </Avatar>
                            <Typography variant="subtitle2">Contact</Typography>
                          </Stack>
                          <Stack spacing={1}>
                            {lieu.telephone ? (
                              <Link href={`tel:${lieu.telephone}`} variant="body2" underline="hover">
                                {lieu.telephone}
                              </Link>
                            ) : (
                              <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                                Phone not specified
                              </Typography>
                            )}
                            {lieu.siteWeb ? (
                              <Link href={lieu.siteWeb} target="_blank" rel="noopener" variant="body2" underline="hover">
                                Visit website
                              </Link>
                            ) : (
                              <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                                No website associated
                              </Typography>
                            )}
                          </Stack>
                        </Stack>
                      </Card>
                    </Grid>
                  </Grid>
                </Box>

                {lieu.avis?.length > 0 && (
                  <Box>
                    <Divider sx={{ mb: 2 }} />
                    <Stack spacing={1} sx={{ mb: 1.5 }}>
                      <Typography variant="overline" sx={{ color: 'text.secondary' }}>
                        Visitor Reviews
                      </Typography>
                      <Typography variant="h5">User Feedback</Typography>
                    </Stack>

                    <Stack spacing={2}>
                      {lieu.avis.slice(0, 3).map((avis, index) => (
                        <Card
                          key={avis._id || index}
                          variant="outlined"
                          sx={{ p: 2, borderRadius: 2.5, bgcolor: 'background.neutral' }}
                        >
                          <Stack direction="row" spacing={2} alignItems="flex-start">
                            <IconButton
                              onClick={() => handleOpenUserProfile(avis.user?._id || avis.touriste_id)}
                              sx={{ p: 0 }}
                            >
                              <Avatar
                                src={avis.user?.avatar}
                                sx={{ bgcolor: 'primary.main', width: 44, height: 44 }}
                              >
                                {getInitial(avis.user?.nom || avis.user?.name || avis.user?.prenom || avis.user?.fullname || String(index + 1))}
                              </Avatar>
                            </IconButton>
                            <Box sx={{ flexGrow: 1, minWidth: 0 }}>
                              <Stack
                                direction={{ xs: 'column', sm: 'row' }}
                                alignItems={{ xs: 'flex-start', sm: 'center' }}
                                justifyContent="space-between"
                                spacing={1}
                                sx={{ mb: 0.75 }}
                              >
                                <Stack direction="row" alignItems="center" spacing={1} flexWrap="wrap">
                                  <Typography variant="subtitle2" sx={{ fontWeight: 600 }}>
                                    {avis.user?.nom || avis.user?.name || avis.user?.prenom || avis.user?.fullname || 'User'}
                                  </Typography>
                                  <Rating value={Number(avis.note) || 0} readOnly size="small" />
                                  <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                                    {Number(avis.note || 0).toFixed(1)}/5
                                  </Typography>
                                </Stack>
                                <Stack direction="row" alignItems="center" spacing={1}>
                                  {isAdmin && avis._id && (
                                    <IconButton
                                      size="small"
                                      onClick={() => handleDeleteReview(avis._id)}
                                      sx={{ color: 'error.main' }}
                                      title="Delete review"
                                    >
                                      <Iconify icon="solar:trash-bin-trash-bold" width={16} />
                                    </IconButton>
                                  )}
                                </Stack>
                              </Stack>

                              <Typography variant="body2" sx={{ color: 'text.secondary', lineHeight: 1.8 }}>
                                {avis.avis || avis.comment || 'No comment provided.'}
                              </Typography>
                            </Box>
                          </Stack>
                        </Card>
                      ))}

                      {lieu.avis.length > 3 && (
                        <Box sx={{ py: 0.5, textAlign: 'center', color: 'text.secondary' }}>
                          <Typography variant="caption">+ {lieu.avis.length - 3} more review{lieu.avis.length - 3 > 1 ? 's' : ''}</Typography>
                        </Box>
                      )}
                    </Stack>
                  </Box>
                )}
                </Stack>
              </Box>
            </Grid>
          </Grid>
        </DialogContent>
      </Box>

      <Dialog open={userProfileOpen} onClose={closeUserProfile} fullWidth maxWidth="md">
        <DialogTitle>
          <Stack spacing={0.5}>
            <Typography variant="h6">Profil utilisateur</Typography>
            <Typography variant="body2" sx={{ color: 'text.secondary' }}>
              Vue complète du profil et de l'état du compte
            </Typography>
          </Stack>
        </DialogTitle>
        <DialogContent dividers>
          {loadingUser ? (
            <Stack alignItems="center" justifyContent="center" sx={{ py: 8 }}>
              <CircularProgress />
            </Stack>
          ) : (
            <Stack spacing={2}>
              <Card
                variant="outlined"
                sx={{
                  p: 2,
                  borderRadius: 2,
                  background: (theme) =>
                    `linear-gradient(135deg, ${theme.palette.primary.main}12 0%, ${theme.palette.info.main}10 100%)`,
                }}
              >
                <Stack direction="row" spacing={2} alignItems="center">
                  <Avatar
                    src={selectedUser?.avatar}
                    sx={{ width: 64, height: 64 }}
                  >
                    {getInitial(selectedUser?.fullname || selectedUser?.nom || selectedUser?.name)}
                  </Avatar>
                  <Box>
                    <Typography variant="h5" sx={{ fontWeight: 700 }}>
                      {selectedUser?.fullname || selectedUser?.nom || selectedUser?.name || '-'}
                    </Typography>
                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                      {selectedUser?.email || '-'}
                    </Typography>
                    <Stack direction="row" spacing={1} sx={{ mt: 1 }}>
                      <Chip size="small" label={selectedUser?.userType || selectedUser?.role || '-'} color="primary" variant="soft" />
                      <Chip
                        size="small"
                        label={selectedUser?.accountStatus || selectedUser?.status || '-'}
                        color={
                          selectedUser?.accountStatus === 'active' || selectedUser?.status === 'active' ? 'success' :
                          selectedUser?.accountStatus === 'suspended' || selectedUser?.status === 'suspended' ? 'warning' :
                          selectedUser?.accountStatus === 'banned' || selectedUser?.status === 'banned' ? 'error' :
                          'default'
                        }
                        variant="soft"
                      />
                    </Stack>
                  </Box>
                </Stack>
              </Card>

              <Card variant="outlined" sx={{ p: 2, borderRadius: 2 }}>
                <Typography variant="subtitle2" sx={{ mb: 1 }}>
                  Avis soumis ({userReviews.length})
                </Typography>
                {userReviews.length === 0 ? (
                  <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                    Aucun avis soumis
                  </Typography>
                ) : (
                  <Box sx={{ maxHeight: 300, overflow: 'auto' }}>
                    <Stack spacing={1}>
                      {userReviews.map((review) => (
                        <Card key={review._id} variant="outlined" sx={{ p: 1.5 }}>
                          <Stack direction="row" justifyContent="space-between" alignItems="flex-start" spacing={1}>
                            <Box sx={{ flex: 1 }}>
                              <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 0.5 }}>
                                <Typography variant="body2" sx={{ fontWeight: 600 }}>
                                  Note: {review.note}/5
                                </Typography>
                              </Stack>
                              <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                                {review.avis || review.comment || 'No comment'}
                              </Typography>
                            </Box>
                          </Stack>
                        </Card>
                      ))}
                    </Stack>
                  </Box>
                )}
              </Card>
            </Stack>
          )}
        </DialogContent>
      </Dialog>
    </Dialog>
  );
}
