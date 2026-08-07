import 'package:flutter/material.dart';

import '../data/location_models.dart';
import '../l10n/app_strings.dart';
import '../l10n/l10n_text.dart';
import '../l10n/locale_controller.dart';
import '../meto_theme.dart';
import '../services/location_catalog_service.dart';

/// Form / filtre için ülke → bölge → şehir seçici.
class LocationCascadePicker extends StatefulWidget {
  const LocationCascadePicker({
    super.key,
    required this.value,
    required this.onChanged,
    this.requireFullSelection = true,
    this.showAnywhereOption = false,
    this.compact = false,
  });

  final LocationData value;
  final ValueChanged<LocationData> onChanged;

  /// true: form — ülke+state+city zorunlu akış
  final bool requireFullSelection;

  /// true: filtre — "Konumdan Bağımsız" seçeneği
  final bool showAnywhereOption;

  final bool compact;

  @override
  State<LocationCascadePicker> createState() => _LocationCascadePickerState();
}

class _LocationCascadePickerState extends State<LocationCascadePicker> {
  final _svc = LocationCatalogService.instance;

  List<LocCountry> _countries = const [];
  List<String> _states = const [];
  List<String> _cities = const [];
  bool _loading = true;
  bool _loadingStates = false;
  bool _loadingCities = false;

  /// null/empty = konumdan bağımsız (filtre)
  String? _countryCode;
  String? _state;
  String? _city;

  @override
  void initState() {
    super.initState();
    _hydrateFromValue();
    _bootstrap();
  }

  @override
  void didUpdateWidget(covariant LocationCascadePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _hydrateFromValue();
      _reloadCascade();
    }
  }

  void _hydrateFromValue() {
    final v = widget.value;
    if (v.countryCode == LocationCatalogService.anywhereCode ||
        (widget.showAnywhereOption && v.countryCode.isEmpty && v.isEmpty)) {
      _countryCode = widget.showAnywhereOption
          ? LocationCatalogService.anywhereCode
          : null;
    } else {
      _countryCode = v.countryCode.isEmpty ? null : v.countryCode;
    }
    _state = v.state.isEmpty ? null : v.state;
    _city = v.city.isEmpty ? null : v.city;
  }

  Future<void> _bootstrap() async {
    setState(() => _loading = true);
    await _svc.ensureCountries();
    if (!mounted) return;
    _countries = _svc.countries;
    if (!widget.showAnywhereOption &&
        (_countryCode == null || _countryCode!.isEmpty)) {
      _countryCode = _svc.defaultCountryCode();
    }
    await _reloadCascade();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _reloadCascade() async {
    final code = _countryCode;
    if (code == null ||
        code.isEmpty ||
        code == LocationCatalogService.anywhereCode) {
      setState(() {
        _states = const [];
        _cities = const [];
      });
      return;
    }
    setState(() => _loadingStates = true);
    final states = await _svc.stateNames(code);
    if (!mounted) return;
    if (_state != null && !states.contains(_state)) {
      _state = null;
      _city = null;
    }
    setState(() {
      _states = states;
      _loadingStates = false;
    });
    await _reloadCities();
  }

  Future<void> _reloadCities() async {
    final code = _countryCode;
    final state = _state;
    if (code == null ||
        code == LocationCatalogService.anywhereCode ||
        state == null ||
        state.isEmpty) {
      setState(() => _cities = const []);
      return;
    }
    setState(() => _loadingCities = true);
    final cities = await _svc.cityNames(countryCode: code, stateName: state);
    if (!mounted) return;
    if (_city != null && !cities.contains(_city)) {
      _city = null;
    }
    setState(() {
      _cities = cities;
      _loadingCities = false;
    });
  }

  void _emit() {
    if (_countryCode == LocationCatalogService.anywhereCode ||
        _countryCode == null ||
        _countryCode!.isEmpty) {
      widget.onChanged(const LocationData());
      return;
    }
    final country = _svc.countryByCode(_countryCode!);
    widget.onChanged(
      LocationData(
        countryCode: _countryCode!,
        country: country?.labelFor(LocaleController.instance.lang) ??
            country?.nameTr ??
            _countryCode!,
        state: _state ?? '',
        city: _city ?? '',
      ),
    );
  }

  LocCountry? get _selectedCountry {
    final c = _countryCode;
    if (c == null || c == LocationCatalogService.anywhereCode) return null;
    return _svc.countryByCode(c);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final gap = widget.compact ? 8.0 : 16.0;
    final country = _selectedCountry;
    final stateLabel = country?.stateLabelTr() ?? 'Bölge';
    final cityLabel = country?.cityLabelTr() ?? 'Şehir';
    final countryLockedToAnywhere =
        _countryCode == LocationCatalogService.anywhereCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label(S.auto('Ülke')),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _dropdownCountryValue(),
          isExpanded: true,
          decoration: _dec(S.auto('Ülke seçin')),
          items: [
            if (widget.showAnywhereOption)
              DropdownMenuItem(
                value: LocationCatalogService.anywhereCode,
                child: Text(S.auto('Konumdan Bağımsız')),
              ),
            for (final c in _countries)
              DropdownMenuItem(
                value: c.code,
                child: Text(
                  '${c.flagEmoji} ${c.labelFor(LocaleController.instance.lang)}',
                ),
              ),
          ],
          onChanged: (v) async {
            setState(() {
              _countryCode = v;
              _state = null;
              _city = null;
            });
            await _reloadCascade();
            _emit();
          },
        ),
        if (!countryLockedToAnywhere) ...[
          SizedBox(height: gap),
          _label(S.auto(stateLabel)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _state != null && _states.contains(_state)
                ? _state
                : (widget.showAnywhereOption
                    ? LocationCatalogService.allStateLabel
                    : null),
            isExpanded: true,
            decoration: _dec(
              _loadingStates
                  ? S.auto('Yükleniyor…')
                  : widget.showAnywhereOption
                      ? S.auto('Tüm $stateLabel')
                      : S.auto('$stateLabel seçin'),
            ),
            items: [
              if (widget.showAnywhereOption)
                DropdownMenuItem(
                  value: LocationCatalogService.allStateLabel,
                  child: Text(S.auto('Tüm ülke / tüm $stateLabel')),
                ),
              for (final s in _states)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: _loadingStates
                ? null
                : (v) async {
                    setState(() {
                      if (v == null ||
                          v == LocationCatalogService.allStateLabel) {
                        _state = null;
                      } else {
                        _state = v;
                      }
                      _city = null;
                    });
                    await _reloadCities();
                    _emit();
                  },
          ),
          if (_state != null && _state!.isNotEmpty) ...[
            SizedBox(height: gap),
            _label(S.auto(cityLabel)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _city != null && _cities.contains(_city)
                  ? _city
                  : (widget.showAnywhereOption
                      ? LocationCatalogService.allCityLabel
                      : null),
              isExpanded: true,
              decoration: _dec(
                _loadingCities
                    ? S.auto('Yükleniyor…')
                    : widget.showAnywhereOption
                        ? S.auto('Tüm $cityLabel')
                        : S.auto('$cityLabel seçin'),
              ),
              items: [
                if (widget.showAnywhereOption)
                  DropdownMenuItem(
                    value: LocationCatalogService.allCityLabel,
                    child: Text(S.auto('Tüm $cityLabel')),
                  ),
                for (final c in _cities)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: _loadingCities
                  ? null
                  : (v) {
                      setState(() {
                        if (v == null ||
                            v == LocationCatalogService.allCityLabel) {
                          _city = null;
                        } else {
                          _city = v;
                        }
                      });
                      _emit();
                    },
            ),
          ],
        ],
      ],
    );
  }

  String? _dropdownCountryValue() {
    final c = _countryCode;
    if (c == null || c.isEmpty) {
      return widget.showAnywhereOption
          ? LocationCatalogService.anywhereCode
          : null;
    }
    return c;
  }

  Widget _label(String text) => L10nText(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: MetoColors.mutedFg,
        ),
      );

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: MetoColors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}
