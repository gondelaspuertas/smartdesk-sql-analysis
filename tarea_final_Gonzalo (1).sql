--=======================================
-- CONTEXTO
--=======================================

CREATE DATABASE if not exists MASTER_UCM;
USE DATABASE MASTER_UCM;
CREATE SCHEMA if not exists SMART_DESK;
USE SCHEMA SMART_DESK;


-- UNA VEZ PUESTO EN CONTEXTO YA PODEMOS COMENZAR A REALIZAR LA TAREA.

--========================================================================
-- PREGUNTA 1 -> Análisis de Ventas y Beneficio por Categoría de Producto
--========================================================================

-- ENUNCIADO: 

-- La dirección comercial necesita un análisis detallado del desempeño de la cuenta Adabs
-- Entertainment durante el año 2020. Se requiere un desglose completo por categoría de producto
-- que incluya todas las líneas de ingreso (mantenimiento, producto, partes y soporte), las unidades
-- vendidas y el beneficio generado.

SELECT
    category                  AS "Categoría",
    ROUND(SUM(maintenance), 2) AS "Mantenimiento",  -- redondeo a 2 decimales por ser tema económico.
    ROUND(SUM(product), 2)     AS "Producto",       --  Selecciono solo las columnas que nos pide el enunciado y lo ordenamos por categoría
    ROUND(SUM(parts), 2)       AS "Partes",
    ROUND(SUM(support), 2)     AS "Soporte",
    ROUND(SUM(total), 2)       AS "Total Ventas",
    SUM(units_sold)            AS "Unidades Vendidas",
    ROUND(SUM(profit), 2)      AS "Beneficio Total"
FROM sales
WHERE account = 'Adabs Entertainment'              -- filtro por cuenta Adabs Entertainment y año 2020
  AND year = 2020
GROUP BY category                                  -- Solo quiero una fila por categoría
ORDER BY "Total Ventas" DESC;                      -- De mayor a menor (aunque no lo pida para ver que categoría funciona mejor)





--===========================================================================
-- PREGUNTA 2 -> Comparación de Rendimiento por País en Regiones APAC y EMEA
--===========================================================================

-- ENUNCIADO: 

-- El departamento de expansión internacional requiere comparar el rendimiento medio diario de los
-- países pertenecientes a APAC y EMEA. Para evitar que los países con más registros queden
-- sobrerrepresentados, primero deberás consolidar las ventas por fecha, región y país y, a
-- continuación, calcular sus promedios diarios. Este análisis permitirá identificar mercados con mayor
-- actividad habitual y establecer benchmarks regionales comparables.


--opción 1 donde meto la "tabla" ventas diarias donde obtengo las métricas que quiero observar en las regiones APAC y EMEA

WITH ventas_diarias AS (
    SELECT
        a.region,
        a.country,
        s.date,
        SUM(s.total)      AS ingreso_dia,
        SUM(s.units_sold) AS unidades_dia,
        SUM(s.profit)     AS beneficio_dia
    FROM sales AS s
    INNER JOIN accounts AS a                   -- como SALES no cuenta con región ni país realizo un inner join junto a ACCOUNTS
        ON s.account = a.account                
    WHERE a.region IN ('APAC', 'EMEA')         -- filtro para solo quedarme con las regiones que quiero 
    GROUP BY a.region, a.country, s.date        
)                                              -- el resultado es la tabla ventas diarias, con una fila por país y día 
SELECT
    region                      AS "Región",   --selecciono las columnas deseadas y las nombro de la tabla ventas diarias
    country                     AS "País",
    ROUND(AVG(ingreso_dia), 2)   AS "Ingreso Diario Promedio",
    ROUND(AVG(unidades_dia), 2)  AS "Unidades Vendidas Diarias Promedio",
    ROUND(AVG(beneficio_dia), 2) AS "Beneficio Diario Promedio"
FROM ventas_diarias
GROUP BY region, country                        -- un fila por país ordenado de manera descendiente
ORDER BY "Región", "Ingreso Diario Promedio" DESC;



-- opción 2 que suma todo lo que ha vendido cada país y lo divide entre el número de días

SELECT
    a.region AS "Región",  -- volvemos a seleccionar de ACCOUNTS país y región que no tenemos en sales
    a.country AS "País",
    ROUND(SUM(s.total) / COUNT(DISTINCT s.date), 2)      AS "Ingreso Diario Promedio",  --obtenemos las métricas que queremos de manera más directa
    ROUND(SUM(s.units_sold) / COUNT(DISTINCT s.date), 2) AS "Unidades Vendidas Diarias Promedio",
    ROUND(SUM(s.profit) / COUNT(DISTINCT s.date), 2)     AS "Beneficio Diario Promedio"
FROM sales AS s
INNER JOIN accounts AS a
    ON s.account = a.account
WHERE a.region IN ('APAC', 'EMEA')              -- filtro para solo quedarme con las regiones que quiero 
GROUP BY a.region, a.country                    -- obtengo el mismo resultado que de la opción 1
ORDER BY "Región", "Ingreso Diario Promedio" DESC;




--==========================================================================================================
-- PREGUNTA 3 ->Beneficio Estratégico por Industria en Cuentas con Oportunidades Cercanas al Cierre en 2022
--==========================================================================================================

-- ENUNCIADO: 

-- El equipo de ventas estratégicas necesita identificar qué industrias han generado más beneficio
-- histórico entre las cuentas que actualmente tienen oportunidades en etapa Commit. Primero,
-- selecciona las cuentas cuyo importe total de FORECAST para 2022 en etapa Commit supere
-- 500.000 $. Después, calcula el beneficio histórico acumulado en SALES para cada industria.
-- Clasifica el resultado como Alto cuando el beneficio de la industria supere 1.000.000 $, o Normal en
-- caso contrario.



SELECT
    a.industry  AS industry,     -- para enseñar la industria, su beneficio y la categoría al ejecutar
    ROUND(SUM(s.profit), 2) AS total_profit,
    CASE
        WHEN SUM(s.profit) > 1000000 THEN 'Alto'        -- clasifico el profit como alto si esta por encima del millón
        ELSE 'Normal'
    END AS benefit_category
FROM sales AS s      -- se utiliza sales y accounts para el profit de sales y la industria de accounts
INNER JOIN accounts AS a
    ON s.account = a.account
WHERE s.account IN (
    SELECT account       --genero una subconsulta para ver que cuentas entran
    FROM forecast        --cojo la tabla de oportunidades comerciales y la filtro por el año 2022 en etapa commit
    WHERE year = 2022
      AND prediction_category = 'Commit'
    GROUP BY account        
    HAVING SUM(forecast) > 500000 --se queda con las cuentas cuyo total supera 500.000
)
GROUP BY a.industry  -- una fila por industria 
ORDER BY total_profit DESC;



--=============================================================
-- PREGUNTA 4 ->Análisis Trimestral Real vs Target (2019–2021)
--=============================================================

-- ENUNCIADO: 

-- La dirección financiera quiere evaluar el desempeño histórico de Smart Desk comparando los
-- resultados reales con los objetivos de TARGETS. Aunque SALES tiene granularidad diaria, la
-- comparación debe realizarse al nivel común de año y trimestre. Agrega primero las ventas y el
-- beneficio de SALES por YEAR y QUARTER y después une ese resultado con TARGETS para los
-- años 2019, 2020 y 2021. 

-- obtengo primero la tabla de ventas trimestre donde paso de diario a trimestre

WITH ventas_trimestre AS (
    SELECT
        year,
        quarter,
        SUM(total)  AS total_real_sales,    -- selecciono las métricas que me interesan
        SUM(profit) AS total_real_profit
    FROM sales
    WHERE year IN (2019, 2020, 2021)        -- filtro según los años de interés 
    GROUP BY year, quarter
)  -- unimo scon targets, ya tengo una fila por trimestre asi que no se duplica nada (3 años 4 trimestres deberia tener 12 filas)
SELECT
    v.year,
    t.quarter_of_year,
    ROUND(v.total_real_sales, 2)                    AS total_real_sales,        
    ROUND(v.total_real_profit, 2)                   AS total_real_profit,
    t.target_total,
    t.target_profit, -- real menos esperado/objetivo 
    ROUND(v.total_real_sales - t.target_total, 2)   AS variacion_ventas,
    ROUND(v.total_real_profit - t.target_profit, 2) AS variacion_beneficio
FROM ventas_trimestre AS v
INNER JOIN targets AS t
    ON v.year = t.year                  -- solo con el año cada trimestre se cruzaría con los cuatro targets
   AND v.quarter = t.quarter_of_year    
ORDER BY v.year, t.quarter_of_year;        -- por orden cronológico






--=============================================================
-- CASO PRÁCTICO -> ANÁLISIS LIBRE
--=============================================================

-- OPCIÓN 1 Efecto de las Vacaciones en el Ciclo Comercial

-- SUGERENCIAS Compara las ventas, el beneficio y las unidades medias diarias de julio y agosto con mayo y junio y
--             con septiembre y octubre. Analiza el patrón por año y segmenta por región o categoría para
--             determinar dónde es más intenso. Propón medidas de cobertura de vacaciones, planificación de
--             campañas o asignación de personal.

-- PREGUNTA DE NEGOCIO -> ¿Se reduce la actividad comercial durante julio y agosto y se produce un efecto rebote en septiembre y octubre?

-- Contexto y relevancia del análisis:
--   Smart Desk casi duplicó sus ventas entre 2019 y 2021 (de 55,0 M a 100,8 M), pero ese
--   crecimiento no es uniforme durante el año: las ventas por día de julio cayeron frente a
--   las de junio los tres años (-29,1 %, -22,4 % y -15,8 %).  datos numéricos que saldrán más adelante.


-- Por qué esta pregunta es importante para Smart Desk:
--   Si la caída de verano y la recuperación posterior son recurrentes, la empresa puede
--   anticiparse en lugar de reaccionar: organizar la cobertura comercial durante las
--   vacaciones, decidir cuándo lanzar campañas y ajustar los objetivos trimestrales a lo
--   que cabe esperar en cada momento. Si la caída se debiera a otra causa, como un cambio
--   de clientes, esas medidas no resolverían el problema. 


--===========================================
--PARTE 1
--===========================================
-- Creo una vista para no repetir el JOIN con ACCOUNTS ni el cálculo del mes en cada consulta.
-- Necesito el mes porque la pregunta compara meses y SALES no tiene esa columna.
-- La región viene de ACCOUNTS y la uso después para segmentar los resultados.
-- Uso OR REPLACE para poder volver a ejecutar el script sin que dé error.


CREATE OR REPLACE VIEW v_ventas AS
SELECT
    s.account,
    s.category,
    a.region,       
    s.date,
    s.year,
    s.quarter,
    MONTH(s.date) AS mes,
    s.support,                  -- SALES no tiene el mes y la pregunta se plantea por meses
    s.total,
    s.profit,
    s.units_sold
FROM sales AS s
INNER JOIN accounts AS a
    ON s.account = a.account;


--===========================================
--PARTE 2 -> Análisis exploratorio
--==========================================


-- 2.1 CRECIMIENTO ANUAL
-- Compruebo cuánto ha crecido Smart Desk, para situar el análisis en su contexto.
-- Como la empresa crece cada año, comparo periodos dentro de un mismo año
SELECT
    year,
    ROUND(SUM(total), 0) AS ventas_anuales,
    -- LAG trae las ventas del año anterior para calcular el crecimiento.
    ROUND((SUM(total) / LAG(SUM(total)) OVER (ORDER BY year) - 1) * 100, 1) AS crecimiento_pct
FROM sales
GROUP BY year
ORDER BY year;

-- 2.2 EVOLUCIÓN MENSUAL Y COBERTURA DE DÍAS 
--  Para conseguir más contexto analizo la evolución mensual
-- Uso ventas por día y no el total del mes, porque los meses no tienen los mismos días
-- Con el WITH calculo las ventas por día de cada mes, y con LAG las comparo.

WITH mensual AS (
    SELECT
        year,
        mes,
        SUM(total) / COUNT(DISTINCT date) AS ventas_dia,
        COUNT(DISTINCT date)              AS dias_con_ventas,
        -- Días que tiene el mes, basicamente si coincide con la columna anterior no falta ninguno
        DAY(LAST_DAY(MIN(date)))          AS dias_calendario
    FROM v_ventas
    GROUP BY year, mes
)
SELECT
    year,
    mes,
    ROUND(ventas_dia, 0) AS ventas_dia,
    -- Sin PARTITION BY se consigue que enero también se compara con el diciembre del año anterior
    ROUND((ventas_dia / LAG(ventas_dia) OVER (ORDER BY year, mes) - 1) * 100, 1) AS var_mes_anterior_pct,
    dias_con_ventas,
    dias_calendario
FROM mensual
ORDER BY year, mes;


-- 2.3 ATÍPICOS Y NULOS
-- primero tengo que ver a que considero atípico, por ejemplo más de 2 desviaciones típicas
-- contamos los nulos de una forma muy sencilla 


WITH diario AS (
    -- Primero consolido por día ya que cada día tiene varias filas una por cuenta y categoría
    SELECT
        date,
        SUM(total) AS ventas,
        -- COUNT(columna) no cuenta los NULL así que la resta da el número de nulos.
        COUNT(*) - COUNT(support) AS nulos_support
    FROM v_ventas
    GROUP BY date
),
estadisticas AS (
    SELECT
        date,
        ventas,
        nulos_support,
        -- OVER calcula la media y la desviación de toda la serie y las pone en cada fila.
        AVG(ventas) OVER () AS media_diaria,
        STDDEV(ventas) OVER () AS desviacion_diaria
    FROM diario
)
SELECT
    YEAR(date)  AS year,
    MONTH(date) AS mes,
    -- La media y la desviación son iguales en todas las filas: MAX solo sirve para mostrarlas.
    ROUND(MAX(media_diaria), 0) AS media_diaria,
    ROUND(MAX(desviacion_diaria), 0) AS desviacion_diaria,
    SUM(CASE WHEN ABS(ventas - media_diaria) > 2 * desviacion_diaria THEN 1 ELSE 0 END) AS dias_atipicos, -- sacamos los atípicos, si es mayor que 2 desviaciones 1, sino 0, y que se vayan sumando
    SUM(nulos_support) AS nulos_support
FROM estadisticas
GROUP BY YEAR(date), MONTH(date)
ORDER BY year, mes;



--2.4 COMPOSICIÓN DE LOS CLIENTES POR TRIMESTRE
-- Compruebo si las ventas cambian porque se vendan más o menos o porque compran otros clientes 

WITH combinaciones AS (
    SELECT year, quarter, account, category, COUNT(*) AS dias
    FROM v_ventas
    GROUP BY year, quarter, account, category
)
SELECT
    c.year,
    c.quarter,
    COUNT(*)                  AS combinaciones,
    COUNT(DISTINCT c.account) AS cuentas_activas,
    -- Si el mínimo y el máximo coinciden todas las combinaciones venden los mismos días.
    MIN(c.dias)               AS dias_min,
    MAX(c.dias)               AS dias_max,
    -- COUNT(p.account) solo cuenta las que han encontrado pareja en el trimestre anterior.
    COUNT(p.account)          AS repiten_trimestre_anterior
FROM combinaciones AS c
-- LEFT JOIN para conservar las combinaciones nuevas con INNER JOIN desaparecerían.
LEFT JOIN combinaciones AS p
    ON c.account = p.account
   AND c.category = p.category
   -- El índice evita el salto de año el trimestre anterior a 2020 T1 es 2019 T4.
   AND p.year * 4 + p.quarter = c.year * 4 + c.quarter - 1
GROUP BY c.year, c.quarter
ORDER BY c.year, c.quarter;

--===============================================
--PARTE 3 ->  RESPUESTA A LA PREGUNTA DE NEGOCIO
--===============================================

--3.1 COMPARACIÓN may-jun, jul-ago, sep-oct
-- Usando lag con partition by year calcula la variación frente al periodo anterior dentro de cada año
-- Limitación debido a que cada tramo incluye clientes distintos.

WITH periodos AS (
    SELECT
        year,
        -- Numeramos las etiquetas para que el orden alfabético coincida con el cronológico.
        CASE
            WHEN mes IN (5, 6) THEN '1. May-Jun'
            WHEN mes IN (7, 8) THEN '2. Jul-Ago'
            ELSE '3. Sep-Oct'
        END AS periodo,
        -- Por día, porque jul-ago tiene 62 días y los otros dos periodos, 61.
        SUM(total) / COUNT(DISTINCT date)      AS ventas_dia,
        SUM(profit) / COUNT(DISTINCT date)     AS beneficio_dia,
        SUM(units_sold) / COUNT(DISTINCT date) AS unidades_dia
    FROM v_ventas
    WHERE mes BETWEEN 5 AND 10  -- gracias a este filtro, el ELSE del CASE solo recoge sep-oct, sin el sería hasta dic.
    GROUP BY year, periodo
)
SELECT
    year,
    periodo,
    ROUND(ventas_dia, 0)    AS ventas_dia,
    ROUND(beneficio_dia, 0) AS beneficio_dia,
    ROUND(unidades_dia, 1)  AS unidades_dia,
    -- PARTITION BY year: may-jun no se compara con el sep-oct del año anterior por lo que saldrá NULL.
    -- basicamente divido el periodo actual entre el anterior y con el -1 convierto la proporcion en variación y con el *100 lo porcentualizo.
    ROUND((ventas_dia / LAG(ventas_dia) OVER (PARTITION BY year ORDER BY periodo) - 1) * 100, 1)       AS var_ventas_pct,
    ROUND((beneficio_dia / LAG(beneficio_dia) OVER (PARTITION BY year ORDER BY periodo) - 1) * 100, 1) AS var_beneficio_pct,
    ROUND((unidades_dia / LAG(unidades_dia) OVER (PARTITION BY year ORDER BY periodo) - 1) * 100, 1)   AS var_unidades_pct
FROM periodos
ORDER BY year, periodo;

--3.2 julio-agosto FRENTE A septiembre con las mismas cuentas
--  Como los tres meses son del t3 nos garantiza que los clientes sean los mismos y sea una comparación limpia. realizo lo mismo que en el 3.1.


WITH tramos AS (
    SELECT
        year,
        -- Etiquetas numeradas para que LAG siga el orden cronológico.
        CASE WHEN mes IN (7, 8) THEN '1. Jul-Ago' ELSE '2. Septiembre' END AS tramo,
        SUM(total) / COUNT(DISTINCT date)      AS ventas_dia,
        SUM(profit) / COUNT(DISTINCT date)     AS beneficio_dia,
        SUM(units_sold) / COUNT(DISTINCT date) AS unidades_dia
    FROM v_ventas
    WHERE quarter = 3  -- el filtro clave dentro del T3 no cambian los clientes
    GROUP BY year, tramo
)
SELECT
    year,
    tramo,
    ROUND(ventas_dia, 0)    AS ventas_dia,
    ROUND(beneficio_dia, 0) AS beneficio_dia,
    ROUND(unidades_dia, 1)  AS unidades_dia,
    -- Ventas, beneficio y unidades por separado para ver si la subida es de volumen o de precio.
    ROUND((ventas_dia / LAG(ventas_dia) OVER (PARTITION BY year ORDER BY tramo) - 1) * 100, 1)       AS var_ventas_pct,
    ROUND((beneficio_dia / LAG(beneficio_dia) OVER (PARTITION BY year ORDER BY tramo) - 1) * 100, 1) AS var_beneficio_pct,
    ROUND((unidades_dia / LAG(unidades_dia) OVER (PARTITION BY year ORDER BY tramo) - 1) * 100, 1)   AS var_unidades_pct
FROM tramos
ORDER BY year, tramo;


--3.3 COMPARACIÓN DE T3 RESPECTO EL RESTO DE TRIMESTRES
--Las ventas pueden subir a lo largo de cualquier trimestre, por lo que la subida de septiembre no nos diría mucha información
-- sobre el verano, asi que comparamos el primer y último mes de cada trimestre, siempre con los mismos clientes.

WITH mensual AS (
    SELECT
        year,
        quarter,
        mes,
        SUM(total) / COUNT(DISTINCT date) AS ventas_dia
    FROM v_ventas
    GROUP BY year, quarter, mes
),
rampa AS (
    SELECT
        year,
        quarter,
        mes,
        ventas_dia,
        -- Partimos por año y trimestre cada trimestre se compara solo consigo mismo.
        FIRST_VALUE(ventas_dia) OVER (PARTITION BY year, quarter ORDER BY mes) AS primer_mes
    FROM mensual
)
SELECT
    year,
    quarter,
    ROUND(primer_mes, 0) AS ventas_dia_primer_mes,
    ROUND(ventas_dia, 0) AS ventas_dia_ultimo_mes,
    ROUND((ventas_dia / primer_mes - 1) * 100, 1) AS subida_pct,
    -- Por trimestre del año (T1, T2...) media de los tres años para no depender de uno solo.
    ROUND(AVG((ventas_dia / primer_mes - 1) * 100) OVER (PARTITION BY quarter), 1) AS subida_media_trimestre_pct
FROM rampa
WHERE MOD(mes, 3) = 0  -- nos quedamos con el último mes de cada trimestre
ORDER BY year, quarter;

--3.4 DONDE ES MÁS INTENSO?¿?¿?
-- Repito la comparación de 3.2 por región y por categoría, con el número de
-- combinaciones de cada segmento es decir con pocas, un solo cliente puede mover el resultado.


-- UNION ALL apila las dos segmentaciones para calcularlas con la misma lógica.
WITH base AS (
    SELECT 'Región' AS dimension, region AS segmento, year, mes, account, category, date, total
    FROM v_ventas
    WHERE quarter = 3  -- solo el T3 para mantener a los mismos clientes
    UNION ALL
    SELECT 'Categoría', category, year, mes, account, category, date, total
    FROM v_ventas
    WHERE quarter = 3
),
tramos AS (
    SELECT
        dimension,
        segmento,
        year,
        -- Tamaño del segmento indica cuánta confianza merece cada porcentaje.
        COUNT(DISTINCT account, category) AS combinaciones,
        -- CASE dentro de SUM para tener los dos tramos en la misma fila y poder dividirlos.
        SUM(CASE WHEN mes IN (7, 8) THEN total END)
            / COUNT(DISTINCT CASE WHEN mes IN (7, 8) THEN date END) AS ventas_dia_jul_ago,
        SUM(CASE WHEN mes = 9 THEN total END)
            / COUNT(DISTINCT CASE WHEN mes = 9 THEN date END)AS ventas_dia_septiembre
    FROM base
    GROUP BY dimension, segmento, year
)
SELECT
    dimension,
    segmento,
    year,
    combinaciones,
    ROUND(ventas_dia_jul_ago, 0)    AS ventas_dia_jul_ago,
    ROUND(ventas_dia_septiembre, 0) AS ventas_dia_septiembre,
    ROUND((ventas_dia_septiembre / ventas_dia_jul_ago - 1) * 100, 1) AS subida_pct
FROM tramos
ORDER BY dimension, segmento, year;


