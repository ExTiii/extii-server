import React, { useCallback, useEffect, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Check, Lock, Sparkles } from 'lucide-react';
import { AppWrapper } from '@ui/components';
import { cn } from '@utils/css';
import { CityGroup, CityHeader, CityToast } from '../CityUI';
import { fetchCity, LevelData, LevelUnlock, MOCK_LEVEL } from '../cityNui';

const num = (n?: number) => Math.round(n ?? 0).toLocaleString('en-US');

// The player level (exti_level): the level, the bar, what the next levels unlock
export const LevelApp: React.FC = () => {
  const { t } = useTranslation();
  const [data, setData] = useState<LevelData | null>(null);
  const [loading, setLoading] = useState(true);
  const [toast, setToast] = useState<{ text: string; tone: 'ok' | 'error' } | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const resp = await fetchCity<LevelData>('level:get', {}, MOCK_LEVEL);
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

  const unlocks: LevelUnlock[] = Array.isArray(data?.unlocks) ? data!.unlocks! : (Object.values(data?.unlocks ?? {}) as LevelUnlock[]);
  const pct = Math.max(0, Math.min(100, data?.pct ?? 0));

  return (
    <AppWrapper>
      <div className="flex flex-1 flex-col overflow-hidden bg-neutral-100 dark:bg-neutral-900">
        <CityHeader
          title={t('APPS_LEVEL')}
          subtitle={t('CITY.LEVEL.SUBTITLE')}
          onRefresh={load}
          loading={loading}
          refreshLabel={t('CITY.REFRESH')}
        />
        <div className="flex-1 overflow-y-auto px-4 pb-6">
          {!data && (
            <p className="py-10 text-center text-[14px] text-neutral-500">{loading ? t('CITY.LOADING') : t('CITY.ERROR_GENERIC')}</p>
          )}
          {data && (
            <>
              <div className="mt-3 overflow-hidden rounded-3xl bg-gradient-to-br from-[#2a2416] via-[#1a1a1d] to-[#111113] p-5 text-white shadow-lg">
                <div className="flex items-center gap-4">
                  <div className="flex h-20 w-20 shrink-0 items-center justify-center rounded-[22px] bg-gradient-to-br from-[#ffd659] to-[#c9970f] text-[32px] font-bold text-[#2a1c00] shadow-[0_8px_24px_rgba(201,151,15,0.45)]">
                    {data.level}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="text-[13px] text-[#ffd659]">{t('CITY.LEVEL.YOUR_LEVEL')}</p>
                    <p className="text-[24px] font-bold leading-tight">
                      {data.max ? t('CITY.LEVEL.MAX') : t('CITY.LEVEL.LEVEL_N', { n: data.level })}
                    </p>
                    <p className="text-[12px] text-neutral-400">
                      {t('CITY.LEVEL.OF', { max: data.maxLevel ?? 300 })}
                    </p>
                  </div>
                </div>
                <div className="mt-4 h-3 overflow-hidden rounded-full bg-white/10" dir="rtl">
                  <div className="h-full rounded-full bg-gradient-to-l from-[#c9970f] to-[#ffd659]" style={{ width: `${pct}%` }} />
                </div>
                <div className="mt-2 flex justify-between text-[12px] text-neutral-300">
                  <span>{data.max ? '' : t('CITY.LEVEL.TO_NEXT', { n: data.level + 1 })}</span>
                  <span dir="ltr">{data.max ? 'MAX' : `${num(data.cur)} / ${num(data.need)} XP`}</span>
                </div>
              </div>

              <CityGroup title={t('CITY.LEVEL.HOW_TITLE')}>
                {['HOW_1', 'HOW_2', 'HOW_3'].map((k, i) => (
                  <div key={k} className={cn('flex items-start gap-3 px-4 py-3 text-[14px] text-neutral-800 dark:text-neutral-200', i > 0 && 'border-t border-neutral-100 dark:border-neutral-700')}>
                    <Sparkles className="mt-0.5 h-4 w-4 shrink-0 text-[#c9970f]" />
                    <span>{t(`CITY.LEVEL.${k}`)}</span>
                  </div>
                ))}
                {typeof data.hourLeft === 'number' && (
                  <div className="border-t border-neutral-100 px-4 py-3 text-[13px] text-neutral-500 dark:border-neutral-700 dark:text-neutral-400">
                    {t('CITY.LEVEL.HOUR_LEFT', { n: num(data.hourLeft) })}
                  </div>
                )}
              </CityGroup>

              {unlocks.length > 0 && (
                <CityGroup title={t('CITY.LEVEL.UNLOCKS')}>
                  {unlocks.map((u, i) => {
                    const open = data.level >= u.level;
                    return (
                      <div key={`${u.level}-${u.label}`} className={cn('flex items-center gap-3 px-4 py-3', i > 0 && 'border-t border-neutral-100 dark:border-neutral-700')}>
                        <div className={cn('flex h-9 w-9 shrink-0 items-center justify-center rounded-xl text-[13px] font-bold', open ? 'bg-[#34C759]/15 text-[#34C759]' : 'bg-neutral-200 text-neutral-500 dark:bg-neutral-700')}>
                          {open ? <Check className="h-4 w-4" /> : <Lock className="h-4 w-4" />}
                        </div>
                        <div className="min-w-0 flex-1">
                          <p className="truncate text-[15px] text-neutral-900 dark:text-neutral-100">{u.label}</p>
                          <p className="text-[12px] text-neutral-500 dark:text-neutral-400">{t('CITY.LEVEL.LEVEL_N', { n: u.level })}</p>
                        </div>
                      </div>
                    );
                  })}
                </CityGroup>
              )}
            </>
          )}
        </div>
        <CityToast message={toast?.text ?? null} tone={toast?.tone} onDone={() => setToast(null)} />
      </div>
    </AppWrapper>
  );
};
