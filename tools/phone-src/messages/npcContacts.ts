// EX_Tii: the city's NPC contacts. Their chats show a name instead of a number, and a list of
// what you can ask them (tap = the message is sent; each line says what it does).
export interface NpcOption {
  label: string;   // the button
  hint: string;    // what it does, in one line
  text: string;    // the message that is sent (the NPC reads the keyword in it)
  group?: string;  // a small heading above a set of options
}
export interface NpcContact {
  name: string;
  about: string;
  options: NpcOption[];
}

export const NPC_CONTACTS: Record<string, NpcContact> = {
  '555-0187': {
    name: 'المصرّف',
    about: 'يشتري المسروقات ويعطيك شغلًا. لا يرسل لك شيئًا إلا إذا طلبت.',
    options: [
      { group: 'كل يوم', label: 'وين مكانك اليوم؟', hint: 'علامة على خريطتك حيث يقف اليوم (يغيّر مكانه كل يوم)', text: 'وين مكانك اليوم؟' },
      { label: 'عندك بيت؟', hint: 'عنوان بيت فاضٍ للسرقة · بالليل فقط (10م - 5ص) · معك ساعة', text: 'عندك شغل؟ بيت' },
      { label: 'مهام اليوم', hint: '3 مهام صغيرة لليوم ومكافأتها، وأين وصلت فيها', text: 'شو مهام اليوم؟' },
      { group: 'الشغل الكبير', label: 'شاحنة مصفّحة', hint: 'شاحنة غروبه 6 تخرج الآن: أوقفها وفجّر بابها الخلفي', text: 'أريد شاحنة مصفّحة' },
      { label: 'بنك', hint: 'أي فرع فيه ضعف المال اليوم (سمعة 4)', text: 'عندك خبر عن بنك؟' },
      { label: 'مزرعة الكارتيل', hint: 'المال في الحظيرة · يحتاج تحضير "مزرعة" أولًا', text: 'أريد المزرعة' },
      { label: 'القافلة', hint: 'قافلة ميري ويذر · يحتاج تحضير "قافلة" أولًا', text: 'أريد القافلة' },
      { group: 'التحضيرات (قبل الشغل الكبير)', label: 'تحضير بنك', hint: 'المخططات: سيارة واقفة فيها ما تحتاجه للبنك', text: 'تحضير بنك' },
      { label: 'تحضير مزرعة', hint: 'بطاقة الحارس للمزرعة', text: 'تحضير مزرعة' },
      { label: 'تحضير قافلة', hint: 'المخططات للقافلة', text: 'تحضير قافلة' },
      { label: 'تحضير يخت', hint: 'زي شركة التموين لليخت', text: 'تحضير يخت' },
    ],
  },
  '555-0420': {
    name: 'الوسيط',
    about: 'للكبار فقط (سمعة 4): فلاشات، بنوك، اليخت، و"الكبيرة".',
    options: [
      { group: 'الفلاشات', label: 'ماذا عندك؟', hint: 'أسعار الفلاشات المتوفرة اليوم', text: 'عندك فلاشات؟' },
      { label: 'فلاشة خضراء', hint: 'للبنوك والإنذارات · تُدفع من حسابك في البنك', text: 'أريد فلاشة خضراء' },
      { label: 'فلاشة زرقاء', hint: 'لكاميرات المزرعة · تُدفع من حسابك في البنك', text: 'أريد فلاشة زرقاء' },
      { group: 'معلومات', label: 'بنك اليوم', hint: 'الفرع الذي فيه ضعف المال اليوم', text: 'أي بنك اليوم؟' },
      { label: 'خزنة باسيفيك', hint: 'ما في خزنة باسيفيك هذا الأسبوع', text: 'شو في باسيفيك؟' },
      { group: 'الشغل', label: 'اليخت', hint: 'يخت قبالة بانهام كانيون · يحتاج زي التموين', text: 'أريد اليخت' },
      { label: 'الكبيرة', hint: 'شاحنة الذهب: موعدها وما ينقصك', text: 'شو أخبار الكبيرة؟' },
      { label: 'أطالب بها', hint: 'خذ "الكبيرة" لطاقمك هذا الأسبوع (بعد التحضيرات الثلاثة)', text: 'أطالب بها' },
      { label: 'ابدأ', hint: 'ابدأ "الكبيرة" الآن (وأنت قرب مستودع الاتحاد)', text: 'ابدأ' },
    ],
  },
  '555-0119': { name: 'المفاوض', about: '', options: [] },
  'رقم مجهول': { name: 'رقم مجهول', about: '', options: [] },
};

const clean = (n: string) => String(n || '').replace(/\s/g, '');
export const npcOf = (numbers: string[] | string): NpcContact | null => {
  const list = Array.isArray(numbers) ? numbers : String(numbers || '').split('+');
  for (const n of list) {
    const c = NPC_CONTACTS[clean(n)];
    if (c) return c;
  }
  return null;
};
