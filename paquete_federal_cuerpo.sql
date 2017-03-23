create or replace package body est_paquete_federal as

    procedure calcular_estadistica2(desde in timestamp, hasta in timestamp, recalculo varchar2 default 'N') as
      cantidad_reg_anteriores int;
    begin
        select nvl(count(*), 0) into cantidad_reg_anteriores from est_fecha_de_procesos;

        if recalculo = 'S' or (upper(recalculo) = 'N' and cantidad_reg_anteriores = 0)then
            insert into est_fecha_de_procesos(fecha) values (sysdate);
        end if;

        select max(n_ejecucion) into est_paquete.v_numero_de_ejecucion from est_fecha_de_procesos;

        select nvl(count(*), 0) into cantidad_reg_anteriores
        from est_total_a
        where ta_fecha < desde
        and TA_NUMERO_DE_EJECUCION = est_paquete.v_numero_de_ejecucion;

        if cantidad_reg_anteriores = 0 then
          est_paquete.saldo_al_inicio(v_fechahasta => desde, id_cam => 8);
        end if;

        est_paquete.ingresados(V_FECHADESDE => desde, V_FECHAHASTA => hasta, id_cam => 8);
        est_paquete.reingresados(v_fechaDesde => desde, v_fechahasta => hasta, id_cam => 8);
        est_paquete.calcula_salidos(finPeriodo => hasta, id_cam => 8);
    end calcular_estadistica2;
end est_paquete_federal;