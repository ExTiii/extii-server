// Number, distance and time helpers for the city apps (Western digits on purpose)

export const isArabic = (lang?: string) => !lang || lang.startsWith('ar');

export const money = (value?: number) =>
  `$${Math.floor(Number(value) || 0).toLocaleString('en-US')}`;

export const distance = (meters: number, lang?: string) => {
  const ar = isArabic(lang);
  if (meters < 1000) return `${Math.max(0, Math.round(meters))} ${ar ? 'م' : 'm'}`;
  const km = meters / 1000;
  return `${km < 10 ? km.toFixed(1) : Math.round(km)} ${ar ? 'كم' : 'km'}`;
};

// Correct Arabic wording for a number of seconds
export const seconds = (n: number, lang?: string) => {
  const s = Math.max(1, Math.ceil(Number(n) || 0));
  if (!isArabic(lang)) return s === 1 ? '1 second' : `${s} seconds`;
  if (s === 1) return 'ثانية واحدة';
  if (s === 2) return 'ثانيتين';
  if (s <= 10) return `${s} ثوانٍ`;
  return `${s} ثانية`;
};

// Only keep digits while typing a phone number or an amount
export const onlyDigits = (value: string, max = 15) => value.replace(/\D/g, '').slice(0, max);
