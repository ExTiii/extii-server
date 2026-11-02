import React, { useState } from 'react';
import { getItemUrl, isSlotWithItem } from '../../helpers';
import useNuiEvent from '../../hooks/useNuiEvent';
import { Items } from '../../store/items';
import { useAppSelector } from '../../store';
import { selectLeftInventory } from '../../store/inventory';
import { SlotWithItem } from '../../typings';
import SlideUp from '../utils/transitions/SlideUp';
import { RARITY_COLOR, rarityOf, shortLabel } from '../../helpers/rarity';

// the 1-5 bar at the bottom of the screen (shown for a moment when you press a number, or with TAB)
const InventoryHotbar: React.FC = () => {
  const [hotbarVisible, setHotbarVisible] = useState(false);
  const items = useAppSelector(selectLeftInventory).items.slice(0, 5);

  const [handle, setHandle] = useState<ReturnType<typeof setTimeout>>();
  useNuiEvent('toggleHotbar', () => {
    if (hotbarVisible) {
      setHotbarVisible(false);
    } else {
      if (handle) clearTimeout(handle);
      setHotbarVisible(true);
      setHandle(setTimeout(() => setHotbarVisible(false), 3000));
    }
  });

  return (
    <SlideUp in={hotbarVisible}>
      <div className="hotbar-container">
        {items.map((item) => {
          const has = isSlotWithItem(item);
          const label = has ? item.metadata?.label || Items[item.name]?.label || item.name : '';
          return (
            <div
              className={`inventory-slot hotkey ${has ? 'has-item' : 'empty'}`}
              style={{ ['--rar' as any]: RARITY_COLOR[has ? rarityOf(item.name) : 'none'] }}
              key={`hotbar-${item.slot}`}
            >
              <span className="slot-key">{item.slot}</span>
              {has && (
                <div className="item-slot-wrapper">
                  <div className="slot-top">
                    <span className="slot-count">{item.count ? `x${item.count.toLocaleString('en-us')}` : ''}</span>
                    <span className="slot-weight" />
                  </div>
                  <div className="slot-img" style={{ backgroundImage: `url(${getItemUrl(item as SlotWithItem) || 'none'})` }} />
                  <div className="slot-bottom">
                    {item.durability !== undefined && (
                      <div className="slot-dura">
                        <i
                          style={{
                            width: `${Math.max(0, Math.min(100, item.durability))}%`,
                            background: item.durability > 50 ? '#3ddc97' : item.durability > 20 ? '#f6a94a' : '#ff5f5f',
                          }}
                        />
                      </div>
                    )}
                    <div className="slot-name">{shortLabel(label)}</div>
                  </div>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </SlideUp>
  );
};

export default InventoryHotbar;
