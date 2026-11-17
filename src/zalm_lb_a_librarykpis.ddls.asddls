@EndUserText.label: 'Abstrakte Entität für KPIs Anzeige'
define abstract entity ZALM_LB_A_LibraryKpis
{
  TotalBooks       : abap.int4;
  TotalCopies      : abap.int4;
  AvailableCopies  : abap.int4;
  ActiveLoans      : abap.int4;
  OverdueLoans     : abap.int4;
  AvgLibraryRating : ZALM_LB_T_Rating;
}
