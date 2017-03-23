create or replace package est_paquete_federal as
    procedure calcular_estadistica2(desde in timestamp, hasta in timestamp, recalculo varchar2 default 'N');
end est_paquete_federal;