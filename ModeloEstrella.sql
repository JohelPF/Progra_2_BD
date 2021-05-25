create schema ModeloEstrella

--Creación de tablas

CREATE TABLE modeloestrella.Pelicula (
    pelicula_id integer GENERATED ALWAYS AS IDENTITY Primary key,
    filme character varying(255) NOT NULL,
    categoria character varying(25) NOT NULL
);

CREATE TABLE modeloestrella.Lugar (
    lugar_id integer GENERATED ALWAYS AS IDENTITY Primary key,
    pais character varying(50) NOT NULL,
    ciudad character varying(50) NOT NULL,
	tienda integer not null
);

CREATE TABLE modeloestrella.Fecha (
    fecha_id integer GENERATED ALWAYS AS IDENTITY Primary key,
    anno integer not null,
    mes integer not null,
	dia integer not null
);

CREATE TABLE modeloestrella.Lenguaje (
    lenguaje_id integer GENERATED ALWAYS AS IDENTITY Primary key,
    lenguaje character varying(20) NOT NULL
);

CREATE TABLE modeloestrella.Duracion (
    duracion_id integer GENERATED ALWAYS AS IDENTITY Primary key,
	fechaPrestamo timestamp,
	fechaDevolucion timestamp,
    dias numeric(10, 2)
);

CREATE TABLE modeloestrella.Prestamos (
	pelicula_id integer REFERENCES modeloestrella.Pelicula (pelicula_id),
	lugar_id integer REFERENCES modeloestrella.Lugar (lugar_id),
	fecha_id integer REFERENCES modeloestrella.Fecha (fecha_id),
	lenguaje_id integer REFERENCES modeloestrella.Lenguaje (lenguaje_id),
    duracion_id integer REFERENCES modeloestrella.Duracion (duracion_id),
    cantidadAlquileres integer not null,
	montoCobrado numeric(10,2) not null
);

ALTER TABLE modeloestrella.Prestamos
	ADD CONSTRAINT fk_modelo_pelicula FOREIGN KEY (pelicula_id) REFERENCES modeloestrella.Pelicula (pelicula_id),
	ADD CONSTRAINT fk_modelo_lugar FOREIGN KEY (lugar_id) REFERENCES modeloestrella.Lugar (lugar_id),
	ADD CONSTRAINT fk_modelo_fecha FOREIGN KEY (fecha_id) REFERENCES modeloestrella.Fecha (fecha_id),
	ADD CONSTRAINT fk_modelo_lenguaje FOREIGN KEY (lenguaje_id) REFERENCES modeloestrella.Lenguaje (lenguaje_id),
	ADD CONSTRAINT fk_modelo_duracion FOREIGN KEY (duracion_id) REFERENCES modeloestrella.Duracion (duracion_id);

--Indices

create index I_modelo_pelicula on modeloestrella.pelicula(filme);
create index I_modelo_lugar on modeloestrella.lugar(tienda);
create index I_modelo_fecha_mes on modeloestrella.fecha(mes);
create unique index I_modelo_fecha on modeloestrella.fecha(anno, mes, dia);
create index I_modelo_lenguaje on modeloestrella.lenguaje(lenguaje);
create index I_modelo_duracion on modeloestrella.duracion(dias);
create index I_modelo_duracion2 on modeloestrella.duracion(fechaprestamo, fechadevolucion);
create index I_modelo_prestamos on modeloestrella.prestamos(pelicula_id, lugar_id);

--Inserts

CREATE PROCEDURE modeloestrella."Insert_Pelicula"()
    LANGUAGE sql
    AS $$
	INSERT INTO modeloestrella.pelicula(filme, categoria)
		select f.title, c.name from film f, category c, film_category fc
		where f.film_id = fc.film_id and fc.category_id = c.category_id;
$$;

CREATE PROCEDURE modeloestrella."Insert_Lugar"()
    LANGUAGE sql
    AS $$
	INSERT INTO modeloestrella.lugar(pais, ciudad, tienda)
		select co.country, ci.city, s.store_id from store s, address a, city ci, country co
		where s.address_id = a.address_id and a.city_id = ci.city_id and ci.country_id = co.country_id;
$$;

CREATE PROCEDURE modeloestrella."Insert_Fecha"()
    LANGUAGE sql
    AS $$
	INSERT INTO modeloestrella.fecha(anno, mes, dia)
		select distinct date_part('year', rental_date), 
				date_part('month', rental_date), 
				date_part('day', rental_date) 
		from rental
$$;
	
CREATE PROCEDURE modeloestrella."Insert_Lenguaje"()
    LANGUAGE sql
    AS $$
	INSERT INTO modeloestrella.lenguaje(lenguaje)
		select name from language
$$;

CREATE PROCEDURE modeloestrella."Insert_Duracion"()
    LANGUAGE sql
    AS $$
	INSERT INTO modeloestrella.duracion(fechaPrestamo, fechaDevolucion, dias)
		select 
			rental_date,
			return_date,
			(EXTRACT(EPOCH FROM (return_date - rental_date))/60/60/24)
		from rental
$$;

CREATE OR REPLACE PROCEDURE modeloestrella."Insert_Prestamos"(
	pelicula_id integer,
	lugar_id integer,
	fecha_id integer,
	lenguaje_id integer,
	duracion_id integer)
LANGUAGE 'sql'
AS $BODY$
	INSERT INTO modeloestrella.prestamos(
		pelicula_id, lugar_id, fecha_id, lenguaje_id, duracion_id, cantidadalquileres, montocobrado)
		VALUES ("pelicula_id", "lugar_id", "fecha_id", "lenguaje_id", "duracion_id", 
				(select count(r.inventory_id) from rental r
					inner join inventory i
					on r.inventory_id = i.inventory_id
					inner join film f
					on i.film_id = f.film_id
					inner join modeloestrella.pelicula p 
					on f.title = p.filme
					where p.pelicula_id = pelicula_id),
				(select sum(p.amount) from payment p, rental r, inventory i, film f, modeloestrella.pelicula pe
					where 	p.rental_id = r.rental_id and r.inventory_id = i.inventory_id and
						i.film_id = f.film_id and f.title = pe.filme and 
						pe.pelicula_id = "pelicula_id")
			   );
$BODY$;

CREATE OR REPLACE FUNCTION modeloestrella.Insert_Prestamos() RETURNS VOID AS
$BODY$
DECLARE
    reg RECORD;
    cur CURSOR FOR SELECT * FROM rental;
BEGIN
   OPEN cur;
   LOOP
    FETCH cur INTO reg;
    EXIT WHEN NOT FOUND;
	INSERT INTO modeloestrella.prestamos(
		pelicula_id, lugar_id, fecha_id, lenguaje_id, duracion_id, cantidadalquileres, montocobrado)
		VALUES (--Pelicula
				(select p.pelicula_id from modeloestrella.pelicula p 
					inner join film f on f.title = p.filme
					inner join inventory i on f.film_id = i.film_id 
					inner join rental r on r.inventory_id = i.inventory_id
					where r.rental_id = reg.rental_id), 
				--Lugar
				(select l.lugar_id from modeloestrella.lugar l 
					inner join inventory i on i.store_id = l.tienda
					inner join rental r on r.inventory_id = i.inventory_id
					where r.rental_id = reg.rental_id),
				--Fecha
				(select f.fecha_id from modeloestrella.fecha f 
					where (SELECT EXTRACT(day FROM rental_date) from rental r 
							where r.rental_id = reg.rental_id) = f.dia and
							(SELECT EXTRACT(month FROM rental_date) from rental r 
							where r.rental_id = reg.rental_id) = f.mes and
							(SELECT EXTRACT(year FROM rental_date) from rental r 
							where r.rental_id = reg.rental_id) = f.anno), 
				--Lenguaje
				(select l.lenguaje_id from modeloestrella.lenguaje l 
					inner join language la on la.name = l.lenguaje
					inner join film f on f.language_id = la.language_id
					inner join inventory i on i.film_id = f.film_id
					inner join rental r on r.inventory_id = i.inventory_id
					where r.rental_id = reg.rental_id),
				--Duracion
				(select d.duracion_id from modeloestrella.duracion d
					inner join rental r on r.rental_date = d.fechaprestamo and r.return_date = d.fechadevolucion 
					where r.rental_id = reg.rental_id),
				--Cantidad de alquileres con la misma pelicula
				(select count(r.inventory_id) from rental r
					 inner join inventory i on r.inventory_id = i.inventory_id
					 inner join film f on f.film_id = i.film_id
						where f.film_id = (select film_id from inventory i 
											inner join rental r on r.inventory_id = i.inventory_id
											where r.rental_id = reg.rental_id)), 
				-- Monto cobrado por alquileres de la misma pelicula
				(select sum(amount) from payment p
					inner join rental r on p.rental_id = r.rental_id
					inner join inventory i on r.inventory_id = i.inventory_id
					inner join film f on f.film_id = i.film_id
					where f.film_id = (select film_id from inventory i 
										inner join rental r on r.inventory_id = i.inventory_id
										where r.rental_id = reg.rental_id))
		);
   END LOOP;
   RETURN;
END
$BODY$
LANGUAGE 'plpgsql';

SELECT modeloestrella.Insert_Prestamos()

--Procedimientos para consultas

-- 1. Para un mes dado, sin importar el año, dar para cada categoría de película el número de alquileres realizados
CREATE OR REPLACE PROCEDURE modeloestrella."Consulta1"(mes integer)
LANGUAGE 'sql'
AS $BODY$
	select f.mes, p.categoria, pre.cantidadalquileres from modeloestrella.fecha f
		inner join modeloestrella.prestamos pre on pre.fecha_id = f.fecha_id
		inner  join modeloestrella.pelicula p on pre.pelicula_id = p.pelicula_id
		where f.mes = 5
	group by f.mes, p.categoria, pre.cantidadalquileres 
	order by f.mes, p.categoria;
$BODY$;

CALL "modeloestrella"."Consulta1"(3)

-- 2. Dar el número de alquileres y el monto cobrado, por duración del préstamo
CREATE OR REPLACE PROCEDURE modeloestrella."Consulta2"()
LANGUAGE 'sql'
AS $BODY$
	select d.dias, p.cantidadAlquileres, p.montoCobrado  from modeloestrella.duracion d
		inner join modeloestrella.prestamos p on p.duracion_id = d.duracion_id
	group by d.dias, p.cantidadAlquileres, p.montoCobrado
	order by d.dias;
$BODY$;

CALL "modeloestrella"."Consulta2"()

-- 3. Hacer un rollup por año y mes para el monto cobrado por alquileres
CREATE OR REPLACE PROCEDURE modeloestrella."Consulta3"()
LANGUAGE 'sql'
AS $BODY$
	select f.anno, f.mes, p.montoCobrado from modeloestrella.fecha f
		inner join modeloestrella.prestamos p on p.fecha_id = f.fecha_id
	group by rollup(f.anno, f.mes),p.montoCobrado
	order by f.anno, f.mes, p.montoCobrado;
$BODY$;

CALL "modeloestrella"."Consulta3"()

-- 4. Hacer un cubo por año y categoría de película para el número de alquileres y el monto cobrado
CREATE OR REPLACE PROCEDURE modeloestrella."Consulta4"()
LANGUAGE 'sql'
AS $BODY$
	select f.anno, p.categoria, pre.cantidadalquileres, pre.montoCobrado from modeloestrella.fecha f
		inner join modeloestrella.prestamos pre on pre.fecha_id = f.fecha_id
		inner  join modeloestrella.pelicula p on pre.pelicula_id = p.pelicula_id
	group by cube(f.anno, p.categoria),pre.cantidadalquileres, pre.montoCobrado
	order by f.anno, p.categoria;
$BODY$;	

CALL "modeloestrella"."Consulta4"()











