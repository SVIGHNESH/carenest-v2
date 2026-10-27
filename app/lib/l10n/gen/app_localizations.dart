import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'CareNest'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Care at home'**
  String get tagline;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get somethingWentWrong;

  /// No description provided for @nothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHere;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach CareNest. Check your internet connection and try again.'**
  String get errorNetwork;

  /// No description provided for @errorTimeout.
  ///
  /// In en, this message translates to:
  /// **'This is taking too long. Please try again.'**
  String get errorTimeout;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'CareNest is having trouble right now. Please try again in a moment.'**
  String get errorServer;

  /// No description provided for @errorRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many tries. Please wait a little and try again.'**
  String get errorRateLimited;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that.'**
  String get errorNotFound;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @keep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get keep;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @startOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get startOver;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String stepOf(int step, int total);

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to CareNest'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number. We\'ll send you a code to log in or create your account.'**
  String get loginSubtitle;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Mobile number'**
  String get phoneLabel;

  /// No description provided for @phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your mobile number'**
  String get phoneRequired;

  /// No description provided for @phoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number'**
  String get phoneInvalid;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @loginHint.
  ///
  /// In en, this message translates to:
  /// **'Standard SMS charges may apply.'**
  String get loginHint;

  /// No description provided for @verifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyTitle;

  /// No description provided for @otpTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the code'**
  String get otpTitle;

  /// No description provided for @otpSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {phone}'**
  String otpSentTo(String phone);

  /// No description provided for @otpLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get otpLabel;

  /// No description provided for @otpInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code'**
  String get otpInvalid;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @changeNumber.
  ///
  /// In en, this message translates to:
  /// **'Change number'**
  String get changeNumber;

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend code in {time}'**
  String resendIn(String time);

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @tellUsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell us about you'**
  String get tellUsTitle;

  /// No description provided for @tellUsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Just your name to get started. Email is optional.'**
  String get tellUsSubtitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get nameRequired;

  /// No description provided for @emailOptional.
  ///
  /// In en, this message translates to:
  /// **'Email (optional)'**
  String get emailOptional;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get emailInvalid;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get navServices;

  /// No description provided for @navBookings.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get navBookings;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @greeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String greeting(String name);

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Trusted nurses, at home, when you need them.'**
  String get homeSubtitle;

  /// No description provided for @bookService.
  ///
  /// In en, this message translates to:
  /// **'Book service'**
  String get bookService;

  /// No description provided for @myBookings.
  ///
  /// In en, this message translates to:
  /// **'My bookings'**
  String get myBookings;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get viewAll;

  /// No description provided for @nextBooking.
  ///
  /// In en, this message translates to:
  /// **'Next booking'**
  String get nextBooking;

  /// No description provided for @noUpcomingBooking.
  ///
  /// In en, this message translates to:
  /// **'No upcoming bookings. Book a service to get started.'**
  String get noUpcomingBooking;

  /// No description provided for @noServices.
  ///
  /// In en, this message translates to:
  /// **'No services yet'**
  String get noServices;

  /// No description provided for @noServicesBody.
  ///
  /// In en, this message translates to:
  /// **'Please check back soon.'**
  String get noServicesBody;

  /// No description provided for @pricePerHour.
  ///
  /// In en, this message translates to:
  /// **'{price} per hour'**
  String pricePerHour(String price);

  /// No description provided for @notAvailableNow.
  ///
  /// In en, this message translates to:
  /// **'Not available right now'**
  String get notAvailableNow;

  /// No description provided for @notAvailableShort.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get notAvailableShort;

  /// No description provided for @bookingsPausedBanner.
  ///
  /// In en, this message translates to:
  /// **'Bookings are temporarily unavailable. Please try again later.'**
  String get bookingsPausedBanner;

  /// No description provided for @bookNow.
  ///
  /// In en, this message translates to:
  /// **'Book now'**
  String get bookNow;

  /// No description provided for @priceIncludesTax.
  ///
  /// In en, this message translates to:
  /// **'Price includes all taxes. No extra fees.'**
  String get priceIncludesTax;

  /// No description provided for @leaveBookingTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave this booking?'**
  String get leaveBookingTitle;

  /// No description provided for @leaveBookingBody.
  ///
  /// In en, this message translates to:
  /// **'What you entered will be cleared.'**
  String get leaveBookingBody;

  /// No description provided for @keepBooking.
  ///
  /// In en, this message translates to:
  /// **'Keep booking'**
  String get keepBooking;

  /// No description provided for @stepPatientTitle.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get stepPatientTitle;

  /// No description provided for @stepWhenTitle.
  ///
  /// In en, this message translates to:
  /// **'Date and time'**
  String get stepWhenTitle;

  /// No description provided for @stepDurationTitle.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get stepDurationTitle;

  /// No description provided for @stepNurseTitle.
  ///
  /// In en, this message translates to:
  /// **'Nurse preference'**
  String get stepNurseTitle;

  /// No description provided for @stepDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details and address'**
  String get stepDetailsTitle;

  /// No description provided for @stepReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get stepReviewTitle;

  /// No description provided for @whoIsVisitFor.
  ///
  /// In en, this message translates to:
  /// **'Who is this visit for?'**
  String get whoIsVisitFor;

  /// No description provided for @myself.
  ///
  /// In en, this message translates to:
  /// **'Myself'**
  String get myself;

  /// No description provided for @addFamilyMemberPlus.
  ///
  /// In en, this message translates to:
  /// **'+ Add family member'**
  String get addFamilyMemberPlus;

  /// No description provided for @pickADay.
  ///
  /// In en, this message translates to:
  /// **'Pick a day'**
  String get pickADay;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// No description provided for @noticeHours.
  ///
  /// In en, this message translates to:
  /// **'{hours, plural, =1{1 hour} other{{hours} hours}}'**
  String noticeHours(int hours);

  /// No description provided for @noticeMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String noticeMinutes(int minutes);

  /// No description provided for @noticeHint.
  ///
  /// In en, this message translates to:
  /// **'Bookings need at least {notice} notice.'**
  String noticeHint(String notice);

  /// No description provided for @earliestStartToday.
  ///
  /// In en, this message translates to:
  /// **'Earliest start today is {time}.'**
  String earliestStartToday(String time);

  /// No description provided for @tooSoonShort.
  ///
  /// In en, this message translates to:
  /// **'too soon'**
  String get tooSoonShort;

  /// No description provided for @bookedShort.
  ///
  /// In en, this message translates to:
  /// **'not available'**
  String get bookedShort;

  /// No description provided for @couldNotLoadTimes.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load the times for this day.'**
  String get couldNotLoadTimes;

  /// No description provided for @noTimesThisDay.
  ///
  /// In en, this message translates to:
  /// **'No times on this day'**
  String get noTimesThisDay;

  /// No description provided for @noTimesThisDayBody.
  ///
  /// In en, this message translates to:
  /// **'Try another day.'**
  String get noTimesThisDayBody;

  /// No description provided for @howManyHours.
  ///
  /// In en, this message translates to:
  /// **'How many hours?'**
  String get howManyHours;

  /// No description provided for @hoursCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour} other{{count} hours}}'**
  String hoursCount(int count);

  /// No description provided for @durationCapped.
  ///
  /// In en, this message translates to:
  /// **'A nurse is free for up to {hours} hours from this start time.'**
  String durationCapped(int hours);

  /// No description provided for @priceTimesHours.
  ///
  /// In en, this message translates to:
  /// **'{price} x {hours, plural, =1{1 hour} other{{hours} hours}}'**
  String priceTimesHours(String price, int hours);

  /// No description provided for @noDurationTitle.
  ///
  /// In en, this message translates to:
  /// **'No visit can start at this time'**
  String get noDurationTitle;

  /// No description provided for @noDurationBody.
  ///
  /// In en, this message translates to:
  /// **'Pick a different start time or day.'**
  String get noDurationBody;

  /// No description provided for @changeDateOrTime.
  ///
  /// In en, this message translates to:
  /// **'Change date or time'**
  String get changeDateOrTime;

  /// No description provided for @whoWouldYouPrefer.
  ///
  /// In en, this message translates to:
  /// **'Who would you prefer?'**
  String get whoWouldYouPrefer;

  /// No description provided for @femaleNurse.
  ///
  /// In en, this message translates to:
  /// **'Female nurse'**
  String get femaleNurse;

  /// No description provided for @maleNurse.
  ///
  /// In en, this message translates to:
  /// **'Male nurse'**
  String get maleNurse;

  /// No description provided for @availableForYourTime.
  ///
  /// In en, this message translates to:
  /// **'Available for your time'**
  String get availableForYourTime;

  /// No description provided for @notAvailableForThisTime.
  ///
  /// In en, this message translates to:
  /// **'Not available for this time'**
  String get notAvailableForThisTime;

  /// No description provided for @noNurseFreeFor.
  ///
  /// In en, this message translates to:
  /// **'No {gender} is free on {when}.'**
  String noNurseFreeFor(String gender, String when);

  /// No description provided for @noNurseFreeBoth.
  ///
  /// In en, this message translates to:
  /// **'No nurse is free on {when}.'**
  String noNurseFreeBoth(String when);

  /// No description provided for @nurseAssignedNote.
  ///
  /// In en, this message translates to:
  /// **'We assign a qualified nurse for you. You\'ll see their name once the booking is confirmed.'**
  String get nurseAssignedNote;

  /// No description provided for @patientDetails.
  ///
  /// In en, this message translates to:
  /// **'Patient details'**
  String get patientDetails;

  /// No description provided for @patientName.
  ///
  /// In en, this message translates to:
  /// **'Patient name'**
  String get patientName;

  /// No description provided for @patientAge.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get patientAge;

  /// No description provided for @patientSex.
  ///
  /// In en, this message translates to:
  /// **'Sex'**
  String get patientSex;

  /// No description provided for @sexMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get sexMale;

  /// No description provided for @sexFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get sexFemale;

  /// No description provided for @sexOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get sexOther;

  /// No description provided for @sexRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose one'**
  String get sexRequired;

  /// No description provided for @conditionNotes.
  ///
  /// In en, this message translates to:
  /// **'Condition or notes'**
  String get conditionNotes;

  /// No description provided for @contactPhone.
  ///
  /// In en, this message translates to:
  /// **'Contact phone'**
  String get contactPhone;

  /// No description provided for @contactPhoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Contact phone (optional)'**
  String get contactPhoneOptional;

  /// No description provided for @contactPhoneHelp.
  ///
  /// In en, this message translates to:
  /// **'The nurse and our team will call this number about the visit.'**
  String get contactPhoneHelp;

  /// No description provided for @ageInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an age from 0 to 120'**
  String get ageInvalid;

  /// No description provided for @whereShouldNurseCome.
  ///
  /// In en, this message translates to:
  /// **'Where should the nurse come?'**
  String get whereShouldNurseCome;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get currentLocation;

  /// No description provided for @pickOnMap.
  ///
  /// In en, this message translates to:
  /// **'Pick on map'**
  String get pickOnMap;

  /// No description provided for @couldNotLoadAddresses.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your saved addresses.'**
  String get couldNotLoadAddresses;

  /// No description provided for @addressRequired.
  ///
  /// In en, this message translates to:
  /// **'Choose or add an address with a map pin'**
  String get addressRequired;

  /// No description provided for @labelHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get labelHome;

  /// No description provided for @labelWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get labelWork;

  /// No description provided for @labelOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get labelOther;

  /// No description provided for @service.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get service;

  /// No description provided for @when.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get when;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @nurse.
  ///
  /// In en, this message translates to:
  /// **'Nurse'**
  String get nurse;

  /// No description provided for @patient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patient;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @nurseGenderLine.
  ///
  /// In en, this message translates to:
  /// **'{gender}'**
  String nurseGenderLine(String gender);

  /// No description provided for @pay.
  ///
  /// In en, this message translates to:
  /// **'Pay'**
  String get pay;

  /// No description provided for @payAmount.
  ///
  /// In en, this message translates to:
  /// **'Pay {amount}'**
  String payAmount(String amount);

  /// No description provided for @confirmedWhenPaid.
  ///
  /// In en, this message translates to:
  /// **'Your booking is confirmed as soon as you pay.'**
  String get confirmedWhenPaid;

  /// No description provided for @holdNote.
  ///
  /// In en, this message translates to:
  /// **'We hold a nurse for you for 15 minutes while you pay.'**
  String get holdNote;

  /// No description provided for @paymentNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payment was not completed. Your nurse is still held for a few minutes.'**
  String get paymentNotCompleted;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment didn\'t go through. Please try again.'**
  String get paymentFailed;

  /// No description provided for @autoCancelledTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t confirm your visit'**
  String get autoCancelledTitle;

  /// No description provided for @autoCancelledBody.
  ///
  /// In en, this message translates to:
  /// **'Your payment arrived after the held time ran out and no nurse was free. {amount} will be refunded in full.'**
  String autoCancelledBody(String amount);

  /// No description provided for @noticeNoNurseFree.
  ///
  /// In en, this message translates to:
  /// **'No nurse is free for that time any more. Please choose another time. Your other choices are kept.'**
  String get noticeNoNurseFree;

  /// No description provided for @noticeHoldExpired.
  ///
  /// In en, this message translates to:
  /// **'Your held time ran out. Please pick a time again. Your other choices are kept.'**
  String get noticeHoldExpired;

  /// No description provided for @noticeTooSoon.
  ///
  /// In en, this message translates to:
  /// **'That start time is too soon. Please pick a later time.'**
  String get noticeTooSoon;

  /// No description provided for @noticeTooFar.
  ///
  /// In en, this message translates to:
  /// **'That day is too far ahead to book. Please pick an earlier day.'**
  String get noticeTooFar;

  /// No description provided for @noticeCrossesMidnight.
  ///
  /// In en, this message translates to:
  /// **'A visit must finish by midnight. Please choose an earlier start or fewer hours.'**
  String get noticeCrossesMidnight;

  /// No description provided for @payUpi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get payUpi;

  /// No description provided for @payUpiHint.
  ///
  /// In en, this message translates to:
  /// **'Any UPI app'**
  String get payUpiHint;

  /// No description provided for @payCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get payCard;

  /// No description provided for @payCardHint.
  ///
  /// In en, this message translates to:
  /// **'Credit or debit'**
  String get payCardHint;

  /// No description provided for @payNetbanking.
  ///
  /// In en, this message translates to:
  /// **'Net banking'**
  String get payNetbanking;

  /// No description provided for @payNetbankingHint.
  ///
  /// In en, this message translates to:
  /// **'All major banks'**
  String get payNetbankingHint;

  /// No description provided for @paySecureTestNote.
  ///
  /// In en, this message translates to:
  /// **'Secure payment. This is a test checkout, no real money moves.'**
  String get paySecureTestNote;

  /// No description provided for @holdTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'Time left to pay: {time}'**
  String holdTimeLeft(String time);

  /// No description provided for @holdTimeLeftSemantics.
  ///
  /// In en, this message translates to:
  /// **'About {minutes, plural, =1{1 minute} other{{minutes} minutes}} left to pay'**
  String holdTimeLeftSemantics(int minutes);

  /// No description provided for @bookingConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Booking confirmed'**
  String get bookingConfirmed;

  /// No description provided for @bookingNumber.
  ///
  /// In en, this message translates to:
  /// **'Booking #{id}'**
  String bookingNumber(int id);

  /// No description provided for @yourNurse.
  ///
  /// In en, this message translates to:
  /// **'Your nurse'**
  String get yourNurse;

  /// No description provided for @nurseSoon.
  ///
  /// In en, this message translates to:
  /// **'Will be shared soon'**
  String get nurseSoon;

  /// No description provided for @smsSentNote.
  ///
  /// In en, this message translates to:
  /// **'We have sent you an SMS with these details.'**
  String get smsSentNote;

  /// No description provided for @viewBooking.
  ///
  /// In en, this message translates to:
  /// **'View booking'**
  String get viewBooking;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backToHome;

  /// No description provided for @setLocation.
  ///
  /// In en, this message translates to:
  /// **'Set location'**
  String get setLocation;

  /// No description provided for @searchPlaces.
  ///
  /// In en, this message translates to:
  /// **'Search area, street or landmark'**
  String get searchPlaces;

  /// No description provided for @useCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my current location'**
  String get useCurrentLocation;

  /// No description provided for @confirmLocation.
  ///
  /// In en, this message translates to:
  /// **'Confirm location'**
  String get confirmLocation;

  /// No description provided for @findingAddress.
  ///
  /// In en, this message translates to:
  /// **'Finding address...'**
  String get findingAddress;

  /// No description provided for @addressNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t name this spot. You can still use it and add the details next.'**
  String get addressNotFound;

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search isn\'t working right now. You can still move the map.'**
  String get searchFailed;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location access is off. You can still search or move the map.'**
  String get locationDenied;

  /// No description provided for @locationDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location access is blocked for CareNest. Turn it on in Settings, or search and move the map instead.'**
  String get locationDeniedForever;

  /// No description provided for @locationOff.
  ///
  /// In en, this message translates to:
  /// **'Location is switched off on this phone. You can still search or move the map.'**
  String get locationOff;

  /// No description provided for @locationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t get your location. You can still search or move the map.'**
  String get locationUnavailable;

  /// No description provided for @simulatedMapLabel.
  ///
  /// In en, this message translates to:
  /// **'Map preview, pin at {point}. Drag to move the pin.'**
  String simulatedMapLabel(String point);

  /// No description provided for @simulatedMapNote.
  ///
  /// In en, this message translates to:
  /// **'Map preview (no Google Maps key)'**
  String get simulatedMapNote;

  /// No description provided for @addressDetails.
  ///
  /// In en, this message translates to:
  /// **'Address details'**
  String get addressDetails;

  /// No description provided for @editAddress.
  ///
  /// In en, this message translates to:
  /// **'Edit address'**
  String get editAddress;

  /// No description provided for @houseOrFlat.
  ///
  /// In en, this message translates to:
  /// **'House or flat number'**
  String get houseOrFlat;

  /// No description provided for @houseRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the house or flat number'**
  String get houseRequired;

  /// No description provided for @landmarkOptional.
  ///
  /// In en, this message translates to:
  /// **'Landmark (optional)'**
  String get landmarkOptional;

  /// No description provided for @saveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get saveAs;

  /// No description provided for @saveForNextTime.
  ///
  /// In en, this message translates to:
  /// **'Save for next time'**
  String get saveForNextTime;

  /// No description provided for @setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default address'**
  String get setAsDefault;

  /// No description provided for @useThisAddress.
  ///
  /// In en, this message translates to:
  /// **'Use this address'**
  String get useThisAddress;

  /// No description provided for @saveAddress.
  ///
  /// In en, this message translates to:
  /// **'Save address'**
  String get saveAddress;

  /// No description provided for @editAreaDetails.
  ///
  /// In en, this message translates to:
  /// **'Edit area details'**
  String get editAreaDetails;

  /// No description provided for @areaStreet.
  ///
  /// In en, this message translates to:
  /// **'Area or street'**
  String get areaStreet;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @stateLabel.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get stateLabel;

  /// No description provided for @pincode.
  ///
  /// In en, this message translates to:
  /// **'Pincode'**
  String get pincode;

  /// No description provided for @tabCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get tabCurrent;

  /// No description provided for @tabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// No description provided for @noCurrentBookings.
  ///
  /// In en, this message translates to:
  /// **'No current bookings'**
  String get noCurrentBookings;

  /// No description provided for @noCurrentBookingsBody.
  ///
  /// In en, this message translates to:
  /// **'Upcoming and ongoing visits show up here.'**
  String get noCurrentBookingsBody;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'No past bookings'**
  String get noHistory;

  /// No description provided for @noHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'Finished and cancelled visits show up here.'**
  String get noHistoryBody;

  /// No description provided for @bookAService.
  ///
  /// In en, this message translates to:
  /// **'Book a service'**
  String get bookAService;

  /// No description provided for @statusPendingPayment.
  ///
  /// In en, this message translates to:
  /// **'Waiting for payment'**
  String get statusPendingPayment;

  /// No description provided for @statusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statusExpired;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statusCompleted;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @nurseNotAssigned.
  ///
  /// In en, this message translates to:
  /// **'Not assigned'**
  String get nurseNotAssigned;

  /// No description provided for @needChangeOrCancel.
  ///
  /// In en, this message translates to:
  /// **'Need to change or cancel? Call support on {phone}.'**
  String needChangeOrCancel(String phone);

  /// No description provided for @callSupport.
  ///
  /// In en, this message translates to:
  /// **'Call support'**
  String get callSupport;

  /// No description provided for @couldNotOpenDialer.
  ///
  /// In en, this message translates to:
  /// **'Could not open the phone app. Please call {phone}.'**
  String couldNotOpenDialer(String phone);

  /// No description provided for @cancelledByCareNest.
  ///
  /// In en, this message translates to:
  /// **'Cancelled by CareNest'**
  String get cancelledByCareNest;

  /// No description provided for @cancelledByYou.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelledByYou;

  /// No description provided for @cancelReason.
  ///
  /// In en, this message translates to:
  /// **'Reason: {reason}'**
  String cancelReason(String reason);

  /// No description provided for @refund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get refund;

  /// No description provided for @refundStatus.
  ///
  /// In en, this message translates to:
  /// **'Refund status'**
  String get refundStatus;

  /// No description provided for @refundSent.
  ///
  /// In en, this message translates to:
  /// **'Sent to your bank'**
  String get refundSent;

  /// No description provided for @refundInProgress.
  ///
  /// In en, this message translates to:
  /// **'Refund in progress'**
  String get refundInProgress;

  /// No description provided for @refundExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected'**
  String get refundExpected;

  /// No description provided for @refundExpectedDefault.
  ///
  /// In en, this message translates to:
  /// **'5 to 7 working days'**
  String get refundExpectedDefault;

  /// No description provided for @bookAgain.
  ///
  /// In en, this message translates to:
  /// **'Book again'**
  String get bookAgain;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get editProfile;

  /// No description provided for @familyMembers.
  ///
  /// In en, this message translates to:
  /// **'Family members'**
  String get familyMembers;

  /// No description provided for @addresses.
  ///
  /// In en, this message translates to:
  /// **'Addresses'**
  String get addresses;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacyPolicy;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @logoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get logoutTitle;

  /// No description provided for @logoutBody.
  ///
  /// In en, this message translates to:
  /// **'You will need a new code to log in again.'**
  String get logoutBody;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @phoneCannotChange.
  ///
  /// In en, this message translates to:
  /// **'Your number can\'t be changed here.'**
  String get phoneCannotChange;

  /// No description provided for @noFamily.
  ///
  /// In en, this message translates to:
  /// **'No family members yet'**
  String get noFamily;

  /// No description provided for @noFamilyBody.
  ///
  /// In en, this message translates to:
  /// **'Save the people you book for so you do not have to type their details again.'**
  String get noFamilyBody;

  /// No description provided for @addFamilyMember.
  ///
  /// In en, this message translates to:
  /// **'Add family member'**
  String get addFamilyMember;

  /// No description provided for @editFamilyMember.
  ///
  /// In en, this message translates to:
  /// **'Edit family member'**
  String get editFamilyMember;

  /// No description provided for @addMember.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get addMember;

  /// No description provided for @relation.
  ///
  /// In en, this message translates to:
  /// **'Relation'**
  String get relation;

  /// No description provided for @relationHint.
  ///
  /// In en, this message translates to:
  /// **'For example Father'**
  String get relationHint;

  /// No description provided for @relationRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter the relation'**
  String get relationRequired;

  /// No description provided for @medicalNotes.
  ///
  /// In en, this message translates to:
  /// **'Medical notes (optional)'**
  String get medicalNotes;

  /// No description provided for @deleteMember.
  ///
  /// In en, this message translates to:
  /// **'Delete this member'**
  String get deleteMember;

  /// No description provided for @deleteMemberTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String deleteMemberTitle(String name);

  /// No description provided for @deleteMemberBody.
  ///
  /// In en, this message translates to:
  /// **'Past bookings are not affected.'**
  String get deleteMemberBody;

  /// No description provided for @addAddressPlus.
  ///
  /// In en, this message translates to:
  /// **'+ Add address'**
  String get addAddressPlus;

  /// No description provided for @noAddresses.
  ///
  /// In en, this message translates to:
  /// **'No saved addresses'**
  String get noAddresses;

  /// No description provided for @noAddressesBody.
  ///
  /// In en, this message translates to:
  /// **'Add a place where a nurse should visit.'**
  String get noAddressesBody;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @deleteAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this address?'**
  String get deleteAddressTitle;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your CareNest account'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountExplain.
  ///
  /// In en, this message translates to:
  /// **'Your personal details and saved family members and addresses will be erased. Booking and payment records are kept without your personal details.'**
  String get deleteAccountExplain;

  /// No description provided for @deleteAccountUpcoming.
  ///
  /// In en, this message translates to:
  /// **'If you have an upcoming confirmed booking, please call support first.'**
  String get deleteAccountUpcoming;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete your account?'**
  String get deleteConfirmTitle;

  /// No description provided for @deleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get deleteConfirmBody;

  /// No description provided for @deleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteMyAccount;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
