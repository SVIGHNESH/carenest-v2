// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'CareNest';

  @override
  String get tagline => 'Care at home';

  @override
  String get close => 'Close';

  @override
  String get loading => 'Loading';

  @override
  String get tryAgain => 'Try again';

  @override
  String get somethingWentWrong => 'Something went wrong';

  @override
  String get nothingHere => 'Nothing here yet';

  @override
  String get errorNetwork =>
      'Can\'t reach CareNest. Check your internet connection and try again.';

  @override
  String get errorTimeout => 'This is taking too long. Please try again.';

  @override
  String get errorServer =>
      'CareNest is having trouble right now. Please try again in a moment.';

  @override
  String get errorRateLimited =>
      'Too many tries. Please wait a little and try again.';

  @override
  String get errorNotFound => 'We couldn\'t find that.';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get keep => 'Keep';

  @override
  String get ok => 'OK';

  @override
  String get change => 'Change';

  @override
  String get stay => 'Stay';

  @override
  String get leave => 'Leave';

  @override
  String get startOver => 'Start over';

  @override
  String get moreActions => 'More actions';

  @override
  String stepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get loginTitle => 'Welcome to CareNest';

  @override
  String get loginSubtitle =>
      'Enter your mobile number. We\'ll send you a code to log in or create your account.';

  @override
  String get phoneLabel => 'Mobile number';

  @override
  String get phoneRequired => 'Enter your mobile number';

  @override
  String get phoneInvalid => 'Enter a valid 10-digit mobile number';

  @override
  String get sendCode => 'Send code';

  @override
  String get loginHint => 'Standard SMS charges may apply.';

  @override
  String get verifyTitle => 'Verify';

  @override
  String get otpTitle => 'Enter the code';

  @override
  String otpSentTo(String phone) {
    return 'We sent a 6-digit code to $phone';
  }

  @override
  String get otpLabel => '6-digit code';

  @override
  String get otpInvalid => 'Enter the 6-digit code';

  @override
  String get verify => 'Verify';

  @override
  String get changeNumber => 'Change number';

  @override
  String resendIn(String time) {
    return 'Resend code in $time';
  }

  @override
  String get resendCode => 'Resend code';

  @override
  String get tellUsTitle => 'Tell us about you';

  @override
  String get tellUsSubtitle =>
      'Just your name to get started. Email is optional.';

  @override
  String get fullName => 'Full name';

  @override
  String get nameRequired => 'Enter a name';

  @override
  String get emailOptional => 'Email (optional)';

  @override
  String get email => 'Email';

  @override
  String get emailInvalid => 'Enter a valid email address';

  @override
  String get getStarted => 'Get started';

  @override
  String get navHome => 'Home';

  @override
  String get navServices => 'Services';

  @override
  String get navBookings => 'Bookings';

  @override
  String get navProfile => 'Profile';

  @override
  String greeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get homeSubtitle => 'Trusted nurses, at home, when you need them.';

  @override
  String get bookService => 'Book service';

  @override
  String get myBookings => 'My bookings';

  @override
  String get services => 'Services';

  @override
  String get viewAll => 'View all';

  @override
  String get nextBooking => 'Next booking';

  @override
  String get noUpcomingBooking =>
      'No upcoming bookings. Book a service to get started.';

  @override
  String get noServices => 'No services yet';

  @override
  String get noServicesBody => 'Please check back soon.';

  @override
  String pricePerHour(String price) {
    return '$price per hour';
  }

  @override
  String get notAvailableNow => 'Not available right now';

  @override
  String get notAvailableShort => 'Unavailable';

  @override
  String get bookingsPausedBanner =>
      'Bookings are temporarily unavailable. Please try again later.';

  @override
  String get bookNow => 'Book now';

  @override
  String get priceIncludesTax => 'Price includes all taxes. No extra fees.';

  @override
  String get leaveBookingTitle => 'Leave this booking?';

  @override
  String get leaveBookingBody => 'What you entered will be cleared.';

  @override
  String get keepBooking => 'Keep booking';

  @override
  String get stepPatientTitle => 'Patient';

  @override
  String get stepWhenTitle => 'Date and time';

  @override
  String get stepDurationTitle => 'Duration';

  @override
  String get stepNurseTitle => 'Nurse preference';

  @override
  String get stepDetailsTitle => 'Details and address';

  @override
  String get stepReviewTitle => 'Review';

  @override
  String get whoIsVisitFor => 'Who is this visit for?';

  @override
  String get myself => 'Myself';

  @override
  String get addFamilyMemberPlus => '+ Add family member';

  @override
  String get pickADay => 'Pick a day';

  @override
  String get startTime => 'Start time';

  @override
  String noticeHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String noticeMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String noticeHint(String notice) {
    return 'Bookings need at least $notice notice.';
  }

  @override
  String earliestStartToday(String time) {
    return 'Earliest start today is $time.';
  }

  @override
  String get tooSoonShort => 'too soon';

  @override
  String get bookedShort => 'not available';

  @override
  String get couldNotLoadTimes => 'We couldn\'t load the times for this day.';

  @override
  String get noTimesThisDay => 'No times on this day';

  @override
  String get noTimesThisDayBody => 'Try another day.';

  @override
  String get howManyHours => 'How many hours?';

  @override
  String hoursCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String durationCapped(int hours) {
    return 'A nurse is free for up to $hours hours from this start time.';
  }

  @override
  String priceTimesHours(String price, int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return '$price x $_temp0';
  }

  @override
  String get noDurationTitle => 'No visit can start at this time';

  @override
  String get noDurationBody => 'Pick a different start time or day.';

  @override
  String get changeDateOrTime => 'Change date or time';

  @override
  String get whoWouldYouPrefer => 'Who would you prefer?';

  @override
  String get femaleNurse => 'Female nurse';

  @override
  String get maleNurse => 'Male nurse';

  @override
  String get availableForYourTime => 'Available for your time';

  @override
  String get notAvailableForThisTime => 'Not available for this time';

  @override
  String noNurseFreeFor(String gender, String when) {
    return 'No $gender is free on $when.';
  }

  @override
  String noNurseFreeBoth(String when) {
    return 'No nurse is free on $when.';
  }

  @override
  String get nurseAssignedNote =>
      'We assign a qualified nurse for you. You\'ll see their name once the booking is confirmed.';

  @override
  String get patientDetails => 'Patient details';

  @override
  String get patientName => 'Patient name';

  @override
  String get patientAge => 'Age';

  @override
  String get patientSex => 'Sex';

  @override
  String get sexMale => 'Male';

  @override
  String get sexFemale => 'Female';

  @override
  String get sexOther => 'Other';

  @override
  String get sexRequired => 'Choose one';

  @override
  String get conditionNotes => 'Condition or notes';

  @override
  String get contactPhone => 'Contact phone';

  @override
  String get contactPhoneOptional => 'Contact phone (optional)';

  @override
  String get contactPhoneHelp =>
      'The nurse and our team will call this number about the visit.';

  @override
  String get ageInvalid => 'Enter an age from 0 to 120';

  @override
  String get whereShouldNurseCome => 'Where should the nurse come?';

  @override
  String get currentLocation => 'Current location';

  @override
  String get pickOnMap => 'Pick on map';

  @override
  String get couldNotLoadAddresses => 'We couldn\'t load your saved addresses.';

  @override
  String get addressRequired => 'Choose or add an address with a map pin';

  @override
  String get labelHome => 'Home';

  @override
  String get labelWork => 'Work';

  @override
  String get labelOther => 'Other';

  @override
  String get service => 'Service';

  @override
  String get when => 'When';

  @override
  String get duration => 'Duration';

  @override
  String get nurse => 'Nurse';

  @override
  String get patient => 'Patient';

  @override
  String get address => 'Address';

  @override
  String get total => 'Total';

  @override
  String get amount => 'Amount';

  @override
  String get paid => 'Paid';

  @override
  String nurseGenderLine(String gender) {
    return '$gender';
  }

  @override
  String get pay => 'Pay';

  @override
  String payAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get confirmedWhenPaid =>
      'Your booking is confirmed as soon as you pay.';

  @override
  String get holdNote =>
      'We hold a nurse for you for 15 minutes while you pay.';

  @override
  String get paymentNotCompleted =>
      'Payment was not completed. Your nurse is still held for a few minutes.';

  @override
  String get paymentFailed => 'Payment didn\'t go through. Please try again.';

  @override
  String get autoCancelledTitle => 'We couldn\'t confirm your visit';

  @override
  String autoCancelledBody(String amount) {
    return 'Your payment arrived after the held time ran out and no nurse was free. $amount will be refunded in full.';
  }

  @override
  String get noticeNoNurseFree =>
      'No nurse is free for that time any more. Please choose another time. Your other choices are kept.';

  @override
  String get noticeHoldExpired =>
      'Your held time ran out. Please pick a time again. Your other choices are kept.';

  @override
  String get noticeTooSoon =>
      'That start time is too soon. Please pick a later time.';

  @override
  String get noticeTooFar =>
      'That day is too far ahead to book. Please pick an earlier day.';

  @override
  String get noticeCrossesMidnight =>
      'A visit must finish by midnight. Please choose an earlier start or fewer hours.';

  @override
  String get payUpi => 'UPI';

  @override
  String get payUpiHint => 'Any UPI app';

  @override
  String get payCard => 'Card';

  @override
  String get payCardHint => 'Credit or debit';

  @override
  String get payNetbanking => 'Net banking';

  @override
  String get payNetbankingHint => 'All major banks';

  @override
  String get paySecureTestNote =>
      'Secure payment. This is a test checkout, no real money moves.';

  @override
  String holdTimeLeft(String time) {
    return 'Time left to pay: $time';
  }

  @override
  String holdTimeLeftSemantics(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'About $_temp0 left to pay';
  }

  @override
  String get bookingConfirmed => 'Booking confirmed';

  @override
  String bookingNumber(int id) {
    return 'Booking #$id';
  }

  @override
  String get yourNurse => 'Your nurse';

  @override
  String get nurseSoon => 'Will be shared soon';

  @override
  String get smsSentNote => 'We have sent you an SMS with these details.';

  @override
  String get viewBooking => 'View booking';

  @override
  String get backToHome => 'Back to home';

  @override
  String get setLocation => 'Set location';

  @override
  String get searchPlaces => 'Search area, street or landmark';

  @override
  String get useCurrentLocation => 'Use my current location';

  @override
  String get confirmLocation => 'Confirm location';

  @override
  String get findingAddress => 'Finding address...';

  @override
  String get addressNotFound =>
      'We couldn\'t name this spot. You can still use it and add the details next.';

  @override
  String get searchFailed =>
      'Search isn\'t working right now. You can still move the map.';

  @override
  String get locationDenied =>
      'Location access is off. You can still search or move the map.';

  @override
  String get locationDeniedForever =>
      'Location access is blocked for CareNest. Turn it on in Settings, or search and move the map instead.';

  @override
  String get locationOff =>
      'Location is switched off on this phone. You can still search or move the map.';

  @override
  String get locationUnavailable =>
      'We couldn\'t get your location. You can still search or move the map.';

  @override
  String simulatedMapLabel(String point) {
    return 'Map preview, pin at $point. Drag to move the pin.';
  }

  @override
  String get simulatedMapNote => 'Map preview (no Google Maps key)';

  @override
  String get addressDetails => 'Address details';

  @override
  String get editAddress => 'Edit address';

  @override
  String get houseOrFlat => 'House or flat number';

  @override
  String get houseRequired => 'Enter the house or flat number';

  @override
  String get landmarkOptional => 'Landmark (optional)';

  @override
  String get saveAs => 'Save as';

  @override
  String get saveForNextTime => 'Save for next time';

  @override
  String get setAsDefault => 'Set as default address';

  @override
  String get useThisAddress => 'Use this address';

  @override
  String get saveAddress => 'Save address';

  @override
  String get editAreaDetails => 'Edit area details';

  @override
  String get areaStreet => 'Area or street';

  @override
  String get city => 'City';

  @override
  String get stateLabel => 'State';

  @override
  String get pincode => 'Pincode';

  @override
  String get tabCurrent => 'Current';

  @override
  String get tabHistory => 'History';

  @override
  String get noCurrentBookings => 'No current bookings';

  @override
  String get noCurrentBookingsBody =>
      'Upcoming and ongoing visits show up here.';

  @override
  String get noHistory => 'No past bookings';

  @override
  String get noHistoryBody => 'Finished and cancelled visits show up here.';

  @override
  String get bookAService => 'Book a service';

  @override
  String get statusPendingPayment => 'Waiting for payment';

  @override
  String get statusExpired => 'Expired';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get nurseNotAssigned => 'Not assigned';

  @override
  String needChangeOrCancel(String phone) {
    return 'Need to change or cancel? Call support on $phone.';
  }

  @override
  String get callSupport => 'Call support';

  @override
  String couldNotOpenDialer(String phone) {
    return 'Could not open the phone app. Please call $phone.';
  }

  @override
  String get cancelledByCareNest => 'Cancelled by CareNest';

  @override
  String get cancelledByYou => 'Cancelled';

  @override
  String cancelReason(String reason) {
    return 'Reason: $reason';
  }

  @override
  String get refund => 'Refund';

  @override
  String get refundStatus => 'Refund status';

  @override
  String get refundSent => 'Sent to your bank';

  @override
  String get refundInProgress => 'Refund in progress';

  @override
  String get refundExpected => 'Expected';

  @override
  String get refundExpectedDefault => '5 to 7 working days';

  @override
  String get bookAgain => 'Book again';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get familyMembers => 'Family members';

  @override
  String get addresses => 'Addresses';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get logout => 'Log out';

  @override
  String get logoutTitle => 'Log out?';

  @override
  String get logoutBody => 'You will need a new code to log in again.';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get phoneCannotChange => 'Your number can\'t be changed here.';

  @override
  String get noFamily => 'No family members yet';

  @override
  String get noFamilyBody =>
      'Save the people you book for so you do not have to type their details again.';

  @override
  String get addFamilyMember => 'Add family member';

  @override
  String get editFamilyMember => 'Edit family member';

  @override
  String get addMember => 'Add member';

  @override
  String get relation => 'Relation';

  @override
  String get relationHint => 'For example Father';

  @override
  String get relationRequired => 'Enter the relation';

  @override
  String get medicalNotes => 'Medical notes (optional)';

  @override
  String get deleteMember => 'Delete this member';

  @override
  String deleteMemberTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get deleteMemberBody => 'Past bookings are not affected.';

  @override
  String get addAddressPlus => '+ Add address';

  @override
  String get noAddresses => 'No saved addresses';

  @override
  String get noAddressesBody => 'Add a place where a nurse should visit.';

  @override
  String get defaultLabel => 'Default';

  @override
  String get deleteAddressTitle => 'Delete this address?';

  @override
  String get deleteAccountTitle => 'Delete your CareNest account';

  @override
  String get deleteAccountExplain =>
      'Your personal details and saved family members and addresses will be erased. Booking and payment records are kept without your personal details.';

  @override
  String get deleteAccountUpcoming =>
      'If you have an upcoming confirmed booking, please call support first.';

  @override
  String get deleteConfirmTitle => 'Delete your account?';

  @override
  String get deleteConfirmBody => 'This cannot be undone.';

  @override
  String get deleteMyAccount => 'Delete my account';
}
