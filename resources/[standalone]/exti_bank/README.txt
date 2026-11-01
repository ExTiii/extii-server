EX_Tii Bank (exti_bank) - Stage 1
==================================

What it does
- Bank teller (exti_shops puts the teller + gold circle at every bank): press E -> you take out a
  tablet: balances, deposit, withdraw, transfer to a player in the city (by ID), full history.
- ATM (exti_shops: E at any ATM): withdraw, deposit, balance. Max $10,000 per action. No transfers.
- Phone bank app (npwd_city): transfers go through exti_bank too (same checks, same history).
  Only to players who are in the city right now.

Where the money lives
- cash and bank are qbx_core money (the same numbers the HUD shows).
- the history lines are saved by Renewed-Banking (player_transactions table), newest 250 per player.
- every bank-money change anywhere on the server (shops, impound, paychecks, jobs, fines...) writes a
  history line by itself (event QBCore:Server:OnMoneyChange). Unknown reasons show as
  "إضافة إلى الحساب" / "خصم من الحساب". Add new reasons with Arabic titles in config.lua -> Config.reasons.

Safety
- the server checks everything: whole numbers, limits, balance, one action at a time, 1.5 s cooldown,
  bank tablet only near a teller, transfers only from the tablet or the phone.
- a transfer takes the money first, then gives it; if giving fails the sender is refunded.
- the old Renewed-Banking deposit / withdraw / transfer callbacks are turned off (exti_bank only).

Needs (start order is automatic in [standalone]): ox_lib, qbx_core, Renewed-Banking, exti_shops.

For other scripts
- exports.exti_bank:Transfer(src, targetSrc, amount, note, 'phone') -> ok, errorCode, { name }
  errorCodes: amount, busy, cooldown, not_found, self, no_bank, failed
- exports.exti_bank:GetHistory(citizenid) -> list of { id, title, amount, dir 'in'|'out', note, from, to, time }

Later stages (not in this resource yet): invoices, business accounts, payroll, bank cards, loans.
