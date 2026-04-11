import { forwardRef } from 'react';
import ReactMap from 'react-map-gl';

import { styled } from '@mui/material/styles';

import { CONFIG } from 'src/global-config';

// ----------------------------------------------------------------------

export const Map = forwardRef((props, ref) => {
  const { sx, ...other } = props;

  return (
    <MapRoot sx={sx}>
      <ReactMap ref={ref} mapboxAccessToken={CONFIG.mapboxApiKey} {...other} />
    </MapRoot>
  );
});

// ----------------------------------------------------------------------

const MapRoot = styled('div')({
  width: '100%',
  overflow: 'hidden',
  position: 'relative',
});
