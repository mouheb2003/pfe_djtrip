
// ----------------------------------------------------------------------

export function formatNumberLocale() {
  const lng = "fr";

  const currentLang = allLangs.find((lang) => lang.value === lng);

  return {
    code: currentLang?.numberFormat.code,
    currency: currentLang?.numberFormat.currency,
  };
}
