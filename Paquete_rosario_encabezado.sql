create or replace package est_paquete_rosario as
    N_CAMARA NUMBER(2) := 25;
    procedure calcular_estadistica_rosario(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp default to_timestamp('31/12/2008', 'dd/mm/yyyy'));
end est_paquete_rosario;