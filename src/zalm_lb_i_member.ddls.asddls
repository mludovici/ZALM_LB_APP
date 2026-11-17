@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View für LB_MEMBER'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define view entity ZALM_LB_I_MEMBER
  as select from zalm_lb_member
{
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
  key member_id                                 as MemberId,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      first_name                                as FirstName,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      last_name                                 as LastName,
      concat_with_space(first_name,last_name,1) as FullName,
      department                                as Department,
      @Search.defaultSearchElement: true
      @Semantics.eMail.address: true
      email                                     as Email,
      @Semantics.telephone.type: [ #CELL ]
      phone                                     as Phone,
      building                                  as Building,
      @Semantics.address.city: true
      city                                      as City,
      @Semantics.address.country: true
      country                                   as Country,
      @Semantics.imageUrl: true
      avatar_url                                as AvatarUrl,
      max_loans                                 as MaxLoans,
      is_blocked                                as IsBlocked
}
