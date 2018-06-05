create or replace package body est_paquete_rosario as
    procedure calcular_estadistica_rosario(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp default to_timestamp('31/12/2008', 'dd/mm/yyyy')) as
      v_proceso varchar2(30) := 'calcular_estadistica_rosario';
    begin
        est_paquete_camaras_interior.calcular_estadistica(desde => desde, hasta => hasta, camara => N_CAMARA);
    exception
      when others then
          est_paquete.inserta_error(m_error => DBMS_UTILITY.format_error_stack, nombre_proceso => v_proceso);
    end calcular_estadistica_rosario;
end est_paquete_rosario;