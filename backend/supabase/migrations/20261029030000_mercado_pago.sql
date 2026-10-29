-- Pasarela de pagos: Mercado Pago (Checkout Pro) en lugar de Wompi.
--
-- El flujo no cambia (API_CONTRATO, parte 5): `start_checkout` crea el
-- intento, la Edge Function `checkout` crea la preferencia en Mercado Pago y
-- el resultado llega por `payment-webhook` o por la consulta de la app. Las
-- funciones traducen los estados de Mercado Pago a los de
-- `apply_payment_event` (PENDING, APPROVED, DECLINED, VOIDED, ERROR), así que
-- la base solo cambia la pasarela registrada en cada pago.
--
-- `gateway_transaction_id` guarda el id del pago de Mercado Pago y
-- `payment_method_type`, su `payment_type_id` (credit_card, debit_card,
-- account_money, ticket, bank_transfer...).

-- Ningún pago llegó a hacerse con Wompi (nunca tuvo llaves); por si algún
-- intento quedó guardado, se registra con la pasarela nueva.
alter table public.payments drop constraint payments_gateway_check;
update public.payments set gateway = 'mercadopago' where gateway = 'wompi';
alter table public.payments
  alter column gateway set default 'mercadopago',
  add constraint payments_gateway_check check (gateway = 'mercadopago');

comment on column public.payments.gateway_transaction_id is 'Id del pago en Mercado Pago.';
comment on column public.payments.payment_method_type is
  'payment_type_id de Mercado Pago: credit_card, debit_card, account_money, ticket, bank_transfer...';
