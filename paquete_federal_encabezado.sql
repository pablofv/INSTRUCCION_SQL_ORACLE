create or replace package est_paquete_federal as
    N_CAMARA NUMBER(2) := 8;
    procedure calcular_estadistica_federal(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp, recalcular varchar2 default 'N');
end est_paquete_federal;