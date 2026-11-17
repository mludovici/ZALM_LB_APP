@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View für LB_LSTATUS'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.resultSet.sizeCategory: #XS
define view entity ZALM_LB_I_LoanStatus as select from zalm_lb_lstatus
{
    key status_id as StatusId,
    status_text as StatusText,
    is_active_loan as IsActiveLoan,
    is_final as IsFinal,
    criticality as Criticality
}
