create or replace package body est_paquete_instruccion as
    procedure calcular_estadistica_instr(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp default to_timestamp('31/12/2008', 'dd/mm/yyyy'), recalcular varchar2 default 'N') as
      error_yaFueCalculado exception; -- excepcion para cuando quiero calcular una estadística que ya está calculada
      hay_registros_anteriores int; -- Variable para saber si ya tengo datos anteriores, y determinar si ejecuto el procecidiento de existentes iniciales.
      v_proceso varchar2(30) := 'calcular_estadistica_instr';
    begin
        if EST_PAQ_EJECUTAR.ejecutar_proceso(f_desde => desde, f_hasta => hasta, CAMARA => N_CAMARA, quieroRecalcular => recalcular, datos_antes_del_inicio => hay_registros_anteriores) = 1 then
            /* 1-> error, 0-> correcto */
            raise error_yaFueCalculado;
        else
            /* En instrucción empezaremos sin expedientes en trámite */
            est_paquete.ingresados(V_FECHADESDE => desde, V_FECHAHASTA => hasta, id_cam => N_CAMARA);
            est_paquete.reingresados(v_fechaDesde => desde, v_fechahasta => hasta, id_cam => N_CAMARA);
            --ELIMINAMOS TODO LO QUE NO SEA UN MOVIMIENTO DE INSTRUCCIÓN
            dejarSoloInstruccion;
            est_paquete.agrego_delito(id_cam => N_CAMARA);
            est_paquete.calcula_salidos(finPeriodo => hasta, id_cam => N_CAMARA);
        end if;
    exception
      when error_yaFueCalculado then
          est_paquete.inserta_error(m_error => 'ESTADÍSTICA YA CALCULADA', nombre_proceso => v_proceso);
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end calcular_estadistica_instr;

    procedure dejarSoloInstruccion is
        v_proceso varchar2(30) := 'dejarSoloInstruccion';
    begin
        /* ELIMINO LOS EXPEDIENTES QUE NO SON DE LAS OFICINAS DE INSTRUCCIÓN HASTA EL AÑO 2012 INCLUSIVE */
        delete from est_total_a ta
        where not exists (select id_oficina
                          from oficina o
                          where ta.ta_oficina = o.id_oficina
                          and   o.sigla_cedulas = 'CI')
        and   TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion
        and   extract(year from ta_fecha) < 2013;

        /* PARA 2013 EN ADELANTE, BORRARÉ TODO LO QUE NO SEA INSTRUCCIÓN, ROGATORIAS, MENORES O CORRECCIONAL */
        delete from est_total_a ta
        where not exists (select id_oficina
                          from oficina o
                          where ta.ta_oficina = o.id_oficina
                          and   o.sigla_cedulas in ('CI', 'CR','JNM', 'RO'))
        and   TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion
        and   extract(year from ta_fecha) >= 2013;

        /* ELIMINO AQUELLOS EXPEDIENTES QUE TIENEN AÑO DE CAUSA ANTERIOR A 2008, YA QUE LO CONSIDERABA ASÍ EN INSTRUCCIÓN CON SQLSERVER */
        delete from est_total_a
        where   ta_anio_exp < 2008
        and   TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion;
        commit;
    exception
        when others then
            est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
            rollback;
    end dejarSoloInstruccion;
end est_paquete_instruccion;