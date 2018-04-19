create or replace package est_paquete_instruccion as
    N_CAMARA NUMBER(2) := 9;
    procedure calcular_estadistica_instr(desde in timestamp default to_timestamp('01/01/2008', 'dd/mm/yyyy'), hasta in timestamp default to_timestamp('31/12/2008', 'dd/mm/yyyy'));
    procedure eliminarAsignacionesAntA2013;
    procedure dejarSoloInstruccion;
    procedure dejarSoloInstruccion2;
    procedure eliminarAnterioresA2008;
    procedure eliminarFalsasAsignaciones;
end est_paquete_instruccion;