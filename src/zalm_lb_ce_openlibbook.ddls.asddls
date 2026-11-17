@EndUserText.label: 'OpenLibrary Buchsuche'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_ALM_LB_OPENLIB_QRY'
@Search.searchable: true
@UI: {
  headerInfo: {
    typeName: 'OpenLibrary-Treffer',
    typeNamePlural: 'OpenLibrary-Treffer',
    title: { type: #STANDARD, value: 'Title' },
    description: { type: #STANDARD, value: 'Author' },
    imageUrl: 'CoverUrl'
  }
}
define root custom entity ZALM_LB_CE_OpenLibBook
{
      @UI.lineItem: [{ position: 60 }]
  key OpenLibKey  : abap.char(40);
      @UI.selectionField: [{ position: 30 }]
      @UI.lineItem: [{ position: 50 }, { 
      type: #FOR_ACTION, 
      position: 10, dataAction: 'importFromOpenLib', 
      label: 'In Bibliothek übernehmen' }]
      Isbn        : ZALM_LB_T_Isbn;
      @Search.defaultSearchElement: true
      @UI.selectionField: [{ position: 10 }]
      @UI.lineItem: [{ position: 20 }]
      Title       : ZALM_LB_T_Title;
      @Search.defaultSearchElement: true
      @UI.selectionField: [{ position: 20 }]
      @UI.lineItem: [{ position: 30 }]
      Author      : abap.char(80);
      @UI.lineItem: [{ position: 40 }]
      PublishYear : abap.numc(4);
      @Semantics.imageUrl: true
      @UI.lineItem: [{ position: 10 }]
      CoverUrl    : ZALM_LB_T_Url;
      @UI.lineItem: [{ position: 70 }]
      SourceMode  : abap.char(15);
}
