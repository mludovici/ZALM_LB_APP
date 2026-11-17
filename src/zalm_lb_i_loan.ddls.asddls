@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View für LB_LOAN'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZALM_LB_I_LOAN 
  as select from zalm_lb_loan
  association to parent ZALM_LB_I_Book                 as _Book   on $projection.BookUuid = _Book.BookUuid
  association of many to one       ZALM_LB_I_MEMBER    as _Member on $projection.MemberId = _Member.MemberId
  association of many to exact one ZALM_LB_I_LoanStatus as _Status on $projection.StatusId = _Status.StatusId
{
  key loan_uuid                                            as LoanUuid,
      book_uuid                                            as BookUuid,
      cast( loan_no as ZALM_LB_T_LoanNo preserving type )  as LoanNo,
      member_id                                            as MemberId,
      loan_date                                            as LoanDate,
      due_date                                             as DueDate,
      return_date                                          as ReturnDate,
      status_id                                            as StatusId,
      extension_count                                      as ExtensionCount,
      note                                                 as Note,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at                                as LocalLastChangedAt,
      
      _Book,
      _Member,
      _Status
}
