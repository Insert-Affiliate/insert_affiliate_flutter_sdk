/// Every label on the drop-in "Refer a friend" screen, so an app can translate
/// or reword it. Pass it as `ReferAFriendOptions(strings: ...)`.
///
/// Every field is optional: a field that is null or blank keeps the English
/// default shown in brackets below. Placeholders in braces are replaced when
/// the screen shows the text, so a translation has to keep them.
///
/// The headline and the reward line are not here: they come from the portal
/// settings and `ReferAFriendOptions.headline` / `rewardText`.
///
/// ```dart
/// const ReferralStrings(
///   joinButton: 'Obter o meu link',
///   premiumUntil: 'Premium gratuito ate {date}',
/// )
/// ```
class ReferralStrings {
  // Joining
  /// The email field ("Email").
  final String? emailLabel;

  /// The name field ("Name").
  final String? nameLabel;

  /// The button that joins the program ("Get my link").
  final String? joinButton;

  /// The line above the join form ("Get your own link to share with friends.").
  final String? joinIntro;

  // Email code step
  /// The code field ("Code").
  final String? codeLabel;

  /// Shown once the code is emailed, with `{email}`
  /// ("We emailed a 6-digit code to {email}. Enter it below to connect.").
  final String? codeSentNotice;

  /// The button that sends the code ("Verify").
  final String? verifyButton;

  /// The button that asks for another code ("Send a new code").
  final String? resendButton;

  /// Confirms another code was sent ("We sent a new code. Check your email.").
  final String? codeResentNotice;

  /// The button back to the join form ("Use a different email").
  final String? differentEmailButton;

  // Joined
  /// The label above the referrer's short code ("Your code").
  final String? codeLabelTitle;

  /// The Copy buttons next to the code and the link ("Copy").
  final String? copyButton;

  /// Confirms the short code was copied ("Code copied").
  final String? copiedNotice;

  /// Confirms the link was copied ("Link copied").
  final String? linkCopiedNotice;

  /// Confirms the dashboard link was copied ("Dashboard link copied").
  final String? dashboardCopiedNotice;

  /// The share button when the referrer has a link ("Share my link").
  final String? shareButton;

  /// The share button for Short Code Only apps ("Share my code").
  final String? shareCodeButton;

  /// The referral count stat ("Referrals").
  final String? referralsLabel;

  /// The earnings stat ("Earned").
  final String? earnedLabel;

  /// Free premium from referral rewards, with `{date}`
  /// ("Free premium until {date}").
  final String? premiumUntil;

  /// The heading above the reward codes ("Your rewards").
  final String? rewardsHeading;

  /// The button on a reward code ("Redeem").
  final String? redeemButton;

  /// The link to the affiliate dashboard ("Open my dashboard").
  final String? dashboardLink;

  // Frame and states
  /// The close button's tooltip and screen reader label ("Close").
  final String? closeButton;

  /// The screen reader label while the screen loads ("Loading..."). The screen
  /// shows a spinner, not this text.
  final String? loading;

  /// The button that loads the screen again ("Try again").
  final String? tryAgainButton;

  // Errors, by the code the server returns
  /// `PROGRAM_DISABLED` ("Referrals are not available in this app right now.").
  final String? errorProgramDisabled;

  /// `AFFILIATE_LIMIT_REACHED`
  /// ("The referral program is full right now. Please try again later.").
  final String? errorAffiliateLimitReached;

  /// `INVALID_CODE`
  /// ("That code is wrong or has expired. Check the email or send a new code.").
  final String? errorInvalidCode;

  /// `TOO_MANY_CODES`
  /// ("Too many codes requested. Please wait a while and try again.").
  final String? errorTooManyCodes;

  /// `RATE_LIMITED` ("Too many attempts. Please wait a moment and try again.").
  final String? errorRateLimited;

  /// `INVALID_EMAIL` ("Please enter a valid email address."). Also shown when
  /// the email field has no `@`.
  final String? errorInvalidEmail;

  /// `NETWORK_ERROR`
  /// ("Could not connect. Check your connection and try again.").
  final String? errorNetwork;

  /// Any other failure ("Something went wrong. Please try again."). The
  /// server's own message is shown when it sends one.
  final String? errorServer;

  /// Shown if Verify runs with fewer than 6 digits in the field
  /// ("Enter the 6-digit code from the email."). The button stays disabled
  /// until there are 6, so this is a safety net.
  final String? errorCodeIncomplete;

  /// Shown when the share sheet will not open
  /// ("Could not open the share sheet. Copy your link instead.").
  final String? errorShareFailed;

  const ReferralStrings({
    this.emailLabel,
    this.nameLabel,
    this.joinButton,
    this.joinIntro,
    this.codeLabel,
    this.codeSentNotice,
    this.verifyButton,
    this.resendButton,
    this.codeResentNotice,
    this.differentEmailButton,
    this.codeLabelTitle,
    this.copyButton,
    this.copiedNotice,
    this.linkCopiedNotice,
    this.dashboardCopiedNotice,
    this.shareButton,
    this.shareCodeButton,
    this.referralsLabel,
    this.earnedLabel,
    this.premiumUntil,
    this.rewardsHeading,
    this.redeemButton,
    this.dashboardLink,
    this.closeButton,
    this.loading,
    this.tryAgainButton,
    this.errorProgramDisabled,
    this.errorAffiliateLimitReached,
    this.errorInvalidCode,
    this.errorTooManyCodes,
    this.errorRateLimited,
    this.errorInvalidEmail,
    this.errorNetwork,
    this.errorServer,
    this.errorCodeIncomplete,
    this.errorShareFailed,
  });
}

/// The app's wording when it set one, otherwise our English default.
String referralText(String? value, String fallback) =>
    (value != null && value.trim().isNotEmpty) ? value.trim() : fallback;

/// Fills `{name}` placeholders, e.g. `{date}` in [ReferralStrings.premiumUntil].
/// A placeholder a translation dropped is simply not shown.
String fillReferralPlaceholders(String text, Map<String, String> values) {
  var filled = text;
  values.forEach((name, value) => filled = filled.replaceAll('{$name}', value));
  return filled;
}
