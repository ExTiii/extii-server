import React, { useState, useRef, useEffect } from 'react';
import { useDrop } from 'react-dnd';
import { useAppDispatch, useAppSelector } from '../../store';
import { selectItemAmount, setItemAmount } from '../../store/inventory';
import { DragSource } from '../../typings';
import { onUse } from '../../dnd/onUse';
import { onGive } from '../../dnd/onGive';
import { fetchNui } from '../../utils/fetchNui';
import UsefulControls from './UsefulControls';

const formatAmount = (n: number) => (n > 0 ? n.toLocaleString('en-US') : '0');
const digitsOnly = (s: string) => s.replace(/\D/g, '');
const countDigitsBefore = (s: string, index: number) => digitsOnly(s.substring(0, index)).length;

const InventoryControl: React.FC = () => {
  const itemAmount = useAppSelector(selectItemAmount);
  const dispatch = useAppDispatch();

  const [infoVisible, setInfoVisible] = useState(false);
  const [value, setValue] = useState(formatAmount(itemAmount));
  const inputRef = useRef<HTMLInputElement>(null);
  const cursorRef = useRef<number | null>(null);

  const [, use] = useDrop<DragSource, void, any>(() => ({
    accept: 'SLOT',
    drop: (source) => {
      source.inventory === 'player' && onUse(source.item);
    },
  }));

  const [, give] = useDrop<DragSource, void, any>(() => ({
    accept: 'SLOT',
    drop: (source) => {
      source.inventory === 'player' && onGive(source.item);
    },
  }));

  const commitValue = (raw: string, cursorIndex: number) => {
    const digitsBefore = countDigitsBefore(raw, cursorIndex);
    const num = parseInt(digitsOnly(raw), 10) || 0;

    setValue(formatAmount(num));
    dispatch(setItemAmount(num));
    cursorRef.current = digitsBefore;
  };

  const handleChange = (event: React.ChangeEvent<HTMLInputElement>) =>
    commitValue(event.target.value, event.target.selectionStart ?? 0);

  const handleKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    const el = event.currentTarget;
    const pos = el.selectionStart ?? 0;

    if (pos !== el.selectionEnd) return;

    if (event.key === 'Backspace' && el.value[pos - 1] === ',') {
      event.preventDefault();
      commitValue(el.value.slice(0, pos - 2) + el.value.slice(pos), pos - 2);
    } else if (event.key === 'Delete' && el.value[pos] === ',') {
      event.preventDefault();
      commitValue(el.value.slice(0, pos) + el.value.slice(pos + 2), pos);
    }
  };

  useEffect(() => {
    if (!inputRef.current || cursorRef.current === null) return;
    let newPos = 0;
    let count = 0;

    for (let i = 0; i < value.length && count < cursorRef.current; i++) {
      if (/\d/.test(value[i])) count++;
      newPos++;
    }

    inputRef.current.setSelectionRange(newPos, newPos);
    cursorRef.current = null;
  }, [value]);

  return (
    <>
      <UsefulControls infoVisible={infoVisible} setInfoVisible={setInfoVisible} />
      <div className="inv-bar">
        <label className="inv-amount" title="0 = الكل">
          <span>الكمية</span>
          <input
            type="text"
            ref={inputRef}
            value={value === '0' ? '' : value}
            placeholder="الكل"
            onChange={handleChange}
            onKeyDown={handleKeyDown}
            onFocus={(e) => e.currentTarget.select()}
          />
        </label>
        <button
          className="inv-btn primary"
          ref={(el) => {
            use(el);
          }}
          title="اسحب غرضًا هنا لاستخدامه"
        >
          <svg viewBox="0 0 24 24" width="16" height="16"><path d="M5 12.5l4.5 4.5L19 7.5" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round" /></svg>
          استخدام
        </button>
        <button
          className="inv-btn"
          ref={(el) => {
            give(el);
          }}
          title="اسحب غرضًا هنا لإعطائه لأقرب شخص"
        >
          <svg viewBox="0 0 24 24" width="16" height="16"><path d="M4 13h3l3 2.5h4a1.5 1.5 0 0 0 0-3h-3M14 12.5l5-2.5a1.6 1.6 0 0 1 1.5 2.8L13 18H4" fill="none" stroke="currentColor" strokeWidth="1.9" strokeLinecap="round" strokeLinejoin="round" /></svg>
          إعطاء
        </button>
        <button className="inv-btn ghost" onClick={() => fetchNui('exit')}>
          <svg viewBox="0 0 24 24" width="16" height="16"><path d="M7 7l10 10M17 7L7 17" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" /></svg>
          إغلاق
        </button>
        <button className="inv-btn icon" onClick={() => setInfoVisible(true)} title="اختصارات مفيدة">
          ?
        </button>
      </div>
    </>
  );
};

export default InventoryControl;
