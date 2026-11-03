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

/* ---------- crew (exti_heists) ---------- */
export interface CrewHeist {
  id: string;
  label: string;
  tier: number;
  where?: string;
  need: number;
  state: 'ready' | 'cooldown' | 'cops' | 'rep' | 'night' | 'busy' | 'prep' | 'window' | 'soon' | string;
  left: number;
  note?: string;
  police?: boolean;
  copsNeed?: number;
  copsNow?: number;
}
export interface CrewMember {
  cid: string;
  name: string;
  online: boolean;
  leader: boolean;
  me: boolean;
}
export interface CrewBoardRow {
  k: string;
  name: string;
  points: number;
}
export interface CrewData {
  known: boolean;
  me: {
    name: string;
    level: number;
    xp: number;
    cur?: number;
    nextXp?: number;
    maxLevel: number;
    skills: { id: string; label: string; level: number }[];
    heat: number;
    titles: string[];
    fence?: string;
  };
  crew?: { id: number; name: string; leader: boolean; members: CrewMember[]; max: number };
  invites: { id: number; name: string; from: string }[];
  heists: CrewHeist[];
  board: { month: string; crews: CrewBoardRow[]; robbers: CrewBoardRow[]; cops: CrewBoardRow[] };
  cops: number;
}

export const MOCK_CREW = (): CrewData => ({
  known: true,
  me: {
    name: 'Omar Haddad',
    level: 4,
    xp: 380,
    cur: 300,
    nextXp: 500,
    maxLevel: 10,
    skills: [
      { id: 'lockpick', label: 'فتح الأقفال', level: 3 },
      { id: 'hacking', label: 'الاختراق', level: 2 },
      { id: 'breaching', label: 'الكسر', level: 1 },
    ],
    heat: 640,
    titles: ['ثاني أخطر طاقم · الذئاب 2026-10'],
    fence: '555-0187',
  },
  crew: {
    id: 3,
    name: 'الذئاب',
    leader: true,
    max: 6,
    members: [
      { cid: 'A1', name: 'Omar Haddad', online: true, leader: true, me: true },
      { cid: 'B2', name: 'Sara Nasser', online: true, leader: false, me: false },
      { cid: 'C3', name: 'Khaled Saeed', online: false, leader: false, me: false },
    ],
  },
  invites: [],
  cops: 3,
  heists: [
    { id: 'register', label: 'صندوق محل', tier: 1, where: '20 محلًا', need: 1, state: 'ready', left: 0, note: 'كل محل كل 20 دقيقة', police: true },
    { id: 'house', label: 'سطو على منزل', tier: 1, where: 'عنوان من المصرّف', need: 1, state: 'night', left: 0, note: 'بالليل فقط (10 مساءً - 5 صباحًا)' },
    { id: 'atm', label: 'جهاز صراف', tier: 2, where: 'بشاحنة وسلسلة', need: 2, state: 'cooldown', left: 1460, note: 'الشرطة متيقّظة هذه الساعة' },
    { id: 'jewelry', label: 'مجوهرات فانجيليكو', tier: 3, where: 'روكفورد هيلز', need: 3, state: 'ready', left: 0, note: 'فلاشة خضراء للطريق الهادئ', police: true },
    { id: 'fleeca', label: 'بنك فليكا', tier: 4, where: '6 فروع · الفرع الساخن اليوم: الطريق 68', need: 4, state: 'cops', left: 0, copsNeed: 3, copsNow: 2 },
    { id: 'pacific', label: 'باسيفيك ستاندرد', tier: 8, where: 'وسط المدينة', need: 8, state: 'rep', left: 0 },
  ],
  board: {
    month: '2026-11',
    crews: [
      { k: '3', name: 'الذئاب', points: 940 },
      { k: '7', name: 'Ballas OG', points: 610 },
    ],
    robbers: [
      { k: 'A1', name: 'Omar Haddad', points: 420 },
      { k: 'B2', name: 'Sara Nasser', points: 300 },
    ],
    cops: [{ k: 'P1', name: 'Adam Harbi', points: 120 }],
  },
});
