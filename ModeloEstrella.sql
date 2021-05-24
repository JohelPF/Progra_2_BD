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
create unique index I_modelo_fecha on modeloestrella.fecha(anno, mes, dia);
create index I_modelo_lenguaje on modeloestrella.lenguaje(lenguaje);
create index I_modelo_duracion on modeloestrella.duracion(dias);
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
	"pelicula_id" integer,
	"lugar_id" integer,
	"fecha_id" integer,
	"lenguaje_id" integer,
	"duracion_id" integer)
LANGUAGE 'sql'
AS $BODY$
	INSERT INTO modeloestrella.prestamos(
		pelicula_id, lugar_id, fecha_id, lenguaje_id, duracion_id, cantidadalquileres, montocobrado)
		VALUES ("pelicula_id", "lugar_id", "fecha_id", "lenguaje_id", "duracion_id", 
				(select count(r.inventory_id) from rental r, inventory i, film f, modeloestrella.pelicula p 
					where 	r.inventory_id = i.inventory_id and 
							i.film_id = f.film_id and f.title = p.filme and
							p.pelicula_id = "pelicula_id"),
				(select sum(p.amount) from payment p, rental r, inventory i, film f, modeloestrella.pelicula pe
					where 	p.rental_id = r.rental_id and r.inventory_id = i.inventory_id and
						i.film_id = f.film_id and f.title = pe.filme and 
						pe.pelicula_id = "pelicula_id")
			   );
$BODY$;

drop procedure modeloestrella."Insert_Prestamos"

--Procedimientos para consultas

-- 1. Para un mes dado, sin importar el año, dar para cada categoría de película el número de alquileres realizados

-- 2. Dar el número de alquileres y el monto cobrado, por duración del préstamo
	
-- 3. Hacer un rollup por año y mes para el monto cobrado por alquileres

-- 4. Hacer un cubo por año y categoría de película para el número de alquileres y el monto cobrado
	



