//BNKSTMT JOB 'Report',NOTIFY=&SYSUID,CLASS=A,MSGCLASS=H,
//          MSGLEVEL=(1,1),REGION=4M
//STEP1    EXEC PGM=IKJEFT01
//STEPLIB  DD  DISP=SHR,DSN=DSND10.SDSNEXIT
//         DD  DISP=SHR,DSN=DSND10.SDSNLOAD
//********************************************
//*MONTH FOR WHICH REPORT IS RUN
//********************************************
//DATECARD DD *
202609
//********************************************
//*ACCOUNT IDENTIFIER FOR WHICH REPORT IS RUN
//********************************************
//SORTCODE DD *
987654
//SYSPRINT DD   SYSOUT=*
//SYSOUT   DD   SYSOUT=*
//SYSTSPRT DD   SYSOUT=*
//SYSTSIN  DD *
 DSN SYSTEM(DBDG)
 RUN  PROGRAM(BNKSTMT) PLAN(BANKZPLN) -
      LIB('BANKZ.V0R1M0.LOAD')
 END
/*
