**FREE
      //=================================================================
      // UTLSRV - Utility Service Program
      // Cross-cutting procedures shared by every domain service program.
      // Bound into PPQBNDDIR. Compile: CRTSQLRPGI OBJTYPE(*MODULE)
      //
      // Naming convention: every variable used as an embedded-SQL host
      // variable (referenced with a leading ':' in an EXEC SQL statement)
      // is prefixed sql_ so host variables are visually distinct from
      // plain RPG working variables at a glance.
      //=================================================================
      ctl-opt nomain;
      ctl-opt datfmt(*iso) timfmt(*iso);

      exec sql SET OPTION commit = *none, closqlcsr = *endmod;

      /copy SREERAMC1/PPQIBMI,CPYERR

      //-----------------------------------------------------------------
      // Global Prototypes (Must be declared before any dcl-proc block)
      //-----------------------------------------------------------------

      dcl-pr NextProtocolNumber varchar(20) extproc('NEXTPROTOCOLNUMBER');
      end-pr;

      dcl-pr CalcPctVariance packed(7:3) extproc('CALCPCTVARIANCE');
        pStdValue    packed(15:4) const;
        pActualValue packed(15:4) const;
      end-pr;

      dcl-pr IsRoleAuthorized ind extproc('ISROLEAUTHORIZED');
        pUserId varchar(10) const;
        pRoleCd char(10) const;
      end-pr;

      //-----------------------------------------------------------------
      // NextProtocolNumber - formats PPQ/<year>/<5-digit seq>
      //-----------------------------------------------------------------
      dcl-proc NextProtocolNumber export;
        dcl-pi *n varchar(20);
        end-pi;
        dcl-s sql_SeqVal    int(10);
        dcl-s sql_YearPart  char(4);
        dcl-s seq5          packed(5:0);
        dcl-s result        varchar(20);

        exec sql SET :sql_SeqVal = NEXT VALUE FOR SEQ_PROTOCOL_NO;
        exec sql VALUES CHAR(YEAR(CURRENT DATE)) INTO :sql_YearPart;

     seq5 = sql_SeqVal; // Convert 10-digit integer to 5-digit packed decimal
     result = 'PPQ/' + %trim(sql_YearPart) + '/' + %editc(seq5 : 'X');
     //result = 'PPQ/' + %trim(sql_YearPart) + '/' + %editc(sql_SeqVal:'Z':0);
        return result;
      end-proc;

      //-----------------------------------------------------------------
      // LogError - writes to the job log and to an application message
      // queue; called from every MONITOR/ON-ERROR block system-wide.
      //-----------------------------------------------------------------
      dcl-proc LogError export;
       // dcl-pi *n extproc('LOGERROR');
       //The extproc keyword is only valid on the prototype (dcl-pr)-
       //the corresponding procedure interface (dcl-pi) in your-
       // implementation file must not specify extproc again.
       //where no prototype existsthe compiler allows you to place the-
       //EXTPROC keyword directly on the Procedure Interface (dcl-pi) to-
       // define its external name
        dcl-pi *n;
          sql_pProcedure varchar(40) const;
          sql_pSqlCode   int(10) const;
          pSqlState      char(5) const;
          sql_pMsgText   varchar(200) const;
          sql_pUserId    varchar(10) const;
        end-pi;

        dcl-s sql_FullMsg varchar(256);
        // Prefixed sql_ to match your file's naming convention
        dcl-s sql_Cmd     varchar(500);

        sql_FullMsg = %trim(sql_pProcedure)
           + ': SQLCODE=' + %char(sql_pSqlCode)
           + ' SQLSTATE=' + %trim(pSqlState)
           + ' - ' + %trim(sql_pMsgText);

        // Send *DIAG to job log for support / trace
       // exec sql
       //   VALUES ( QSYS2.QCMDEXC(
       //     'SNDPGMMSG MSG(''' concat replace(:sql_FullMsg,'''','') concat
       //     ''') TOPGMQ(*EXT) MSGTYPE(*DIAG)' ) );

      // Safely escape single quotes and build command natively in RPG
      sql_Cmd = 'SNDPGMMSG MSG(''' + %scanrpl('''': '': sql_FullMsg) + ''') '
                 + 'TOPGMQ(*EXT) MSGTYPE(*DIAG)';

       // Send *DIAG to job log
        exec sql CALL QSYS2.QCMDEXC(:sql_Cmd);

        // Persist to PPQ_AUDIT so failed attempts are never silently lost
        exec sql
          INSERT INTO PPQ_AUDIT (AUDIT_ID, TABLE_NAME, ACTION,
             KEY_VALUE, COLUMN_NAME, OLD_VALUE, NEW_VALUE, CHANGED_BY)
          VALUES (NEXT VALUE FOR SEQ_AUDIT_ID, :sql_pProcedure,
                       'E', '*ERROR', 'SQLCODE',
                  CHAR(:sql_pSqlCode), :sql_pMsgText, :sql_pUserId);
      end-proc;

      //-----------------------------------------------------------------
      // CalcPctVariance - shared percentage-variance calculation
      // used by Formula (std vs actual) and Yield (theoretical vs actual)
      // - pure RPG math, no embedded SQL, so no host variables here.
      //-----------------------------------------------------------------


      dcl-proc CalcPctVariance export;
        dcl-pi *n packed(7:3);
            dcl-parm pStdValue    packed(15:4) const;
            dcl-parm pActualValue packed(15:4) const;
        end-pi;

        dcl-s result packed(7:3);

        if pStdValue = 0;
          return 0;
        endif;
        result = %dec(((pActualValue - pStdValue) / pStdValue)
                      * 100 : 7 : 3);
        return result;
      end-proc;

      //-----------------------------------------------------------------
      // IsRoleAuthorized - checks SEC_ROLE_PERM for a user/role pair
      //-----------------------------------------------------------------


      dcl-proc IsRoleAuthorized export;
        dcl-pi *n ind;
            dcl-parm sql_pUserId varchar(10) const;
            dcl-parm sql_pRoleCd char(10) const;
         end-pi;

        dcl-s sql_Cnt int(10);

        exec sql
          SELECT COUNT(*) INTO :sql_Cnt
          FROM SREERAMC1.SCRLPRM
          WHERE USER_ID = :sql_pUserId AND ROLE_CD = :sql_pRoleCd;

        return (sql_Cnt > 0);
      end-proc;

