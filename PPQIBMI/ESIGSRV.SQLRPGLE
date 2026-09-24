**FREE
      //=================================================================
      // ESIGSRV - Module 1/25: Electronic Signature capture
      // Every signature requires password re-authentication distinct
      // from the 5250 session login (21 CFR Part 11 - two distinct
      // identification components for a signing event).
      //=================================================================
      ctl-opt nomain;
      exec sql SET OPTION commit = *none, closqlcsr = *endmod;

      /copy SREERAMC1/PPQIBMI,CPYERR

      dcl-pr VerifyPassword ind extproc('VERIFYPASSWORD');
        pUserId   varchar(10) const;
        pPassword varchar(128) const;
      end-pr;

      dcl-pr HashPassword varchar(128) extproc('HASHPASSWORD');
        pPassword varchar(128) const;
      end-pr;

      dcl-pr CaptureESignature int(20) extproc('CAPTUREESIGNATURE');
        pUserId     varchar(10) const;
        pPassword   varchar(128) const;
        pMeaningTxt varchar(100) const;
        pDeviceIp   varchar(45) const;
      end-pr;

      //-----------------------------------------------------------------
      dcl-proc HashPassword export;
        dcl-pi *n varchar(128);
            dcl-parm sql_pPassword varchar(128) const;
        end-pi;

        dcl-s sql_HashOut varchar(128);
        // Production build: call QC3CALCH / Qc3CalculateHash (SHA-256) API.
        // Shown here as an SQL built-in for brevity in the design template.
        exec sql VALUES HEX(HASH_SHA256(:sql_pPassword)) INTO :sql_HashOut;
        return sql_HashOut;
      end-proc;

      //-----------------------------------------------------------------
      dcl-proc VerifyPassword export;
        dcl-pi *n ind;
           dcl-parm sql_pUserId   varchar(10) const;
           dcl-parm pPassword varchar(128) const;
        end-pi;

        dcl-s sql_StoredHash varchar(128);
        dcl-s suppliedHash varchar(128);
        dcl-s sql_Locked char(1);
        dcl-s sql_Active char(1);


        exec sql
          SELECT PASSWORD_HASH, LOCKED_IND, ACTIVE_IND
          INTO :sql_StoredHash, :sql_Locked, :sql_Active
          FROM SEC_USER WHERE USER_ID = :sql_pUserId;

        if sqlcode <> 0 or sql_Locked = 'Y' or sql_Active = 'N';
          return *off;
        endif;

        suppliedHash = HashPassword(pPassword);

        if suppliedHash = sql_StoredHash;
          exec sql UPDATE SEC_USER SET FAILED_LOGIN_CNT = 0
                   WHERE USER_ID = :sql_pUserId;
          return *on;
        else;
          exec sql
            UPDATE SEC_USER
            SET FAILED_LOGIN_CNT = FAILED_LOGIN_CNT + 1,
                LOCKED_IND = CASE WHEN FAILED_LOGIN_CNT
                             + 1 >= 5 THEN 'Y' ELSE LOCKED_IND END
            WHERE USER_ID = :sql_pUserId;
          return *off;
        endif;
      end-proc;

      //-----------------------------------------------------------------
      // CaptureESignature - re-authenticates then writes SEC_ESIGNATURE.
      // Returns the generated ESIG_ID, or -1 on failed re-authentication.
      //-----------------------------------------------------------------
      dcl-proc CaptureESignature export;
        dcl-pi *n int(20);
        dcl-parm sql_pUserId     varchar(10) const;
        dcl-parm pPassword   varchar(128) const;
        dcl-parm sql_pMeaningTxt varchar(100) const;
        dcl-parm sql_pDeviceIp   varchar(45) const;
        end-pi;
        dcl-s sql_NewEsigId int(20);

        if not VerifyPassword(sql_pUserId: pPassword);
          return -1;
        endif;

        monitor;
          exec sql
            INSERT INTO SCSGNTR (USER_ID, MEANING_TXT, REAUTH_IND,
                                        SOURCE_IP)
            VALUES (:sql_pUserId, :sql_pMeaningTxt, 'Y', :sql_pDeviceIp);

          exec sql VALUES IDENTITY_VAL_LOCAL() INTO :sql_NewEsigId;
          return sql_NewEsigId;
        on-error;
          LogError('CaptureESignature': sqlcode: sqlstt:
                  'Failed to capture signature': sql_pUserId);
          return -1;
        endmon;
      end-proc;

