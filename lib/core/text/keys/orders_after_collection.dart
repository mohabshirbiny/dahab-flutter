import '../text_key.dart';

/// Stage 1 of the app text (backend spec 019, FR-008): every visible sentence, label and
/// button of the spec 018 screens — the free-relist card and its notes on the order screen,
/// the relist form and the rating screen. English is the code's own text, unchanged; the
/// Arabic default is what `LangController` already has for it. Keys are append-only (Q1).
///
/// `order.free_relist.*` — the offer, `order.no_fee.*` — the seller's note,
/// `order.rating.*` — the rating. There is no invite or referral text here (spec 018 FR-038).
abstract final class OrdersAfterCollectionKeys {
  static const _area = 'Orders';
  static const _card = 'Order screen, the offer to relist with no commission';
  static const _used = 'Order screen, after the free relist was made';
  static const _form = 'Relist with no commission screen';
  static const _rate = 'Rate an order screen';

  // ---- The order screen: the offer ----

  static const freeRelistCardTitle = TextKey('order.free_relist.card_title', 'Sell it again with no commission', area: _area, where: _card);
  static const freeRelistCardBody = TextKey(
    'order.free_relist.card_body',
    'You collected this piece. Put it back on the market now and Dahab takes no commission on that sale. It goes live straight away, with no review.',
    area: _area,
    where: _card,
  );
  static const freeRelistCardUntil = TextKey('order.free_relist.card_until', 'Until', area: _area, where: _card);
  static const freeRelistCardTimeLeft = TextKey('order.free_relist.card_time_left', 'Time left', area: _area, where: _card);
  static const freeRelistCardLeftHoursMinutes = TextKey(
    'order.free_relist.card_left_hours_minutes',
    '{hours} h {minutes} min left',
    ar: 'فاضل {hours} ساعة و{minutes} دقيقة',
    placeholders: ['hours', 'minutes'],
    area: _area,
    where: _card,
  );
  static const freeRelistCardLeftMinutes = TextKey('order.free_relist.card_left_minutes', '{minutes} min left', ar: 'فاضل {minutes} دقيقة', placeholders: ['minutes'], area: _area, where: _card);
  static const freeRelistCardButton = TextKey('order.free_relist.card_button', 'Relist this piece, no commission', area: _area, where: _card);
  static const freeRelistUsedNote = TextKey('order.free_relist.used_note', 'You put this piece back on the market with no commission.', area: _area, where: _used);
  static const freeRelistUsedSeeListings = TextKey('order.free_relist.used_see_listings', 'See it in My listings', area: _area, where: _used);

  // ---- The order screen: the seller's note and the rating line ----

  static const noFeeSellerNote = TextKey(
    'order.no_fee.seller_note',
    'No Dahab fee on this sale. It was a free relist, so the whole price reached you.',
    area: _area,
    where: 'Order screen, seller of a free relist',
  );
  static const ratingGivenNote = TextKey('order.rating.given_note', 'You rated this order {stars} out of 5.', placeholders: ['stars'], area: _area, where: 'Order screen, after rating');
  static const ratingRateButton = TextKey('order.rating.rate_button', 'Rate this order', area: _area, where: 'Order screen, when rating is open');

  // ---- The relist form ----

  static const formUsedAlready = TextKey('order.free_relist.form.used_already', 'You already put this piece back on the market.', area: _area, where: _form);
  static const formWindowOver = TextKey('order.free_relist.form.window_over', 'The time to relist this piece with no commission has passed.', area: _area, where: _form);
  static const formBackToOrder = TextKey('order.free_relist.form.back_to_order', 'Back to the order', area: _area, where: _form);
  static const formLiveAgainNote = TextKey(
    'order.free_relist.form.live_again_note',
    'Your piece goes live again straight away, with no review. The karat and weight are the ones IGI measured, and your photos and branches come with it. You set the price.',
    area: _area,
    where: _form,
  );
  static const formPriceLabelGold = TextKey('order.free_relist.form.price_label_gold', 'Your making charge per gram (EGP)', area: _area, where: _form);
  static const formPriceLabelOther = TextKey('order.free_relist.form.price_label_other', 'The price you are asking (EGP)', area: _area, where: _form);
  static const formPriceHintGold = TextKey('order.free_relist.form.price_hint_gold', 'For example 250', area: _area, where: _form);
  static const formPriceHintOther = TextKey('order.free_relist.form.price_hint_other', 'For example 120000', area: _area, where: _form);
  static const formDescriptionLabel = TextKey('order.free_relist.form.description_label', 'Anything to add? (optional)', area: _area, where: _form);
  static const formDescriptionHint = TextKey('order.free_relist.form.description_hint', 'A line about the piece.', area: _area, where: _form);

  /// The estimate line. Spec 018 A6: the wording is still to be approved by the owner with its Arabic.
  static const formEstimateLine = TextKey(
    'order.free_relist.form.estimate_line',
    'No Dahab commission on this sale. The difference between the rate you were charged and the rate you are paid still applies, and the final figure is worked out on the weight IGI measures.',
    area: _area,
    where: 'Relist with no commission screen, the line under the price',
  );
  static const formDeclarationFallback = TextKey(
    'order.free_relist.form.declaration_fallback',
    'I confirm this piece is mine to sell and the details above are accurate.',
    area: _area,
    where: 'Relist with no commission screen, the ownership tick box when the declaration text is empty',
  );
  static const formSubmitButton = TextKey('order.free_relist.form.submit_button', 'Relist with no commission', area: _area, where: _form);
  static const formErrorPriceGold = TextKey('order.free_relist.form.error_price_gold', 'Enter your making charge per gram.', area: _area, where: _form);
  static const formErrorPriceOther = TextKey('order.free_relist.form.error_price_other', 'Enter the price you are asking.', area: _area, where: _form);
  static const formErrorConfirmOwnership = TextKey('order.free_relist.form.error_confirm_ownership', 'Confirm ownership to list the piece.', area: _area, where: _form);
  static const formErrorDeclarationChanged = TextKey(
    'order.free_relist.form.error_declaration_changed',
    'The declaration text changed. Read it again and confirm.',
    area: _area,
    where: _form,
  );
  static const formSuccessTitle = TextKey('order.free_relist.form.success_title', 'Back on the market', area: _area, where: 'Relist with no commission screen, the dialog after sending');
  static const formSuccessBody = TextKey(
    'order.free_relist.form.success_body',
    'Your piece is live again with no Dahab commission. You can see it in My listings.',
    area: _area,
    where: 'Relist with no commission screen, the dialog after sending',
  );
  static const formWindowUntil = TextKey('order.free_relist.form.window_until', 'Relist with no commission until', area: _area, where: _form);
  static const formWindowTimeLeft = TextKey('order.free_relist.form.window_time_left', 'Time left', area: _area, where: _form);
  static const formWindowTimeUp = TextKey('order.free_relist.form.window_time_up', 'Time is up', area: _area, where: _form);
  static const formWindowLeftHoursMinutes = TextKey(
    'order.free_relist.form.window_left_hours_minutes',
    '{hours} h {minutes} min left',
    ar: 'فاضل {hours} ساعة و{minutes} دقيقة',
    placeholders: ['hours', 'minutes'],
    area: _area,
    where: _form,
  );
  static const formWindowLeftMinutes = TextKey('order.free_relist.form.window_left_minutes', '{minutes} min left', ar: 'فاضل {minutes} دقيقة', placeholders: ['minutes'], area: _area, where: _form);

  // ---- The rating screen ----

  static const rateThanksTitle = TextKey('order.rating.thanks_title', 'Thank you', area: _area, where: _rate);
  static const rateThanksBody = TextKey('order.rating.thanks_body', 'It helps more than you think.', area: _area, where: _rate);
  static const rateBackToOrder = TextKey('order.rating.back_to_order', 'Back to the order', area: _area, where: _rate);
  static const rateClosedNote = TextKey('order.rating.closed_note', 'The time to rate this order has passed.', area: _area, where: _rate);
  static const rateNotYetNote = TextKey('order.rating.not_yet_note', 'You can rate this order once the sale is settled for you.', area: _area, where: _rate);
  static const rateTitleSeller = TextKey('order.rating.title_seller', 'How did your sale go?', area: _area, where: _rate);
  static const rateTitleBuyer = TextKey('order.rating.title_buyer', 'How did your purchase go?', area: _area, where: _rate);
  static const rateSubtitle = TextKey('order.rating.subtitle', 'Tell us about your experience with Dahab. It is only for us.', area: _area, where: _rate);
  static const rateErrorStars = TextKey('order.rating.error_stars', 'Choose how many stars before sending.', area: _area, where: _rate);
  static const rateNoteHint = TextKey('order.rating.note_hint', 'Anything we could do better?', area: _area, where: _rate);
  static const rateSendButton = TextKey('order.rating.send_button', 'Send', area: _area, where: _rate);

  static const all = <TextKey>[
    freeRelistCardTitle,
    freeRelistCardBody,
    freeRelistCardUntil,
    freeRelistCardTimeLeft,
    freeRelistCardLeftHoursMinutes,
    freeRelistCardLeftMinutes,
    freeRelistCardButton,
    freeRelistUsedNote,
    freeRelistUsedSeeListings,
    noFeeSellerNote,
    ratingGivenNote,
    ratingRateButton,
    formUsedAlready,
    formWindowOver,
    formBackToOrder,
    formLiveAgainNote,
    formPriceLabelGold,
    formPriceLabelOther,
    formPriceHintGold,
    formPriceHintOther,
    formDescriptionLabel,
    formDescriptionHint,
    formEstimateLine,
    formDeclarationFallback,
    formSubmitButton,
    formErrorPriceGold,
    formErrorPriceOther,
    formErrorConfirmOwnership,
    formErrorDeclarationChanged,
    formSuccessTitle,
    formSuccessBody,
    formWindowUntil,
    formWindowTimeLeft,
    formWindowTimeUp,
    formWindowLeftHoursMinutes,
    formWindowLeftMinutes,
    rateThanksTitle,
    rateThanksBody,
    rateBackToOrder,
    rateClosedNote,
    rateNotYetNote,
    rateTitleSeller,
    rateTitleBuyer,
    rateSubtitle,
    rateErrorStars,
    rateNoteHint,
    rateSendButton,
  ];
}
