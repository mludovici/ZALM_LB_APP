@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View für LB_REVIEW'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZALM_LB_I_REVIEW 
  as select from zalm_lb_review
  association to parent ZALM_LB_I_Book              as _Book   on $projection.BookUuid = _Book.BookUuid
  association of many to one       ZALM_LB_I_MEMBER as _Member on $projection.MemberId = _Member.MemberId
{
  key review_uuid                                          as ReviewUuid,
      book_uuid                                            as BookUuid,
      member_id                                            as MemberId,
      cast( rating as ZALM_LB_T_Rating preserving type )   as Rating,
      headline                                             as Headline,
      comment_text                                         as CommentText,
      review_date                                          as ReviewDate,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at                                as LocalLastChangedAt,
      
      _Book,
      _Member
}
