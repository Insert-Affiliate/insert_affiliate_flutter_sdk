import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../insert_affiliate_flutter_sdk.dart';
import 'referrals.dart' show normaliseVerificationCode;

/// Options for the drop-in "Refer a friend" screen.
///
/// Copy and colour fall back to the portal settings, then to the defaults
/// ("Refer a friend", `#6A0DAD`), so wording can change without an app release.
class ReferAFriendOptions {
  /// Prefills the email field, usually the app's logged-in user.
  final String? email;

  /// Prefills the name field.
  final String? name;

  /// The user's RevenueCat app user id or Adapty customer user id, used to
  /// grant referral rewards automatically. Sent when the user enrols, or via
  /// `setReferrerAccount` when the screen opens for an enrolled user.
  final String? appUserId;

  /// The user's own Google Play subscription purchase token (Android), sent
  /// the same way as [appUserId].
  final String? playPurchaseToken;

  /// Share text. May use `{link}` and `{code}` placeholders.
  final String? shareMessage;

  /// Overrides the portal colour.
  final Color? primaryColor;

  /// Override the portal copy.
  final String? headline;
  final String? rewardText;

  final String? fontFamily;
  final double cornerRadius;

  /// Called after the screen is dismissed (via `showReferAFriend`).
  final VoidCallback? onClose;

  const ReferAFriendOptions({
    this.email,
    this.name,
    this.appUserId,
    this.playPurchaseToken,
    this.shareMessage,
    this.primaryColor,
    this.headline,
    this.rewardText,
    this.fontFamily,
    this.cornerRadius = 12,
    this.onClose,
  });
}

enum _ScreenState { loading, notEnrolled, codeStep, enrolled, loadError }

/// Drop-in "Refer a friend" screen. Present it with
/// `InsertAffiliateFlutterSDK.showReferAFriend`, or push / embed it yourself.
///
/// Uses the system share sheet only: no Contacts access, and nothing in the
/// app should be gated behind sharing.
class ReferAFriendScreen extends StatefulWidget {
  final InsertAffiliateFlutterSDK sdk;
  final ReferAFriendOptions options;

  const ReferAFriendScreen({
    super.key,
    required this.sdk,
    this.options = const ReferAFriendOptions(),
  });

  @override
  State<ReferAFriendScreen> createState() => _ReferAFriendScreenState();
}

class _ReferAFriendScreenState extends State<ReferAFriendScreen> {
  static const Color _defaultColor = Color(0xFF6A0DAD);

  _ScreenState _state = _ScreenState.loading;
  ReferralProgramConfig? _config;
  MyAffiliateDetails? _details;
  String? _error;
  bool _busy = false;
  bool _accountSaved = false;

  late final TextEditingController _emailController;
  late final TextEditingController _nameController;
  final TextEditingController _codeController = TextEditingController();
  final GlobalKey _shareButtonKey = GlobalKey();

  InsertAffiliateFlutterSDK get _sdk => widget.sdk;
  ReferAFriendOptions get _options => widget.options;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: _options.email ?? '');
    _nameController = TextEditingController(text: _options.name ?? '');
    _load();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _state = _ScreenState.loading;
      _error = null;
    });
    final results = await Future.wait([_sdk.getReferralProgramConfig(), _sdk.getMyAffiliateDetails()]);
    final config = results[0] as ReferralProgramConfig?;
    final details = results[1] as MyAffiliateDetails?;
    final stillConnected = details == null && await _sdk.isUserAnAffiliate();
    if (details != null) _saveReferrerAccount();
    if (!mounted) return;
    setState(() {
      _config = config;
      _details = details;
      if (details != null) {
        _state = _ScreenState.enrolled;
      } else if (stillConnected) {
        // The token is kept on network errors, so this is a connection problem.
        _state = _ScreenState.loadError;
        _error = _messageFor('NETWORK_ERROR', null);
      } else {
        _state = _ScreenState.notEnrolled;
        if (config != null && !config.enabled) {
          _error = _messageFor('PROGRAM_DISABLED', null);
        }
      }
    });
  }

  bool get _hasAccount =>
      (_options.appUserId?.trim().isNotEmpty ?? false) || (_options.playPurchaseToken?.trim().isNotEmpty ?? false);

  // Lets the server grant rewards that were waiting for the referrer's account. Once per screen.
  void _saveReferrerAccount() {
    if (_accountSaved || !_hasAccount) return;
    _accountSaved = true;
    _sdk.setReferrerAccount(appUserId: _options.appUserId, playPurchaseToken: _options.playPurchaseToken);
  }

  Future<void> _enrol() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = _messageFor('INVALID_EMAIL', null));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _sdk.createAffiliateForUser(
      email,
      _nameController.text,
      appUserId: _options.appUserId,
      playPurchaseToken: _options.playPurchaseToken,
    );
    await _handleResult(result);
  }

  Future<void> _verify() async {
    final code = normaliseVerificationCode(_codeController.text);
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _sdk.verifyAffiliateCode(
      _emailController.text,
      code,
      name: _nameController.text,
      appUserId: _options.appUserId,
      playPurchaseToken: _options.playPurchaseToken,
    );
    await _handleResult(result);
  }

  Future<void> _handleResult(AffiliateEnrolmentResult result) async {
    MyAffiliateDetails? details;
    if (result.isConnected) {
      details = await _sdk.getMyAffiliateDetails() ?? _detailsFromAffiliate(result.affiliate);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result.status) {
        case AffiliateEnrolmentStatus.created:
        case AffiliateEnrolmentStatus.connected:
          _details = details;
          _state = _ScreenState.enrolled;
          _codeController.clear();
          break;
        case AffiliateEnrolmentStatus.verificationRequired:
          _state = _ScreenState.codeStep;
          break;
        case AffiliateEnrolmentStatus.error:
          _error = _messageFor(result.errorCode, result.errorMessage);
          break;
      }
    });
  }

  // Used when the stats call fails right after connecting: shows the code and link with zero counts.
  MyAffiliateDetails? _detailsFromAffiliate(AffiliateDetails? affiliate) {
    if (affiliate == null) return null;
    return MyAffiliateDetails(
      affiliateName: affiliate.affiliateName,
      affiliateShortCode: affiliate.affiliateShortCode,
      deeplinkUrl: affiliate.deeplinkUrl,
      referralTrigger: _config?.referralTrigger ?? '',
      referralCount: 0,
      installCount: 0,
      eventCount: 0,
      purchaseCount: 0,
      totalEarned: 0,
      totalPaid: 0,
      totalUnpaid: 0,
      currency: 'USD',
      dashboardUrl: '',
    );
  }

  String _messageFor(String? code, String? fallback) {
    switch (code) {
      case 'PROGRAM_DISABLED':
        return 'Referrals are not available in this app right now.';
      case 'AFFILIATE_LIMIT_REACHED':
        return 'The referral program is full right now. Please try again later.';
      case 'INVALID_CODE':
        return 'That code is wrong or has expired. Check the email or send a new code.';
      case 'TOO_MANY_CODES':
        return 'Too many codes requested. Please wait a while and try again.';
      case 'RATE_LIMITED':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'INVALID_EMAIL':
        return 'Please enter a valid email address.';
      case 'NETWORK_ERROR':
        return 'Could not connect. Check your connection and try again.';
      default:
        return fallback ?? 'Something went wrong. Please try again.';
    }
  }

  Color get _primaryColor =>
      _options.primaryColor ?? parseReferralHexColor(_config?.primaryColor) ?? _defaultColor;

  String get _headline => _firstNonEmpty([_options.headline, _config?.headline]) ?? 'Refer a friend';

  String? get _rewardText => _firstNonEmpty([_options.rewardText, _config?.rewardText]);

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('$label copied')));
  }

  Future<void> _share() async {
    final details = _details;
    if (details == null) return;
    final text = buildReferralShareText(
      deeplinkUrl: details.deeplinkUrl,
      shortCode: details.affiliateShortCode,
      companyName: _config?.companyName ?? '',
      message: _options.shareMessage,
    );
    Rect? origin;
    final box = _shareButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }
    try {
      await SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: origin));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open the share sheet. Copy your link instead.');
    }
  }

  Future<void> _redeem(ReferralRewardCode reward) async {
    final uri = Uri.tryParse(reward.redeemUrl);
    final opened = uri != null && reward.redeemUrl.isNotEmpty && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) await _copy(reward.code, 'Code');
  }

  Future<void> _openDashboard(String url) async {
    final uri = Uri.tryParse(url);
    final opened = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) await _copy(url, 'Dashboard link');
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final primary = _primaryColor;
    final onPrimary = ThemeData.estimateBrightnessForColor(primary) == Brightness.dark ? Colors.white : Colors.black;
    final radius = BorderRadius.circular(_options.cornerRadius);
    final theme = base.copyWith(
      colorScheme: base.colorScheme.copyWith(primary: primary, onPrimary: onPrimary),
      textTheme: _options.fontFamily == null ? base.textTheme : base.textTheme.apply(fontFamily: _options.fontFamily),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: radius)),
    );

    return Theme(
      data: theme,
      child: Material(
        color: theme.colorScheme.surface,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(theme),
                const SizedBox(height: 16),
                ..._body(theme, radius),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(ThemeData theme) {
    final reward = _rewardText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(_headline, style: theme.textTheme.headlineSmall)),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        if (reward != null) ...[
          const SizedBox(height: 4),
          Text(reward, style: theme.textTheme.bodyMedium),
        ],
      ],
    );
  }

  List<Widget> _body(ThemeData theme, BorderRadius radius) {
    switch (_state) {
      case _ScreenState.loading:
        return const [Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))];
      case _ScreenState.loadError:
        return [
          _errorText(theme),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Try again')),
        ];
      case _ScreenState.notEnrolled:
        return _notEnrolled(theme);
      case _ScreenState.codeStep:
        return _codeStep(theme);
      case _ScreenState.enrolled:
        return _enrolled(theme, radius);
    }
  }

  Widget _errorText(ThemeData theme) {
    final error = _error;
    if (error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(error, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error)),
    );
  }

  Widget _primaryButton(String label, VoidCallback? onPressed, {Key? key}) {
    return ElevatedButton(
      key: key,
      onPressed: _busy ? null : onPressed,
      child: _busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Text(label),
    );
  }

  List<Widget> _notEnrolled(ThemeData theme) {
    return [
      Text('Get your own link to share with friends.', style: theme.textTheme.bodyMedium),
      const SizedBox(height: 16),
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _nameController,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
      const SizedBox(height: 16),
      _errorText(theme),
      _primaryButton('Get my link', _enrol),
    ];
  }

  List<Widget> _codeStep(ThemeData theme) {
    return [
      Text(
        'We emailed a 6-digit code to ${_emailController.text.trim()}. Enter it below to connect.',
        style: theme.textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _codeController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        autofillHints: const [AutofillHints.oneTimeCode],
        // Any script's digits (Arabic-Indic, fullwidth, ...) become 0-9; spaces and other characters are dropped.
        inputFormatters: [_verificationCodeFormatter],
        decoration: const InputDecoration(labelText: 'Code', counterText: ''),
      ),
      const SizedBox(height: 16),
      _errorText(theme),
      // Verify is enabled at exactly 6 digits.
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _codeController,
        builder: (context, value, _) =>
            _primaryButton('Verify', normaliseVerificationCode(value.text).length == 6 ? _verify : null),
      ),
      const SizedBox(height: 8),
      TextButton(onPressed: _busy ? null : _enrol, child: const Text('Send a new code')),
      TextButton(
        onPressed: _busy
            ? null
            : () => setState(() {
                  _state = _ScreenState.notEnrolled;
                  _error = null;
                  _codeController.clear();
                }),
        child: const Text('Use a different email'),
      ),
    ];
  }

  List<Widget> _enrolled(ThemeData theme, BorderRadius radius) {
    final details = _details!;
    final hasLink = details.deeplinkUrl.startsWith('http');
    final premiumUntil = details.premiumUntil;
    final showPremium = premiumUntil != null && premiumUntil.isAfter(DateTime.now());
    // Only codes this phone's store can redeem (App Store on iOS, Google Play on Android).
    final rewardCodes = rewardCodesForPlatform(details.rewardCodes, platform: defaultTargetPlatform, isWeb: kIsWeb);
    final boxDecoration = BoxDecoration(
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      borderRadius: radius,
    );

    return [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: boxDecoration,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your code', style: theme.textTheme.labelMedium),
                  SelectableText(
                    details.affiliateShortCode,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: () => _copy(details.affiliateShortCode, 'Code'), child: const Text('Copy')),
          ],
        ),
      ),
      if (hasLink) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          decoration: boxDecoration,
          child: Row(
            children: [
              Expanded(
                child: Text(details.deeplinkUrl, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              TextButton(onPressed: () => _copy(details.deeplinkUrl, 'Link'), child: const Text('Copy')),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      _errorText(theme),
      ElevatedButton.icon(
        key: _shareButtonKey,
        onPressed: _share,
        icon: const Icon(Icons.ios_share),
        label: Text(hasLink ? 'Share my link' : 'Share my code'),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _stat(theme, 'Referrals', '${details.referralCount}')),
          const SizedBox(width: 12),
          Expanded(child: _stat(theme, 'Earned', formatReferralAmount(details.totalEarned, details.currency))),
        ],
      ),
      if (showPremium) ...[
        const SizedBox(height: 12),
        Text(
          'Free premium until ${MaterialLocalizations.of(context).formatMediumDate(premiumUntil.toLocal())}',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
      if (rewardCodes.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Your rewards', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final reward in rewardCodes)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              decoration: boxDecoration,
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(reward.code, style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 1)),
                  ),
                  TextButton(onPressed: () => _redeem(reward), child: const Text('Redeem')),
                ],
              ),
            ),
          ),
      ],
      if (details.dashboardUrl.isNotEmpty) ...[
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _openDashboard(details.dashboardUrl),
          child: const Text('Open my dashboard'),
        ),
      ],
    ];
  }

  Widget _stat(ThemeData theme, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(_options.cornerRadius),
      ),
      child: Column(
        children: [
          Text(value, style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// Keeps the code field to ASCII digits: see [normaliseVerificationCode].
final TextInputFormatter _verificationCodeFormatter = TextInputFormatter.withFunction((oldValue, newValue) {
  final digits = normaliseVerificationCode(newValue.text);
  if (digits == newValue.text) return newValue;
  return TextEditingValue(text: digits, selection: TextSelection.collapsed(offset: digits.length));
});

/// Parses `#RRGGBB` (or `RRGGBB`) into a colour, or null.
Color? parseReferralHexColor(String? hex) {
  if (hex == null) return null;
  final value = hex.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(value)) return null;
  return Color(0xFF000000 | int.parse(value, radix: 16));
}

/// Formats an earned amount for the stats strip, e.g. `$12.50` or `12.50 SEK`.
String formatReferralAmount(double amount, String currency) {
  const symbols = {'USD': r'$', 'EUR': '€', 'GBP': '£'};
  final fixed = amount.toStringAsFixed(2);
  final symbol = symbols[currency.toUpperCase()];
  return symbol != null ? '$symbol$fixed' : '$fixed ${currency.toUpperCase()}';
}
