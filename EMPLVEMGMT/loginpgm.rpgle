     H DATEDIT(*DMY/) DEBUG(*YES)
     FLOGIN     IF   E           K DISK
     FEMPMASTER IF   E           K DISK
     DLOGIN_REC        DS
     D LOGEMPID                       4S 0 OVERLAY(LOGIN_REC:1)
     D LOGPWD                        20A   OVERLAY(LOGIN_REC:5)
     D*
     D PWD_INPUT       S             20A

     D EMPID_SCR       S              4A   INZ('')
     D PWD_SCR         S             20A   INZ('')
     D MSG_SCR         S             70A   INZ('')
     D ROLE_OUT        S              1A   INZ('')

      /FREE
           EMPID_SCR='1001';
           PWD_SCR = 'MYPASSWORD';
           MSG_SCR = '';  //MSG_SCR=*BLANKS
         //VALIDATE INPUT FIELDS (BASIC VALIDATION)
            CALLP QXLGDSS(INP_FLD : VALIDCH : RESULT);
            IF RESULT= '0';
