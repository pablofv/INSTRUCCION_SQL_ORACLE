create or replace package body est_paquete_corrientes as
    procedure calcular_estadistica_ctes(desde in timestamp, hasta in timestamp) as
      v_proceso varchar2(30) := 'calcular_estadistica_ctes';
    begin
        est_paquete_camaras_interior.calcular_estadistica(desde => desde, hasta => hasta, camara => N_CAMARA);
    exception
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end calcular_estadistica_ctes;
end est_paquete_corrientes;