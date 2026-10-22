-- OfiNails: actualización de servicios y precios
-- Ejecutar en Supabase > SQL Editor si ya habías ejecutado el esquema anterior.
-- Desactiva los servicios antiguos y crea/actualiza los 15 servicios con los precios indicados.
update public.services set active=false;

insert into public.services(name,description,price,duration_minutes) values
('Semipermanente — Manos liso','Semipermanente para manos, acabado liso.',6000,60),
('Semipermanente — Manos con diseño','Semipermanente para manos con diseño.',8000,75),
('Semipermanente — Pies','Semipermanente para pies.',5000,60),
('Recubrimiento natural — Building gel','Recubrimiento en uña natural con building gel.',14000,90),
('Recubrimiento natural — Rubber base','Recubrimiento en uña natural con rubber base.',12000,75),
('Recubrimiento natural — Gel calcio','Recubrimiento en uña natural con gel calcio.',13000,75),
('Recubrimiento natural — Polygel','Recubrimiento en uña natural con polygel.',13000,90),
('Extensión en uñas — Polygel','Extensión en uñas con polygel.',15000,120),
('Extensión en uñas — Building gel','Extensión en uñas con building gel.',15000,120),
('Extensión en uñas — Uña del pie','Extensión en uña del pie (precio por uña).',1000,30),
('Gel X — Corto o mediano','Gel X para uñas cortas o medianas.',13000,90),
('Gel X — Largo','Gel X para uñas largas.',15000,120),
('Pies — Pedi Spa','Tratamiento Pedi Spa.',18000,90),
('Retiros — Manos','Retiro de producto en manos.',2000,30),
('Retiros — Pies','Retiro de producto en pies.',1000,30)
on conflict(name) do update set description=excluded.description, price=excluded.price, duration_minutes=excluded.duration_minutes, active=true;
