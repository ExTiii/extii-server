import React, { useCallback, useEffect, useMemo, useState } from 'react';
import { useTranslation } from 'react-i18next';
import {
  Crown,
  Flame,
  KeyRound,
  Lock,
  MapPin,
  Moon,
  RefreshCw,
  Shield,
  Siren,
  Timer,
  Trophy,
  UserMinus,
  UserPlus,
  Users,
} from 'lucide-react';
import { AppWrapper } from '@ui/components';
import { cn } from '@utils/css';
import { CityToast } from '../CityUI';
import { CrewData, CrewHeist, fetchCity, MOCK_CREW } from '../cityNui';

// The Crew app (exti_heists): your criminal Rep and skills, your crew, the heist board
// (what can run right now), and the monthly boards. Dark on purpose: it's the city's underside.

const num = (n?: number) => Math.round(n ?? 0).toLocaleString('en-US');
const mmss = (s: number) => {
  s = Math.max(0, Math.floor(s));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const sec = s % 60;
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${String(sec).padStart(2, '0')}` : `${m}:${String(sec).padStart(2, '0')}`;
};

type Tab = 'me' | 'crew' | 'jobs' | 'board';

const ERR: Record<string, string> = {
  name: 'الاسم من 3 إلى 24 حرفًا',
  taken: 'هذا الاسم مأخوذ',
  in_crew: 'أنت في طاقم بالفعل',
  not_leader: 'هذا للقائد فقط',
  full: 'الطاقم ممتلئ',
  not_found: 'لا أحد بهذا الرقم في المدينة الآن',
  self: 'هذا رقمك',
  has_crew: 'عنده طاقم بالفعل',
  gone: 'انتهت الدعوة',
  cop: 'ليس وأنت في الخدمة',
  slow: 'على مهلك',
};

const STATE: Record<string, { label: string; tone: string; icon: React.ReactNode }> = {
  ready: { label: 'جاهز', tone: 'text-[#3ddc97] bg-[#3ddc97]/12', icon: <KeyRound className="h-3.5 w-3.5" /> },
  cooldown: { label: 'انتظار', tone: 'text-[#e8b547] bg-[#e8b547]/12', icon: <Timer className="h-3.5 w-3.5" /> },
  cops: { label: 'شرطة غير كافية', tone: 'text-[#8ab8ff] bg-[#3d8bfd]/14', icon: <Siren className="h-3.5 w-3.5" /> },
  rep: { label: 'سمعتك لا تكفي', tone: 'text-neutral-400 bg-white/6', icon: <Lock className="h-3.5 w-3.5" /> },
  night: { label: 'بالليل فقط', tone: 'text-[#b9a6ff] bg-[#8b6cff]/14', icon: <Moon className="h-3.5 w-3.5" /> },
  busy: { label: 'يُسرق الآن', tone: 'text-[#ff6b6f] bg-[#e5484d]/14', icon: <Flame className="h-3.5 w-3.5" /> },
  prep: { label: 'يحتاج تحضيرًا', tone: 'text-[#e8b547] bg-[#e8b547]/12', icon: <Lock className="h-3.5 w-3.5" /> },
  window: { label: 'خارج الموعد', tone: 'text-[#b9a6ff] bg-[#8b6cff]/14', icon: <Moon className="h-3.5 w-3.5" /> },
  soon: { label: 'قريبًا', tone: 'text-neutral-500 bg-white/5', icon: <Lock className="h-3.5 w-3.5" /> },
};

const Card: React.FC<{ className?: string; children: React.ReactNode }> = ({ className, children }) => (
  <div className={cn('rounded-2xl border border-white/[0.06] bg-[#16171b]', className)}>{children}</div>
);
const Label: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <p className="mb-2 mt-5 px-1 text-[12px] font-semibold tracking-wide text-[#8d8a82]">{children}</p>
);

export const CrewApp: React.FC = () => {
  const { t } = useTranslation();
  const [data, setData] = useState<CrewData | null>(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<Tab>('jobs');
  const [toast, setToast] = useState<{ text: string; tone: 'ok' | 'error' } | null>(null);
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [tick, setTick] = useState(0);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const resp = await fetchCity<CrewData>('crew:get', {}, MOCK_CREW);
      setData(resp ?? null);
    } catch {
      setToast({ text: t('CITY.ERROR_GENERIC'), tone: 'error' });
    } finally {
      setLoading(false);
    }
  }, [t]);

  useEffect(() => {
    load();
  }, [load]);
  // the timers count down on their own
  useEffect(() => {
    const id = setInterval(() => setTick((x) => x + 1), 1000);
    return () => clearInterval(id);
  }, []);
  useEffect(() => setTick(0), [data]);

  const act = async (action: string, body: any, okText?: string) => {
    const res = await fetchCity<any>(`crew:${action}`, body, (d: any) => ({ ok: true, data: MOCK_CREW(), name: 'Sara Nasser', ...d }));
    if (res?.ok) {
      if (res.data) setData(res.data);
      if (okText) setToast({ text: okText.replace('{name}', res.name ?? ''), tone: 'ok' });
      return true;
    }
    setToast({ text: ERR[res?.error] ?? t('CITY.ERROR_GENERIC'), tone: 'error' });
    return false;
  };

  const me = data?.me;
  const pct = useMemo(() => {
    if (!me || !me.nextXp) return 100;
    const cur = me.cur ?? 0;
    return Math.max(0, Math.min(100, ((me.xp - cur) / Math.max(1, me.nextXp - cur)) * 100));
  }, [me]);
  const heists: CrewHeist[] = Array.isArray(data?.heists) ? data!.heists : (Object.values(data?.heists ?? {}) as CrewHeist[]);
  const arr = <T,>(v: any): T[] => (Array.isArray(v) ? v : Object.values(v ?? {})) as T[];

  return (
    <AppWrapper>
      <div className="relative flex flex-1 flex-col overflow-hidden bg-[#0d0e11] text-[#f1efe9]" dir="rtl">
        {/* header */}
        <div className="flex items-end justify-between px-4 pb-3 pt-5">
          <div>
            <p className="text-[12px] font-semibold tracking-[0.18em] text-[#e8b547]">EX_TII · UNDERGROUND</p>
            <h3 className="text-[28px] font-bold leading-tight">{String(t('APPS_CREW'))}</h3>
          </div>
          <button
            onClick={load}
            aria-label={String(t('CITY.REFRESH'))}
            className="mb-1 flex h-9 w-9 items-center justify-center rounded-full bg-white/[0.06] text-[#e8b547] active:scale-95"
          >
            <RefreshCw className={cn('h-[18px] w-[18px]', loading && 'animate-spin')} />
          </button>
        </div>
        {/* tabs */}
        <div className="mx-4 grid grid-cols-4 gap-1 rounded-xl bg-white/[0.05] p-1 text-[13px] font-semibold">
          {(
            [
              ['jobs', 'السرقات'],
              ['crew', 'الطاقم'],
              ['me', 'أنا'],
              ['board', 'الترتيب'],
            ] as [Tab, string][]
          ).map(([id, label]) => (
            <button
              key={id}
              onClick={() => setTab(id)}
              className={cn('rounded-lg py-2 transition-colors', tab === id ? 'bg-[#e8b547] text-[#1b1406]' : 'text-[#a3a09a]')}
            >
              {label}
            </button>
          ))}
        </div>

        <div className="flex-1 overflow-y-auto px-4 pb-8">
          {!data && <p className="py-12 text-center text-[14px] text-neutral-500">{String(loading ? t('CITY.LOADING') : t('CITY.ERROR_GENERIC'))}</p>}

          {data && !data.known && (
            <Card className="mt-6 p-5 text-center">
              <Users className="mx-auto h-9 w-9 text-[#e8b547]" />
              <p className="mt-3 text-[16px] font-bold">لا أحد يعرفك هنا بعد</p>
              <p className="mt-1.5 text-[13px] leading-relaxed text-[#a3a09a]">
                ابدأ صغيرًا: صندوق محل، أو اعثر على المصرّف في المدينة وخذ رقمه. حين يسمع باسمك تُفتح لك هذه الصفحة.
              </p>
            </Card>
          )}

          {/* ------------------------------------------------ the heist board */}
          {data && data.known && tab === 'jobs' && (
            <>
              <div className="mt-4 flex items-center gap-2 rounded-xl bg-white/[0.04] px-3 py-2.5 text-[13px] text-[#cfccc5]">
                <Shield className="h-4 w-4 text-[#8ab8ff]" />
                <span>شرطة في الخدمة الآن:</span>
                <b className="text-[#f1efe9]" dir="ltr">{data.cops}</b>
                {me && me.heat > 0 && (
                  <span className="mr-auto flex items-center gap-1 text-[#ff8b8e]">
                    <Flame className="h-4 w-4" />
                    <span dir="ltr">{mmss(me.heat - tick)}</span>
                  </span>
                )}
              </div>
              <Label>السرقات (السمعة المطلوبة · الحالة)</Label>
              <div className="flex flex-col gap-2">
                {heists.map((h) => {
                  const s = STATE[h.state] ?? STATE.soon;
                  const left = Math.max(0, h.left - tick);
                  return (
                    <Card key={h.id} className={cn('p-3.5', h.state === 'soon' && 'opacity-55')}>
                      <div className="flex items-center gap-3">
                        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-[#2a2416] to-[#17140c] text-[15px] font-bold text-[#e8b547]">
                          {h.tier}
                        </div>
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-[15px] font-semibold">{h.label}</p>
                          <p className="truncate text-[12px] text-[#8d8a82]">
                            {h.where} · سمعة {h.need}
                          </p>
                        </div>
                        <span className={cn('flex shrink-0 items-center gap-1 rounded-full px-2.5 py-1 text-[11.5px] font-semibold', s.tone)}>
                          {s.icon}
                          {h.state === 'cooldown' && left > 0 ? <span dir="ltr">{mmss(left)}</span> : s.label}
                        </span>
                      </div>
                      {(h.note || h.state === 'cops') && (
                        <p className="mt-2 border-t border-white/[0.05] pt-2 text-[12px] text-[#a3a09a]">
                          {h.state === 'cops' ? `تحتاج ${h.copsNeed} شرطة في الخدمة (الآن ${h.copsNow})` : h.note}
                          {h.state === 'ready' && !h.police && h.tier <= 6 ? ' · بلا شرطة: حراسة الحي، 60% من المال' : ''}
                        </p>
                      )}
                    </Card>
                  );
                })}
              </div>
              {me?.fence && (
                <button
                  onClick={() => act('fence', {}, 'وضعنا مكانه على خريطتك')}
                  className="mt-4 flex w-full items-center justify-center gap-2 rounded-2xl border border-[#e8b547]/30 py-3 text-[14px] font-semibold text-[#e8b547] active:scale-[0.98]"
                >
                  <MapPin className="h-4 w-4" /> أين المصرّف اليوم؟ ({me.fence})
                </button>
              )}
            </>
          )}

          {/* ------------------------------------------------ my crew */}
          {data && data.known && tab === 'crew' && (
            <>
              {arr<any>(data.invites).length > 0 && (
                <>
                  <Label>دعوات</Label>
                  {arr<any>(data.invites).map((i) => (
                    <Card key={i.id} className="mb-2 flex items-center gap-3 p-3.5">
                      <UserPlus className="h-5 w-5 text-[#e8b547]" />
                      <div className="min-w-0 flex-1">
                        <p className="truncate text-[15px] font-semibold">{i.name}</p>
                        <p className="text-[12px] text-[#8d8a82]">من {i.from}</p>
                      </div>
                      <button onClick={() => act('accept', { id: i.id }, 'انضممت إلى الطاقم')} className="rounded-xl bg-[#e8b547] px-3 py-1.5 text-[13px] font-bold text-[#1b1406]">
                        قبول
                      </button>
                      <button onClick={() => act('decline', { id: i.id })} className="rounded-xl bg-white/[0.06] px-3 py-1.5 text-[13px] text-[#cfccc5]">
                        رفض
                      </button>
                    </Card>
                  ))}
                </>
              )}
              {!data.crew && (
                <Card className="mt-4 p-4">
                  <p className="text-[16px] font-bold">كوّن طاقمك</p>
                  <p className="mt-1 text-[13px] text-[#a3a09a]">حتى 6 أشخاص. السمعة التي تجمعونها معًا تضعكم على لوحة الشهر.</p>
                  <input
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    maxLength={24}
                    placeholder="اسم الطاقم"
                    className="mt-3 w-full rounded-xl border border-white/[0.08] bg-black/30 px-3 py-2.5 text-[15px] text-[#f1efe9] outline-none placeholder:text-[#6d6a64] focus:border-[#e8b547]/60"
                  />
                  <button
                    onClick={async () => {
                      if (await act('create', { name }, 'تم: طاقمك جاهز')) setName('');
                    }}
                    className="mt-3 w-full rounded-xl bg-[#e8b547] py-3 text-[15px] font-bold text-[#1b1406] active:scale-[0.98]"
                  >
                    أنشئ الطاقم
                  </button>
                </Card>
              )}
              {data.crew && (
                <>
                  <div className="mt-4 flex items-center gap-3">
                    <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-[#e8b547] text-[#1b1406]">
                      <Users className="h-6 w-6" />
                    </div>
                    <div>
                      <p className="text-[20px] font-bold">{data.crew.name}</p>
                      <p className="text-[12px] text-[#8d8a82]">
                        {arr<any>(data.crew.members).length} من {data.crew.max}
                      </p>
                    </div>
                  </div>
                  <Label>الأعضاء</Label>
                  <Card>
                    {arr<any>(data.crew.members).map((m, i) => (
                      <div key={m.cid} className={cn('flex items-center gap-3 px-3.5 py-3', i > 0 && 'border-t border-white/[0.05]')}>
                        <span className={cn('h-2.5 w-2.5 rounded-full', m.online ? 'bg-[#3ddc97]' : 'bg-neutral-600')} />
                        <p className="min-w-0 flex-1 truncate text-[15px]">
                          {m.name} {m.me && <span className="text-[12px] text-[#8d8a82]">(أنت)</span>}
                        </p>
                        {m.leader && <Crown className="h-4 w-4 text-[#e8b547]" />}
                        {data.crew!.leader && !m.me && (
                          <>
                            <button aria-label="lead" onClick={() => act('lead', { cid: m.cid }, 'سلّمته القيادة')} className="rounded-lg bg-white/[0.06] p-1.5 text-[#e8b547]">
                              <Crown className="h-4 w-4" />
                            </button>
                            <button aria-label="kick" onClick={() => act('kick', { cid: m.cid }, 'أخرجته من الطاقم')} className="rounded-lg bg-white/[0.06] p-1.5 text-[#ff8b8e]">
                              <UserMinus className="h-4 w-4" />
                            </button>
                          </>
                        )}
                      </div>
                    ))}
                  </Card>
                  {data.crew.leader && (
                    <>
                      <Label>ادعُ شخصًا (برقم هاتفه)</Label>
                      <div className="flex gap-2">
                        <input
                          value={phone}
                          onChange={(e) => setPhone(e.target.value.replace(/[^\d-]/g, ''))}
                          inputMode="numeric"
                          placeholder="555-1234"
                          dir="ltr"
                          className="min-w-0 flex-1 rounded-xl border border-white/[0.08] bg-black/30 px-3 py-2.5 text-[15px] text-[#f1efe9] outline-none placeholder:text-[#6d6a64] focus:border-[#e8b547]/60"
                        />
                        <button
                          onClick={async () => {
                            if (await act('invite', { phone }, 'أرسلت الدعوة إلى {name}')) setPhone('');
                          }}
                          className="rounded-xl bg-[#e8b547] px-4 text-[14px] font-bold text-[#1b1406]"
                        >
                          ادعُ
                        </button>
                      </div>
                    </>
                  )}
                  <button
                    onClick={() => act('leave', {}, 'تركت الطاقم')}
                    className="mt-6 w-full rounded-xl border border-[#e5484d]/30 py-3 text-[14px] font-semibold text-[#ff8b8e]"
                  >
                    اترك الطاقم
                  </button>
                </>
              )}
            </>
          )}

          {/* ------------------------------------------------ me */}
          {data && data.known && tab === 'me' && me && (
            <>
              <div className="mt-4 overflow-hidden rounded-3xl bg-gradient-to-br from-[#2a2416] via-[#17181c] to-[#0f1013] p-5 shadow-lg">
                <div className="flex items-center gap-4">
                  <div className="flex h-[70px] w-[70px] shrink-0 items-center justify-center rounded-[20px] bg-gradient-to-br from-[#ffd36a] to-[#b98612] text-[30px] font-bold text-[#2a1c00]">
                    {me.level}
                  </div>
                  <div className="min-w-0">
                    <p className="text-[12px] text-[#e8b547]">السمعة الإجرامية</p>
                    <p className="truncate text-[20px] font-bold">{me.name}</p>
                    <p className="text-[12px] text-[#8d8a82]">المستوى {me.level} من {me.maxLevel}</p>
                  </div>
                </div>
                <div className="mt-4 h-2.5 overflow-hidden rounded-full bg-white/10">
                  <div className="mr-0 h-full rounded-full bg-gradient-to-l from-[#b98612] to-[#ffd36a]" style={{ width: `${pct}%` }} />
                </div>
                <div className="mt-1.5 flex justify-between text-[12px] text-[#a3a09a]">
                  <span>{me.nextXp ? `إلى المستوى ${me.level + 1}` : 'أعلى مستوى'}</span>
                  <span dir="ltr">{me.nextXp ? `${num(me.xp)} / ${num(me.nextXp)} XP` : `${num(me.xp)} XP`}</span>
                </div>
              </div>
              <Label>المهارات (كل مستوى = وقت أطول في الألعاب)</Label>
              <Card>
                {arr<any>(me.skills).map((s, i) => (
                  <div key={s.id} className={cn('flex items-center gap-3 px-3.5 py-3', i > 0 && 'border-t border-white/[0.05]')}>
                    <p className="flex-1 text-[15px]">{s.label}</p>
                    <div className="flex gap-1">
                      {[1, 2, 3, 4, 5].map((n) => (
                        <span key={n} className={cn('h-2 w-5 rounded-full', n <= s.level ? 'bg-[#e8b547]' : 'bg-white/10')} />
                      ))}
                    </div>
                  </div>
                ))}
              </Card>
              {me.heat > 0 && (
                <Card className="mt-3 flex items-center gap-3 border-[#e5484d]/25 p-3.5">
                  <Flame className="h-5 w-5 text-[#ff6b6f]" />
                  <p className="flex-1 text-[14px]">مطلوب: لا سرقات كبيرة حتى تبرد</p>
                  <span className="text-[14px] font-bold text-[#ff8b8e]" dir="ltr">{mmss(me.heat - tick)}</span>
                </Card>
              )}
              {arr<string>(me.titles).length > 0 && (
                <>
                  <Label>ألقابك</Label>
                  <Card>
                    {arr<string>(me.titles).map((tt, i) => (
                      <div key={i} className={cn('flex items-center gap-3 px-3.5 py-3 text-[14px]', i > 0 && 'border-t border-white/[0.05]')}>
                        <Trophy className="h-4 w-4 text-[#e8b547]" />
                        {tt}
                      </div>
                    ))}
                  </Card>
                </>
              )}
            </>
          )}

          {/* ------------------------------------------------ the boards */}
          {data && data.known && tab === 'board' && (
            <>
              {(
                [
                  ['crews', 'الطواقم', Users],
                  ['robbers', 'اللصوص', Flame],
                  ['cops', 'الشرطة', Shield],
                ] as [keyof CrewData['board'], string, any][]
              ).map(([k, label, Icon]) => {
                const rows = arr<any>(data.board?.[k]);
                return (
                  <div key={k}>
                    <Label>
                      {label} · شهر {data.board?.month}
                    </Label>
                    <Card>
                      {rows.length === 0 && <p className="px-3.5 py-3 text-[13px] text-[#6d6a64]">لا أحد بعد هذا الشهر</p>}
                      {rows.map((r, i) => (
                        <div key={r.k} className={cn('flex items-center gap-3 px-3.5 py-2.5', i > 0 && 'border-t border-white/[0.05]')}>
                          <span
                            className={cn(
                              'flex h-7 w-7 items-center justify-center rounded-lg text-[13px] font-bold',
                              i === 0 ? 'bg-[#e8b547] text-[#1b1406]' : i < 3 ? 'bg-white/10 text-[#f1efe9]' : 'text-[#8d8a82]',
                            )}
                          >
                            {i + 1}
                          </span>
                          <Icon className="h-4 w-4 text-[#8d8a82]" />
                          <p className="min-w-0 flex-1 truncate text-[14.5px]">{r.name}</p>
                          <span className="text-[13px] font-semibold text-[#e8b547]" dir="ltr">
                            {num(r.points)}
                          </span>
                        </div>
                      ))}
                    </Card>
                  </div>
                );
              })}
              <p className="mt-4 px-1 text-[12px] leading-relaxed text-[#6d6a64]">
                في أول كل شهر يأخذ أول ثلاثة في كل لوحة لقبًا يبقى معهم. السمعة لا تُصفّر، اللوحة فقط.
              </p>
            </>
          )}
        </div>
        <CityToast message={toast?.text ?? null} tone={toast?.tone} onDone={() => setToast(null)} />
      </div>
    </AppWrapper>
  );
};
