-- COFFEE REGISTER MVP | Ejecutar completo en Supabase SQL Editor
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null default '', email text, customer_type text not null default 'otro' check(customer_type in ('estudiante','docente','otro')),
 phone text, role text not null default 'cliente' check(role in ('cliente','admin')),
 credit_limit numeric(12,2) not null default 0 check(credit_limit>=0), credit_enabled boolean not null default false,
 guardian_authorized boolean not null default false,
 created_at timestamptz not null default now()
);
create table if not exists public.categories(id bigint generated always as identity primary key, name text unique not null);
create table if not exists public.products(id bigint generated always as identity primary key, category_id bigint references public.categories(id), name text not null, description text default '', image_url text, price numeric(12,2) not null check(price>=0), cost numeric(12,2) not null default 0 check(cost>=0), stock integer not null default 0 check(stock>=0), min_stock integer not null default 5 check(min_stock>=0), active boolean not null default true, created_at timestamptz default now());
create table if not exists public.orders(id bigint generated always as identity primary key, customer_id uuid not null references public.profiles(id), status text not null default 'pendiente' check(status in ('pendiente','aceptado','preparacion','listo','entregado','cancelado')), payment_method text not null check(payment_method in ('efectivo','transferencia','credito')), total numeric(12,2) not null default 0, notes text default '', created_at timestamptz default now());
create table if not exists public.order_items(id bigint generated always as identity primary key, order_id bigint not null references public.orders(id) on delete cascade, product_id bigint not null references public.products(id), quantity integer not null check(quantity>0), unit_price numeric(12,2) not null check(unit_price>=0));
create table if not exists public.sales(id bigint generated always as identity primary key, order_id bigint unique references public.orders(id), customer_id uuid references public.profiles(id), payment_method text not null check(payment_method in ('efectivo','transferencia','credito')), total numeric(12,2) not null check(total>=0), notes text default '', created_at timestamptz default now());
create table if not exists public.sale_items(id bigint generated always as identity primary key, sale_id bigint not null references public.sales(id) on delete cascade, product_id bigint not null references public.products(id), quantity integer not null check(quantity>0), unit_price numeric(12,2) not null);
create table if not exists public.payments(id bigint generated always as identity primary key, customer_id uuid not null references public.profiles(id), amount numeric(12,2) not null check(amount>0), method text not null check(method in ('efectivo','transferencia')), notes text default '', created_at timestamptz default now());
create table if not exists public.credit_requests(id bigint generated always as identity primary key, customer_id uuid not null references public.profiles(id), requested_limit numeric(12,2) not null check(requested_limit>0), status text not null default 'pendiente' check(status in ('pendiente','aprobada','rechazada')), created_at timestamptz default now(), resolved_at timestamptz);
create table if not exists public.suppliers(id bigint generated always as identity primary key, name text not null, phone text default '');
create table if not exists public.purchases(id bigint generated always as identity primary key, supplier_id bigint references public.suppliers(id), product_id bigint not null references public.products(id), quantity integer not null check(quantity>0), unit_cost numeric(12,2) not null check(unit_cost>=0), created_at timestamptz default now());
create table if not exists public.expenses(id bigint generated always as identity primary key, concept text not null, amount numeric(12,2) not null check(amount>0), category text default 'general', created_at timestamptz default now());
create table if not exists public.stock_movements(id bigint generated always as identity primary key, product_id bigint not null references public.products(id), change integer not null, reason text not null, created_at timestamptz default now());
create index if not exists idx_orders_customer on public.orders(customer_id);
create index if not exists idx_sales_customer on public.sales(customer_id);
create index if not exists idx_payments_customer on public.payments(customer_id);
create index if not exists idx_requests_customer on public.credit_requests(customer_id);

create or replace function public.new_profile() returns trigger language plpgsql security definer set search_path=public as $$
begin
 insert into public.profiles(id,full_name,email,customer_type,phone)
 values(new.id,coalesce(new.raw_user_meta_data->>'full_name',''),new.email,
 case when new.raw_user_meta_data->>'customer_type' in ('estudiante','docente','otro') then new.raw_user_meta_data->>'customer_type' else 'otro' end,
 new.raw_user_meta_data->>'phone');
 return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.new_profile();

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin');
$$;
create or replace function public.balance_for(p_customer uuid) returns numeric language sql stable security definer set search_path=public as $$
 select coalesce((select sum(total) from public.sales where customer_id=p_customer and payment_method='credito'),0)
 - coalesce((select sum(amount) from public.payments where customer_id=p_customer),0);
$$;

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.payments enable row level security;
alter table public.credit_requests enable row level security;
alter table public.suppliers enable row level security;
alter table public.purchases enable row level security;
alter table public.expenses enable row level security;
alter table public.stock_movements enable row level security;

create policy "profiles read" on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
create policy "profiles admin write" on public.profiles for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "categories read" on public.categories for select to anon,authenticated using(true);
create policy "categories admin" on public.categories for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "products read" on public.products for select to anon,authenticated using(active or public.is_admin());
create policy "products admin" on public.products for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "orders read" on public.orders for select to authenticated using(customer_id=auth.uid() or public.is_admin());
create policy "orders admin" on public.orders for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "order items read" on public.order_items for select to authenticated using(public.is_admin() or exists(select 1 from public.orders o where o.id=order_id and o.customer_id=auth.uid()));
create policy "order items admin" on public.order_items for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "sales read" on public.sales for select to authenticated using(customer_id=auth.uid() or public.is_admin());
create policy "sales admin" on public.sales for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "sale items read" on public.sale_items for select to authenticated using(public.is_admin() or exists(select 1 from public.sales s where s.id=sale_id and s.customer_id=auth.uid()));
create policy "sale items admin" on public.sale_items for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "payments read" on public.payments for select to authenticated using(customer_id=auth.uid() or public.is_admin());
create policy "payments admin" on public.payments for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "requests read" on public.credit_requests for select to authenticated using(customer_id=auth.uid() or public.is_admin());
create policy "requests admin" on public.credit_requests for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "suppliers admin" on public.suppliers for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "purchases admin" on public.purchases for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "expenses admin" on public.expenses for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "stock admin" on public.stock_movements for all to authenticated using(public.is_admin()) with check(public.is_admin());

-- Solicitudes: solo el cliente autenticado puede solicitarlas.
create or replace function public.request_credit(p_limit numeric) returns bigint language plpgsql security definer set search_path=public as $$
declare v_id bigint;
begin
 if auth.uid() is null then raise exception 'Inicia sesión'; end if;
 if p_limit<=0 or p_limit>10000000 then raise exception 'Cupo solicitado inválido'; end if;
 if exists(select 1 from public.credit_requests where customer_id=auth.uid() and status='pendiente') then raise exception 'Ya tienes una solicitud pendiente'; end if;
 insert into public.credit_requests(customer_id,requested_limit) values(auth.uid(),p_limit) returning id into v_id;
 return v_id;
end $$;

-- Pedidos: el servidor calcula precios, stock y cupo, nunca el navegador.
create or replace function public.place_order(p_items jsonb,p_method text,p_notes text default '') returns bigint language plpgsql security definer set search_path=public as $$
declare v_id bigint; v_item jsonb; v_product public.products%rowtype; v_qty int; v_total numeric:=0; v_credit public.profiles%rowtype; v_reserved int; v_qty_total int;
begin
 if auth.uid() is null then raise exception 'Inicia sesión'; end if;
 if p_method not in ('efectivo','transferencia','credito') then raise exception 'Método inválido'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 or jsonb_array_length(p_items)>30 then raise exception 'Pedido inválido'; end if;
 -- Bloqueo global por producto para evitar carreras de inventario en pedidos concurrentes.
 perform pg_advisory_xact_lock(725341);
 for v_item in select * from jsonb_array_elements(p_items) loop
   v_qty := (v_item->>'quantity')::integer;
   if v_qty<1 or v_qty>100 then raise exception 'Cantidad inválida'; end if;
   select * into v_product from public.products where id=(v_item->>'product_id')::bigint and active;
   if not found then raise exception 'Producto no disponible'; end if;
   select coalesce(sum(oi.quantity),0) into v_reserved from public.order_items oi join public.orders o on o.id=oi.order_id where oi.product_id=v_product.id and o.status in ('aceptado','preparacion','listo');
   select coalesce(sum((x->>'quantity')::int),0) into v_qty_total from jsonb_array_elements(p_items) x where (x->>'product_id')::bigint=v_product.id;
   if v_product.stock-v_reserved<v_qty_total then raise exception 'Inventario insuficiente para %',v_product.name; end if;
   v_total:=v_total+v_product.price*v_qty;
 end loop;
 if p_method='credito' then
   select * into v_credit from public.profiles where id=auth.uid();
   if not v_credit.credit_enabled or public.balance_for(auth.uid())+v_total>v_credit.credit_limit then raise exception 'Crédito no autorizado o cupo insuficiente'; end if;
 end if;
 insert into public.orders(customer_id,payment_method,total,notes) values(auth.uid(),p_method,v_total,left(coalesce(p_notes,''),500)) returning id into v_id;
 for v_item in select * from jsonb_array_elements(p_items) loop
  select * into v_product from public.products where id=(v_item->>'product_id')::bigint;
  insert into public.order_items(order_id,product_id,quantity,unit_price) values(v_id,v_product.id,(v_item->>'quantity')::int,v_product.price);
 end loop;
 return v_id;
end $$;

-- Venta directa de administrador, también se usa para registrar una entrega.
create or replace function public.register_sale(p_items jsonb,p_method text,p_customer uuid default null,p_order bigint default null,p_notes text default '') returns bigint language plpgsql security definer set search_path=public as $$
declare v_sale bigint; v_item jsonb; v_prod public.products%rowtype; v_qty int; v_total numeric:=0; v_reserved int; v_order public.orders%rowtype; v_cust public.profiles%rowtype; v_count int;
begin
 if not public.is_admin() then raise exception 'No autorizado'; end if;
 if p_method not in ('efectivo','transferencia','credito') then raise exception 'Método inválido'; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Sin productos'; end if;
 perform pg_advisory_xact_lock(725341);
 if p_order is not null then
  select * into v_order from public.orders where id=p_order for update;
  if not found or v_order.status not in ('aceptado','preparacion','listo') then raise exception 'Pedido no entregable'; end if;
  if v_order.payment_method<>p_method or v_order.customer_id is distinct from p_customer then raise exception 'Datos de pedido inconsistentes'; end if;
  if (select count(*) from public.order_items where order_id=p_order)<>jsonb_array_length(p_items) then raise exception 'Detalle de pedido inconsistente'; end if;
 end if;
 for v_item in select * from jsonb_array_elements(p_items) loop
  v_qty:=(v_item->>'quantity')::int;
  if v_qty<1 then raise exception 'Cantidad inválida'; end if;
  select * into v_prod from public.products where id=(v_item->>'product_id')::bigint for update;
  if not found or not v_prod.active then raise exception 'Producto inválido'; end if;
  select coalesce(sum(oi.quantity),0) into v_reserved from public.order_items oi join public.orders o on o.id=oi.order_id where oi.product_id=v_prod.id and o.status in ('aceptado','preparacion','listo') and (p_order is null or o.id<>p_order);
  if v_prod.stock-v_reserved < (select sum((x->>'quantity')::int) from jsonb_array_elements(p_items) x where (x->>'product_id')::bigint=v_prod.id) then raise exception 'Stock insuficiente: %',v_prod.name; end if;
  if p_order is not null then
    select count(*) into v_count from public.order_items where order_id=p_order and product_id=v_prod.id and quantity=v_qty and unit_price=v_prod.price;
    if v_count<>1 then raise exception 'El detalle o precio del pedido cambió'; end if;
  end if;
  v_total:=v_total+v_prod.price*v_qty;
 end loop;
 if p_order is not null and v_total<>v_order.total then raise exception 'Total inconsistente'; end if;
 if p_method='credito' then
  if p_customer is null then raise exception 'Selecciona cliente'; end if;
  select * into v_cust from public.profiles where id=p_customer;
  if not found or not v_cust.credit_enabled or public.balance_for(p_customer)+v_total>v_cust.credit_limit then raise exception 'Crédito no disponible'; end if;
 end if;
 insert into public.sales(order_id,customer_id,payment_method,total,notes) values(p_order,p_customer,p_method,v_total,left(coalesce(p_notes,''),500)) returning id into v_sale;
 for v_item in select * from jsonb_array_elements(p_items) loop
  select * into v_prod from public.products where id=(v_item->>'product_id')::bigint;
  v_qty:=(v_item->>'quantity')::int;
  insert into public.sale_items(sale_id,product_id,quantity,unit_price) values(v_sale,v_prod.id,v_qty,v_prod.price);
  update public.products set stock=stock-v_qty where id=v_prod.id;
  insert into public.stock_movements(product_id,change,reason) values(v_prod.id,-v_qty,'Venta #'||v_sale);
 end loop;
 if p_order is not null then update public.orders set status='entregado' where id=p_order; end if;
 return v_sale;
end $$;

create or replace function public.change_order_status(p_id bigint,p_status text) returns void language plpgsql security definer set search_path=public as $$
declare v_order public.orders%rowtype; v_item record; v_reserved int; v_stock int;
begin
 if not public.is_admin() then raise exception 'No autorizado'; end if;
 if p_status not in ('aceptado','preparacion','listo','cancelado') then raise exception 'Estado inválido'; end if;
 perform pg_advisory_xact_lock(725341);
 select * into v_order from public.orders where id=p_id for update;
 if not found or v_order.status in ('cancelado','entregado') then raise exception 'Pedido cerrado'; end if;
 if p_status='aceptado' and v_order.status<>'pendiente' then raise exception 'Transición inválida'; end if;
 if p_status='preparacion' and v_order.status<>'aceptado' then raise exception 'Transición inválida'; end if;
 if p_status='listo' and v_order.status<>'preparacion' then raise exception 'Transición inválida'; end if;
 if p_status not in ('aceptado','cancelado') and v_order.status='pendiente' then raise exception 'Primero acepta el pedido'; end if;
 if p_status='aceptado' then
  for v_item in select product_id,sum(quantity) qty from public.order_items where order_id=p_id group by product_id loop
   select stock into v_stock from public.products where id=v_item.product_id;
   select coalesce(sum(oi.quantity),0) into v_reserved from public.order_items oi join public.orders o on o.id=oi.order_id where oi.product_id=v_item.product_id and o.status in ('aceptado','preparacion','listo');
   if v_stock-v_reserved<v_item.qty then raise exception 'Inventario insuficiente'; end if;
  end loop;
 end if;
 update public.orders set status=p_status where id=p_id;
end $$;

create or replace function public.register_purchase(p_product bigint,p_quantity integer,p_cost numeric,p_supplier bigint default null) returns bigint language plpgsql security definer set search_path=public as $$
declare v_id bigint;
begin
 if not public.is_admin() then raise exception 'No autorizado'; end if;
 if p_quantity<=0 or p_cost<0 then raise exception 'Datos inválidos'; end if;
 insert into public.purchases(product_id,quantity,unit_cost,supplier_id) values(p_product,p_quantity,p_cost,p_supplier) returning id into v_id;
 update public.products set stock=stock+p_quantity,cost=p_cost where id=p_product;
 insert into public.stock_movements(product_id,change,reason) values(p_product,p_quantity,'Compra #'||v_id);
 return v_id;
end $$;
create or replace function public.register_payment(p_customer uuid,p_amount numeric,p_method text,p_notes text default '') returns bigint language plpgsql security definer set search_path=public as $$
declare v_id bigint;
begin
 if not public.is_admin() then raise exception 'No autorizado'; end if;
 if p_amount<=0 or p_method not in ('efectivo','transferencia') then raise exception 'Pago inválido'; end if;
 perform pg_advisory_xact_lock(725342);
 if p_amount>public.balance_for(p_customer) then raise exception 'El abono supera el saldo'; end if;
 insert into public.payments(customer_id,amount,method,notes) values(p_customer,p_amount,p_method,left(coalesce(p_notes,''),500)) returning id into v_id;
 return v_id;
end $$;
create or replace function public.resolve_credit(p_request bigint,p_approve boolean,p_limit numeric default 0,p_guardian_authorized boolean default false) returns void language plpgsql security definer set search_path=public as $$
declare v_req public.credit_requests%rowtype; v_type text;
begin
 if not public.is_admin() then raise exception 'No autorizado'; end if;
 select * into v_req from public.credit_requests where id=p_request and status='pendiente' for update;
 if not found then raise exception 'Solicitud no disponible'; end if;
 if p_approve then
  if p_limit<=0 then raise exception 'Cupo inválido'; end if;
  select customer_type into v_type from public.profiles where id=v_req.customer_id;
  if v_type='estudiante' and not p_guardian_authorized then raise exception 'Confirma autorización del acudiente para estudiantes menores de edad'; end if;
  update public.profiles set credit_enabled=true,credit_limit=p_limit,guardian_authorized=p_guardian_authorized where id=v_req.customer_id;
 end if;
 update public.credit_requests set status=case when p_approve then 'aprobada' else 'rechazada' end,resolved_at=now() where id=p_request;
end $$;
-- Restringir funciones expuestas: solo usuarios autenticados.
revoke execute on function public.is_admin() from public,anon;
revoke execute on function public.balance_for(uuid) from public,anon;
revoke execute on function public.request_credit(numeric) from public,anon;
revoke execute on function public.place_order(jsonb,text,text) from public,anon;
revoke execute on function public.register_sale(jsonb,text,uuid,bigint,text) from public,anon;
revoke execute on function public.change_order_status(bigint,text) from public,anon;
revoke execute on function public.register_purchase(bigint,integer,numeric,bigint) from public,anon;
revoke execute on function public.register_payment(uuid,numeric,text,text) from public,anon;
revoke execute on function public.resolve_credit(bigint,boolean,numeric,boolean) from public,anon;
grant execute on function public.is_admin(),public.balance_for(uuid),public.request_credit(numeric),public.place_order(jsonb,text,text),public.register_sale(jsonb,text,uuid,bigint,text),public.change_order_status(bigint,text),public.register_purchase(bigint,integer,numeric,bigint),public.register_payment(uuid,numeric,text,text),public.resolve_credit(bigint,boolean,numeric,boolean) to authenticated;
-- Nota: balance_for solo debe exponerse al propietario o admin: se protege adicionalmente abajo.
create or replace function public.balance_for(p_customer uuid) returns numeric language plpgsql stable security definer set search_path=public as $$
declare v_balance numeric;
begin
 if auth.uid() is null or (auth.uid()<>p_customer and not public.is_admin()) then raise exception 'No autorizado'; end if;
 select coalesce((select sum(total) from public.sales where customer_id=p_customer and payment_method='credito'),0)-coalesce((select sum(amount) from public.payments where customer_id=p_customer),0) into v_balance;
 return v_balance;
end $$;
-- Datos de ejemplo (opcional):
insert into public.categories(name) values ('Desayunos'),('Bebidas'),('Snacks'),('Otros') on conflict(name) do nothing;
-- IMPORTANTE: después de crear TU cuenta en la web, convertirla en admin manualmente:
-- update public.profiles set role='admin' where email='TU_CORREO@EJEMPLO.COM';
