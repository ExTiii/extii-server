-- EX_Tii Bank
-- The bank balance itself lives in qbx_core (money.bank). Renewed-Banking keeps the history
-- and the job / shared accounts in the database. This script is the only door players use:
-- the tablet at every bank teller, the ATMs and (through Transfer) the phone bank app.

Config = {}

Config.bankName = 'EX_Tii Bank'

Config.minAmount = 1            -- smallest amount for any action
Config.maxAmount = 1000000      -- largest deposit / withdrawal / transfer at the bank
Config.atmMax = 10000           -- largest deposit / withdrawal at an ATM (bigger amounts at a bank)
Config.cooldown = 1.5           -- seconds between two money actions of the same player
Config.historyLimit = 250       -- how many history lines the tablet shows (the bank keeps the newest 250)
Config.noteLength = 60          -- longest transfer note
Config.tellerDistance = 4.0     -- how close to a bank teller's circle you must stay
Config.atmDistance = 3.0        -- how far you may move from where you opened the ATM
Config.sessionMinutes = 15      -- an open tablet / ATM closes itself after this long

-- what a money change is called in your history (the "reason" the other scripts give)
Config.reasons = {
    ['paycheck'] = 'الراتب',
    ['paid-depot'] = 'رسوم ساحة الحجز',
    ['depot-spawn-refund'] = 'استرداد رسوم الحجز',
    ['garage-move-refund'] = 'استرداد رسوم نقل المركبة',
    ['vehicle-bought-in-showroom'] = 'شراء مركبة من المعرض',
    ['vehicle-purchase-refund'] = 'استرداد ثمن مركبة',
    ['shop-refund'] = 'استرداد مشتريات',
    ['job-vehicle-deposit'] = 'تأمين مركبة العمل',
    ['job-vehicle-deposit-refund'] = 'استرداد تأمين مركبة العمل',
    ['job-deposit-refund'] = 'استرداد تأمين مركبة العمل',
    ['job-return-bonus'] = 'مكافأة إرجاع مركبة العمل',
    ['garbage-stop'] = 'أجر · جمع القمامة',
    ['delivery-drop'] = 'أجر · توصيل الطرود',
    ['tow-mission'] = 'أجر · سحب مركبة معطلة',
    ['tow-impound'] = 'أجر · سحب مركبة متروكة',
    ['police-fine'] = 'غرامة',
    ['police-fine-refund'] = 'استرداد غرامة',
    ['police-lawyer-paid'] = 'أتعاب محاماة',
    ['police-tow-paid'] = 'أجر سحب (الشرطة)',
    ['police-deposit'] = 'إيداع في حساب الشرطة',
    ['police-deposit-refund'] = 'استرداد إيداع (الشرطة)',
    ['police-withdraw'] = 'سحب من حساب الشرطة',
    ['police-bonus'] = 'مكافأة من الشرطة',
    ['respawned-at-hospital'] = 'فاتورة المستشفى',
    ['paid-bills'] = 'دفع فاتورة',
    ['tow-truck-deposit'] = 'تأمين شاحنة السحب',
    ['tow-truck-deposit-refund'] = 'استرداد تأمين شاحنة السحب',
    ['garbage-deposit'] = 'تأمين شاحنة القمامة',
    ['garbage-deposit-refund'] = 'استرداد تأمين شاحنة القمامة',
    ['vehicle-sold-back'] = 'بيع مركبة لمعرض المستعمل',
    ['trucker-salary'] = 'أجر · نقل البضائع',
    ['garbage-payslip'] = 'أجر · جمع القمامة',
    ['tow-received-bail'] = 'تأمين شاحنة السحب',
    ['garage-move-vehicle'] = 'رسوم نقل المركبة',
    ['Radar Fine'] = 'مخالفة رادار',
    ['armored-truck'] = 'تكلفة مهمة الشاحنة المصفحة',
    ['vehicle-finance-payment'] = 'قسط تمويل مركبة',
    ['vehicle-finance-payment-full'] = 'سداد كامل لتمويل مركبة',
    ['vehicle-financed-in-showroom'] = 'دفعة أولى لتمويل مركبة',
    ['vehicle-bought-from-player'] = 'شراء مركبة من مواطن',
    ['vehicle-sold-to-player'] = 'بيع مركبة لمواطن',
    ['cityhall-item'] = 'رسوم البلدية',
    -- exti_fuel ("fuel|<station>": the station name shows under the title)
    ['fuel'] = 'وقود',
    ['fuel-refund'] = 'استرداد وقود',
    ['ev-charge'] = 'شحن مركبة كهربائية',
    ['ev-charge-refund'] = 'استرداد شحن',
    ['fuel-can'] = 'تعبئة جالون وقود',
}

-- who gets the money of a paid bill (the job account in Renewed-Banking) and its name on the receipt
Config.societies = {
    police = 'شرطة لوس سانتوس',
    ambulance = 'مستشفى بيلبوكس',
}

-- "shop-<type>" from exti_shops
Config.shopLabels = {
    general = 'بقالة 24/7',
    exmart = 'إكس مارت',
    liquor = 'متجر المشروبات',
    tools = 'متجر العدد',
    ammunation = 'متجر الأسلحة',
    fuel = 'متجر المحطة',
    -- EX_Tii: these showed as just "متجر"
    pharmacy = 'صيدلية المستشفى',
    clothing = 'متجر الملابس',
    barber = 'الحلاق',
    tattoo = 'محل الوشم',
}
