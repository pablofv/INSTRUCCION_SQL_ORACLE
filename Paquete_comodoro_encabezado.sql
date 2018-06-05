create or replace package est_paquete_comodoro as
    N_CAMARA NUMBER(2) := 14;
    procedure calcular_estadistica_comodoro(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp default to_timestamp('31/12/2008', 'dd/mm/yyyy'));
end est_paquete_comodoro;