import React, { useCallback, useRef } from 'react';
import { DragSource, Inventory, InventoryType, Slot, SlotWithItem } from '../../typings';
import { useDrag, useDragDropManager, useDrop } from 'react-dnd';
import { useAppDispatch, useAppSelector } from '../../store';
import { selectSearch } from '../../store/inventory';
import { RARITY_COLOR, rarityOf, shortLabel } from '../../helpers/rarity';
import { onDrop } from '../../dnd/onDrop';
import { onBuy } from '../../dnd/onBuy';
import { Items } from '../../store/items';
import { canCraftItem, canPurchaseItem, getItemUrl, isSlotWithItem } from '../../helpers';
import { onUse } from '../../dnd/onUse';
import { Locale } from '../../store/locale';
import { onCraft } from '../../dnd/onCraft';
import useNuiEvent from '../../hooks/useNuiEvent';
import { ItemsPayload } from '../../reducers/refreshSlots';
import { closeTooltip, openTooltip } from '../../store/tooltip';
import { openContextMenu } from '../../store/contextMenu';
import { useMergeRefs } from '@floating-ui/react';

interface SlotProps {
  inventoryId: Inventory['id'];
  inventoryType: Inventory['type'];
  inventoryGroups: Inventory['groups'];
  item: Slot;
  hotkey?: boolean; // EX_Tii: the 1-5 column in the middle
}

const formatWeight = (w: number) =>
  w >= 1000
    ? `${(w / 1000).toLocaleString('en-us', { maximumFractionDigits: 2 })}kg`
    : `${w.toLocaleString('en-us', { maximumFractionDigits: 0 })}g`;

const InventorySlot: React.ForwardRefRenderFunction<HTMLDivElement, SlotProps> = (
  { item, inventoryId, inventoryType, inventoryGroups, hotkey },
  ref
) => {
  const manager = useDragDropManager();
  const dispatch = useAppDispatch();
  const search = useAppSelector(selectSearch).trim().toLowerCase();
  const timerRef = useRef<number | null>(null);

  const canDrag = useCallback(() => {
    return canPurchaseItem(item, { type: inventoryType, groups: inventoryGroups }) && canCraftItem(item, inventoryType);
  }, [item, inventoryType, inventoryGroups]);

  const [{ isDragging }, drag] = useDrag<DragSource, void, { isDragging: boolean }>(
    () => ({
      type: 'SLOT',
      collect: (monitor) => ({
        isDragging: monitor.isDragging(),
      }),
      item: () =>
        isSlotWithItem(item, inventoryType !== InventoryType.SHOP)
          ? {
              inventory: inventoryType,
              item: {
                name: item.name,
                slot: item.slot,
              },
              image: item?.name && `url(${getItemUrl(item) || 'none'}`,
            }
          : null,
      canDrag,
    }),
    [inventoryType, item]
  );

  const [{ isOver }, drop] = useDrop<DragSource, void, { isOver: boolean }>(
    () => ({
      accept: 'SLOT',
      collect: (monitor) => ({
        isOver: monitor.isOver(),
      }),
      drop: (source) => {
        dispatch(closeTooltip());
        switch (source.inventory) {
          case InventoryType.SHOP:
            onBuy(source, { inventory: inventoryType, item: { slot: item.slot } });
            break;
          case InventoryType.CRAFTING:
            onCraft(source, { inventory: inventoryType, item: { slot: item.slot } });
            break;
          default:
            onDrop(source, { inventory: inventoryType, item: { slot: item.slot } });
            break;
        }
      },
      canDrop: (source) =>
        (source.item.slot !== item.slot || source.inventory !== inventoryType) &&
        inventoryType !== InventoryType.SHOP &&
        inventoryType !== InventoryType.CRAFTING,
    }),
    [inventoryType, item]
  );

  useNuiEvent('refreshSlots', (data: { items?: ItemsPayload | ItemsPayload[] }) => {
    if (!isDragging && !data.items) return;
    if (!Array.isArray(data.items)) return;

    const itemSlot = data.items.find(
      (dataItem) => dataItem.item.slot === item.slot && dataItem.inventory === inventoryId
    );

    if (!itemSlot) return;

    manager.dispatch({ type: 'dnd-core/END_DRAG' });
  });

  const connectRef = (element: HTMLDivElement | null) => {
    if (!element) return;
    drag(drop(element));
  };

  const handleContext = (event: React.MouseEvent<HTMLDivElement>) => {
    event.preventDefault();
    if (inventoryType !== 'player' || !isSlotWithItem(item)) return;

    dispatch(openContextMenu({ item, coords: { x: event.clientX, y: event.clientY } }));
  };

  const handleClick = (event: React.MouseEvent<HTMLDivElement>) => {
    dispatch(closeTooltip());
    if (timerRef.current) clearTimeout(timerRef.current);
    if (event.ctrlKey && isSlotWithItem(item) && inventoryType !== 'shop' && inventoryType !== 'crafting') {
      onDrop({ item: item, inventory: inventoryType });
    } else if (event.altKey && isSlotWithItem(item) && inventoryType === 'player') {
      onUse(item);
    }
  };

  const refs = useMergeRefs([connectRef, ref]);

  const hasItem = isSlotWithItem(item);
  const fullLabel = hasItem ? (item.metadata?.label ? item.metadata.label : Items[item.name]?.label || item.name) : '';
  const rarity = hasItem ? rarityOf(item.name) : 'none';
  const locked =
    !canPurchaseItem(item, { type: inventoryType, groups: inventoryGroups }) || !canCraftItem(item, inventoryType);
  // the search box: matching slots glow, the others fade
  const matches =
    search.length > 0 && hasItem
      ? fullLabel.toLowerCase().includes(search) || item.name.toLowerCase().includes(search)
      : false;
  const classes = [
    'inventory-slot',
    hasItem ? 'has-item' : 'empty',
    hotkey ? 'hotkey' : '',
    isOver ? 'over' : '',
    isDragging ? 'dragging' : '',
    locked ? 'locked' : '',
    search.length > 0 ? (matches ? 'match' : 'nomatch') : '',
  ].join(' ');

  return (
    <div
      ref={refs}
      onContextMenu={handleContext}
      onClick={handleClick}
      className={classes}
      style={{ ['--rar' as any]: RARITY_COLOR[rarity] }}
    >
      {hotkey && <span className="slot-key">{item.slot}</span>}
      {hasItem && (
        <div
          className="item-slot-wrapper"
          onMouseEnter={() => {
            timerRef.current = window.setTimeout(() => {
              dispatch(openTooltip({ item, inventoryType }));
            }, 450) as unknown as number;
          }}
          onMouseLeave={() => {
            dispatch(closeTooltip());
            if (timerRef.current) {
              clearTimeout(timerRef.current);
              timerRef.current = null;
            }
          }}
        >
          <div className="slot-top">
            <span className="slot-count">{item.count ? `x${item.count.toLocaleString('en-us')}` : ''}</span>
            <span className="slot-weight">{item.weight > 0 ? formatWeight(item.weight) : ''}</span>
          </div>
          <div
            className="slot-img"
            style={{ backgroundImage: `url(${getItemUrl(item as SlotWithItem) || 'none'})` }}
          />
          <div className="slot-bottom">
            {inventoryType !== 'shop' && item?.durability !== undefined && (
              <div className="slot-dura">
                <i
                  style={{
                    width: `${Math.max(0, Math.min(100, item.durability))}%`,
                    background: item.durability > 50 ? '#3ddc97' : item.durability > 20 ? '#f6a94a' : '#ff5f5f',
                  }}
                />
              </div>
            )}
            {inventoryType === 'shop' && item?.price !== undefined && item.price > 0 && (
              <>
                {item?.currency !== 'money' && item.currency !== 'black_money' && item.currency ? (
                  <div className="slot-price">
                    <img src={getItemUrl(item.currency) || 'none'} alt="" />
                    <span>{item.price.toLocaleString('en-us')}</span>
                  </div>
                ) : (
                  <div className={`slot-price ${item.currency === 'black_money' ? 'dirty' : ''}`}>
                    <span>
                      {Locale.$ || '$'}
                      {item.price.toLocaleString('en-us')}
                    </span>
                  </div>
                )}
              </>
            )}
            <div className="slot-name">{shortLabel(fullLabel)}</div>
          </div>
        </div>
      )}
    </div>
  );
};

export default React.memo(React.forwardRef(InventorySlot));
