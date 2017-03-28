create or replace package est_paquete_cordoba as
    N_CAMARA NUMBER(2) := 15;
    procedure calcular_estadistica_cordoba(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp, recalculo varchar2 default 'N');
end est_paquete_cordoba;