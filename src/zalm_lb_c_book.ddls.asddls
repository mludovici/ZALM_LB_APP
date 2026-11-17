@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Root Projektions View für I_Book'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'BookId' ]
@Search.searchable: true
define root view entity ZALM_LB_C_Book
  provider contract transactional_query
  as projection on ZALM_LB_I_Book
{
  key BookUuid,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      BookId,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Isbn,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Title,
      @EndUserText.label: 'Autor'
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      Author,
      Category,
      @EndUserText.label: 'Erscheinungsjahr'
      PublishYear,
      @EndUserText.label: 'Seitenzahl'
      PageCount,
      @EndUserText.label: 'Preis'
      @Semantics.amount.currencyCode: 'CurrencyCode'
      Price,      
      @Semantics.currencyCode: true
      CurrencyCode,
      @EndUserText.label: 'Gesamtbestand'
      TotalCopies,
      @EndUserText.label: 'Verfügbare Exemplare'
      AvailCopies,
      AvgRating,
      CoverUrl,
      SamplePdf,
      SampleMime,
      SampleFilename,
      IsArchived,
      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,
      /* Associations */
      _Loan   : redirected to composition child ZALM_LB_C_Loan,
      _Review : redirected to composition child ZALM_LB_C_Review
}
