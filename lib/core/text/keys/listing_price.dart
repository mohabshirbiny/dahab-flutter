import '../text_key.dart';

/// Changing the price of a live piece (backend spec 022): the form behind *Change fee* /
/// *Change price* on the seller's own piece, and the line that explains why it is closed.
/// `listing.price.*`.
///
/// English is the code's own text. The Arabic defaults below are AR-DRAFT: written for the
/// owner's review (the Egyptian wording of the app), published only through App text.
/// Keys are append-only (Q1).
abstract final class ListingPriceKeys {
  static const _area = 'Selling';
  static const _form = 'Change price screen';
  static const _piece = 'Piece page';

  // ---- The form ----

  static const titleStones = TextKey('listing.price.title_stones', 'Change price', ar: 'غيّر السعر', area: _area, where: _form);
  static const note = TextKey(
    'listing.price.note',
    'You can change the price while no one has asked to buy the piece. The piece keeps its place and its views.',
    ar: 'تقدر تغيّر السعر طول ما مفيش حد طلب القطعة. القطعة بتفضل في مكانها وبمشاهداتها.',
    area: _area,
    where: _form,
  );
  static const makingNow = TextKey('listing.price.making_now', 'Making charge now', ar: 'المصنعية دلوقتي', area: _area, where: _form);
  static const askingNow = TextKey('listing.price.asking_now', 'Asking price now', ar: 'السعر المطلوب دلوقتي', area: _area, where: _form);
  static const makingLabel = TextKey('listing.price.making_label', 'New making charge per gram', ar: 'المصنعية الجديدة للجرام', area: _area, where: _form);
  static const askingLabel = TextKey('listing.price.asking_label', 'New asking price', ar: 'السعر المطلوب الجديد', area: _area, where: _form);
  static const youWouldReceive = TextKey('listing.price.you_would_receive', 'You would receive', ar: 'هتستلم', area: _area, where: _form);
  static const estimatePaused = TextKey('listing.price.estimate_paused', 'The estimate is paused right now.', ar: 'التقدير واقف دلوقتي.', area: _area, where: _form);
  static const save = TextKey('listing.price.save', 'Save', ar: 'حفظ', area: _area, where: _form);
  static const saved = TextKey('listing.price.saved', 'Price updated.', ar: 'السعر اتحدّث.', area: _area, where: _form);
  static const loadFailed = TextKey('listing.price.load_failed', 'This piece could not be loaded.', ar: 'مقدرناش نحمّل القطعة.', area: _area, where: _form);
  static const amountInvalid = TextKey(
    'listing.price.amount_invalid',
    'Enter the new figure, with at most two decimals.',
    ar: 'اكتب الرقم الجديد، وبحد أقصى رقمين بعد العلامة.',
    area: _area,
    where: _form,
  );
  static const same = TextKey('listing.price.same', 'This is already the price.', ar: 'ده هو السعر الحالي.', area: _area, where: _form);

  // ---- Refusals ----

  static const errHasRequests = TextKey(
    'listing.price.err_has_requests',
    "Someone has already asked to buy this piece, so its price can't change.",
    ar: 'فيه حد طلب القطعة دي، فالسعر مينفعش يتغيّر.',
    area: _area,
    where: _form,
  );
  static const errLocked = TextKey(
    'listing.price.err_locked',
    "This piece's price is fixed for now. Contact us if you need to change it.",
    ar: 'سعر القطعة دي ثابت دلوقتي. كلمنا لو محتاج تغيّره.',
    area: _area,
    where: _form,
  );
  static const errNotLive = TextKey('listing.price.err_not_live', "Only a live piece's price can be changed.", ar: 'السعر بيتغيّر بس للقطعة المعروضة.', area: _area, where: _form);
  static const errStopped = TextKey(
    'listing.price.err_stopped',
    'Dahab is paused for a short while. Your money and pieces are safe.',
    ar: 'دهب واقف شوية. فلوسك وقطعك في أمان.',
    area: _area,
    where: _form,
  );

  // ---- On the piece page ----

  static const changePrice = TextKey('listing.price.change_price', 'Change price', ar: 'غيّر السعر', area: _area, where: _piece);
  static const reservedNote = TextKey(
    'listing.price.reserved_note',
    "Someone is in line for this piece, so its price can't change. You can change it again if the line empties.",
    ar: 'فيه حد في الدور على القطعة دي، فالسعر مينفعش يتغيّر. تقدر تغيّره تاني لو الدور فضي.',
    area: _area,
    where: _piece,
  );

  static const all = <TextKey>[
    titleStones,
    note,
    makingNow,
    askingNow,
    makingLabel,
    askingLabel,
    youWouldReceive,
    estimatePaused,
    save,
    saved,
    loadFailed,
    amountInvalid,
    same,
    errHasRequests,
    errLocked,
    errNotLive,
    errStopped,
    changePrice,
    reservedNote,
  ];
}
