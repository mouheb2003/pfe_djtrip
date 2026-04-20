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

import { Iconify } from 'src/components/iconify';
import { Carousel, useCarousel, CarouselArrowBasicButtons } from 'src/components/carousel';

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
  return (Array.isArray(images) ? images : [])
    .map((image) => {
      if (typeof image === 'string') return image;
      return image?.imageUrl || image?.url || '';
    })
    .filter(Boolean);
}

export function LieuDetailsDialog({ open, onClose, lieu }) {
  const carousel = useCarousel({ loop: true });

  if (!lieu) return null;

  const images = normalizeImages(lieu.galerieImages);
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
                          label={lieu.categorie}
                          color={categorieColor(lieu.categorie)}
                          icon={<Iconify icon={categorieIcon(lieu.categorie)} width={16} />}
                          sx={{ bgcolor: 'rgba(255,255,255,0.12)', color: 'common.white' }}
                        />
                        {lieu.prix === 0 && (
                          <Chip
                            label="Gratuit"
                            sx={{ bgcolor: 'rgba(46, 125, 50, 0.9)', color: 'common.white' }}
                          />
                        )}
                        <Chip
                          label={`${images.length} photo${images.length > 1 ? 's' : ''}`}
                          sx={{ bgcolor: 'rgba(255,255,255,0.12)', color: 'common.white' }}
                        />
                      </Stack>

                      <Box>
                        <Typography variant="overline" sx={{ color: 'rgba(255,255,255,0.72)' }}>
                          Vue détaillée du lieu
                        </Typography>
                        <Typography variant="h3" sx={{ fontWeight: 800, lineHeight: 1.1 }}>
                          {lieu.nom}
                        </Typography>
                      </Box>

                      <Stack direction="row" alignItems="center" spacing={1.5} flexWrap="wrap">
                        <Stack direction="row" alignItems="center" spacing={0.75}>
                          <Rating value={averageRating} precision={0.1} readOnly size="small" />
                          <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.82)' }}>
                            {averageRating.toFixed(1)} ({totalReviews} avis)
                          </Typography>
                        </Stack>
                        <Box sx={{ width: 4, height: 4, borderRadius: '50%', bgcolor: 'rgba(255,255,255,0.45)' }} />
                        <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.82)' }}>
                          {lieu.ville || 'Ville non renseignée'}
                        </Typography>
                      </Stack>
                    </Stack>
                  </Box>

                  {images.length > 1 && (
                    <Box
                      sx={{
                        position: 'absolute',
                        bottom: 104,
                        left: 24,
                        right: 24,
                        display: 'flex',
                        gap: 1,
                        overflowX: 'auto',
                        pb: 0.5,
                        '&::-webkit-scrollbar': { height: 4 },
                      }}
                    >
                      {images.slice(0, 5).map((image, index) => (
                        <Box
                          key={`${image}-thumb-${index}`}
                          component="img"
                          src={image}
                          alt={`Miniature ${index + 1}`}
                          onClick={() => handleImageClick(index)}
                          sx={{
                            width: 64,
                            height: 64,
                            objectFit: 'cover',
                            borderRadius: 2,
                            cursor: 'pointer',
                            border: (theme) =>
                              carousel.dots.selectedIndex === index
                                ? `2px solid ${theme.palette.common.white}`
                                : '2px solid rgba(255,255,255,0.25)',
                            opacity: carousel.dots.selectedIndex === index ? 1 : 0.62,
                            transition: 'all 0.2s ease',
                            '&:hover': { opacity: 1, transform: 'translateY(-1px)' },
                            flexShrink: 0,
                            boxShadow: '0 10px 30px rgba(0,0,0,0.24)',
                          }}
                        />
                      ))}
                      {images.length > 5 && (
                        <Box
                          sx={{
                            width: 64,
                            height: 64,
                            borderRadius: 2,
                            bgcolor: 'rgba(255,255,255,0.16)',
                            border: '1px solid rgba(255,255,255,0.22)',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            color: 'white',
                            flexShrink: 0,
                            backdropFilter: 'blur(12px)',
                          }}
                        >
                          <Typography variant="caption" sx={{ fontWeight: 700 }}>
                            +{images.length - 5}
                          </Typography>
                        </Box>
                      )}
                    </Box>
                  )}
                </Box>
              </Grid>
            )}

            <Grid size={{ xs: 12, md: hasImages ? 6 : 12 }}>
              <Stack spacing={3} sx={{ p: { xs: 2.5, md: 4 }, minHeight: hasImages ? 760 : 'auto' }}>
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
                        {lieu.prix === 0 && (
                          <Chip
                            label="Gratuit"
                            sx={{ bgcolor: 'rgba(46, 125, 50, 0.9)', color: 'common.white' }}
                          />
                        )}
                      </Stack>

                      <Typography variant="h4" sx={{ fontWeight: 800 }}>
                        {lieu.nom}
                      </Typography>

                      <Stack direction="row" alignItems="center" spacing={1.25} flexWrap="wrap">
                        <Rating value={averageRating} precision={0.1} readOnly size="small" />
                        <Typography variant="body2" sx={{ color: 'rgba(255,255,255,0.82)' }}>
                          {averageRating.toFixed(1)} sur 5, basé sur {totalReviews} avis
                        </Typography>
                      </Stack>
                    </Stack>
                  </Box>
                )}

                <Box>
                  <Stack spacing={1} sx={{ mb: 1.5 }}>
                    <Typography variant="overline" sx={{ color: 'text.secondary' }}>
                      Aperçu rapide
                    </Typography>
                    <Typography variant="h5">Informations principales</Typography>
                  </Stack>

                  <Grid container spacing={2}>
                    <Grid size={{ xs: 12, sm: 6 }}>
                      <Card variant="outlined" sx={{ p: 2, height: '100%', borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                        <Stack spacing={1.2}>
                          <Stack direction="row" alignItems="center" spacing={1}>
                            <Avatar sx={{ width: 36, height: 36, bgcolor: 'error.lighter', color: 'error.main' }}>
                              <Iconify icon="mdi:map-marker" width={18} />
                            </Avatar>
                            <Typography variant="subtitle2">Localisation</Typography>
                          </Stack>
                          <Typography variant="body2" sx={{ color: 'text.secondary', lineHeight: 1.7 }}>
                            {lieu.adresse || 'Adresse non renseignée'}
                          </Typography>
                          <Stack direction="row" spacing={1} flexWrap="wrap">
                            <Chip label={lieu.ville || 'Ville inconnue'} size="small" icon={<Iconify icon="mdi:city" width={16} />} />
                            <Chip
                              variant="outlined"
                              size="small"
                              label={`${lieu.latitude.toFixed(4)}, ${lieu.longitude.toFixed(4)}`}
                              icon={<Iconify icon="mdi:crosshairs-gps" width={16} />}
                            />
                          </Stack>
                        </Stack>
                      </Card>
                    </Grid>

                    <Grid size={{ xs: 12, sm: 6 }}>
                      <Card variant="outlined" sx={{ p: 2, height: '100%', borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                        <Stack spacing={1.2}>
                          <Stack direction="row" alignItems="center" spacing={1}>
                            <Avatar sx={{ width: 36, height: 36, bgcolor: 'warning.lighter', color: 'warning.main' }}>
                              <Iconify icon="mdi:cash" width={18} />
                            </Avatar>
                            <Typography variant="subtitle2">Prix</Typography>
                          </Stack>
                          <Typography variant="h5" sx={{ color: 'primary.main', fontWeight: 800 }}>
                            {priceLabel(lieu.prix)}
                          </Typography>
                          <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                            {lieu.prix === 0 ? 'Accès gratuit au lieu' : 'Tarif affiché pour l’accès au lieu'}
                          </Typography>
                        </Stack>
                      </Card>
                    </Grid>

                    <Grid size={{ xs: 12, sm: 6 }}>
                      <Card variant="outlined" sx={{ p: 2, height: '100%', borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                        <Stack spacing={1.2}>
                          <Stack direction="row" alignItems="center" spacing={1}>
                            <Avatar sx={{ width: 36, height: 36, bgcolor: 'info.lighter', color: 'info.main' }}>
                              <Iconify icon="mdi:clock-outline" width={18} />
                            </Avatar>
                            <Typography variant="subtitle2">Horaires</Typography>
                          </Stack>
                          <Typography variant="body2" sx={{ color: 'text.secondary', lineHeight: 1.7 }}>
                            {lieu.horaires || 'Non spécifié'}
                          </Typography>
                        </Stack>
                      </Card>
                    </Grid>

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
                                Téléphone non renseigné
                              </Typography>
                            )}
                            {lieu.siteWeb ? (
                              <Link href={lieu.siteWeb} target="_blank" rel="noopener" variant="body2" underline="hover">
                                Visiter le site web
                              </Link>
                            ) : (
                              <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                                Aucun site web associé
                              </Typography>
                            )}
                          </Stack>
                        </Stack>
                      </Card>
                    </Grid>
                  </Grid>
                </Box>

                {lieu.description && (
                  <Box>
                    <Typography variant="overline" sx={{ color: 'text.secondary' }}>
                      Description
                    </Typography>
                    <Card variant="outlined" sx={{ mt: 1, p: 2.5, borderRadius: 2.5, bgcolor: 'background.neutral' }}>
                      <Typography variant="body2" sx={{ color: 'text.secondary', lineHeight: 1.9 }}>
                        {lieu.description}
                      </Typography>
                    </Card>
                  </Box>
                )}

                {lieu.avis?.length > 0 && (
                  <Box>
                    <Divider sx={{ mb: 2 }} />
                    <Stack spacing={1} sx={{ mb: 1.5 }}>
                      <Typography variant="overline" sx={{ color: 'text.secondary' }}>
                        Avis des visiteurs
                      </Typography>
                      <Typography variant="h5">Retour des utilisateurs</Typography>
                    </Stack>

                    <Stack spacing={2}>
                      {lieu.avis.slice(0, 3).map((avis, index) => (
                        <Card
                          key={avis._id || index}
                          variant="outlined"
                          sx={{ p: 2, borderRadius: 2.5, bgcolor: 'background.neutral' }}
                        >
                          <Stack direction="row" spacing={2} alignItems="flex-start">
                            <Avatar sx={{ bgcolor: 'primary.main', width: 44, height: 44 }}>
                              {getInitial(avis.user?.nom || avis.user?.name || avis.user?.prenom || String(index + 1))}
                            </Avatar>
                            <Box sx={{ flexGrow: 1, minWidth: 0 }}>
                              <Stack
                                direction={{ xs: 'column', sm: 'row' }}
                                alignItems={{ xs: 'flex-start', sm: 'center' }}
                                justifyContent="space-between"
                                spacing={1}
                                sx={{ mb: 0.75 }}
                              >
                                <Stack direction="row" alignItems="center" spacing={1} flexWrap="wrap">
                                  <Rating value={Number(avis.note) || 0} readOnly size="small" />
                                  <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                                    {Number(avis.note || 0).toFixed(1)}/5
                                  </Typography>
                                </Stack>
                                <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                                  Avis {index + 1}
                                </Typography>
                              </Stack>

                              <Typography variant="body2" sx={{ color: 'text.secondary', lineHeight: 1.8 }}>
                                {avis.avis || 'Aucun commentaire fourni.'}
                              </Typography>
                            </Box>
                          </Stack>
                        </Card>
                      ))}

                      {lieu.avis.length > 3 && (
                        <Box sx={{ py: 0.5, textAlign: 'center', color: 'text.secondary' }}>
                          <Typography variant="caption">+ {lieu.avis.length - 3} autres avis</Typography>
                        </Box>
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
