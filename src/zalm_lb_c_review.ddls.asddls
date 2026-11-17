@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projektions View für I_Review'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZALM_LB_C_Review
  as projection on ZALM_LB_I_REVIEW
{
  key ReviewUuid,
      BookUuid,
      @Consumption.valueHelpDefinition:[{ entity: { name: 'ZALM_LB_I_MEMBER', element: 'MemberId' } }]
      @ObjectModel.text.element: ['MemberName']
      @EndUserText.label: 'Rezensent'
      MemberId,
      @EndUserText.label: 'Bewertung'
      Rating,
      @EndUserText.label: 'Überschrift'
      Headline,
      @EndUserText.label: 'Kommentar'
      CommentText,
      @EndUserText.label: 'Rezensionsdatum'
      ReviewDate,
      LocalLastChangedAt,
      /* Associations */
      _Book : redirected to parent ZALM_LB_C_Book,
      _Member,
      _Member.FullName  as MemberName,
      _Member.AvatarUrl as MemberAvatar
}
