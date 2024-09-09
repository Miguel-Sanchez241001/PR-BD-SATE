

create PROCEDURE BNPD_09_CUENTA_ACT
IS
BEGIN
    INSERT INTO BN_SATE.BNSATE04_ASIGNACION
    (B05_ID_TAR, B04_CODIGO_ASIGNACION, B04_FECHA_INICIO_LINEA, B04_FECHA_FIN_LINEA, B04_FECHA_REGISTRO, B04_LINEA,
     B04_CUENTA_EXPEDIENTE)
        (SELECT tar.B05_ID_TAR,
                '000000',
                mef.B13_FEC_INICIO_AUT,
                mef.B13_FEC_FIN_AUT,
                sysdate,
                mef.B13_IMPORTE,
                mef.B13_SEC_OPERACION_REF
         from BNSATE13_RPTA_MEF_TEMP mef
                  join BNSATE00_EMPRESA empre
                       on empre.B00_NUM_RUC = mef.B13_RUC_MEF_TEMP
                  join BNSATE05_TARJETA tar
                       on tar.B00_ID_EMP = empre.B00_ID_EMP and tar.B05_DISENO = SUBSTR(mef.B13_TIPO_TARJETA, -1)
                  join (SELECT t.B05_ID_TAR,
                               t.B07_ESTADO,
                               t.B07_FEC_REGISTRO
                        FROM BNSATE07_EST_TARJETA t
                                 JOIN (
                            -- Subconsulta para obtener la última fecha de cada tarjeta
                            SELECT B05_ID_TAR,
                                   MAX(B07_FEC_REGISTRO) AS max_fecha
                            FROM BNSATE07_EST_TARJETA
                            GROUP BY B05_ID_TAR) t_max
                                      ON t.B05_ID_TAR = t_max.B05_ID_TAR
                                          AND
                                         t.B07_FEC_REGISTRO = t_max.max_fecha -- Agrupa los resultados por `B04_ID_CAS`
         ) B07ET
                       on tar.B05_ID_TAR = B07ET.B05_ID_TAR
                  join BNSATE06_CLIENTE cliente
                       on tar.B06_ID_CLI = cliente.B06_ID_CLI
                           and cliente.B06_TIPO_DOCUMENTO = SUBSTR(mef.B13_TIPO_DOCUMENTO, -1)
                           AND cliente.B06_NUM_DOCUMENTO = SUBSTR(mef.B13_NUM_DOCUMENTO, -8)
         where B07ET.B07_ESTADO = '5');

    MERGE INTO BN_SATE.BNSATE05_TARJETA tar
    USING (SELECT mef.B13_FEC_INICIO_AUT,
                  mef.B13_FEC_INICIO_AUT AS B13_FEC_INICIO_AUT_DUPLICATE,
                  mef.B13_FEC_FIN_AUT,
                  mef.B13_IMPORTE,
                  tar.B05_ID_TAR
           FROM BNSATE13_RPTA_MEF_TEMP mef
                    JOIN BNSATE00_EMPRESA empre
                         ON empre.B00_NUM_RUC = mef.B13_RUC_MEF_TEMP
                    JOIN BNSATE05_TARJETA tar
                         ON tar.B00_ID_EMP = empre.B00_ID_EMP
                             AND tar.B05_DISENO = SUBSTR(mef.B13_TIPO_TARJETA, -1)
                    JOIN (SELECT t.B05_ID_TAR,
                                 t.B07_ESTADO,
                                 t.B07_FEC_REGISTRO
                          FROM BNSATE07_EST_TARJETA t
                                   JOIN (
                              -- Subconsulta para obtener la última fecha de cada tarjeta
                              SELECT B05_ID_TAR,
                                     MAX(B07_FEC_REGISTRO) AS max_fecha
                              FROM BNSATE07_EST_TARJETA
                              GROUP BY B05_ID_TAR) t_max
                                        ON t.B05_ID_TAR = t_max.B05_ID_TAR
                                            AND t.B07_FEC_REGISTRO = t_max.max_fecha) B07ET
                         ON tar.B05_ID_TAR = B07ET.B05_ID_TAR
                    JOIN BNSATE06_CLIENTE cliente
                         ON tar.B06_ID_CLI = cliente.B06_ID_CLI
                             AND cliente.B06_TIPO_DOCUMENTO = SUBSTR(mef.B13_TIPO_DOCUMENTO, -1)
                             AND cliente.B06_NUM_DOCUMENTO = SUBSTR(mef.B13_NUM_DOCUMENTO, -8)
           WHERE B07ET.B07_ESTADO = '5') data
    ON (tar.B05_ID_TAR = data.B05_ID_TAR)
    WHEN MATCHED THEN
        UPDATE
        SET tar.B05_FEC_AUTORIZACION     = data.B13_FEC_INICIO_AUT,
            tar.B05_FEC_INICIO_LINEA     = data.B13_FEC_INICIO_AUT,
            tar.B05_FEC_TERMINO_LINEA    = data.B13_FEC_FIN_AUT,
            tar.B05_MONTO_LINEA_ASIGNADO = data.B13_IMPORTE;

    MERGE INTO BNSATE00_EMPRESA e
    USING (SELECT DISTINCT rpt.B13_RUC_MEF_TEMP, rpt.B13_CUENTA_CARGO
           FROM BN_SATE.BNSATE13_RPTA_MEF_TEMP rpt) c
    ON (e.B00_NUM_RUC = c.B13_RUC_MEF_TEMP)
    WHEN MATCHED THEN
        UPDATE SET e.B00_NUM_CUENTA_CORRIENTE = c.B13_CUENTA_CARGO;

    DELETE FROM BN_SATE.BNSATE13_RPTA_MEF_TEMP rpt;

    COMMIT;
END BNPD_09_CUENTA_ACT;
/


create trigger BNTG_04_ASIGNACION
    before insert
    on BNSATE04_ASIGNACION
    for each row
BEGIN
  IF :new.B04_ID_CAS IS NULL THEN
    SELECT BNSQ_04_ASIGNACION.nextval INTO :new.B04_ID_CAS FROM DUAL;
  END IF;

  INSERT INTO BNSATE19_EST_ASIGNACION (
    B04_ID_CAS,B019_ESTADO,B019_FEC_REGISTRO) VALUES (
    :new.B04_ID_CAS, -- Utiliza el ID generado
    '1',             -- Valor de estado (ajusta según necesidad)
    SYSDATE          -- Fecha actual
  );
END;
/