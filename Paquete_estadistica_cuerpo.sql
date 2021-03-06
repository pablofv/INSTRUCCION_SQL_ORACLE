create or replace package body est_paquete as
/****************************************************/
/*          GENERAR_EST_CAMBIO_ASIGNACION           */
/****************************************************/
    procedure generar_est_cambio_asignacion(v_fechaDesde in timestamp, v_fechaHasta in timestamp, id_cam in int) as
      v_proceso varchar2(30) := 'generar_est_cambio_asignacion';
      v_inicio timestamp := systimestamp;
      v_fin timestamp;
    begin
        delete from est_cambio_asignacion_exp;
        commit; -- por si quedaron datos anteriores

        insert into est_cambio_asignacion_exp(N_FILA, TABLADESDE, ID_EXPEDIENTE, ID_OFICINA, ID_SECRETARIA, FECHA_ASIGNACION, CODIGO_TIPO_CAMBIO_ASIGNACION, ID_CAMBIO_ASIGNACION_EXP, ANIO_EXP, NUMERO_EXP)
        select *
        from (select ROW_NUMBER() over(partition by c.ID_EXPEDIENTE, est_busca_juzgado(c.id_oficina) order by FECHA_ASIGNACION, ID_CAMBIO_ASIGNACION_EXP, tabladesde) n_fila,
                     TABLADESDE, c.ID_EXPEDIENTE, c.ID_OFICINA, ID_SECRETARIA, FECHA_ASIGNACION, CODIGO_TIPO_CAMBIO_ASIGNACION, ID_CAMBIO_ASIGNACION_EXP, ANIO_EXPEDIENTE, NUMERO_EXPEDIENTE
              from (select COMENTARIOS, 1 tabladesde, c1.ID_EXPEDIENTE, c1.ID_OFICINA, c1.id_secretaria, c1.FECHA_ASIGNACION, c1.CODIGO_TIPO_CAMBIO_ASIGNACION, c1.ID_CAMBIO_ASIGNACION_EXP, c1.status
                    from CAMBIO_ASIGNACION_EXP c1
                    union all
                    select NULL, 2, a.ID_EXPEDIENTE, a.ID_OFICINA, a.id_secretaria, a.FECHA_actuacion, ee.codigo_estado_expediente, a.ID_actuacion_EXP, a.status
                    from actuacion_exp a join estado_Expediente ee on a.id_estado_expediente = ee.id_estado_expediente
                    where ee.codigo_estado_expediente = 'REI') c
              JOIN EXPEDIENTE e on e.status = 0 and e.ID_EXPEDIENTE = c.ID_EXPEDIENTE and e.NATURALEZA_EXPEDIENTE in ('P')
              JOIN OFICINA o on c.ID_OFICINA = o.ID_OFICINA
              where c.status = 0
              and o.ID_TIPO_INSTANCIA = 1
              and o.ID_CAMARA in (id_cam)
              and O.ID_TIPO_OFICINA IN (1,2)
              and not (fecha_asignacion = to_timestamp('01/03/2017 12:00:00,000000000 AM', 'DD/MM/YYYY HH12:MI:SS,FF AM')
                                 and    C.comentarios = 'POR ACORDADA 1/2017 CSJN') --No quiero las falsas asignaciones
              order by id_expediente, fecha_asignacion
        ) where trunc(fecha_asignacion) between v_fechaDesde and v_fechaHasta;
        commit;
        v_fin := systimestamp;
        inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    exception
      when others then
          rollback;
          inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
          v_fin := systimestamp;
          inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    end generar_est_cambio_asignacion;

/****************************************************/
/*            GENERAR_EST_ACTUACION_EXP             */
/****************************************************/
  procedure generar_est_actuacion_exp(v_fechaDesde in timestamp, v_fechaHasta in timestamp, id_cam in int) as
      v_proceso varchar2(30) := 'GENERAR_EST_ACTUACION_EXP';
      v_inicio timestamp := systimestamp;
      v_fin timestamp;
  begin
      delete from est_actuacion_exp;
      commit;

      /* C�DIGOS DE SALIDA DE LAS CAUSAS DEL PER�ODO */
      insert into est_actuacion_exp(origen_dato, num_consulta, radicacion, id_actuacion_exp, fecha_actuacion, codigo, id_oficina, id_expediente, id_expediente_origen)
      select 'codigos_salida' origen_dato, 1, null radicacion, a.id_actuacion_exp, a.fecha_actuacion, ee.codigo_estado_expediente as codigo, est_busca_juzgado(a.id_oficina), a.id_expediente, e.id_expediente_origen
      from actuacion_exp a join estado_expediente ee on a.id_estado_expediente = ee.id_estado_expediente
                           join expediente e on a.id_expediente = e.id_expediente
      where ee.CODIGO_ESTADO_EXPEDIENTE in (select codigo from est_codigos_salida where camara = id_cam)
      and   a.id_expediente in (select ta_idexp
                                from est_total_a ta
                                where a.id_expediente = ta.ta_idexp
                                and   ta.ta_numero_estadistica = v_numero_estadistica -- quiero solo la estad�stica actual en proceso
                                and   ta_finalizo = 1 -- quiero solo las causas que siguen activas
                                and   ta_camara = id_cam)
      and   trunc(a.fecha_actuacion) between v_fechaDesde and v_fechaHasta;
      commit;

      /* C�DIGOS ETO DE LAS CAUSAS DEL PER�ODO */
      insert into est_actuacion_exp(origen_dato, num_consulta, radicacion, id_actuacion_exp, fecha_actuacion, codigo, id_oficina, id_expediente, id_expediente_origen)
      select 'c�digos_ETO' origen_dato, 2, null radicacion, a.id_actuacion_exp, a.fecha_actuacion, ee.codigo_estado_expediente as codigo, est_busca_juzgado(a.id_oficina), a.id_expediente, e.id_expediente_origen
      from actuacion_exp a join estado_expediente ee on a.id_estado_expediente = ee.id_estado_expediente
                           join expediente e on a.id_expediente = e.id_expediente
      where ee.CODIGO_ESTADO_EXPEDIENTE in ('ETO')
      and   a.id_expediente in (select e1.id_expediente
                                from est_total_a ta, expediente e1
                                where ta.ta_idexp in (e1.id_expediente, e1.id_expediente_origen)
                                and   ta.ta_numero_estadistica = v_numero_estadistica -- quiero solo la estad�stica actual en proceso
                                and   ta_finalizo = 1 -- quiero solo las causas que siguen activas
                                and   ta_camara = id_cam)
      and   trunc(a.fecha_actuacion) between v_fechaDesde and v_fechaHasta;
      commit;

      /* ASIGNACIONES ETO DE LAS CAUSAS DEL PER�ODO */
      insert into est_actuacion_exp(origen_dato, num_consulta, radicacion, id_actuacion_exp, fecha_actuacion, codigo, id_oficina, id_expediente, id_expediente_origen)
      select 'asignaciones_ETO', 3, c.tipo_radicacion, c.id_cambio_asignacion_exp, c.fecha_asignacion, c.codigo_tipo_cambio_asignacion as codigo, c.id_oficina, e.id_expediente, id_expediente_origen
      from cambio_asignacion_exp c join expediente e on c.id_expediente = e.id_expediente
      where c.CODIGO_TIPO_CAMBIO_ASIGNACION in ('ETO')
      and   c.id_expediente in (select e1.id_expediente
                                from est_total_a ta, expediente e1
                                where ta.ta_idexp in (e1.id_expediente, e1.id_expediente_origen)
                                and   ta.ta_numero_estadistica = v_numero_estadistica -- quiero solo la estad�stica actual en proceso
                                and   ta_finalizo = 1 -- quiero solo las causas que siguen activas
                                and   ta_camara = id_cam)
      and   trunc(c.fecha_asignacion) between v_fechaDesde and v_fechaHasta;
      commit;

      /* CIERRE MASIVO DE CAUSAS */
      insert into est_actuacion_exp(origen_dato, num_consulta, radicacion, id_actuacion_exp, fecha_actuacion, codigo, id_oficina, id_expediente, id_expediente_origen)
      select 'cierre_masivo', 4, null, i.id_informacion, i.fecha_informacion, ti.codigo_tipo_informacion,
                                            est_busca_juzgado((select id_oficina
                                                              from actuacion_exp a
                                                              where a.id_informacion = i.id_informacion
                                                              group by id_oficina)), i.id_expediente, e.id_expediente_origen
      from informacion i join tipo_informacion ti on i.id_tipo_informacion = ti.id_tipo_informacion
                         join expediente e on i.id_expediente = e.id_expediente
      where ti.codigo_tipo_informacion = 'CMC' -- CMC CIERRE MASIVO DE CAUSAS, id 241 -- i.id_tipo_informacion = 241
      and   i.id_expediente in (select ta_idexp
                                from est_total_a ta
                                where i.id_expediente = ta.ta_idexp
                                and   ta.ta_numero_estadistica = v_numero_estadistica -- quiero solo la estad�stica actual en proceso
                                and   ta_finalizo = 1 -- quiero solo las causas que siguen activas
                                and   ta_camara = id_cam)
      and   trunc(i.fecha_informacion) between v_fechaDesde and v_fechaHasta;
      commit;

      v_fin := systimestamp;
      inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
  exception
      when others then
          rollback;
          inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
          v_fin := systimestamp;
          inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    end GENERAR_EST_ACTUACION_EXP;

/****************************************************/
/*                  SALDO_AL_INICIO                 */
/****************************************************/

    procedure saldo_al_inicio(v_fechahasta in timestamp, id_cam in int) as
      v_proceso varchar2(30) := 'saldo_al_inicio';
      v_inicio timestamp := systimestamp;
      v_fin timestamp;
    begin
        /* Calculo los existentes en base a la consulta de ingresados base, eligiendo la c�mara 8, particiono por expediente y oficina,
        y ordeno la fecha descendente, para que rn = 1 sea el �ltimo ingreso previo al a�o que quiera considerar -por ahora inicio de 2012-
        para luego a todos esos registros buscarle un c�digo de salida posterior */
        INSERT INTO LEX100MAESTRAS.EST_TOTAL_A(TA_IDEXP, TA_RN, TA_ANIO_EXP, TA_NUMERO_EXP, TA_OFICINA, TA_FECHA, TA_CODIGO, TA_OBJETO,
                                           TA_FINALIZO, -- 0 -> fuera de tr�mite 1 -> en tr�mite
                                           TA_IDTABLAORIGEN, TA_TABLAORIGEN, -- 1 -> cambio_asignacion 2 -> actuacion_exp
                                           TA_TIPO_DE_DATO, -- 0 -> existente 1 -> ingresado 2 -> reingresados
                                           TA_FECHA_PROCESO, TA_NUMERO_DE_EJECUCION, TA_NUMERO_ESTADISTICA, TA_MATERIA, TA_CAMARA)
        SELECT idexp, rn, anio, numExp, id_juzgado, fecha_asignacion, codigo, objeto,
                1, /* -> finalizo originalmente est� en 1 (quiere decir en tr�mite) y luego si la considero salida actualizo a 0 que es fuera de tr�mite */
                ID_CAMBIO_ASIGNACION_EXP, tabladesde,
                0,
                v_inicio, v_numero_de_ejecucion, v_numero_estadistica, id_materia, id_cam
        from (select ROW_NUMBER() over(partition by c.ID_EXPEDIENTE, est_ofi_o_ofi_sup(case when id_secretaria is null then c.id_oficina else c.id_secretaria end) order by FECHA_ASIGNACION desc, ID_CAMBIO_ASIGNACION_EXP, tabladesde) rn,  -- Particiona por Expte y Oficina ordenado por fecha de asignaci�n, si la fecha es igual que ordene por id de la tabla proveniente
                     e.id_expediente idexp,
                     e.ANIO_EXPEDIENTE anio,
                     e.NUMERO_EXPEDIENTE numExp,
                     e.id_materia,
                     est_ofi_o_ofi_sup(case when id_secretaria is null then c.id_oficina else c.id_secretaria end) id_juzgado,
                     c.FECHA_ASIGNACION,
                     c.CODIGO_TIPO_CAMBIO_ASIGNACION codigo,
                     null objeto,
                     c.tabladesde,
                     c.ID_CAMBIO_ASIGNACION_EXP
              from (select 1 tabladesde, c1.ID_EXPEDIENTE, c1.ID_OFICINA, c1.id_secretaria, c1.FECHA_ASIGNACION, c1.CODIGO_TIPO_CAMBIO_ASIGNACION, c1.ID_CAMBIO_ASIGNACION_EXP, c1.status
                    from CAMBIO_ASIGNACION_EXP c1
                    union all
                    select 2, a.ID_EXPEDIENTE, a.ID_OFICINA, a.id_secretaria, a.FECHA_actuacion, ee.codigo_estado_expediente, a.ID_actuacion_EXP, a.status
                    from actuacion_exp a join estado_Expediente ee on a.id_estado_expediente = ee.id_estado_expediente
                    where ee.codigo_estado_expediente = 'REI') c
              JOIN EXPEDIENTE e on e.status = 0 and e.ID_EXPEDIENTE = c.ID_EXPEDIENTE and e.NATURALEZA_EXPEDIENTE in ('P')
              JOIN OFICINA o on c.ID_OFICINA = o.ID_OFICINA
              where c.status = 0
              and o.ID_TIPO_INSTANCIA = 1
              and o.ID_CAMARA in (id_cam)
              and O.ID_TIPO_OFICINA IN (1,2) -- Toma solo los Juzgados y Secretar�as.
             )
        where rn = 1
        and   trunc(FECHA_ASIGNACION) < v_fechahasta;
        commit;

        /*Ahora que ya tengo los �ltimos ingresos anteriores a la fecha buscada, me fijo cuantos de esos expedientes tienen luego de esa fecha    */
        /*Y antes de la fecha indicada (por ej. si buscamos 2012, busco salidas entre la fecha del ingreso -que todos son anteriores a dicho a�o- */
        /*y el inicio de dicho a�o) un c�digo de salida, y a esos los elimino -porque considero que al iniciar el per�odo est�n fuera de tr�mite  */
        delete from est_total_a e
        where ta_tipo_de_dato = 0
        and   TA_numero_de_ejecucion = v_numero_de_ejecucion
        and   exists (select 1
                      from actuacion_exp a join ESTADO_EXPEDIENTE ee on a.ID_ESTADO_EXPEDIENTE = ee.ID_ESTADO_EXPEDIENTE
                      where e.TA_IDEXP = a.id_expediente
                      and   ee.CODIGO_ESTADO_EXPEDIENTE in (select codigo from est_codigos_salida where camara = id_cam)
                      and   a.FECHA_ACTUACION > e.TA_FECHA
                      and   a.fecha_actuacion < v_fechahasta
                      union all
                      /* busco que los expedientes que estoy considerando, sean expediente origen de otro, con lo cual ese es un nuevo expediente */
                      /* que representa un ingreso a TO para el primer expediente, pero el sistema les da distintos id, y me sirve para dar fin a */
                      /* la causa "madre" */
                      select 1 
                      from expediente x join actuacion_exp a on (x.id_expediente = a.id_expediente or x.id_expediente_origen = a.id_expediente)
                      join estado_expediente ee on a.id_estado_expediente = ee.id_estado_expediente
                      where e.ta_idexp in(x.ID_EXPEDIENTE_ORIGEN, x.id_expediente) 
                      and   ee.CODIGO_ESTADO_EXPEDIENTE in ('ETO')
                      and   a.FECHA_ACTUACION > e.TA_FECHA
                      and   a.fecha_actuacion < v_fechahasta);
        commit;
        v_fin := systimestamp;
        inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    exception
        when others then
          rollback;
          inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
          v_fin := systimestamp;
          inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    end saldo_al_inicio;


/*******************************************************************/
/*                     AGREGAR SALDO MULTIBASE                     */
/*******************************************************************/
  procedure saldo_multibase(v_camara in int, v_numero_ejecucion in int, v_numero_estadistica in int) as
    v_proceso varchar2(30) := 'saldo_multibase';
    v_inicio timestamp := systimestamp;
    v_fin timestamp;
    v_materia int := 9;
    v_clave_antes_commit int;
    v_clave_despues_commit int;
  begin
    insert into est_total_a(TA_ANIO_EXP,
                            TA_CAMARA,
                            TA_CODIGO,
                            TA_FECHA,
                            TA_FECHA_DE_FINALIZACION,
                            TA_FECHA_PROCESO,
                            TA_FINALIZO,
                            TA_IDEXP,
                            TA_IDTABLAORIGEN,
                            TA_MATERIA,
                            TA_NUMERO_DE_EJECUCION,
                            TA_NUMERO_ESTADISTICA,
                            TA_NUMERO_EXP,
                            TA_OBJETO,
                            TA_OFICINA,
                            TA_RN,
                            TA_TABLAORIGEN,
                            TA_TIPO_DE_DATO)
    select anode, --ta_anio_exp
            v_camara, --ta_camara
            codigo_tipo_cambio_asignacion, --ta_codigo
            to_timestamp('31/12/2012 23:59:59,999999', 'DD/MM/YYYY HH24:MI:SS,FF'),--ta_fecha
            null, --ta_fecha_de_finalizacion
            systimestamp, --ta_fecha_proceso
            1, --ta_finalizo
            d.id_expediente, --ta_idexp
            id_cambio_asignacion_exp, --ta_idtablaorigen
            v_materia, --ta_materia
            v_numero_ejecucion, --ta_numero_ejecucion
            v_numero_estadistica, --ta_numero_de_estadistica
            numdem, --ta_numero_exp
            null, --ta_objdem
            d.id_oficina, --ta_oficina
            1, --ta_rn
            1, --ta_tablaorigen ESTO DEBE CAMBIARSE, PARA DISCRIMINAR LOS 3 REGISTROS QUE VIENEN DE OFICINA_EXP DE LOS DEM�S QUE SON DE CAMBIO
            0 --TA_TIPO_DE_DATO
    from EST_SQLSRV_DEFINITIVO d join est_saldo_sql s on d.id_expediente = s.id_expediente;
    select max(ta_clave) into v_clave_antes_commit from est_total_a where ta_numero_estadistica = v_numero_estadistica;
    commit;
    
    select max(ta_clave) into v_clave_despues_commit from est_total_a where ta_numero_estadistica = v_numero_estadistica;
    
    inserta_error(m_error => 'Valor m�ximo de clave antes de commit: ' || to_char(v_clave_antes_commit), nombre_proceso => v_proceso);
    inserta_error(m_error => 'Valor m�ximo de clave despu�s de commit: ' || to_char(v_clave_despues_commit), nombre_proceso => v_proceso);
  exception
      when others then
        rollback;
        inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
        v_fin := systimestamp;
        inserta_duracion_procesos(camara => v_camara, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
  end saldo_multibase;


/*******************************************************************/
/*                    INGRESADOS Y REINGRESADOS                    */
/*******************************************************************/

    procedure ingresados_y_reingresados(v_fechaDesde in timestamp, v_fechahasta in timestamp, id_cam in int) as
      v_proceso varchar2(30) := 'ingresados';
      v_inicio timestamp := systimestamp;
      v_fin timestamp;
    begin
    
        /* Calculo los ingresados en base a la consulta de ingresados base, eligiendo la c�mara 8, al particionar por
           expediente y oficina, los rn=1 son los primeros ingresos a cada una */
        INSERT INTO LEX100MAESTRAS.EST_TOTAL_A(TA_IDEXP, TA_RN, TA_ANIO_EXP, TA_NUMERO_EXP, TA_OFICINA, TA_FECHA, TA_CODIGO, TA_OBJETO,
                                               TA_FINALIZO, -- 0 -> fuera de tr�mite 1 -> en tr�mite
                                               TA_IDTABLAORIGEN, TA_TABLAORIGEN, -- 1 -> cambio_asignacion 2 -> actuacion_exp
                                               TA_TIPO_DE_DATO, -- 0 -> existente 1 -> ingresado 2 -> reingresados
                                               TA_FECHA_PROCESO, TA_NUMERO_DE_EJECUCION, TA_NUMERO_ESTADISTICA, TA_MATERIA, TA_CAMARA)
        SELECT c.id_expediente, n_fila, anio_exp, numero_exp, EST_OFI_O_OFI_SUP(id_oficina), fecha_asignacion, codigo_tipo_cambio_asignacion, null objeto,
               1, /* -> finalizo originalmente est� en 1 (quiere decir en tr�mite) y luego si la considero salida actualizo a 0 que es fuera de tr�mite */
               ID_CAMBIO_ASIGNACION_EXP, tabladesde,
               case when n_fila = 1 then 1 when n_fila > 1 then 2 end, /* -> 1 = ingresados , 2 = reingresados */
               v_inicio, v_numero_de_ejecucion, v_numero_estadistica, e.id_materia, id_cam
        from est_cambio_asignacion_exp c join expediente e on c.id_expediente = e.id_expediente;
        commit;
--  Elimino todo lo anterior a 2013.
   --     est_paquete_instruccion.eliminarAsignacionesAntA2013;
-- Agrego el saldo que qued� del proceso SQL.
        if id_cam = 9 and v_fechaDesde = to_timestamp('01/01/2013', 'dd/mm/yyyy') then
            saldo_multibase(v_camara => id_cam, v_numero_ejecucion => v_numero_de_ejecucion, v_numero_estadistica => v_numero_estadistica);
        end if;

        v_fin := systimestamp;
        inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    exception
        when others then
          rollback;
          inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
          v_fin := systimestamp;
          inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    end ingresados_y_reingresados;

/***************************************************/
/*                  AGREGO_DELITO                  */
/***************************************************/

    procedure agrego_delito(id_cam in int) is
      v_proceso varchar2(30) := 'agrego_delito';
      v_inicio timestamp := systimestamp;
      v_fin timestamp;
    begin
        update est_total_a
        set ta_objeto = nvl((select id_delito
                             from (select ROW_NUMBER() over(partition by id_expediente order by id_delito_expediente) n_fila, id_delito, id_expediente
                                   from delito_expediente delito) delito
                             where   delito.id_expediente = ta_idexp
                             and     n_fila = 1
                             and    ta_camara = id_cam
                             and    TA_numero_de_ejecucion = est_paquete.v_numero_de_ejecucion), -1)
        where   ta_numero_de_ejecucion = est_paquete.v_numero_de_ejecucion;
        commit;
        v_fin := systimestamp;
        inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    exception
        when others then
          rollback;
          inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
          v_fin := systimestamp;
          inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    end agrego_delito;

/***************************************************/
/*                 CALCULA_SALIDOS                 */
/***************************************************/

    procedure calcula_salidos(finPeriodo in timestamp, id_cam in number) as
      filaActual int := 0;
      reg cursor_Salidos%rowtype;
      regAnt cursor_salidos%ROWTYPE;
  --    salida int;
 --     v_fechaSalida date;
 --     v_codigoSalida varchar2(4 char);
 --     fallo_est_busca_salida exception;
      resultado int;
      v_fechaHasta timestamp;
      v_proceso varchar2(30) := 'calcula_salidos';
      v_inicio timestamp := systimestamp;
      v_fin timestamp;
    begin
        /* al fin de per�odo le sumo uno por el tema de las fechas con horas, por ejemplo 31/12/2010 12:24 es mayor que 31/12/2010 que es la fecha
        pasada por par�metro, entonces me deja afuera los registros del �ltimo d�a del per�odo */
        v_fechaHasta := finPeriodo + 1;
        DBMS_OUTPUT.put_line(v_fechaHasta);

        open cursor_salidos(v_numero_estadistica, id_cam);
        loop
            fetch cursor_salidos into reg;
            exit when cursor_salidos%NOTFOUND or cursor_salidos%NOTFOUND is null;
            filaActual := cursor_salidos%rowcount;
            /* VERIFICO QUE HAYA MAS DE UNA FILA */
            if cursor_salidos%rowcount > 1 then
                resultado := f_gestiona_salidas(reg => reg, regAnt => regant, id_camara => id_cam, findePeriodo => v_fechaHasta, v_FECHA_DE_EJECUCION => v_inicio, nroFila => filaActual);
            end if;
            regAnt := reg;
        end loop;
        close cursor_salidos;
        if filaActual = 0 then
            inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso); -- No hab�a filas
        else
            resultado := f_gestiona_ultima_salida(reg => null, regAnt => regant, id_camara => id_cam, finDePeriodo => v_fechaHasta, v_FECHA_DE_EJECUCION => v_inicio, nroFila  => filaActual);
        end if; -- filaActual = 0
        v_fin := systimestamp;
        inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
        exception
            when others then
              rollback;
              inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
              v_fin := systimestamp;
              inserta_duracion_procesos(camara => id_cam, nombre => v_proceso, inicio => v_inicio, fin => v_fin);
    end calcula_salidos;

/****************************************************/
/*                F_GESTIONA_SALIDAS                */
/****************************************************/

    function f_gestiona_salidas(reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_camara number, finDePeriodo in timestamp, v_FECHA_DE_EJECUCION in timestamp, nroFila in int) return int is
        actuacion_id int;
        v_proceso varchar2(30) := 'f_gestiona_salidas';
    begin
        if reg.ta_idexp = regant.ta_idexp then /* SI ES LA MISMA CAUSA */
            -- Busco salida entre esos dos registros
            actuacion_id := f_busca_la_salida(idexp => reg.ta_idexp, id_cam => id_camara, fechaDesde => REGANT.TA_FECHA, fechaHasta => reg.ta_fecha, oficina => regAnt.ta_oficina, reg => reg, regAnt => regAnt, filaActual => nroFila, fechaDelProceso => v_FECHA_DE_EJECUCION);
        else -- cambie de expediente, busco hasta el fin de per�odo
            actuacion_id := f_busca_la_salida(idexp => regAnt.ta_idexp, id_cam => id_camara, fechaDesde => REGANT.TA_FECHA, fechaHasta => finDePeriodo, oficina => regAnt.ta_oficina, reg => reg, regAnt => regAnt, filaActual => nroFila, fechaDelProceso => v_FECHA_DE_EJECUCION);
        end if;
        /* Inserto en el log los valores del cursor */
        -- Le resto uno a la fila para que empiece por uno (a las comparaciones entre filas del cursor reci�n entro en la segunda iteraci�n,
        -- entonces empezaba con la fila 2) y solo la �ltima llamada la dejar� tal cual para que ah� si quede el �ltimo n�mero de fila y no
        -- repita eso en las dos �ltimas filas de la tabla log.
        inserta_log(reg => reg, regAnt => regAnt, id_actuacion => actuacion_id, filaActual => nroFila - 1, fechaProceso => v_FECHA_DE_EJECUCION);
        return actuacion_id;
    exception
        when others then
          inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end f_gestiona_salidas;

/***************************************************/
/*                F_BUSCA_LA_SALIDA                */
/***************************************************/

    function f_busca_la_salida(idexp int, fechaDesde timestamp, fechaHasta timestamp, oficina int, id_cam number, reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, filaActual in int, fechaDelProceso in timestamp) return int is
      id_act int;
      fechaSalida timestamp;
      codigoSalida varchar2(3);
      radicacion varchar2(10);
      r_insertSalido reg_est_salidos;
      v_proceso varchar2(30) := 'f_busca_la_salida';
    begin
        select id_actuacion_exp, fecha_actuacion, codigo, radicacion into id_act, fechaSalida, codigoSalida, radicacion
        from (select ROW_NUMBER() over(partition by id_expediente order by fecha_actuacion desc) numero_fila, id_actuacion_exp, fecha_actuacion, codigo, radicacion
              from (select radicacion, a.id_actuacion_exp, a.fecha_actuacion, a.codigo, a.id_expediente
                    from est_actuacion_exp a 
                    where a.id_expediente = idexp
                    and   a.codigo in (select codigo from est_codigos_salida where camara = id_cam)
                    and   a.fecha_actuacion between fechaDesde and fechaHasta
                    and   a.id_oficina = est_busca_juzgado(oficina)
                    union all
                    select radicacion, a.id_actuacion_exp, a.fecha_actuacion, a.codigo, case when a.ID_EXPEDIENTE_ORIGEN is null then a.id_expediente else a.id_expediente_origen end
                    from est_actuacion_exp a
                    where idexp in (a.ID_EXPEDIENTE_ORIGEN, a.id_expediente)
                    and   a.CODIGO in ('ETO')
                    and   a.fecha_actuacion between fechaDesde and fechaHasta
                    union all
                    select radicacion, a.id_actuacion_exp, a.fecha_actuacion, a.codigo, a.id_expediente
                    from EST_actuacion_exp a
                    where a.id_expediente = idexp
                    and   a.fecha_actuacion between fechaDesde and fechaHasta
                    and   a.CODIGO in ('CMC') -- CIERRE MASIVO DE CAUSAS
                    ) cambio_actuacion
              ) r -- de resultado
        where numero_fila = 1;

      /* ENCONTR� UNA SALIDA, PREPARO EL REGISTRO PARA INSERTAR EN LA TABLA DE SALIDOS */
        r_insertSalido.radicacion := radicacion;
        r_insertSalido.actuacion := id_act;
        r_insertSalido.anio_exp := regAnt.ta_anio_exp;
        r_insertSalido.codigo := codigoSalida;
        r_insertSalido.fecha := fechaSalida;
        r_insertSalido.fecha_proceso := fechaDelProceso;
        r_insertSalido.idexp := regAnt.ta_idexp;
        r_insertSalido.numero_exp := regAnt.ta_numero_exp;
        r_insertSalido.objeto := regAnt.ta_objeto;
        r_insertSalido.oficina := regAnt.ta_oficina;
        r_insertSalido.rn := regAnt.ta_rn;
        r_insertSalido.id_ingresado := regAnt.ta_clave;
        r_insertSalido.tipo_de_dato := regAnt.ta_tipo_de_dato;

        inserta_salida(registro => r_insertSalido, reg => reg, regAnt => regAnt, id_actuacion => id_act, filaActual => filaActual, fechaProceso => fechaDelProceso);
        
        return id_act;
    exception
        when no_data_found then
            --inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
            /* Si estoy buscando salidas entre dos registros de la misma causa inserto un c�digo FIN, pero si estoy buscando entre dos causas */
            /* diferentes, y no encontr� una salida no debo insertar un c�digo FIN */
        declare /* Otro bloque para manejar excepciones que se puedan dar dentro del bloque de excepciones */
        begin
            -- Si no hay salidas, busco si hubo cambios de asignacion
            select id_actuacion_exp, fecha_actuacion, codigo, radicacion into id_act, fechaSalida, codigoSalida, radicacion
            from (select ROW_NUMBER() over(partition by id_expediente order by fecha_actuacion desc) numero_fila, id_actuacion_exp, fecha_actuacion, codigo, radicacion
                  from (select c.tipo_radicacion radicacion, c.id_cambio_asignacion_exp id_actuacion_exp, c.fecha_asignacion fecha_actuacion, c.codigo_tipo_cambio_asignacion as codigo, c.id_expediente
                        from cambio_asignacion_exp c
                        where c.id_expediente = idexp
                        and   c.fecha_asignacion > fechaDesde
                        and   c.fecha_asignacion < fechaHasta
                        and   not (fecha_asignacion = to_timestamp('01/03/2017 12:00:00,000000000 AM', 'DD/MM/YYYY HH12:MI:SS,FF AM')
                                   and    comentarios = 'POR ACORDADA 1/2017 CSJN') --No quiero las falsas asignaciones
                        ) cambio_actuacion
                  ) r -- de resultado
            where numero_fila = 1;
            -- Hubo un cambio de asignacion, considero la causa como finalizada en la oficina actual
            /* ENCONTR� UNA SALIDA, PREPARO EL REGISTRO PARA INSERTAR EN LA TABLA DE SALIDOS */
            r_insertSalido.radicacion := radicacion;
            r_insertSalido.actuacion := id_act;
            r_insertSalido.anio_exp := regAnt.ta_anio_exp;
            r_insertSalido.codigo := 'FIN'; -- Agrego un c�digo FIN para no tener muchos c�digos de asignaciones como c�digos de salida
            r_insertSalido.fecha := fechaSalida;
            r_insertSalido.fecha_proceso := fechaDelProceso;
            r_insertSalido.idexp := regAnt.ta_idexp;
            r_insertSalido.numero_exp := regAnt.ta_numero_exp;
            r_insertSalido.objeto := regAnt.ta_objeto;
            r_insertSalido.oficina := regAnt.ta_oficina;
            r_insertSalido.rn := regAnt.ta_rn;
            r_insertSalido.id_ingresado := regAnt.ta_clave;
            r_insertSalido.tipo_de_dato := regAnt.ta_tipo_de_dato;

            inserta_salida(registro => r_insertSalido, reg => reg, regAnt => regAnt, id_actuacion => id_act, filaActual => filaActual, fechaProceso => fechaDelProceso);

            return id_act;
        exception
            when no_data_found then
                --Si estoy en la misma causa, agrego un c�digo de FIN
                if (reg.ta_idexp) = (regAnt.ta_idexp) then
                    /* preparo el registro que insertaremos */
                    r_insertSalido.actuacion := id_act;
                    r_insertSalido.anio_exp := regAnt.ta_anio_exp;
                    r_insertSalido.codigo := 'FIN';
                    r_insertSalido.fecha := reg.ta_fecha; -- cambio la fecha del reg anterior por la fecha del registro actual
                    r_insertSalido.fecha_proceso := fechaDelProceso;
                    r_insertSalido.idexp := regAnt.ta_idexp;
                    r_insertSalido.numero_exp := regAnt.ta_numero_exp;
                    r_insertSalido.objeto := regAnt.ta_objeto;
                    r_insertSalido.oficina := regAnt.ta_oficina;
                    r_insertSalido.rn := regAnt.ta_rn;
                    r_insertSalido.id_ingresado := regAnt.ta_clave;
                    r_insertSalido.tipo_de_dato := regAnt.ta_tipo_de_dato;
                    inserta_salida(registro => r_insertSalido, reg => reg, regAnt => regAnt, id_actuacion => id_act, filaActual => filaActual, fechaProceso => fechaDelProceso);
                end if; --(reg = regAnt)
                return 0;
            when too_many_rows then
                inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
                return -3;
            when others then
                inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
                return -1;
        end;
            
            return 0;
        when too_many_rows then
            inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
            return -3;
        when others then
            inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
            return -1;
    end f_busca_la_salida;

/****************************************************/
/*                  INSERTA_SALIDA                  */
/****************************************************/

    procedure inserta_salida (registro in reg_est_salidos, reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_actuacion in number, filaActual in int, fechaProceso in timestamp) is
      idexp int;
      ofi int;
      numfila int;
      t_d int;
      Numero_ejecucion int;
      v_proceso varchar2(30) := 'inserta_salida';
    begin
        insert into est_salidos(SAL_ANIO_EXP, SAL_CODIGO, SAL_FECHA, sal_fechaProceso, SAL_IDEXP, SAL_NUMERO_EXP, SAL_OBJETO, SAL_OFICINA, sal_rn, sal_actuacion, SAL_NUMERO_DE_EJECUCION, sal_numero_estadistica, SAL_REFERENCIA_INGRESADO, sal_radicacion)
        values(registro.anio_exp, registro.codigo, registro.fecha, registro.fecha_Proceso, registro.idexp, registro.numero_exp, registro.objeto, registro.oficina, registro.rn, registro.actuacion, v_numero_de_ejecucion, v_numero_estadistica, registro.id_ingresado, registro.radicacion);
        commit;
        
        idexp := registro.idexp;
        ofi := registro.oficina;
        numfila := registro.rn;
        t_d := registro.tipo_de_dato;
        Numero_ejecucion := regAnt.TA_NUMERO_ESTADISTICA;
        
        update est_total_a
        set ta_finalizo = 0, TA_FECHA_DE_FINALIZACION = REGISTRO.FECHA
        where ta_clave = registro.id_ingresado ;

        if(sql%rowcount) > 1 then
            inserta_error(m_error => 'EL UPDATE ACTUALIZ� MAS DE UNA FILA. LA CANTIDAD ES: ' || sql%rowcount || 'LA CLAVE ES: ' || registro.id_ingresado, nombre_proceso => v_proceso);
        end if;
        commit;
    exception
      when others then
        rollback;
        inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end inserta_salida;

/***************************************************/
/*                   INSERTA_LOG                   */
/***************************************************/

    procedure inserta_log(reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_actuacion in number, filaActual in int, fechaProceso in timestamp) is
      v_proceso varchar2(30) := 'inserta_log';
    begin
        insert into est_log(ant_ide, ide, ant_fecha, fecha, id_act, ant_ofi, ofi, rn_ant, rn, numfila, FECHA_DE_EJECUCION, NUMERO_DE_EJECUCION)
        values (regant.ta_idexp, reg.ta_idexp, regant.ta_fecha, reg.ta_fecha, id_actuacion, regant.ta_oficina, reg.ta_oficina, regant.ta_rn, reg.ta_rn, filaActual, fechaProceso, v_numero_de_ejecucion);
        commit;
    exception
      when others then
        rollback;
        inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end inserta_log;

/***************************************************/
/*                  INSERTA_ERROR                  */
/***************************************************/

    procedure inserta_error(m_error in varchar2, nombre_proceso in varchar2) is
    begin
      insert into est_errores(problema, fecha, numero_secuencia, proceso)
      values (m_error, systimestamp, (select nvl(max(numero_secuencia) + 1, 1) from est_errores), nombre_proceso);
      commit;
    exception
      when others then
        rollback;
    end inserta_error;

/****************************************************/
/*             F_GESTIONA_ULTIMA_SALIDA             */
/****************************************************/

    function f_gestiona_ultima_salida(reg in cursor_Salidos%rowtype, regAnt in cursor_Salidos%rowtype, id_camara number, finDePeriodo in timestamp, v_FECHA_DE_EJECUCION in timestamp, nroFila in int) return int is
        actuacion_id int;
        v_proceso varchar2(30) := 'f_gestiona_ultima_salida';
    begin
        /* AL SER EL �LTIMO REGISTRO, ES COMO BUSCAR CUANDO CAMBIO DE CAUSA, HASTA EL FIN DE PER�ODO, EN ESTE CASO SI NO ENCUENTRO UNA SALIDA, NO AGREG� UN C�DIGO FIN */
        actuacion_id := f_busca_la_salida(idexp => regAnt.ta_idexp, id_cam => id_camara, fechaDesde => regAnt.ta_fecha, fechaHasta => finDePeriodo, oficina => regAnt.ta_oficina, reg => reg, regAnt => regAnt, filaActual => nroFila, fechaDelProceso => v_FECHA_DE_EJECUCION);
        /* Inserto en el log los valores del cursor */
        inserta_log(reg => reg, regAnt => regAnt, id_actuacion => actuacion_id, filaActual => nroFila, fechaProceso => v_FECHA_DE_EJECUCION);
        return actuacion_id;
    exception
        when others then
          inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end f_gestiona_ultima_salida;

/***************************************************/
/*            INSERTA_DURACION_PROCESOS            */
/***************************************************/

    procedure inserta_duracion_procesos(camara in int, nombre in varchar2, inicio in timestamp, fin in timestamp) is
    begin
      insert into est_duracion_proceso(CAMARA, NOMBRE_PROCESO, INICIO_PROCESO, FIN_PROCESO)
                                values(camara, nombre, inicio, fin);
      commit;
    exception
      when others then
        rollback;
    end inserta_duracion_procesos;

/***************************************************/
/*              DEJARMATERIASPENALES               */
/***************************************************/

    procedure dejarMateriasPenales(camara in int) is
      v_proceso varchar2(30) := 'dejarMateriasPenales';
    begin
        /* BORRO LOS EXPEDIENTES DE C�RDOBA -O LA C�MARA QUE QUIERA- QUE NO SEAN DE MATERIA PENAL -LAS INCLU�DAS EN EL VECTOR MP */
        delete from est_total_a
        where ta_camara = camara
        and   ta_numero_de_ejecucion = v_numero_de_ejecucion
        and   ta_materia not in (9,11);
        commit;
    exception
      when others then
        rollback;
        inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end dejarMateriasPenales;
end est_paquete;