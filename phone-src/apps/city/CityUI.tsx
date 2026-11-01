import React, { useEffect } from 'react';
import { RefreshCw, X } from 'lucide-react';
import { cn } from '@utils/css';

/* Large iOS-style title with an optional refresh button */
export const CityHeader: React.FC<{
  title: string;
  subtitle?: string;
  onRefresh?: () => void;
  loading?: boolean;
  refreshLabel?: string;
}> = ({ title, subtitle, onRefresh, loading, refreshLabel }) => (
  <div className="flex items-end justify-between px-4 pb-2 pt-4">
    <div>
      <h3 className="text-3xl font-bold text-neutral-900 dark:text-neutral-100">{title}</h3>
      {subtitle && (
        <p className="mt-0.5 text-[13px] leading-snug text-neutral-500 dark:text-neutral-400">
          {subtitle}
        </p>
      )}
    </div>
    {onRefresh && (
      <button
        aria-label={refreshLabel}
        title={refreshLabel}
        onClick={onRefresh}
        className="mb-1 flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-white text-[#007AFF] shadow-sm active:scale-95 dark:bg-neutral-800"
      >
        <RefreshCw className={cn('h-[18px] w-[18px]', loading && 'animate-spin')} />
      </button>
    )}
  </div>
);

/* Rounded white group, like iOS inset grouped lists */
export const CityGroup: React.FC<{ title?: string; className?: string; children: React.ReactNode }> = ({
  title,
  className,
  children,
}) => (
  <div className={cn('mt-5', className)}>
    {title && (
      <p className="mb-1.5 px-4 text-[13px] font-medium text-neutral-500 dark:text-neutral-400">{title}</p>
    )}
    <div className="overflow-hidden rounded-2xl bg-white dark:bg-neutral-800">{children}</div>
  </div>
);

/* Sheet that slides up from the bottom of the phone */
export const CitySheet: React.FC<{
  open: boolean;
  title: string;
  onClose: () => void;
  closeLabel?: string;
  children: React.ReactNode;
}> = ({ open, title, onClose, closeLabel, children }) => {
  if (!open) return null;
  return (
    <div className="absolute inset-0 z-30 flex flex-col justify-end">
      <div className="absolute inset-0 bg-black/40" onClick={onClose} />
      <div className="relative max-h-[88%] overflow-y-auto rounded-t-[28px] bg-neutral-100 px-4 pb-6 pt-3 shadow-2xl dark:bg-neutral-900">
        <div className="mx-auto mb-3 h-1.5 w-10 rounded-full bg-neutral-300 dark:bg-neutral-700" />
        <div className="mb-4 flex items-center justify-between">
          <h4 className="text-lg font-semibold text-neutral-900 dark:text-neutral-100">{title}</h4>
          <button
            aria-label={closeLabel}
            onClick={onClose}
            className="flex h-8 w-8 items-center justify-center rounded-full bg-neutral-200 text-neutral-500 dark:bg-neutral-800 dark:text-neutral-400"
          >
            <X className="h-4 w-4" strokeWidth={2.5} />
          </button>
        </div>
        {children}
      </div>
    </div>
  );
};

/* Small message that appears above the bottom of the app for a few seconds */
export const CityToast: React.FC<{
  message: string | null;
  tone?: 'ok' | 'error';
  onDone: () => void;
}> = ({ message, tone = 'ok', onDone }) => {
  useEffect(() => {
    if (!message) return;
    const id = setTimeout(onDone, 3200);
    return () => clearTimeout(id);
  }, [message, onDone]);

  if (!message) return null;
  return (
    <div className="pointer-events-none absolute inset-x-4 bottom-4 z-40 flex justify-center">
      <div
        className={cn(
          'rounded-2xl px-4 py-3 text-center text-[14px] font-medium text-white shadow-lg backdrop-blur-xl',
          tone === 'ok' ? 'bg-neutral-900/85' : 'bg-[#FF3B30]/90',
        )}
      >
        {message}
      </div>
    </div>
  );
};

export const CityButton: React.FC<
  React.ButtonHTMLAttributes<HTMLButtonElement> & { tone?: 'blue' | 'red' | 'gray' | 'green' }
> = ({ tone = 'blue', className, ...props }) => (
  <button
    {...props}
    className={cn(
      'flex w-full items-center justify-center gap-2 rounded-2xl py-3.5 text-[16px] font-semibold transition-transform active:scale-[0.98] disabled:opacity-40',
      tone === 'blue' && 'bg-[#007AFF] text-white',
      tone === 'red' && 'bg-[#FF3B30] text-white',
      tone === 'green' && 'bg-[#34C759] text-white',
      tone === 'gray' && 'bg-neutral-200 text-neutral-800 dark:bg-neutral-800 dark:text-neutral-100',
      className,
    )}
  />
);
