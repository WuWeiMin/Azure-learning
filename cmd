// ============================================================
// 公式: Case_ProcessGenie_CreateFinalBillSubmission
// 类型: Process Genie (被动调用,由按钮/JS/流程显式触发)
// 返回: Boolean (Display Format = Boolean)
// Hit Policy: 假设默认"命中即停" (建议右键Hit Policy确认)
// ============================================================

function CreateFinalBillSubmission(incident) {

    // ---------- 第4行: 门诊账单 ----------
    if ( incident.aia_requesttype == {OP-BILL}
         && HasAllAmendedCompleted() == true          // B列: Snippet,检查所有修正账单已完成
         && CreateOPFinalBillSubmission() == 'Yes' )  // C列: Snippet,⚠内部实际执行"创建OP最终账单提交记录",返回是否成功
    {
        return TRUE;                                  // D列: 返回给调用方
    }

    // ---------- 第5行: 住院出院账单 ----------
    else if ( incident.aia_requesttype == {IP-DISCHARGE}
              && HasAllAmendedCompleted() == true
              && CreateIPFinalBillSubmission() == 'Yes' )
    {
        return TRUE;
    }

    // ---------- 第6行: 住院随访账单 ----------
    else if ( incident.aia_requesttype == {IP-FUPBILL}
              && HasAllAmendedCompleted() == true
              && CreateIPFollowUpFinalBillSubmission() == 'Yes' )
    {
        return TRUE;
    }

    // ---------- 第7行: PR账单 ----------
    else if ( incident.aia_requesttype == {PR-BILL}
              && HasAllAmendedCompleted() == true
              && CreatePRFinalBillSubmission() == 'Yes' )
    {
        return TRUE;
    }

    // ---------- 第8行: MT账单 ----------
    else if ( incident.aia_requesttype == {MT-BILL}
              && HasAllAmendedCompleted() == true
              && CreatedMTFinalBillSubmission() == 'Yes' )
    {
        return TRUE;
    }

    // ---------- 第10行: 兜底(所有条件列为空 = 无条件命中) ----------
    else
    {
        return FALSE;    // 请求类型不在上述5种,或修正账单未完成,或创建失败
    }
}
