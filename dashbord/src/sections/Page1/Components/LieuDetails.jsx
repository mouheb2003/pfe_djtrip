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

import { Label } from 'src/components/label';
import { Iconify } from 'src/components/iconify';
import { Carousel, useCarousel, CarouselArrowBasicButtons } from 'src/components/carousel';

// ----------------------------------------------------------------------

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
  const sum = avis.reduce((acc, item) => acc + (item.note || 0), 0);
  return sum / avis.length;
}

// ----------------------------------------------------------------------

export function LieuDetailsDialog({ open, onClose, lieu }) {
  const carousel = useCarousel({ loop: true });

  if (!lieu) return null;

  const averageRating = calculateAverageNote(lieu.avis);
  const images = lieu.galerieImages || [];
  const hasImages = images.length > 0;

  const handleImageClick = (index) => {
    carousel.api?.scrollTo(index);
  };

  return (
    <Dialog
      open={open}
      onClose={onClose}
      maxWidth="lg"
      fullWidth
      PaperProps={{
        sx: { borderRadius: 2 }
      }}
    >
      <Box sx={{ position: 'relative' }}>
        {/* Close button */}
        <IconButton
          onClick={onClose}
          sx={{
            position: 'absolute',
            right: 8,
            top: 8,
            zIndex: 9,
            bgcolor: 'background.paper',
            boxShadow: (theme) => theme.shadows[8],
            '&:hover': { bgcolor: 'background.paper' },
          }}
        >
          <Iconify icon="mingcute:close-line" />
        </IconButton>

        <DialogContent sx={{ p: 0 }}>
          <Grid container spacing={0}>
            {/* Image Gallery Section - Left Side */}
            {hasImages && (
              <Grid size={{ xs: 12, md: 6 }}>
                <Box sx={{ position: 'relative', bgcolor: 'grey.900', height: '100%', minHeight: 400 }}>
                  <Carousel carousel={carousel} sx={{ height: '100%' }}>
                    {images.map((image, index) => (
                      <Box
                        key={image._id || index}
                        component="img"
                        src={image.imageUrl}
                        alt={`${lieu.nom} ${index + 1}`}
                        sx={{
                          width: '100%',
                          height: { xs: 400, md: 600 },
                          objectFit: 'cover',
                        }}
                      />
                    ))}
                  </Carousel>

                  <CarouselArrowBasicButtons
                    {...carousel.arrows}
                    options={carousel.options}
                    sx={{
                      position: 'absolute',
                      top: '50%',
                      left: 0,
                      right: 0,
                      transform: 'translateY(-50%)',
                    }}
                  />

                  {/* Image counter */}
                  <Box
                    sx={{
                      position: 'absolute',
                      bottom: 16,
                      right: 16,
                      bgcolor: 'rgba(0,0,0,0.6)',
                      color: 'white',
                      px: 1.5,
                      py: 0.5,
                      borderRadius: 1,
                    }}
                  >
                    <Typography variant="caption">
                      {carousel.dots.selectedIndex + 1} / {images.length}
                    </Typography>
                  </Box>

                  {/* Thumbnail strip */}
                  {images.length > 1 && (
                    <Box
                      sx={{
                        position: 'absolute',
                        bottom: 16,
                        left: 16,
                        right: 80,
                        display: 'flex',
                        gap: 1,
                        overflowX: 'auto',
                        '&::-webkit-scrollbar': { height: 4 },
                      }}
                    >
                      {images.slice(0, 5).map((image, index) => (
                        <Box
                          key={image._id || index}
                          component="img"
                          src={image.imageUrl}
                          alt={`Thumbnail ${index + 1}`}
                          onClick={() => handleImageClick(index)}
                          sx={{
                            width: 60,
                            height: 60,
                            objectFit: 'cover',
                            borderRadius: 1,
                            cursor: 'pointer',
                            border: (theme) =>
                              carousel.dots.selectedIndex === index
                                ? `2px solid ${theme.palette.primary.main}`
                                : '2px solid transparent',
                            opacity: carousel.dots.selectedIndex === index ? 1 : 0.6,
                            transition: 'all 0.2s',
                            '&:hover': { opacity: 1 },
                            flexShrink: 0,
                          }}
                        />
                      ))}
                      {images.length > 5 && (
                        <Box
                          sx={{
                            width: 60,
                            height: 60,
                            borderRadius: 1,
                            bgcolor: 'rgba(0,0,0,0.6)',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            color: 'white',
                            flexShrink: 0,
                          }}
                        >
                          <Typography variant="caption">+{images.length - 5}</Typography>
                        </Box>
                      )}
                    </Box>
                  )}
                </Box>
              </Grid>
            )}

            {/* Details Section - Right Side */}
            <Grid size={{ xs: 12, md: hasImages ? 6 : 12 }}>
              <Stack spacing={3} sx={{ p: 3, height: '100%', overflow: 'auto', maxHeight: 600 }}>
                {/* Header */}
                <Box>
                  <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
                    <Label variant="soft" color={categorieColor(lieu.categorie)} startIcon={<Iconify icon={categorieIcon(lieu.categorie)} />}>
                      {lieu.categorie}
                    </Label>
                    {lieu.prix === 0 && (
                      <Chip label="Gratuit" size="small" color="success" variant="outlined" />
                    )}
                  </Stack>

                  <Typography variant="h4" sx={{ mb: 1 }}>
                    {lieu.nom}
                  </Typography>

                  {/* Rating */}
                  <Stack direction="row" alignItems="center" spacing={1}>
                    <Rating value={averageRating} precision={0.1} readOnly size="small" />
                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                      {averageRating.toFixed(1)} ({lieu.avis?.length || 0} avis)
                    </Typography>
                  </Stack>
                </Box>

                <Divider />

                {/* Description */}
                {lieu.description && (
                  <Box>
                    <Typography variant="subtitle2" sx={{ mb: 1 }}>
                      Description
                    </Typography>
                    <Typography variant="body2" sx={{ color: 'text.secondary', lineHeight: 1.8 }}>
                      {lieu.description}
                    </Typography>
                  </Box>
                )}

                {/* Info Cards */}
                <Grid container spacing={2}>
                  {/* Location */}
                  <Grid size={{ xs: 12 }}>
                    <Card variant="outlined" sx={{ p: 2, bgcolor: 'background.neutral' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Iconify icon="mdi:map-marker" width={20} sx={{ color: 'error.main' }} />
                          <Typography variant="subtitle2">Localisation</Typography>
                        </Stack>
                        <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                          {lieu.adresse}
                        </Typography>
                        <Stack direction="row" spacing={2}>
                          <Chip
                            label={lieu.ville}
                            size="small"
                            icon={<Iconify icon="mdi:city" width={16} />}
                            variant="filled"
                          />
                          <Chip
                            label={`${lieu.latitude.toFixed(4)}, ${lieu.longitude.toFixed(4)}`}
                            size="small"
                            icon={<Iconify icon="mdi:crosshairs-gps" width={16} />}
                            variant="outlined"
                          />
                        </Stack>
                      </Stack>
                    </Card>
                  </Grid>

                  {/* Contact & Hours */}
                  <Grid size={{ xs: 12, sm: 6 }}>
                    <Card variant="outlined" sx={{ p: 2, bgcolor: 'background.neutral', height: '100%' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Iconify icon="mdi:clock-outline" width={20} sx={{ color: 'info.main' }} />
                          <Typography variant="subtitle2">Horaires</Typography>
                        </Stack>
                        <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                          {lieu.horaires || 'Non spécifié'}
                        </Typography>
                      </Stack>
                    </Card>
                  </Grid>

                  <Grid size={{ xs: 12, sm: 6 }}>
                    <Card variant="outlined" sx={{ p: 2, bgcolor: 'background.neutral', height: '100%' }}>
                      <Stack spacing={1.5}>
                        <Stack direction="row" alignItems="center" spacing={1}>
                          <Iconify icon="mdi:cash" width={20} sx={{ color: 'warning.main' }} />
                          <Typography variant="subtitle2">Prix</Typography>
                        </Stack>
                        <Typography variant="h6" sx={{ color: 'primary.main' }}>
                          {lieu.prix === 0 ? 'Gratuit' : `${lieu.prix} TND`}
                        </Typography>
                      </Stack>
                    </Card>
                  </Grid>

                  {/* Contact Info */}
                  {(lieu.telephone || lieu.siteWeb) && (
                    <Grid size={{ xs: 12 }}>
                      <Card variant="outlined" sx={{ p: 2, bgcolor: 'background.neutral' }}>
                        <Stack spacing={1.5}>
                          <Stack direction="row" alignItems="center" spacing={1}>
                            <Iconify icon="mdi:contact" width={20} sx={{ color: 'success.main' }} />
                            <Typography variant="subtitle2">Contact</Typography>
                          </Stack>
                          <Stack spacing={1}>
                            {lieu.telephone && (
                              <Stack direction="row" alignItems="center" spacing={1}>
                                <Iconify icon="mdi:phone" width={18} sx={{ color: 'text.secondary' }} />
                                <Link href={`tel:${lieu.telephone}`} variant="body2" underline="hover">
                                  {lieu.telephone}
                                </Link>
                              </Stack>
                            )}
                            {lieu.siteWeb && (
                              <Stack direction="row" alignItems="center" spacing={1}>
                                <Iconify icon="mdi:web" width={18} sx={{ color: 'text.secondary' }} />
                                <Link
                                  href={lieu.siteWeb}
                                  target="_blank"
                                  rel="noopener"
                                  variant="body2"
                                  underline="hover"
                                >
                                  Visiter le site web
                                </Link>
                              </Stack>
                            )}
                          </Stack>
                        </Stack>
                      </Card>
                    </Grid>
                  )}
                </Grid>

                {/* Reviews */}
                {lieu.avis && lieu.avis.length > 0 && (
                  <Box>
                    <Typography variant="subtitle2" sx={{ mb: 2 }}>
                      Avis des visiteurs ({lieu.avis.length})
                    </Typography>
                    <Stack spacing={2}>
                      {lieu.avis.slice(0, 3).map((avis, index) => (
                        <Card key={avis._id || index} variant="outlined" sx={{ p: 2 }}>
                          <Stack direction="row" spacing={2}>
                            <Avatar sx={{ bgcolor: 'primary.main', width: 40, height: 40 }}>
                              {index + 1}
                            </Avatar>
                            <Box sx={{ flexGrow: 1 }}>
                              <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 0.5 }}>
                                <Rating value={avis.note} readOnly size="small" />
                                <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                                  {avis.note}/5
                                </Typography>
                              </Stack>
                              <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                                {avis.avis}
                              </Typography>
                            </Box>
                          </Stack>
                        </Card>
                      ))}
                      {lieu.avis.length > 3 && (
                        <Typography variant="caption" sx={{ color: 'text.secondary', textAlign: 'center' }}>
                          + {lieu.avis.length - 3} autres avis
                        </Typography>
                      )}
                    </Stack>
                  </Box>
                )}
              </Stack>
            </Grid>
          </Grid>
        </DialogContent>
      </Box>
    </Dialog>
  );
}
