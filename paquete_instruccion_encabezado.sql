create or replace package est_paquete_instruccion as
    N_CAMARA NUMBER(2) := 9;
    procedure calcular_estadistica(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp, recalculo varchar2 default 'N');
    procedure reingresadosDeActuacion(f_desde in timestamp, f_hasta in timestamp);
    procedure dejarSoloInstruccion;
end est_paquete_instruccion;