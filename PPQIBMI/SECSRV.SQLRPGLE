**FREE
      //=================================================================
      // SECSRV - Module 1: Security (Login / Role-Based Access)
      //=================================================================
      ctl-opt nomain;
      exec sql SET OPTION commit = *cs, closqlcsr = *endmod;

      /copy SREERAMC1/PPQIBMI,CPYERR

      // SECSRV is the single owner of the session context - EXPORT'd here;
      // all other modules /copy CPYSEC.rpgleinc, which IMPORTs this instance.
      dcl-ds SessionInfo_t qualified template;
        UserId      varchar(10);
        FullName    varchar(60);
        DeptCd      char(10);
        RoleList    varchar(200);
        LoginTs     timestamp;
        DeviceName  char(10);
      end-ds;
      dcl-ds sql_gSession likeds(SessionInfo_t) export;

      dcl-pr VerifyPassword ind extproc('VERIFYPASSWORD');
        pUserId   varchar(10) const;
        pPassword varchar(128) const;
      end-pr;

      dcl-pr Login ind extproc('LOGIN');
        pUserId    varchar(10) const;
        pPassword  varchar(128) const;
        pDeviceNm  char(10) const;
      end-pr;

      dcl-pr HasRole ind extproc('HASROLE');
        pRoleCd char(10) const;
      end-pr;

      dcl-pr Logoff extproc('LOGOFF');
      end-pr;

      //-----------------------------------------------------------------
      // Login - authenticates and populates the exported sql_gSession DS
      // used by every presentation-layer program for the duration of
      // the interactive job.
      //-----------------------------------------------------------------

      dcl-proc Login export;
        dcl-pi *n ind;
        dcl-parm sql_pUserId   varchar(10) const;
        dcl-parm pPassword varchar(128) const;
        dcl-parm sql_pDeviceNm char(10) const;
         end-pi;
        dcl-s sql_Roles varchar(200);

        if not VerifyPassword(sql_pUserId: pPassword);
          exec sql
            INSERT INTO SCLGNDT (USER_ID, EVENT_TYPE, DEVICE_NAME)
            VALUES (:sql_pUserId, 'FAILED', :sql_pDeviceNm);
          exec sql COMMIT;
          return *off;
        endif;

        exec sql
          SELECT LISTAGG(ROLE_CD, ',') WITHIN GROUP (ORDER BY ROLE_CD)
          INTO :sql_Roles
          FROM SCRLPRM WHERE USER_ID = :sql_pUserId;

        exec sql
          SELECT USER_ID, FULL_NAME, DEPT_CD
          INTO :sql_gSession.UserId, :sql_gSession.FullName,
               :sql_gSession.DeptCd
          FROM SEC_USER WHERE USER_ID = :sql_pUserId;

        sql_gSession.RoleList  = sql_Roles;
        sql_gSession.LoginTs   = %timestamp();
        sql_gSession.DeviceName = sql_pDeviceNm;

        exec sql
          UPDATE SEC_USER SET LAST_LOGIN_TS = CURRENT TIMESTAMP
          WHERE USER_ID = :sql_pUserId;
        exec sql
          INSERT INTO SCLGNDT (USER_ID, EVENT_TYPE, DEVICE_NAME)
          VALUES (:sql_pUserId, 'LOGIN', :sql_pDeviceNm);
        exec sql COMMIT;

        return *on;
      end-proc;

      //-----------------------------------------------------------------
      // HasRole - checks the current session against a required role
      //-----------------------------------------------------------------

      dcl-proc HasRole export;
        dcl-pi *n ind;
        dcl-parm pRoleCd char(10) const;
         end-pi;
        return (%scan(%trim(pRoleCd): sql_gSession.RoleList) > 0);
      end-proc;

      //-----------------------------------------------------------------
      // Logoff
      //-----------------------------------------------------------------

      dcl-proc Logoff export;
        dcl-pi *n end-pi;
        exec sql
          INSERT INTO SCLGNDT (USER_ID, EVENT_TYPE, DEVICE_NAME)
          VALUES (:sql_gSession.UserId, 'LOGOFF', :sql_gSession.DeviceName);
        exec sql COMMIT;
        clear sql_gSession;
      end-proc;

