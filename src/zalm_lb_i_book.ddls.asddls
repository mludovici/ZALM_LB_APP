@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Interface View für LB_BOOK'
@Metadata.ignorePropagatedAnnotations: true
define root view entity ZALM_LB_I_Book
  as select from zalm_lb_book
  composition of exact one to many ZALM_LB_I_LOAN   as _Loan
  composition of exact one to many ZALM_LB_I_REVIEW as _Review
{
  key book_uuid                                              as BookUuid,
      //gleicher Datentyp aber mit semant. Informationen
      cast( book_id as ZALM_LB_T_BookId preserving type )    as BookId,
      cast( isbn as ZALM_LB_T_Isbn preserving type )         as Isbn,
      cast( title as ZALM_LB_T_Title preserving type )       as Title,
      author                                                 as Author,
      cast( category as ZALM_LB_T_Category preserving type ) as Category,
      publish_year                                           as PublishYear,
      page_count                                             as PageCount,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      price                                                  as Price,
      currency_code                                          as CurrencyCode,
      total_copies                                           as TotalCopies,
      avail_copies                                           as AvailCopies,
      cast( avg_rating as ZALM_LB_T_Rating preserving type ) as AvgRating,
      @Semantics.imageUrl: true
      cast (cover_url as ZALM_LB_T_Url preserving type )     as CoverUrl,
      @Semantics.largeObject: {
      mimeType: 'SampleMime',
      fileName: 'SampleFilename',
      contentDispositionPreference: #INLINE
      }
      sample_pdf                                             as SamplePdf,
      @Semantics.mimeType: true
      sample_mime                                            as SampleMime,
      sample_filename                                        as SampleFilename,
      is_archived                                            as IsArchived,
      @Semantics.user.createdBy: true
      created_by                                             as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at                                             as CreatedAt,
      
      @Semantics.user.lastChangedBy: true
      local_last_changed_by                                  as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at                                  as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at                                        as LastChangedAt,
      _Loan, // Make association public
      _Review
}
