import { onUse } from '../../dnd/onUse';
import { onGive } from '../../dnd/onGive';
import { onDrop } from '../../dnd/onDrop';
import { Items } from '../../store/items';
import { fetchNui } from '../../utils/fetchNui';
import { Locale } from '../../store/locale';
import { isSlotWithItem } from '../../helpers';
import { setClipboard } from '../../utils/setClipboard';
import { store, useAppSelector } from '../../store';
import { setShiftPressed } from '../../store/inventory';
import React from 'react';
import { Menu, MenuItem } from '../utils/menu/Menu';

interface DataProps {
  action: string;
  component?: string;
  slot?: number;
  serial?: string;
  id?: number;
}

interface Button {
  label: string;
  index: number;
  group?: string;
}

interface Group {
  groupName: string | null;
  buttons: ButtonWithIndex[];
}

interface ButtonWithIndex extends Button {
  index: number;
}

interface GroupedButtons extends Array<Group> {}

const InventoryContext: React.FC = () => {
  const contextMenu = useAppSelector((state) => state.contextMenu);
  const item = contextMenu.item;

  const handleClick = (data: DataProps) => {
    if (!item) return;

    switch (data && data.action) {
      case 'use':
        onUse({ name: item.name, slot: item.slot });
        break;
      case 'give':
        onGive({ name: item.name, slot: item.slot });
        break;
      case 'drop':
        isSlotWithItem(item) && onDrop({ item: item, inventory: 'player' });
        break;
      case 'split': {
        // EX_Tii: half of the stack into the first empty slot of your pockets
        const left = store.getState().inventory.leftInventory;
        const empty = left.items.find((s) => !s.name && s.slot > 5) || left.items.find((s) => !s.name);
        if (!empty || !isSlotWithItem(item) || item.count < 2) break;
        const wasShift = store.getState().inventory.shiftPressed;
        store.dispatch(setShiftPressed(true));
        onDrop({ item: { name: item.name, slot: item.slot }, inventory: 'player' }, { inventory: 'player', item: { slot: empty.slot } });
        store.dispatch(setShiftPressed(wasShift));
        break;
      }
      case 'remove':
        fetchNui('removeComponent', { component: data?.component, slot: data?.slot });
        break;
      case 'removeAmmo':
        fetchNui('removeAmmo', item.slot);
        break;
      case 'copy':
        setClipboard(data.serial || '');
        break;
      case 'custom':
        fetchNui('useButton', { id: (data?.id || 0) + 1, slot: item.slot });
        break;
    }
  };

  const groupButtons = (buttons: any): GroupedButtons => {
    return buttons.reduce((groups: Group[], button: Button, index: number) => {
      if (button.group) {
        const groupIndex = groups.findIndex((group) => group.groupName === button.group);
        if (groupIndex !== -1) {
          groups[groupIndex].buttons.push({ ...button, index });
        } else {
          groups.push({
            groupName: button.group,
            buttons: [{ ...button, index }],
          });
        }
      } else {
        groups.push({
          groupName: null,
          buttons: [{ ...button, index }],
        });
      }
      return groups;
    }, []);
  };

  return (
    <>
      <Menu>
        <MenuItem onClick={() => handleClick({ action: 'use' })} label="استخدام" />
        <MenuItem onClick={() => handleClick({ action: 'give' })} label="إعطاء لأقرب شخص" />
        {item && item.count > 1 && <MenuItem onClick={() => handleClick({ action: 'split' })} label="تقسيم إلى نصفين" />}
        <MenuItem onClick={() => handleClick({ action: 'drop' })} label="رمي على الأرض" />
        {item && item.metadata?.ammo > 0 && (
          <MenuItem onClick={() => handleClick({ action: 'removeAmmo' })} label="إخراج الرصاص" />
        )}
        {item && item.metadata?.serial && (
          <MenuItem
            onClick={() => handleClick({ action: 'copy', serial: item.metadata?.serial })}
            label="نسخ الرقم التسلسلي"
          />
        )}
        {item && item.metadata?.components && item.metadata?.components.length > 0 && (
          <Menu label="فك الملحقات">
            {item &&
              item.metadata?.components.map((component: string, index: number) => (
                <MenuItem
                  key={index}
                  onClick={() => handleClick({ action: 'remove', component, slot: item.slot })}
                  label={Items[component]?.label || ''}
                />
              ))}
          </Menu>
        )}
        {((item && item.name && Items[item.name]?.buttons?.length) || 0) > 0 && (
          <>
            {item &&
              item.name &&
              groupButtons(Items[item.name]?.buttons).map((group: Group, index: number) => (
                <React.Fragment key={index}>
                  {group.groupName ? (
                    <Menu label={group.groupName}>
                      {group.buttons.map((button: Button) => (
                        <MenuItem
                          key={button.index}
                          onClick={() => handleClick({ action: 'custom', id: button.index })}
                          label={button.label}
                        />
                      ))}
                    </Menu>
                  ) : (
                    group.buttons.map((button: Button) => (
                      <MenuItem
                        key={button.index}
                        onClick={() => handleClick({ action: 'custom', id: button.index })}
                        label={button.label}
                      />
                    ))
                  )}
                </React.Fragment>
              ))}
          </>
        )}
      </Menu>
    </>
  );
};

export default InventoryContext;
