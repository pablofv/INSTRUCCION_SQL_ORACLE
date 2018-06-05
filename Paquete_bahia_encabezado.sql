create or replace package est_paquete_bahia as
    N_CAMARA NUMBER(2) := 13;
    procedure calcular_estadistica_bahia(f_desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), f_hasta in timestamp default to_timestamp('31/12/2008', 'dd/mm/yyyy'));
end est_paquete_bahia;