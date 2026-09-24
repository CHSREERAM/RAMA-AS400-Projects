**FREE
            //=================================================================
            // APRSRV - Module 25: Approval Workflow
            // Records role-level approval/rejection with a captured e-signature.
            // PPQ_HEADER cannot move to APPROVED until every row here is
            // APPROVED (enforced independently by TRG_PPQ_HEADER_WORKFLOW).
            //=================================================================
            ctl-opt nomain;
            exec sql SET OPTION commit = *cs, closqlcsr = *endmod;

            /copy SREERAMC1/PPQIBMI,CPYERR

            dcl-pr CaptureESignature int(20) extproc('CAPTUREESIGNATURE');
            pUserId     varchar(10) const;
            pPassword   varchar(128) const;
            pMeaningTxt varchar(100) const;
            pDeviceIp   varchar(45) const;
            end-pr;

            dcl-pr IsRoleAuthorized ind extproc('ISROLEAUTHORIZED');
            pUserId varchar(10) const;
            pRoleCd char(10) const;
            end-pr;

            dcl-pr ChangeStatus ind extproc('CHANGESTATUS');
            pProtocolId int(20) const;
            pNewStatus  varchar(10) const;
            pUserId     varchar(10) const;
            end-pr;

            //-----------------------------------------------------------------
            // RecordApproval - re-authenticates the approver, captures the
            // e-signature, marks the role row APPROVED/REJECTED, and - only
            // once every role for the protocol is APPROVED - advances the
            // header STATUS to APPROVED via ChangeStatus (HDRSRV).
            //-----------------------------------------------------------------
            dcl-pr RecordApproval ind extproc('RECORDAPPROVAL');
            pProtocolId int(20) const;
            pApprSeq    int(5) const;
            pRoleCd     char(10) const;
            pUserId     varchar(10) const;
            pPassword   varchar(128) const;
            pApprove    ind const;         // *on = approve, *off = reject
            pMeaningTxt varchar(100) const;
            pDeviceIp   varchar(45) const;
            end-pr;

            dcl-proc RecordApproval export;
            dcl-pi *n ind;
                pProtocolId    int(20) const;
                pApprSeq       int(5) const;
                pRoleCd        char(10) const;
                pUserId        varchar(10) const;
                pPassword      varchar(128) const;
                pApprove       ind const;
                pMeaningTxt    varchar(100) const;
                pDeviceIp      varchar(45) const;
            end-pi;

            // Renamed with 'l_' prefix to satisfy database manager rules
            dcl-s l_EsigId    int(20);
            dcl-s l_NewStatus varchar(10);
            dcl-s l_Remaining int(10);

            if not IsRoleAuthorized(pUserId: pRoleCd);
                return *off;   // user does not hold the role this row requires
            endif;

            l_EsigId = CaptureESignature(pUserId: pPassword:
                                        pMeaningTxt: pDeviceIp);
            if l_EsigId = -1;
                return *off;   // re-authentication failed
            endif;

            if pApprove;
                l_NewStatus = 'APPROVED';
            else;
                l_NewStatus = 'REJECTED';
            endif;

            monitor;
                exec sql
                UPDATE PPQ_APPROVAL
                SET APPR_STATUS = :l_NewStatus,
                    USER_ID = :pUserId,
                    ESIG_ID = :l_EsigId,
                    APPR_DT = CURRENT TIMESTAMP,
                    APPR_MEANING = :pMeaningTxt
                WHERE PROTOCOL_ID = :pProtocolId AND
                        APPR_SEQ = :pApprSeq;
                exec sql COMMIT;
            on-error;
                exec sql ROLLBACK;
                LogError('RecordApproval': sqlcode: sqlstt:
                    'Failed to record approval': pUserId);
                return *off;
            endmon;

            if pApprove;
                exec sql
                SELECT COUNT(*) INTO :l_Remaining
                FROM PPQ_APPROVAL
                WHERE PROTOCOL_ID = :pProtocolId
                    AND APPR_STATUS <> 'APPROVED';
                if l_Remaining = 0;
                ChangeStatus(pProtocolId: 'APPROVED': pUserId);
                endif;
            endif;

            return *on;
            end-proc;
