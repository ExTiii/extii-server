// EX_Tii: the colour of a slot's edge, from the kind of item in it
// (food green, medical red, weapons orange, job goods gold, documents purple, money teal, tools blue)

export type Rarity = 'weapon' | 'ammo' | 'medical' | 'food' | 'job' | 'document' | 'money' | 'tool' | 'none';

export const RARITY_COLOR: Record<Rarity, string> = {
  weapon: '#f6a94a',
  ammo: '#d9a441',
  medical: '#ff6b6b',
  food: '#3ddc97',
  job: '#e8b547',
  document: '#a78bfa',
  money: '#2ec4a6',
  tool: '#5aa9ff',
  none: 'rgba(255, 255, 255, 0.14)',
};

export const RARITY_LABEL: Record<Rarity, string> = {
  weapon: 'سلاح',
  ammo: 'ذخيرة',
  medical: 'طبي',
  food: 'طعام وشراب',
  job: 'بضاعة عمل',
  document: 'وثيقة',
  money: 'مال',
  tool: 'أداة',
  none: '',
};

const sets: Partial<Record<Rarity, Set<string>>> = {
  medical: new Set([
    'gauze', 'painkillers', 'medikit', 'bandage', 'firstaid', 'ifaks', 'blood_bag', 'bvm', 'defibrillator',
    'forceps', 'ibuprofen', 'morphine', 'pressure_bandage', 'quickclot', 'saline', 'tourniquet', 'medreport',
  ]),
  food: new Set([
    'burger', 'burger_chicken', 'water', 'water_bottle', 'sprunk', 'redbull', 'cola', 'coffee', 'donut', 'sandwich',
    'tosti', 'fries', 'beer', 'wine', 'vodka', 'whiskey', 'snikkel_candy', 'twerks_candy', 'mustard', 'grapejuice',
    'pizza_ham', 'pizza_ham_slice', 'pizza_ham_box', 'grape',
  ]),
  job: new Set([
    'poultry_kit', 'live_chicken', 'slaughtered_chicken', 'packed_chicken', 'packing_tray',
    'grape_bunch', 'raisins', 'raisin_box', 'empty_carton',
    'engine_kit', 'brake_kit', 'trans_kit', 'susp_kit', 'turbo_kit', 'paint_can', 'wheel_set', 'body_kit',
    'tint_film', 'neon_kit', 'xenon_kit', 'nitro_kit', 'nitro_bottle', 'engine_crate', 'repairkit', 'cleaningkit',
  ]),
  document: new Set([
    'id_card', 'driver_license', 'weaponlicense', 'truck_license', 'boat_license', 'heli_license', 'lawyerpass',
    'card_id', 'card_bank', 'bank_card', 'certificate', 'printerdocument', 'stickynote',
  ]),
  money: new Set(['money', 'black_money', 'markedbills', 'moneybag', 'casinochips', 'goldbar', 'cryptostick']),
  tool: new Set([
    'lockpick', 'advancedlockpick', 'phone', 'iphone', 'samsungphone', 'radio', 'jerry_can', 'tablet', 'laptop',
    'lighter', 'binoculars', 'drill', 'screwdriverset', 'tirerepairkit', 'handcuffs', 'harness', 'parachute',
    'diving_gear', 'fishingrod', 'carkey', 'key', 'electronickit', 'advancedkit', 'veh_toolbox',
  ]),
};

const cache: Record<string, Rarity> = {};

export const rarityOf = (name?: string): Rarity => {
  if (!name) return 'none';
  if (cache[name]) return cache[name];
  const lower = name.toLowerCase();
  let r: Rarity = 'none';
  if (lower.startsWith('weapon_')) r = 'weapon';
  else if (lower.startsWith('ammo') || lower.endsWith('_ammo')) r = 'ammo';
  else {
    for (const key of Object.keys(sets) as Rarity[]) {
      if (sets[key]!.has(lower)) {
        r = key;
        break;
      }
    }
  }
  cache[name] = r;
  return r;
};

// item labels are "Arabic (English)": the slot shows the Arabic part, the tooltip shows everything
export const shortLabel = (label: string) => {
  const i = label.indexOf(' (');
  return i > 0 ? label.slice(0, i) : label;
};
