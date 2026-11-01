import React, { useCallback, useEffect, useState } from 'react';
import dayjs from 'dayjs';
import { useTranslation } from 'react-i18next';
import { ArrowDownLeft, ArrowUpRight, Landmark, Send, Wallet, CheckCircle2, Receipt } from 'lucide-react';
import { AppWrapper } from '@ui/components';
import { NPWDInput } from '@ui/components/Input';
import { cn } from '@utils/css';
import { CityButton, CityGroup, CityHeader, CitySheet, CityToast } from '../CityUI';
import {
  BankBill,
  BankData,
  BankTransaction,
  BillPayResult,
  fetchCity,
  MOCK_BANK,
  MOCK_PAY,
  MOCK_TRANSFER,
  TransferResult,
} from '../cityNui';
import { money, onlyDigits, seconds } from '../format';

type Step = 'form' | 'confirm' | 'done';

const inputClass =
  'rounded-xl bg-white px-4 py-3 text-[16px] text-neutral-900 placeholder:text-neutral-400 dark:bg-neutral-800 dark:text-neutral-100';

export const BankApp: React.FC = () => {
  const { t, i18n } = useTranslation();
  const [data, setData] = useState<BankData | null>(null);
  const [loading, setLoading] = useState(true);
  const [toast, setToast] = useState<{ text: string; tone: 'ok' | 'error' } | null>(null);

  const [sheetOpen, setSheetOpen] = useState(false);
  const [step, setStep] = useState<Step>('form');
  const [number, setNumber] = useState('');
  const [amount, setAmount] = useState('');
  const [note, setNote] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState<TransferResult | null>(null);

  // bills (fines, workshop bills…): tap one, confirm, paid from the bank account
  const [bill, setBill] = useState<BankBill | null>(null);
  const [paying, setPaying] = useState(false);
  const [billError, setBillError] = useState<string | null>(null);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const resp = await fetchCity<BankData>('bank:get', {}, MOCK_BANK);
      setData(resp ?? {});
    } catch {
      setToast({ text: t('CITY.ERROR_GENERIC'), tone: 'error' });
    } finally {
      setLoading(false);
    }
  }, [t]);

  useEffect(() => {
    load();
  }, [load]);

  const openTransfer = () => {
    setStep('form');
    setNumber('');
    setAmount('');
    setNote('');
    setError(null);
    setResult(null);
    setSheetOpen(true);
  };

  const errorText = (r: TransferResult) => {
    switch (r.error) {
      case 'amount':
        return t('CITY.BANK.ERR_AMOUNT', { min: money(r.min ?? 1), max: money(r.max ?? 500000) });
      case 'number':
        return t('CITY.BANK.ERR_NUMBER');
      case 'not_found':
        return t('CITY.BANK.ERR_NOT_FOUND');
      case 'self':
        return t('CITY.BANK.ERR_SELF');
      case 'balance':
        return t('CITY.BANK.ERR_BALANCE');
      case 'cooldown':
        return t('CITY.WAIT', { time: seconds(r.wait ?? 5, i18n.language) });
      default:
        return t('CITY.ERROR_GENERIC');
    }
  };

  const goConfirm = () => {
    const value = Number(amount);
    if (onlyDigits(number).length < 3) return setError(t('CITY.BANK.ERR_NUMBER'));
    if (!value || value < 1) return setError(t('CITY.BANK.ERR_AMOUNT', { min: money(1), max: money(500000) }));
    if (data?.balance !== undefined && value > data.balance) return setError(t('CITY.BANK.ERR_BALANCE'));
    setError(null);
    setStep('confirm');
  };

  const send = async () => {
    setSending(true);
    try {
      const resp = await fetchCity<TransferResult>(
        'bank:transfer',
        { number: onlyDigits(number), amount: Number(amount), note: note.trim() },
        MOCK_TRANSFER,
      );
      if (resp?.ok) {
        setResult(resp);
        setStep('done');
        setData((prev) => (prev ? { ...prev, balance: resp.balance ?? prev.balance } : prev));
        load();
      } else {
        setError(errorText(resp ?? { ok: false }));
        setStep('form');
      }
    } catch {
      setError(t('CITY.ERROR_GENERIC'));
      setStep('form');
    } finally {
      setSending(false);
    }
  };

  const payError = (r: BillPayResult) => {
    switch (r.error) {
      case 'no_bank':
        return t('CITY.BANK.ERR_BALANCE');
      case 'no_bill':
        return t('CITY.BANK.BILL_GONE');
      case 'cooldown':
        return t('CITY.WAIT', { time: seconds(r.wait ?? 5, i18n.language) });
      default:
        return t('CITY.ERROR_GENERIC');
    }
  };

  const payBill = async () => {
    if (!bill) return;
    setPaying(true);
    setBillError(null);
    try {
      const resp = await fetchCity<BillPayResult>('bank:payBill', { id: bill.id }, MOCK_PAY);
      if (resp?.ok) {
        setBill(null);
        setToast({ text: t('CITY.BANK.BILL_PAID', { amount: money(resp.amount ?? bill.amount) }), tone: 'ok' });
        load();
      } else {
        setBillError(payError(resp ?? { ok: false }));
        if (resp?.error === 'no_bill') load();
      }
    } catch {
      setBillError(t('CITY.ERROR_GENERIC'));
    } finally {
      setPaying(false);
    }
  };

  const history = data?.history ?? [];
  const bills = data?.bills ?? [];
  const billsTotal = bills.reduce((sum, b) => sum + (Number(b.amount) || 0), 0);

  return (
    <AppWrapper>
      <div className="flex flex-1 flex-col overflow-y-auto bg-neutral-100 pb-6 dark:bg-neutral-900">
        <CityHeader
          title={t('APPS_BANK')}
          onRefresh={load}
          loading={loading}
          refreshLabel={t('CITY.REFRESH')}
        />

        <div className="px-4">
          {/* Account card */}
          <div className="relative mt-2 overflow-hidden rounded-[22px] bg-gradient-to-br from-[#0A84FF] via-[#1F5FD6] to-[#4B2FB5] p-5 text-white shadow-lg">
            <div className="absolute -end-10 -top-12 h-40 w-40 rounded-full bg-white/10" />
            <div className="absolute -bottom-16 -start-8 h-40 w-40 rounded-full bg-white/5" />
            <div className="relative flex items-center justify-between">
              <span className="text-[13px] font-medium text-white/80">{t('CITY.BANK.PERSONAL')}</span>
              <Landmark className="h-5 w-5 text-white/80" />
            </div>
            <p className="relative mt-4 text-[13px] text-white/75">{t('CITY.BANK.BALANCE')}</p>
            <p dir="ltr" className="relative text-end text-[34px] font-bold leading-tight tracking-tight">
              {data ? money(data.balance) : '—'}
            </p>
            <div className="relative mt-4 flex items-end justify-between text-[13px]">
              <div>
                <p className="text-white/70">{t('CITY.BANK.HOLDER')}</p>
                <p dir="auto" className="font-semibold">{data?.name || '—'}</p>
              </div>
              <div className="text-end">
                <p className="text-white/70">{t('CITY.BANK.ACCOUNT')}</p>
                <p dir="ltr" className="font-semibold tracking-wider">{data?.phone || '—'}</p>
              </div>
            </div>
          </div>

          {/* Cash + transfer */}
          <div className="mt-3 grid grid-cols-2 gap-3">
            <div className="rounded-2xl bg-white p-3.5 dark:bg-neutral-800">
              <div className="flex items-center gap-2 text-[13px] text-neutral-500 dark:text-neutral-400">
                <Wallet className="h-4 w-4 text-[#34C759]" />
                {t('CITY.BANK.CASH')}
              </div>
              <p dir="ltr" className="mt-1 text-end text-[20px] font-semibold text-neutral-900 dark:text-neutral-100">
                {data ? money(data.cash) : '—'}
              </p>
            </div>
            <button
              onClick={openTransfer}
              disabled={!data}
              className="flex flex-col items-start justify-between rounded-2xl bg-[#007AFF] p-3.5 text-white transition-transform active:scale-[0.97] disabled:opacity-50"
            >
              <Send className="h-5 w-5" />
              <span className="text-[16px] font-semibold">{t('CITY.BANK.TRANSFER')}</span>
            </button>
          </div>
          <p className="mt-2 px-1 text-[12px] text-neutral-500 dark:text-neutral-400">{t('CITY.BANK.ACCOUNT_HINT')}</p>

          {/* Bills */}
          <CityGroup title={bills.length ? t('CITY.BANK.BILLS_TOTAL', { count: bills.length, total: money(billsTotal) }) : t('CITY.BANK.BILLS')}>
            {bills.length === 0 && (
              <p className="px-4 py-5 text-center text-[14px] text-neutral-500 dark:text-neutral-400">
                {loading ? t('CITY.LOADING') : t('CITY.BANK.BILLS_EMPTY')}
              </p>
            )}
            {bills.map((b, index) => (
              <button
                key={b.id}
                onClick={() => {
                  setBillError(null);
                  setBill(b);
                }}
                className="flex w-full items-center gap-3 px-4 py-3 text-start active:bg-neutral-100 dark:active:bg-neutral-700/50"
              >
                <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-[#FF9500]/15 text-[#FF9500]">
                  <Receipt className="h-[18px] w-[18px]" />
                </div>
                <div className={cn('min-w-0 flex-1 py-0.5', index !== bills.length - 1 && 'border-b border-neutral-200/70 dark:border-neutral-700/60')}>
                  <div className="flex items-center justify-between gap-2">
                    <p dir="auto" className="truncate text-[15px] font-medium text-neutral-900 dark:text-neutral-100">{b.title}</p>
                    <p dir="ltr" className="shrink-0 text-[15px] font-semibold text-[#FF3B30]">{money(b.amount)}</p>
                  </div>
                  <div className="mt-0.5 flex items-center justify-between gap-2 text-[12.5px] text-neutral-500 dark:text-neutral-400">
                    <p dir="auto" className="truncate">{[b.societyLabel, b.issuer].filter(Boolean).join(' · ') || ' '}</p>
                    <span className="shrink-0 font-semibold text-[#007AFF]">{t('CITY.BANK.PAY')}</span>
                  </div>
                </div>
              </button>
            ))}
          </CityGroup>

          {/* History */}
          <CityGroup title={t('CITY.BANK.HISTORY')}>
            {history.length === 0 && (
              <p className="px-4 py-6 text-center text-[14px] text-neutral-500 dark:text-neutral-400">
                {loading ? t('CITY.LOADING') : t('CITY.BANK.EMPTY')}
              </p>
            )}
            {history.map((tx, index) => (
              <HistoryRow key={tx.id ?? index} tx={tx} myName={data?.name} last={index === history.length - 1} />
            ))}
          </CityGroup>
        </div>
      </div>

      <CitySheet
        open={sheetOpen}
        title={step === 'done' ? t('CITY.BANK.SUCCESS_TITLE') : t('CITY.BANK.TRANSFER')}
        onClose={() => !sending && setSheetOpen(false)}
        closeLabel={t('CITY.CLOSE')}
      >
        {step === 'form' && (
          <div className="flex flex-col gap-3">
            <label className="flex flex-col gap-1.5">
              <span className="px-1 text-[13px] font-medium text-neutral-500 dark:text-neutral-400">
                {t('CITY.BANK.NUMBER')}
              </span>
              <NPWDInput
                dir="ltr"
                inputMode="numeric"
                className={cn(inputClass, 'text-start tracking-wider')}
                placeholder={t('CITY.BANK.NUMBER_PLACEHOLDER')}
                value={number}
                onChange={(e) => setNumber(onlyDigits(e.target.value))}
              />
            </label>
            <label className="flex flex-col gap-1.5">
              <span className="px-1 text-[13px] font-medium text-neutral-500 dark:text-neutral-400">
                {t('CITY.BANK.AMOUNT')}
              </span>
              <div className="relative" dir="ltr">
                <span className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-[16px] text-neutral-400">
                  $
                </span>
                <NPWDInput
                  dir="ltr"
                  inputMode="numeric"
                  className={cn(inputClass, 'pl-8 text-left')}
                  placeholder="0"
                  value={amount}
                  onChange={(e) => setAmount(onlyDigits(e.target.value, 9))}
                />
              </div>
              {data && (
                <span className="px-1 text-[12px] text-neutral-500 dark:text-neutral-400">
                  {t('CITY.BANK.AVAILABLE', { balance: money(data.balance) })}
                </span>
              )}
            </label>
            <label className="flex flex-col gap-1.5">
              <span className="px-1 text-[13px] font-medium text-neutral-500 dark:text-neutral-400">
                {t('CITY.BANK.NOTE')}
              </span>
              <NPWDInput
                dir="auto"
                maxLength={50}
                className={inputClass}
                placeholder={t('CITY.BANK.NOTE_PLACEHOLDER')}
                value={note}
                onChange={(e) => setNote(e.target.value)}
              />
            </label>
            {error && (
              <p className="rounded-xl bg-[#FF3B30]/10 px-3 py-2 text-[14px] text-[#FF3B30]">{error}</p>
            )}
            <CityButton className="mt-1" onClick={goConfirm} disabled={!number || !amount}>
              {t('CITY.BANK.CONTINUE')}
            </CityButton>
          </div>
        )}

        {step === 'confirm' && (
          <div className="flex flex-col items-center gap-3 text-center">
            <div className="flex h-14 w-14 items-center justify-center rounded-full bg-[#007AFF]/10 text-[#007AFF]">
              <Send className="h-6 w-6" />
            </div>
            <p dir="ltr" className="text-[30px] font-bold text-neutral-900 dark:text-neutral-100">
              {money(Number(amount))}
            </p>
            <p className="text-[15px] leading-relaxed text-neutral-600 dark:text-neutral-300">
              {t('CITY.BANK.CONFIRM_TEXT', { amount: money(Number(amount)), number: onlyDigits(number) })}
            </p>
            {note.trim() && (
              <p dir="auto" className="rounded-xl bg-white px-3 py-2 text-[14px] text-neutral-600 dark:bg-neutral-800 dark:text-neutral-300">
                {note.trim()}
              </p>
            )}
            <div className="mt-2 flex w-full flex-col gap-2">
              <CityButton onClick={send} disabled={sending}>
                {sending ? t('CITY.BANK.SENDING') : t('CITY.BANK.CONFIRM')}
              </CityButton>
              <CityButton tone="gray" onClick={() => setStep('form')} disabled={sending}>
                {t('CITY.BACK')}
              </CityButton>
            </div>
          </div>
        )}

        {step === 'done' && result && (
          <div className="flex flex-col items-center gap-3 py-2 text-center">
            <CheckCircle2 className="h-16 w-16 text-[#34C759]" strokeWidth={1.75} />
            <p className="text-[16px] leading-relaxed text-neutral-800 dark:text-neutral-200">
              {t('CITY.BANK.SUCCESS_TEXT', { amount: money(result.amount), name: result.name?.trim() || onlyDigits(number) })}
            </p>
            {result.balance !== undefined && (
              <p className="text-[14px] text-neutral-500 dark:text-neutral-400">
                {t('CITY.BANK.NEW_BALANCE', { balance: money(result.balance) })}
              </p>
            )}
            <CityButton className="mt-2" tone="green" onClick={() => setSheetOpen(false)}>
              {t('CITY.DONE')}
            </CityButton>
          </div>
        )}
      </CitySheet>

      <CitySheet
        open={!!bill}
        title={t('CITY.BANK.PAY_TITLE')}
        onClose={() => !paying && setBill(null)}
        closeLabel={t('CITY.CLOSE')}
      >
        {bill && (
          <div className="flex flex-col items-center gap-3 text-center">
            <div className="flex h-14 w-14 items-center justify-center rounded-full bg-[#FF9500]/15 text-[#FF9500]">
              <Receipt className="h-6 w-6" />
            </div>
            <p dir="ltr" className="text-[30px] font-bold text-neutral-900 dark:text-neutral-100">{money(bill.amount)}</p>
            <p dir="auto" className="text-[15px] font-medium leading-relaxed text-neutral-800 dark:text-neutral-200">{bill.title}</p>
            {(bill.societyLabel || bill.issuer) && (
              <p dir="auto" className="text-[13px] text-neutral-500 dark:text-neutral-400">
                {[bill.societyLabel, bill.issuer].filter(Boolean).join(' · ')}
                {bill.created ? ` · ${dayjs.unix(bill.created).fromNow()}` : ''}
              </p>
            )}
            {bill.note?.trim() && (
              <p dir="auto" className="rounded-xl bg-white px-3 py-2 text-[14px] text-neutral-600 dark:bg-neutral-800 dark:text-neutral-300">{bill.note.trim()}</p>
            )}
            <p className="text-[13px] text-neutral-500 dark:text-neutral-400">
              {t('CITY.BANK.PAY_FROM', { balance: data ? money(data.balance) : '—' })}
            </p>
            {billError && <p className="w-full rounded-xl bg-[#FF3B30]/10 px-3 py-2 text-[14px] text-[#FF3B30]">{billError}</p>}
            <div className="mt-1 flex w-full flex-col gap-2">
              <CityButton tone="green" onClick={payBill} disabled={paying}>
                {paying ? t('CITY.BANK.PAYING') : t('CITY.BANK.PAY_CONFIRM', { amount: money(bill.amount) })}
              </CityButton>
              <CityButton tone="gray" onClick={() => setBill(null)} disabled={paying}>
                {t('CITY.BACK')}
              </CityButton>
            </div>
          </div>
        )}
      </CitySheet>

      <CityToast message={toast?.text ?? null} tone={toast?.tone} onDone={() => setToast(null)} />
    </AppWrapper>
  );
};

const HistoryRow: React.FC<{ tx: BankTransaction; myName?: string; last: boolean }> = ({ tx, myName, last }) => {
  const { t } = useTranslation();
  const incoming = tx.type === 'deposit';
  const other = incoming ? tx.from : tx.to;
  const party =
    other && other.trim() && other.trim() !== myName?.trim()
      ? t(incoming ? 'CITY.BANK.FROM' : 'CITY.BANK.TO', { name: other.trim() })
      : null;
  const details = [party, tx.note?.trim()].filter(Boolean).join(' · ');

  return (
    <div className="flex items-center gap-3 px-4 py-3">
      <div
        className={cn(
          'flex h-9 w-9 shrink-0 items-center justify-center rounded-full',
          incoming ? 'bg-[#34C759]/15 text-[#34C759]' : 'bg-neutral-200 text-neutral-600 dark:bg-neutral-700 dark:text-neutral-300',
        )}
      >
        {incoming ? <ArrowDownLeft className="h-[18px] w-[18px]" /> : <ArrowUpRight className="h-[18px] w-[18px]" />}
      </div>
      <div className={cn('min-w-0 flex-1 py-0.5', !last && 'border-b border-neutral-200/70 dark:border-neutral-700/60')}>
        <div className="flex items-center justify-between gap-2">
          <p dir="auto" className="truncate text-[15px] font-medium text-neutral-900 dark:text-neutral-100">
            {tx.title}
          </p>
          <p
            dir="ltr"
            className={cn(
              'shrink-0 text-[15px] font-semibold',
              incoming ? 'text-[#34C759]' : 'text-neutral-900 dark:text-neutral-100',
            )}
          >
            {incoming ? '+' : '-'}
            {money(tx.amount)}
          </p>
        </div>
        <div className="mt-0.5 flex items-center justify-between gap-2 text-[12.5px] text-neutral-500 dark:text-neutral-400">
          <p dir="auto" className="truncate">{details || ' '}</p>
          <p className="shrink-0">{tx.time ? dayjs.unix(tx.time).fromNow() : ''}</p>
        </div>
      </div>
    </div>
  );
};
