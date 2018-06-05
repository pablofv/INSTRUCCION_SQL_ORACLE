create or replace package est_paquete_la_plata as
    N_CAMARA NUMBER(2) := 18;
    procedure calcular_estadistica_la_plata(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp default to_timestamp('31/12/2008', 'dd/mm/yyyy'));
end est_paquete_la_plata;