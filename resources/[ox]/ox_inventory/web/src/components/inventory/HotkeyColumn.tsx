import React from 'react';
import { useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';
import InventorySlot from './InventorySlot';

// EX_Tii: slots 1-5 of your pockets, standing in the middle between your inventory and the other side
const HotkeyColumn: React.FC = () => {
  const inv = useAppSelector(selectLeftInventory);
  const isBusy = useAppSelector((state) => state.inventory.isBusy);
  const items = inv.items.slice(0, 5);

  return (
    <div className="inv-hotkeys" style={{ pointerEvents: isBusy ? 'none' : 'auto' }}>
      <div className="inv-hotkeys-head">
        <span>اختصارات</span>
        <small>1 - 5</small>
      </div>
      <div className="inv-hotkeys-col">
        {items.map((item) => (
          <InventorySlot
            key={`hot-${inv.id}-${item.slot}`}
            item={item}
            hotkey
            inventoryType={inv.type}
            inventoryGroups={inv.groups}
            inventoryId={inv.id}
          />
        ))}
      </div>
    </div>
  );
};

export default HotkeyColumn;
