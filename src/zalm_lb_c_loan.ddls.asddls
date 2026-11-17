@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Projektions View für I_Loan'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZALM_LB_C_Loan
  as projection on ZALM_LB_I_LOAN
{
    key LoanUuid,
    BookUuid,
    @EndUserText.label: 'Ausleihnummer'
    LoanNo,
    @ObjectModel.text.element: ['MemberName']
     @Consumption.valueHelpDefinition: [{ 
      entity: { name: 'ZALM_LB_I_MEMBER', element: 'MemberId'}
      }]
    @EndUserText.label: 'Entleiher'
    MemberId,
    @EndUserText.label: 'Ausleihdatum'
    LoanDate,
    @EndUserText.label: 'Fälligkeitsdatum'
    DueDate,
    @EndUserText.label: 'Rückgabedatum'
    ReturnDate,
    @ObjectModel.text.element: ['StatusText']
    //element ist das Feld das "zurückgespeichert" werden soll, also in dem Fall StatusId nach StatusId
     @Consumption.valueHelpDefinition: [{ 
      entity: { name: 'ZALM_LB_I_LoanStatus', element: 'StatusId'},
      //Prüft, ob der Wert in ZALM_LB_I_LoanStatus existiert, z.B bei manueller Eingabe
      useForValidation: true
      }]
      @EndUserText.label: 'Status'
    StatusId,
    @EndUserText.label: 'Verlängerungen'
    ExtensionCount,
       @EndUserText.label: 'Notiz'
    Note,
    LocalLastChangedAt,
    /* Associations */
    _Book : redirected to parent ZALM_LB_C_Book,
    _Member,
    _Member.FullName as MemberName,
    _Status,
    _Status.StatusText as StatusText,
    _Status.Criticality as StatusCriticality
}
