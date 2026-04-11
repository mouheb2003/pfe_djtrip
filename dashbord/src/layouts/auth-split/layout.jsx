import { AuthSplitContent } from './content';
import { AuthSplitSection } from './section';
import { MainSection } from '../core/main-section';
import { LayoutSection } from '../core/layout-section';

// ----------------------------------------------------------------------

export function AuthSplitLayout({ sx, cssVars, children, slotProps, layoutQuery = 'md' }) {
  const renderFooter = () => null;

  const renderMain = () => (
    <MainSection
      {...slotProps?.main}
      sx={[
        (theme) => ({
          [theme.breakpoints.up(layoutQuery)]: {
            flexDirection: 'row',
          },
        }),
        ...(Array.isArray(slotProps?.main?.sx) ? slotProps.main.sx : [slotProps?.main?.sx]),
      ]}
    >
      <AuthSplitContent layoutQuery={layoutQuery} {...slotProps?.content}>
        {children}
      </AuthSplitContent>
      <AuthSplitSection layoutQuery={layoutQuery} {...slotProps?.section} />
    </MainSection>
  );

  return (
    <LayoutSection
      /** **************************************
       * @Footer
       *************************************** */
      footerSection={renderFooter()}
      /** **************************************
       * @Styles
       *************************************** */
      cssVars={{ '--layout-auth-content-width': '480px', ...cssVars }}
      sx={sx}
    >
      {renderMain()}
    </LayoutSection>
  );
}
