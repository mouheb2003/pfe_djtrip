import { useEffect, useCallback, useState } from 'react';
import { hasKeys, varAlpha } from 'minimal-shared/utils';

import Box from '@mui/material/Box';
import Badge from '@mui/material/Badge';
import Drawer from '@mui/material/Drawer';
import Tooltip from '@mui/material/Tooltip';
import IconButton from '@mui/material/IconButton';
import Typography from '@mui/material/Typography';
import Button from '@mui/material/Button';
import Divider from '@mui/material/Divider';
import { useColorScheme } from '@mui/material/styles';
import { useRouter } from 'src/routes/hooks';

import { themeConfig } from 'src/theme/theme-config';
import { primaryColorPresets } from 'src/theme/with-settings';

import { Iconify } from '../../iconify';
import { BaseOption } from './base-option';
import { Scrollbar } from '../../scrollbar';
import { SmallBlock, LargeBlock } from './styles';
import { PresetsOptions } from './presets-options';
import { FullScreenButton } from './fullscreen-button';
import { FontSizeOptions, FontFamilyOptions } from './font-options';
import { useSettingsContext } from '../context/use-settings-context';
import { NavColorOptions, NavLayoutOptions } from './nav-layout-option';
import { OptionButton } from './styles';
import { BACKEND_MODES, getBackendMode, setBackendMode } from 'src/services/backend';
import { useAuthContext } from 'src/auth/hooks';

// ----------------------------------------------------------------------

export function SettingsDrawer({ sx, defaultSettings }) {
  const settings = useSettingsContext();
  const router = useRouter();
  const { logout } = useAuthContext();
  const [backendMode, setBackendModeState] = useState(getBackendMode());

  const { mode, setMode, systemMode } = useColorScheme();

  useEffect(() => {
    if (mode === 'system' && systemMode) {
      settings.setState({ colorScheme: systemMode });
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [mode, systemMode]);

  useEffect(() => {
    setBackendModeState(getBackendMode());
  }, [settings.openDrawer]);

  // Visible options by default settings
  const isFontFamilyVisible = hasKeys(defaultSettings, ['fontFamily']);
  const isCompactLayoutVisible = hasKeys(defaultSettings, ['compactLayout']);
  const isDirectionVisible = hasKeys(defaultSettings, ['direction']);
  const isColorSchemeVisible = hasKeys(defaultSettings, ['colorScheme']);
  const isContrastVisible = hasKeys(defaultSettings, ['contrast']);
  const isNavColorVisible = hasKeys(defaultSettings, ['navColor']);
  const isNavLayoutVisible = hasKeys(defaultSettings, ['navLayout']);
  const isPrimaryColorVisible = hasKeys(defaultSettings, ['primaryColor']);
  const isFontSizeVisible = hasKeys(defaultSettings, ['fontSize']);

  const handleReset = useCallback(() => {
    settings.onReset();
    setMode(defaultSettings.colorScheme);
  }, [defaultSettings.colorScheme, setMode, settings]);

  const handleChangePassword = useCallback(() => {
    settings.onCloseDrawer();
    router.push('/dashboard/change-password');
  }, [router, settings]);

  const handleLogout = useCallback(async () => {
    try {
      await logout();
      settings.onCloseDrawer();
      router.push('/auth/jwt/sign-in');
    } catch (error) {
      console.error('Logout error:', error);
    }
  }, [logout, settings, router]);

  const renderHead = () => (
    <Box
      sx={{
        py: 2,
        pr: 1,
        pl: 2.5,
        display: 'flex',
        alignItems: 'center',
      }}
    >
      <Typography variant="h6" sx={{ flexGrow: 1 }}>
        Settings
      </Typography>

      <FullScreenButton />

      <Tooltip title="Reset all">
        <IconButton onClick={handleReset}>
          <Badge color="error" variant="dot" invisible={!settings.canReset}>
            <Iconify icon="solar:restart-bold" />
          </Badge>
        </IconButton>
      </Tooltip>

      <Tooltip title="Close">
        <IconButton onClick={settings.onCloseDrawer}>
          <Iconify icon="mingcute:close-line" />
        </IconButton>
      </Tooltip>
    </Box>
  );

  const renderMode = () => (
    <BaseOption
      label="Dark mode"
      icon="moon"
      selected={settings.state.colorScheme === 'dark'}
      onChangeOption={() => {
        setMode(mode === 'light' ? 'dark' : 'light');
        settings.setState({ colorScheme: mode === 'light' ? 'dark' : 'light' });
      }}
    />
  );

  const renderContrast = () => (
    <BaseOption
      label="Contrast"
      icon="contrast"
      selected={settings.state.contrast === 'hight'}
      onChangeOption={() =>
        settings.setState({
          contrast: settings.state.contrast === 'default' ? 'hight' : 'default',
        })
      }
    />
  );

  const renderRtl = () => (
    <BaseOption
      label="Right to left"
      icon="align-right"
      selected={settings.state.direction === 'rtl'}
      onChangeOption={() =>
        settings.setState({
          direction: settings.state.direction === 'ltr' ? 'rtl' : 'ltr',
        })
      }
    />
  );

  const renderCompact = () => (
    <BaseOption
      tooltip="Dashboard only and available at large resolutions > 1600px (xl)"
      label="Compact"
      icon="autofit-width"
      selected={!!settings.state.compactLayout}
      onChangeOption={() => settings.setState({ compactLayout: !settings.state.compactLayout })}
    />
  );

  const renderPresets = () => (
    <LargeBlock
      title="Presets"
      canReset={settings.state.primaryColor !== defaultSettings.primaryColor}
      onReset={() => settings.setState({ primaryColor: defaultSettings.primaryColor })}
    >
      <PresetsOptions
        options={Object.keys(primaryColorPresets).map((key) => ({
          name: key,
          value: primaryColorPresets[key].main,
        }))}
        value={settings.state.primaryColor}
        onChangeOption={(newOption) => settings.setState({ primaryColor: newOption })}
      />
    </LargeBlock>
  );

  const renderNav = () => (
    <LargeBlock title="Nav" tooltip="Dashboard only" sx={{ gap: 2.5 }}>
      {isNavColorVisible && (
        <SmallBlock
          label="Color"
          canReset={settings.state.navColor !== defaultSettings.navColor}
          onReset={() => settings.setState({ navColor: defaultSettings.navColor })}
        >
          <NavColorOptions
            options={['integrate', 'apparent']}
            value={settings.state.navColor}
            onChangeOption={(newOption) => settings.setState({ navColor: newOption })}
          />
        </SmallBlock>
      )}
    </LargeBlock>
  );

  const renderBackend = () => (
    <LargeBlock title="Backend" tooltip="Switch between local and hosted API">
      <Box
        sx={{
          gap: 1.25,
          mt: 1.5,
          display: 'grid',
          gridTemplateColumns: 'repeat(2, 1fr)',
        }}
      >
        {BACKEND_MODES.map((option) => (
          <OptionButton
            key={option.value}
            selected={backendMode === option.value}
            onClick={() => {
              const nextMode = setBackendMode(option.value);
              setBackendModeState(nextMode);
            }}
            sx={{ p: 0 }}
          >
            <Box
              sx={{
                width: 1,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'flex-start',
                gap: 0.25,
                p: 1.5,
              }}
            >
              <Typography variant="subtitle2">{option.label}</Typography>
              <Typography variant="caption" sx={{ color: 'text.secondary' }}>
                {option.description}
              </Typography>
            </Box>
          </OptionButton>
        ))}
      </Box>
    </LargeBlock>
  );

  const renderFont = () => (
    <LargeBlock title="Font" sx={{ gap: 2.5 }}>
      {isFontFamilyVisible && (
        <SmallBlock
          label="Family"
          canReset={settings.state.fontFamily !== defaultSettings.fontFamily}
          onReset={() => settings.setState({ fontFamily: defaultSettings.fontFamily })}
        >
          <FontFamilyOptions
            options={[
              themeConfig.fontFamily.primary,
              'Inter Variable',
              'DM Sans Variable',
              'Nunito Sans Variable',
            ]}
            value={settings.state.fontFamily}
            onChangeOption={(newOption) => settings.setState({ fontFamily: newOption })}
          />
        </SmallBlock>
      )}
      {isFontSizeVisible && (
        <SmallBlock
          label="Size"
          canReset={settings.state.fontSize !== defaultSettings.fontSize}
          onReset={() => settings.setState({ fontSize: defaultSettings.fontSize })}
          sx={{ gap: 5 }}
        >
          <FontSizeOptions
            options={[12, 20]}
            value={settings.state.fontSize}
            onChangeOption={(newOption) => settings.setState({ fontSize: newOption })}
          />
        </SmallBlock>
      )}
    </LargeBlock>
  );

  const renderAccountActions = () => (
    <LargeBlock title="Account" sx={{ gap: 1.5 }}>
      <Button
        fullWidth
        variant="outlined"
        startIcon={<Iconify icon="solar:lock-password-bold" />}
        onClick={handleChangePassword}
      >
        Change Password
      </Button>
      <Button
        fullWidth
        variant="outlined"
        color="error"
        startIcon={<Iconify icon="solar:logout-2-bold" />}
        onClick={handleLogout}
      >
        Sign Out
      </Button>
    </LargeBlock>
  );

  return (
    <Drawer
      anchor="right"
      open={settings.openDrawer}
      onClose={settings.onCloseDrawer}
      slotProps={{ backdrop: { invisible: true } }}
      PaperProps={{
        sx: [
          (theme) => ({
            ...theme.mixins.paperStyles(theme, {
              color: varAlpha(theme.vars.palette.background.defaultChannel, 0.9),
            }),
            width: 360,
          }),
          ...(Array.isArray(sx) ? sx : [sx]),
        ],
      }}
    >
      {renderHead()}

      <Scrollbar>
        <Box
          sx={{
            pb: 5,
            gap: 6,
            px: 2.5,
            display: 'flex',
            flexDirection: 'column',
          }}
        >
          <Box
            sx={{
              gap: 2,
              display: 'grid',
              gridTemplateColumns: 'repeat(2, 1fr)',
            }}
          >
            {isColorSchemeVisible && renderMode()}
            {isContrastVisible && renderContrast()}
            {isDirectionVisible && renderRtl()}
            {isCompactLayoutVisible && renderCompact()}
          </Box>

          {isNavColorVisible && renderNav()}
          {isPrimaryColorVisible && renderPresets()}
          {(isFontFamilyVisible || isFontSizeVisible) && renderFont()}
          {renderAccountActions()}
        </Box>
      </Scrollbar>
    </Drawer>
  );
}
