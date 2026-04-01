import { useState, useEffect } from 'react';

import Box from '@mui/material/Box';
import Card from '@mui/material/Card';
import Chip from '@mui/material/Chip';
import Link from '@mui/material/Link';
import Grid from '@mui/material/Grid2';
import Stack from '@mui/material/Stack';
import Avatar from '@mui/material/Avatar';
import Button from '@mui/material/Button';
import Rating from '@mui/material/Rating';
import Divider from '@mui/material/Divider';
import Typography from '@mui/material/Typography';

import { useParams } from 'src/routes/hooks/use-params';
import { useRouter } from 'src/routes/hooks/use-router';

import { getLieuById } from 'src/Controller/actions';
import { DashboardContent } from 'src/layouts/dashboard';

import { Label } from 'src/components/label';
import { toast } from 'src/components/snackbar';
import { Iconify } from 'src/components/iconify';
import { LoadingScreen } from 'src/components/loading-screen';
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
  const sum = avis.reduce((acc, item) => acc + (item.note || 0), 0);
  return sum / avis.length;
}

function mapLieu(lieu) {
  return {
    id: lieu._id,
    nom: lieu.nom,
    description: lieu.description,
    categorie: lieu.categorie,
    ville: lieu.position?.ville || '',
    adresse: lieu.position?.adresse || '',
    latitude: lieu.position?.localisation?.latitude || 0,
    longitude: lieu.position?.localisation?.longitude || 0,
    prix: lieu.prix,
    horaires: lieu.horaires,
    telephone: lieu.telephone,
    siteWeb: lieu.siteWeb,
    galerieImages: lieu.galerieImages || [],
    avis: lieu.avis || [],
    createdAt: lieu.createdAt,
  };
}

export function LieuxDetailsView() {
  const router = useRouter();
  const { id } = useParams();
  const carousel = useCarousel({ loop: true });

  const [loading, setLoading] = useState(true);
  const [lieu, setLieu] = useState(null);

  useEffect(() => {
    const loadLieu = async () => {
      try {
        setLoading(true);
        const result = await getLieuById(id);
        if (!result) {
          toast.error('Lieu introuvable');
          router.back();
          return;
        }
        setLieu(mapLieu(result));
      } catch (error) {
        console.error('Erreur chargement détail lieu:', error);
        toast.error('Erreur lors du chargement du détail');
        router.back();
      } finally {
        setLoading(false);
      }
    };

    loadLieu();
  }, [id, router]);

  if (loading) {
    return <LoadingScreen />;
  }

  if (!lieu) {
    return null;
  }

  const averageRating = calculateAverageNote(lieu.avis);
  const images = lieu.galerieImages || [];

  return (
    <DashboardContent maxWidth="xl">
      <Stack spacing={3}>
        <Stack direction="row" alignItems="center" justifyContent="space-between">
          <Stack spacing={1}>
            <Typography variant="h4">Détails du lieu</Typography>
            <Typography variant="body2" sx={{ color: 'text.secondary' }}>
              Consultez les informations complètes de ce lieu.
            </Typography>
          </Stack>

          <Button
            variant="outlined"
            startIcon={<Iconify icon="eva:arrow-back-fill" />}
            onClick={router.back}
          >
            Retour
          </Button>
        </Stack>

        <Card sx={{ overflow: 'hidden' }}>
          <Grid container spacing={0}>
            {!!images.length && (
              <Grid size={{ xs: 12, md: 6 }}>
                <Box sx={{ position: 'relative', bgcolor: 'grey.900', height: '100%', minHeight: 400 }}>
                  <Carousel carousel={carousel} sx={{ height: '100%' }}>
                    {images.map((image, index) => (
                      <Box
                        key={image._id || index}
                        component="img"
                        src={image.imageUrl}
                        alt={`${lieu.nom} ${index + 1}`}
                        sx={{ width: '100%', height: { xs: 320, md: 560 }, objectFit: 'cover' }}
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
                </Box>
              </Grid>
            )}

            <Grid size={{ xs: 12, md: images.length ? 6 : 12 }}>
              <Stack spacing={3} sx={{ p: 3 }}>
                <Box>
                  <Stack direction="row" alignItems="center" spacing={1} sx={{ mb: 1 }}>
                    <Label
                      variant="soft"
                      color={categorieColor(lieu.categorie)}
                      startIcon={<Iconify icon={categorieIcon(lieu.categorie)} />}
                    >
                      {lieu.categorie}
                    </Label>
                    {lieu.prix === 0 && <Chip label="Gratuit" size="small" color="success" variant="outlined" />}
                  </Stack>

                  <Typography variant="h4" sx={{ mb: 1 }}>
                    {lieu.nom}
                  </Typography>

                  <Stack direction="row" alignItems="center" spacing={1}>
                    <Rating value={averageRating} precision={0.1} readOnly size="small" />
                    <Typography variant="body2" sx={{ color: 'text.secondary' }}>
                      {averageRating.toFixed(1)} ({lieu.avis?.length || 0} avis)
                    </Typography>
                  </Stack>
                </Box>

                <Divider />

                <Box>
                  <Typography variant="subtitle2" sx={{ mb: 1 }}>
                    Description
                  </Typography>
                  <Typography variant="body2" sx={{ color: 'text.secondary', lineHeight: 1.8 }}>
                    {lieu.description || 'Aucune description disponible'}
                  </Typography>
                </Box>

                <Grid container spacing={2}>
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
                        <Stack direction="row" spacing={1} flexWrap="wrap">
                          <Chip label={lieu.ville} size="small" icon={<Iconify icon="mdi:city" width={16} />} />
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
                </Grid>

                {(lieu.telephone || lieu.siteWeb) && (
                  <Box>
                    <Typography variant="subtitle2" sx={{ mb: 1 }}>
                      Contact
                    </Typography>
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
                          <Link href={lieu.siteWeb} target="_blank" rel="noopener" variant="body2" underline="hover">
                            Visiter le site web
                          </Link>
                        </Stack>
                      )}
                    </Stack>
                  </Box>
                )}

                {lieu.avis?.length > 0 && (
                  <Box>
                    <Typography variant="subtitle2" sx={{ mb: 2 }}>
                      Avis des visiteurs ({lieu.avis.length})
                    </Typography>
                    <Stack spacing={2}>
                      {lieu.avis.map((avis, index) => (
                        <Card key={avis._id || index} variant="outlined" sx={{ p: 2 }}>
                          <Stack direction="row" spacing={2}>
                            <Avatar sx={{ bgcolor: 'primary.main', width: 40, height: 40 }}>{index + 1}</Avatar>
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
                    </Stack>
                  </Box>
                )}
              </Stack>
            </Grid>
          </Grid>
        </Card>
      </Stack>
    </DashboardContent>
  );
}
