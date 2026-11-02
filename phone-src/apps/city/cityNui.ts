// Talks to the "npwd_city" game resource (Bank, Places, 911 apps).
// In the browser preview it answers with sample data instead.
import { isEnvBrowser } from '@utils/misc';

const CITY_RESOURCE = 'npwd_city';

export async function fetchCity<T = any>(
  event: string,
  data?: unknown,
  mock?: T | ((data: any) => T),
): Promise<T> {
  if (isEnvBrowser()) {
    await new Promise((resolve) => setTimeout(resolve, 250));
    return (typeof mock === 'function' ? (mock as any)(data) : mock) as T;
  }

  const resp = await fetch(`https://${CITY_RESOURCE}/${event}`, {
    method: 'post',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data ?? {}),
  });
  return resp.json();
}

/* ---------- shared types ---------- */

export interface BankTransaction {
  id: string;
  title: string;
  amount: number;
  type: 'deposit' | 'withdraw' | string;
  note?: string;
  from?: string;
  to?: string;
  time: number;
}

export interface BankBill {
  id: number;
  title: string;
  amount: number;
  note?: string;
  issuer?: string;
  society?: string;
  societyLabel?: string;
  created?: number;
}

export interface BankData {
  name?: string;
  phone?: string;
  balance?: number;
  cash?: number;
  history?: BankTransaction[];
  bills?: BankBill[];
}

export interface BillPayResult {
  ok: boolean;
  error?: 'no_bank' | 'no_bill' | 'cooldown' | 'generic';
  wait?: number;
  balance?: number;
  amount?: number;
}

export interface TransferResult {
  ok: boolean;
  error?: 'amount' | 'number' | 'not_found' | 'self' | 'balance' | 'cooldown' | 'generic';
  wait?: number;
  min?: number;
  max?: number;
  amount?: number;
  name?: string;
  balance?: number;
}

export interface PlaceCategory {
  id: string;
  label: string;
}

export interface Place {
  id: number;
  cat: string;
  icon: string;
  label: string;
  dist: number;
}

export interface PlacesData {
  categories: PlaceCategory[];
  places: Place[];
}

export interface ServiceInfo {
  id: string;
  label: string;
}

export interface ServiceAlert {
  id: string;
  service: string;
  label: string;
  number: string;
  message: string;
  zone?: string;
  time: number;
}

export interface ServicesData {
  services: ServiceInfo[];
  alerts: ServiceAlert[];
  cooldown: number;
  maxLength: number;
}

export interface ServiceResult {
  ok: boolean;
  error?: 'cooldown' | 'generic';
  wait?: number;
  count?: number;
  hidden?: boolean;
}

/* ---------- sample data for the browser preview ---------- */

const now = () => Math.floor(Date.now() / 1000);

export const MOCK_BANK = (): BankData => ({
  name: 'Omar Haddad',
  phone: '5551234',
  balance: 12500,
  cash: 350,
  history: [
    { id: 'a1', title: 'تحويل عبر الهاتف', amount: 500, type: 'deposit', note: 'ثمن السيارة', from: 'Sara Nasser', to: 'Omar Haddad', time: now() - 320 },
    { id: 'a2', title: 'تحويل عبر الهاتف', amount: 1200, type: 'withdraw', note: 'إيجار الشقة', from: 'Omar Haddad', to: 'Khaled Saeed', time: now() - 5400 },
    { id: 'a3', title: 'الحساب الشخصي / 5551234', amount: 2000, type: 'deposit', note: 'Omar Haddad أودع $2000', from: 'Omar Haddad', to: 'Omar Haddad', time: now() - 86000 },
    { id: 'a4', title: 'الحساب الشخصي / 5551234', amount: 150, type: 'withdraw', note: '', from: 'Omar Haddad', to: 'Omar Haddad', time: now() - 190000 },
  ],
  bills: [
    { id: 12, title: 'مخالفة: تجاوز السرعة، قطع إشارة حمراء', amount: 550, note: 'شارع فينوود', issuer: 'آدم الحربي', society: 'police', societyLabel: 'شرطة لوس سانتوس', created: now() - 900 },
    { id: 11, title: 'فاتورة الورشة: فحص المركبة، تغيير زيت المحرك', amount: 350, note: 'سلطان ABC 123', issuer: 'مصطفى', society: 'mechanic', societyLabel: 'ورشة الميكانيكي', created: now() - 7200 },
  ],
});

export const MOCK_PAY = (data: any): BillPayResult => {
  if (Number(data?.id) === 12) return { ok: true, amount: 550, balance: 11950 };
  return { ok: false, error: 'no_bank' };
};

export const MOCK_TRANSFER = (data: any): TransferResult => {
  const amount = Number(data?.amount);
  if (String(data?.number ?? '').replace(/\D/g, '') === '5551234') return { ok: false, error: 'self' };
  if (amount > 12500) return { ok: false, error: 'balance' };
  return { ok: true, amount, name: 'Sara Nasser', balance: 12500 - amount };
};

export const MOCK_PLACES = (): PlacesData => ({
  categories: [
    { id: 'gov', label: 'الخدمات العامة' },
    { id: 'banks', label: 'البنوك' },
    { id: 'jobs', label: 'الوظائف' },
    { id: 'vehicles', label: 'المركبات' },
    { id: 'shops', label: 'المتاجر' },
    { id: 'style', label: 'المظهر' },
  ],
  places: [
    { id: 1, cat: 'gov', icon: 'cityhall', label: 'البلدية (City Hall)', dist: 420 },
    { id: 7, cat: 'banks', icon: 'bank', label: 'بنك فليكا (Legion Square)', dist: 610 },
    { id: 4, cat: 'gov', icon: 'police', label: 'شرطة ميشن رو (Mission Row)', dist: 880 },
    { id: 60, cat: 'shops', icon: 'store', label: 'بقالة (Strawberry)', dist: 1250 },
    { id: 2, cat: 'gov', icon: 'hospital', label: 'مستشفى بيلبوكس (Pillbox)', dist: 1430 },
    { id: 30, cat: 'vehicles', icon: 'dealer', label: 'معرض السيارات (PDM)', dist: 1710 },
    { id: 34, cat: 'vehicles', icon: 'garage', label: 'موقف بيلبوكس (Pillbox)', dist: 1820 },
    { id: 90, cat: 'style', icon: 'clothing', label: 'محل ملابس (Textile City)', dist: 1990 },
    { id: 14, cat: 'jobs', icon: 'job', label: 'محطة الحافلات (Bus Depot)', dist: 2240 },
    { id: 33, cat: 'vehicles', icon: 'customs', label: 'ورشة بيني (Benny\'s)', dist: 2650 },
    { id: 91, cat: 'style', icon: 'barber', label: 'حلاق (Davis)', dist: 3100 },
    { id: 80, cat: 'shops', icon: 'weapons', label: 'متجر الأسلحة (Pillbox Hill)', dist: 3350 },
    { id: 12, cat: 'jobs', icon: 'job', label: 'مستودع النفايات (Garbage)', dist: 3900 },
    { id: 31, cat: 'vehicles', icon: 'impound', label: 'ساحة الحجز (Impound)', dist: 4100 },
    { id: 95, cat: 'style', icon: 'tattoo', label: 'محل وشم (Vespucci)', dist: 5200 },
  ],
});

export const MOCK_SERVICES = (): ServicesData => ({
  services: [
    { id: 'police', label: 'الشرطة' },
    { id: 'ems', label: 'الإسعاف' },
    { id: 'mechanic', label: 'الميكانيكي' },
    { id: 'taxi', label: 'التاكسي' },
  ],
  alerts: [
    { id: 'x1', service: 'ems', label: 'الإسعاف', number: '5559876', message: 'حادث سير عند الإشارة، شخص مصاب', zone: 'Strawberry', time: now() - 75 },
    { id: 'x2', service: 'mechanic', label: 'الميكانيكي', number: '5554411', message: 'سيارتي تعطلت على الطريق السريع', zone: 'Davis', time: now() - 900 },
  ],
  cooldown: 60,
  maxLength: 120,
});

export const MOCK_SERVICE_SEND = (data: any): ServiceResult =>
  data?.service === 'police' ? { ok: true, hidden: true } : { ok: true, count: data?.service === 'taxi' ? 0 : 2 };

/* ---------- level (exti_level) ---------- */
export interface LevelUnlock {
  level: number;
  label: string;
}

export interface LevelData {
  level: number;
  cur: number;
  need: number;
  pct: number;
  max?: boolean;
  xp?: number;
  maxLevel?: number;
  hourLeft?: number;
  unlocks?: LevelUnlock[];
}

export const MOCK_LEVEL = (): LevelData => ({
  level: 12,
  cur: 1240,
  need: 2060,
  pct: 60.2,
  xp: 9240,
  maxLevel: 300,
  hourLeft: 900,
  unlocks: [
    { level: 3, label: 'صياد سمك (قريبًا)' },
    { level: 8, label: 'بائع نقانق (قريبًا)' },
    { level: 15, label: 'منظف نوافذ (قريبًا)' },
    { level: 22, label: 'عامل بيتزا (قريبًا)' },
    { level: 30, label: 'مزارع (قريبًا)' },
    { level: 40, label: 'سائق حافلة (قريبًا)' },
  ],
});
