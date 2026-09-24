**FREE
      //=================================================================
      // PPQAPRR - Approval Worklist / e-Signature capture (Module 25)
      //=================================================================
      ctl-opt main(Main);
      ctl-opt dftactgrp(*no) actgrp('PPQ') bnddir('SREERAMC1/PPQBNDDIR');

      dcl-f PPQAPRD workstn indds(AprInd);

      dcl-ds AprInd len(99);
        F03 ind pos(3);
        F12 ind pos(12);
      end-ds;

      /copy SREERAMC1/PPQIBMI,CPYSEC

      dcl-pr RecordApproval ind extproc('RECORDAPPROVAL');
        pProtocolId int(20) const;
        pApprSeq    int(5) const;
        pRoleCd     char(10) const;
        pUserId     varchar(10) const;
        pPassword   varchar(128) const;
        pApprove    ind const;
        pMeaningTxt varchar(100) const;
        pDeviceIp   varchar(45) const;
      end-pr;

      dcl-pr Main extpgm('PPQAPRR');
        pProtocolId int(20) const options(*nopass);
        pApprSeq    int(5)  const options(*nopass);
        pRoleCd     char(10) const options(*nopass);
      end-pr;

      // In production this program is entered from a worklist subfile
      // of PPQ_APPROVAL rows WHERE APPR_STATUS='PENDING' AND ROLE_CD
      // is one the logged-in user holds (HasRole()); the selected row's
      // PROTOCOL_ID/APPR_SEQ/ROLE_CD are passed in as parameters.


      dcl-proc Main;

        dcl-pi Main;
        pProtocolId int(20) const options(*nopass);
        pApprSeq    int(5)  const options(*nopass);
        pRoleCd     char(10) const options(*nopass);
        end-pi;



        $A_PROTNO = %char(pProtocolId);
        $A_ROLE   = pRoleCd;

        exfmt APRDTL;

        if not *in12;
          if RecordApproval(pProtocolId: pApprSeq: pRoleCd:
                           sql_gSession.UserId: $A_PASSWD:
                           ($A_DECISN = 'A'): $A_MEANING: '*LOCAL');
            $MSGTXT = 'Signature captured.';
          else;
            $MSGTXT = 'Signature failed - check password +
                      and role authorization.';
          endif;
        endif;

        close PPQAPRD;

        *inlr = *on;
      end-proc;

