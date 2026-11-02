import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Inventory } from '../../typings';
import InventorySlot from './InventorySlot';
import { getTotalWeight } from '../../helpers';
import { useAppDispatch, useAppSelector } from '../../store';
import { useIntersection } from '../../hooks/useIntersection';
import { selectSearch, setSearch } from '../../store/inventory';

const PAGE_SIZE = 45;

// EX_Tii: one panel of the inventory.
//   side 'left'  = your pockets: slots 6-50 on one page (1-5 are in the middle column), never scrolls
//   side 'right' = the ground / trunk / stash / shop: one page of 45, big ones scroll (only this side)
const InventoryGrid: React.FC<{ inventory: Inventory; side: 'left' | 'right' }> = ({ inventory, side }) => {
  const dispatch = useAppDispatch();
  const search = useAppSelector(selectSearch);
  const weight = useMemo(
    () => (inventory.maxWeight !== undefined ? Math.floor(getTotalWeight(inventory.items) * 1000) / 1000 : 0),
    [inventory.maxWeight, inventory.items]
  );
  const [page, setPage] = useState(0);
  const { ref, entry } = useIntersection({ threshold: 0.5 });
  const isBusy = useAppSelector((state) => state.inventory.isBusy);
  const searchRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (entry && entry.isIntersecting) setPage((prev) => prev + 1);
  }, [entry]);

  // a new inventory on this side starts from the top
  useEffect(() => setPage(0), [inventory.id]);

  const isPlayer = side === 'left' && inventory.type === 'player';
  const items = isPlayer ? inventory.items.slice(5) : inventory.items.slice(0, (page + 1) * PAGE_SIZE);
  const used = inventory.items.filter((i) => i.name).length;
  const pct = inventory.maxWeight ? Math.min(100, (weight / inventory.maxWeight) * 100) : 0;
  const scrolls = !isPlayer && inventory.items.length > PAGE_SIZE;

  return (
    <div className={`inv-panel inv-${side}`} style={{ pointerEvents: isBusy ? 'none' : 'auto' }}>
      <div className="inv-head">
        <div className="inv-title">
          <h3>{inventory.label || (side === 'right' ? 'الأرض' : 'حقيبتك')}</h3>
          <span className="inv-slots">
            {used}/{inventory.slots} خانة
          </span>
        </div>
        {inventory.maxWeight ? (
          <div className="inv-weight">
            <div className={`inv-wbar ${pct >= 90 ? 'full' : pct >= 70 ? 'heavy' : ''}`}>
              <i style={{ width: `${pct}%` }} />
            </div>
            <span>
              <b>{(weight / 1000).toLocaleString('en-us', { maximumFractionDigits: 1 })}</b> /{' '}
              {(inventory.maxWeight / 1000).toLocaleString('en-us', { maximumFractionDigits: 1 })} kg
            </span>
          </div>
        ) : (
          <div className="inv-weight" />
        )}
        {side === 'right' && (
          <div className="inv-hint">
            <span><kbd>Ctrl + نقرة</kbd>نقل سريع</span>
            <span><kbd>Shift + سحب</kbd>نصف الكمية</span>
            <span><kbd>الزر الأيمن</kbd>خيارات</span>
          </div>
        )}
        {isPlayer && (
          <label className="inv-search">
            <svg viewBox="0 0 24 24" width="15" height="15">
              <circle cx="11" cy="11" r="6.5" fill="none" stroke="currentColor" strokeWidth="2" />
              <path d="M16 16l4.5 4.5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" />
            </svg>
            <input
              ref={searchRef}
              value={search}
              placeholder="ابحث عن غرض..."
              onChange={(e) => dispatch(setSearch(e.target.value))}
              onKeyDown={(e) => e.key === 'Escape' && (e.currentTarget.blur(), dispatch(setSearch('')))}
            />
            {search && (
              <button className="inv-search-clear" onClick={() => dispatch(setSearch(''))}>
                ×
              </button>
            )}
          </label>
        )}
      </div>
      <div className={`inv-grid ${scrolls ? 'scrolls' : ''}`}>
        {items.map((item, index) => (
          <InventorySlot
            key={`${inventory.type}-${inventory.id}-${item.slot}`}
            item={item}
            ref={!isPlayer && index === (page + 1) * PAGE_SIZE - 1 ? ref : null}
            inventoryType={inventory.type}
            inventoryGroups={inventory.groups}
            inventoryId={inventory.id}
          />
        ))}
      </div>
    </div>
  );
};

export default InventoryGrid;
