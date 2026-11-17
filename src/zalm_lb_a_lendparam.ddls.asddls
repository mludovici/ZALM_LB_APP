@EndUserText.label: 'Abstrakte Entität für Ausleih-Dialog'
define abstract entity ZALM_LB_A_LendParam

{ //Wertehilfe anzeigen
  @Consumption.valueHelpDefinition: [{ entity: { name: 'ZALM_LB_I_MEMBER', element: 'MemberId' } }]
  @EndUserText.label: 'Mitgliedsnummer'
  MemberId : abap.char(8);
  @EndUserText.label: 'Leihdatum'
  LoanDate : abap.dats;
  @EndUserText.label: 'Fälligkeitsdatum'
  DueDate  : abap.dats;
  @EndUserText.label: 'Notiz'
  Note     : abap.char(255);

}
